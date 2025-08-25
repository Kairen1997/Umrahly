defmodule UmrahlyWeb.UserPackageDetailsLive do
  use UmrahlyWeb, :live_view

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Packages

  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:selected_schedule_id, nil)

    {:ok, socket}
  end


  def handle_params(%{"id" => package_id}, _url, socket) do
    package = Packages.get_package_with_schedules!(package_id)

    # Validate package has required fields
    if is_nil(package.price) do
      socket =
        socket
        |> put_flash(:error, "Package data is incomplete (missing price). Please contact support.")
        |> push_navigate(to: ~p"/packages")

      {:noreply, socket}
    else
      # Only show active packages to users
      if package.status != "active" do
        {:noreply, push_navigate(socket, to: ~p"/packages")}
      else
        # Get current user for income-based recommendations
        current_user = socket.assigns[:current_user]

        # Analyze schedules and rank them by affordability
        ranked_schedules = rank_schedules_by_affordability(package.package_schedules || [], current_user, package)

        # Don't pre-select any schedule - let user choose
        selected_schedule_id = nil

        socket =
          socket
          |> assign(:package, package)
          |> assign(:current_user, current_user)
          |> assign(:ranked_schedules, ranked_schedules)
          |> assign(:selected_schedule_id, selected_schedule_id)
          |> assign(:current_page, "packages")
          |> assign(:page_title, package.name)

        {:noreply, socket}
      end
    end
  rescue
    e ->
      # Handle any errors gracefully
      socket =
        socket
        |> put_flash(:error, "Failed to load package details: #{Exception.message(e)}")
        |> push_navigate(to: ~p"/packages")

      {:noreply, socket}
  end

      # Handle schedule selection with proper error handling
  def handle_event("select_schedule", %{"schedule_id" => schedule_id}, socket) do
    # Convert the string schedule_id to an integer to match the database IDs
    case Integer.parse(schedule_id) do
      {new_selected_id, _} ->
        updated_socket =
          socket
          |> assign(:selected_schedule_id, new_selected_id)
          |> put_flash(:info, "Schedule #{new_selected_id} selected!")
        {:noreply, updated_socket}
      :error ->
        updated_socket = put_flash(socket, :error, "Failed to parse schedule ID")
        {:noreply, updated_socket}
    end
  end

    # Rank schedules by affordability based on user's monthly income
  defp rank_schedules_by_affordability(schedules, current_user, package) do
    # Always ensure all schedules have the required fields
    base_schedules = Enum.map(schedules, fn schedule ->
      total_price = calculate_schedule_price(schedule, package)

      schedule
      |> Map.put(:total_price, total_price)
      |> Map.put(:affordability_ratio, nil)
      |> Map.put(:affordability_score, 0)
      |> Map.put(:affordability_level, "unknown")
      |> Map.put(:is_recommended, false)
    end)

    case current_user && current_user.monthly_income do
      nil ->
        # If no user or no income info, return schedules with base fields
        base_schedules

      monthly_income when is_integer(monthly_income) and monthly_income > 0 ->
        Enum.map(base_schedules, fn schedule ->
          # Calculate affordability metrics
          affordability_ratio = schedule.total_price / monthly_income
          affordability_score = calculate_affordability_score(affordability_ratio)
          affordability_level = get_affordability_level(affordability_ratio)
          is_recommended = is_schedule_recommended?(affordability_ratio, schedule)

          schedule
          |> Map.put(:affordability_ratio, affordability_ratio)
          |> Map.put(:affordability_score, affordability_score)
          |> Map.put(:affordability_level, affordability_level)
          |> Map.put(:is_recommended, is_recommended)
        end)
        |> Enum.sort_by(& &1.affordability_score, :desc)

      _ ->
        # Invalid income data, return schedules with base fields
        base_schedules
    end
  end

  # Calculate total price for a schedule (base price + override)
  defp calculate_schedule_price(schedule, package) do
    base_price = package.price
    override_price = if schedule.price_override, do: Decimal.to_integer(schedule.price_override), else: 0
    base_price + override_price
  end

  # Calculate affordability score (higher is better)
  defp calculate_affordability_score(affordability_ratio) do
    cond do
      affordability_ratio <= 0.3 -> 100    # Very affordable (≤30% of income)
      affordability_ratio <= 0.5 -> 90     # Highly affordable (≤50% of income)
      affordability_ratio <= 0.8 -> 80     # Affordable (≤80% of income)
      affordability_ratio <= 1.0 -> 70     # Manageable (≤100% of income)
      affordability_ratio <= 1.5 -> 50     # Challenging (≤150% of income)
      affordability_ratio <= 2.0 -> 30     # Difficult (≤200% of income)
      true -> 10                            # Very difficult (>200% of income)
    end
  end

  # Get affordability level description
  defp get_affordability_level(affordability_ratio) do
    cond do
      affordability_ratio <= 0.3 -> "very_affordable"
      affordability_ratio <= 0.5 -> "highly_affordable"
      affordability_ratio <= 0.8 -> "affordable"
      affordability_ratio <= 1.0 -> "manageable"
      affordability_ratio <= 1.5 -> "challenging"
      affordability_ratio <= 2.0 -> "difficult"
      true -> "very_difficult"
    end
  end

  # Determine if a schedule should be recommended
  defp is_schedule_recommended?(affordability_ratio, schedule) do
    # Recommend if affordable and has good quota
    affordability_ratio <= 1.0 and schedule.quota > 5
  end

  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div class="max-w-6xl mx-auto space-y-6 px-4">


        <!-- Back Button -->
        <div class="flex items-center">
          <a
            href="/packages"
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Back to Packages
          </a>
        </div>

        <!-- Package Header -->
        <div class="bg-white rounded-lg shadow-lg overflow-hidden">
          <!-- Package Image -->
          <div class="h-80 bg-gray-200 relative">
            <%= if @package.picture do %>
              <img
                src={@package.picture}
                alt={"#{@package.name} picture"}
                class="w-full h-full object-cover"
              />
            <% else %>
              <div class="w-full h-full flex items-center justify-center">
                <svg class="w-32 h-32 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 002 2v12a2 2 0 002 2z" />
                </svg>
              </div>
            <% end %>

            <!-- Status Badge -->
            <div class="absolute top-4 right-4">
              <span class="inline-flex px-3 py-1 text-sm font-semibold rounded-full bg-green-100 text-green-800">
                <%= @package.status %>
              </span>
            </div>
          </div>

          <!-- Package Info -->
          <div class="p-6">
            <div class="flex flex-col lg:flex-row lg:items-start lg:justify-between">
              <div class="flex-1">
                <h1 class="text-2xl font-bold text-gray-900 mb-3"><%= @package.name %></h1>

                <%= if @package.description && @package.description != "" do %>
                  <p class="text-base text-gray-600 mb-4 leading-relaxed"><%= @package.description %></p>
                <% end %>

                <!-- Key Details Grid -->
                <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
                  <div class="text-center">
                    <div class="text-2xl font-bold text-blue-600">RM <%= @package.price %></div>
                    <div class="text-xs text-gray-500">Total Price</div>
                  </div>
                  <div class="text-center">
                    <div class="text-2xl font-bold text-gray-900"><%= @package.duration_days %></div>
                    <div class="text-xs text-gray-500">Days</div>
                  </div>
                  <div class="text-center">
                    <div class="text-2xl font-bold text-gray-900"><%= @package.duration_nights %></div>
                    <div class="text-xs text-gray-500">Nights</div>
                  </div>
                  <div class="text-center">
                    <div class="text-2xl font-bold text-green-600">
                      <%= length(@package.package_schedules) %>
                    </div>
                    <div class="text-xs text-gray-500">Available Schedules</div>
                  </div>
                </div>

                <!-- Income-Based Note -->
                <%= if @current_user && @current_user.monthly_income do %>
                  <div class="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
                    <div class="flex items-center text-sm text-blue-800">
                      <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <span>
                        <strong>Smart Recommendation:</strong> Based on your monthly income of RM <%= @current_user.monthly_income %>,
                        we'll show you the most suitable departure dates below.
                      </span>
                    </div>
                  </div>
                <% end %>
              </div>

              <!-- Action Buttons -->
              <div class="lg:ml-6 mt-4 lg:mt-0">
                <div class="space-y-3">
                  <%= if length(@ranked_schedules) > 0 do %>
                    <%= if @selected_schedule_id do %>
                      <a
                        href={~p"/book/#{@package.id}/#{@selected_schedule_id}"}
                        class="w-full bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors font-medium text-base text-center block"
                      >
                        Book This Package
                      </a>
                    <% else %>
                      <button disabled class="w-full bg-gray-400 text-white px-6 py-3 rounded-lg cursor-not-allowed font-medium text-base">
                        Select a Date to Book
                      </button>
                    <% end %>
                  <% else %>
                    <button disabled class="w-full bg-gray-400 text-white px-6 py-3 rounded-lg cursor-not-allowed font-medium text-base">
                      No Available Schedules
                    </button>
                  <% end %>
                  <button class="w-full bg-gray-100 text-gray-700 px-6 py-3 rounded-lg hover:bg-gray-200 transition-colors font-medium text-sm">
                    Download Brochure
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Package Details Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Accommodation Details -->
          <div class="bg-white rounded-lg shadow-lg p-5">
            <h3 class="text-lg font-semibold text-gray-900 mb-3 flex items-center">
              <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
              Accommodation
            </h3>
            <%= if @package.accommodation_type && @package.accommodation_type != "" do %>
              <div class="space-y-2">
                <div>
                  <span class="font-medium text-gray-900">Type:</span>
                  <span class="ml-2 text-gray-600"><%= @package.accommodation_type %></span>
                </div>
                <%= if @package.accommodation_details && @package.accommodation_details != "" do %>
                  <div>
                    <span class="font-medium text-gray-900">Details:</span>
                    <p class="mt-1 text-gray-600 text-sm"><%= @package.accommodation_details %></p>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-500">Accommodation details not available</p>
            <% end %>
          </div>

          <!-- Transport Details -->
          <div class="bg-white rounded-lg shadow-lg p-5">
            <h3 class="text-lg font-semibold text-gray-900 mb-3 flex items-center">
              <svg class="w-5 h-5 mr-2 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              Transportation
            </h3>
            <%= if @package.transport_type && @package.transport_type != "" do %>
              <div class="space-y-2">
                <div>
                  <span class="font-medium text-gray-900">Type:</span>
                  <span class="ml-2 text-gray-600"><%= @package.transport_type %></span>
                </div>
                <%= if @package.transport_details && @package.transport_details != "" do %>
                  <div>
                    <span class="font-medium text-gray-900">Details:</span>
                    <p class="mt-1 text-gray-600 text-sm"><%= @package.transport_details %></p>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-500">Transportation details not available</p>
            <% end %>
          </div>
        </div>

        <!-- Selected Schedule Display -->
        <%= if @selected_schedule_id do %>
          <%= if selected_schedule = Enum.find(@ranked_schedules, & &1.id == @selected_schedule_id) do %>
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
              <div class="flex items-center justify-between">
                <div class="flex items-center">
                  <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <span class="text-sm font-medium text-blue-900">Selected Departure Date:</span>
                  <span class="ml-2 text-sm font-semibold text-blue-800">
                    <%= Calendar.strftime(selected_schedule.departure_date, "%B %d, %Y") %>
                  </span>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>



        <!-- Income-Based Recommendations -->
        <%= if @current_user && @current_user.monthly_income do %>
          <div class="bg-gradient-to-r from-green-50 to-blue-50 border border-green-200 rounded-lg p-5">
            <div class="flex items-center mb-4">
              <svg class="w-6 h-6 mr-3 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <h3 class="text-lg font-semibold text-gray-900">Personalized Date Recommendations</h3>
            </div>

            <div class="mb-4">
              <p class="text-sm text-gray-600 mb-2">
                Based on your monthly income of <span class="font-semibold text-green-700">RM <%= @current_user.monthly_income %></span>,
                we've analyzed all available dates and ranked them by affordability:
              </p>

              <!-- Affordability Legend -->
              <div class="flex flex-wrap gap-2 mb-4">
                <div class="flex items-center text-xs">
                  <div class="w-3 h-3 bg-green-500 rounded-full mr-1"></div>
                  <span class="text-gray-600">Very Affordable (≤30% of income)</span>
                </div>
                <div class="flex items-center text-xs">
                  <div class="w-3 h-3 bg-blue-500 rounded-full mr-1"></div>
                  <span class="text-gray-600">Affordable (≤80% of income)</span>
                </div>
                <div class="flex items-center text-xs">
                  <div class="w-3 h-3 bg-yellow-500 rounded-full mr-1"></div>
                  <span class="text-gray-600">Manageable (≤100% of income)</span>
                </div>
                <div class="flex items-center text-xs">
                  <div class="w-3 h-3 bg-orange-500 rounded-full mr-1"></div>
                  <span class="text-gray-600">Challenging (≤150% of income)</span>
                </div>
                <div class="flex items-center text-xs">
                  <div class="w-3 h-3 bg-red-500 rounded-full mr-1"></div>
                  <span class="text-gray-600">Difficult (>150% of income)</span>
                </div>
              </div>
            </div>

            <!-- Top Recommended Dates -->
            <%= if Enum.any?(@ranked_schedules, & &1.is_recommended) do %>
              <div class="mb-4">
                <h4 class="text-md font-semibold text-gray-800 mb-3">🌟 Top Recommendations for You</h4>
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                  <%= for schedule <- Enum.take(Enum.filter(@ranked_schedules, & &1.is_recommended), 3) do %>
                    <div class="bg-white border-2 border-green-300 rounded-lg p-3 shadow-sm">
                      <div class="text-center">
                        <div class="flex items-center justify-center mb-2">
                          <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800 mr-2">
                            Recommended
                          </span>
                                                  <span class={[
                          "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                          case schedule.affordability_level do
                            "very_affordable" -> "bg-green-100 text-green-800"
                            "highly_affordable" -> "bg-blue-100 text-blue-800"
                            "affordable" -> "bg-blue-100 text-blue-800"
                            "manageable" -> "bg-yellow-100 text-yellow-800"
                            "challenging" -> "bg-orange-100 text-orange-800"
                            "difficult" -> "bg-red-100 text-red-800"
                            "very_difficult" -> "bg-red-100 text-red-800"
                            "unknown" -> "bg-gray-100 text-gray-600"
                            _ -> "bg-gray-100 text-gray-800"
                          end
                        ]}>
                          <%= if schedule.affordability_level == "unknown" do %>
                            Not Available
                          <% else %>
                            <%= String.replace(schedule.affordability_level, "_", " ") |> String.capitalize() %>
                          <% end %>
                        </span>
                        </div>
                        <div class="text-base font-semibold text-gray-900">
                          <%= Calendar.strftime(schedule.departure_date, "%B %d, %Y") %>
                        </div>
                        <div class="text-xs text-gray-500 mt-1">
                          <%= Calendar.strftime(schedule.departure_date, "%A") %>
                        </div>
                                                <div class="mt-2 space-y-1">
                          <div class="text-xs text-gray-600">
                            <span class="font-medium">Base Price:</span>
                            <span class="font-medium text-gray-700">RM <%= @package.price %></span>
                          </div>
                          <%= if schedule.price_override && Decimal.to_integer(schedule.price_override) > 0 do %>
                            <div class="text-xs text-gray-600">
                              <span class="font-medium">Price Override:</span>
                              <span class="font-medium text-orange-600">+RM <%= Decimal.to_integer(schedule.price_override) %></span>
                            </div>
                          <% end %>
                          <div class="text-xs text-gray-600">
                            <span class="font-medium">Total Price:</span>
                            <span class="font-bold text-green-700">RM <%= schedule.total_price %></span>
                          </div>
                          <div class="text-xs text-gray-600">
                            <span class="font-medium">Affordability:</span>
                            <span class="font-medium">
                              <%= if schedule.affordability_ratio do %>
                                <%= Float.round(schedule.affordability_ratio * 100, 1) %>%
                              <% else %>
                                Not available
                              <% end %>
                            </span> of monthly income
                          </div>
                          <div class="text-xs text-gray-600">
                            <span class="font-medium">Score:</span>
                            <span class="font-medium text-blue-600">
                              <%= if schedule.affordability_score > 0 do %>
                                <%= schedule.affordability_score %>/100
                              <% else %>
                                Not available
                              <% end %>
                            </span>
                          </div>
                          <div class="text-xs text-gray-600">
                            <span class="font-medium">Quota:</span>
                            <span class="font-medium"><%= schedule.quota %></span> spots
                          </div>
                        </div>
                        <div class="mt-3 text-center">
                          <span class={[
                            "inline-flex px-3 py-2 text-xs font-semibold rounded-full",
                            if @selected_schedule_id == schedule.id do
                              "bg-blue-100 text-blue-800 border-2 border-blue-300"
                            else
                              "bg-gray-100 text-gray-600 border-2 border-gray-300"
                            end
                          ]}>
                            <%= if @selected_schedule_id == schedule.id do %>
                              ✓ Currently Selected
                            <% else %>
                              Click below to select
                            <% end %>
                          </span>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <!-- No Income Information Available -->
          <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-5">
            <div class="flex items-center mb-4">
              <svg class="w-6 h-6 mr-3 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
              <h3 class="text-lg font-semibold text-gray-900">Complete Your Profile for Personalized Recommendations</h3>
            </div>

            <p class="text-sm text-gray-600 mb-4">
              To get personalized date recommendations based on your budget, please complete your profile with your monthly income information.
            </p>

            <a href="/profile" class="inline-flex items-center px-4 py-2 bg-yellow-600 text-white text-sm font-medium rounded-lg hover:bg-yellow-700 transition-colors">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
              Complete Profile
            </a>
          </div>
        <% end %>

        <!-- Available Schedules -->
        <%= if @ranked_schedules && length(@ranked_schedules) > 0 do %>
          <div class="bg-white rounded-lg shadow-lg p-5">
            <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
              <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              All Available Departure Dates
              <%= if @current_user && @current_user.monthly_income do %>
                <span class="ml-2 text-sm font-normal text-gray-500">(Ranked by affordability)</span>
              <% end %>
            </h3>

            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              <%= for schedule <- @ranked_schedules do %>
                <div class={[
                  "border rounded-lg p-3 transition-colors",
                  cond do
                    @selected_schedule_id == schedule.id ->
                      "border-2 border-blue-500 bg-blue-50 shadow-md"
                    schedule.is_recommended ->
                      "border-2 border-green-300 bg-green-50"
                    true ->
                      "border-gray-200 hover:border-blue-300"
                  end
                ]}>
                  <div class="text-center">
                    <%= if schedule.is_recommended do %>
                      <div class="mb-2">
                        <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
                          ⭐ Recommended
                        </span>
                      </div>
                    <% end %>
                    <div class="text-base font-semibold text-gray-900">
                      <%= Calendar.strftime(schedule.departure_date, "%B %d, %Y") %>
                    </div>
                    <div class="text-xs text-gray-500 mt-1">
                      <%= Calendar.strftime(schedule.departure_date, "%A") %>
                    </div>
                    <div class="mt-2 space-y-1">
                      <div class="text-xs text-gray-600">
                        <span class="font-medium">Base:</span>
                        <span class="font-medium text-gray-700">RM <%= @package.price %></span>
                      </div>
                      <%= if schedule.price_override && Decimal.to_integer(schedule.price_override) > 0 do %>
                        <div class="text-xs text-gray-600">
                          <span class="font-medium">Override:</span>
                          <span class="font-medium text-orange-600">+RM <%= Decimal.to_integer(schedule.price_override) %></span>
                        </div>
                      <% end %>
                      <div class="text-xs text-gray-600">
                        <span class="font-medium">Total:</span>
                        <span class="font-bold text-green-700">RM <%= schedule.total_price %></span>
                      </div>
                      <div class="mt-2 flex items-center justify-between">
                        <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800">
                          Quota: <%= schedule.quota %>
                        </span>
                      </div>
                    </div>

                    <%= if @current_user && @current_user.monthly_income do %>
                      <div class="mt-2 text-xs text-gray-600">
                        <span class="font-medium">Affordability:</span>
                        <span class="font-medium">
                          <%= if schedule.affordability_ratio do %>
                            <%= Float.round(schedule.affordability_ratio * 100, 1) %>%
                          <% else %>
                            Not available
                          <% end %>
                        </span> of monthly income
                      </div>
                      <div class="mt-1 text-xs text-gray-600">
                        <span class="font-medium">Score:</span>
                        <span class="font-medium text-blue-600">
                          <%= if schedule.affordability_score > 0 do %>
                            <%= schedule.affordability_score %>/100
                          <% else %>
                            Not available
                          <% end %>
                        </span>
                      </div>
                    <% end %>

                    <button
                      phx-click="select_schedule"
                      phx-value-schedule_id={schedule.id}
                      class={[
                        "mt-2 w-full px-3 py-2 rounded-lg text-xs font-medium text-center block transition-colors",
                        if @selected_schedule_id == schedule.id do
                          "bg-blue-600 text-white border-2 border-blue-700"
                        else
                          "bg-gray-100 text-gray-700 hover:bg-gray-200 border-2 border-gray-300"
                        end
                      ]}
                    >
                      <!-- Debug: selected_id=<%= @selected_schedule_id %> schedule_id=<%= schedule.id %> types: selected=<%= @selected_schedule_id |> inspect %> schedule=<%= schedule.id |> inspect %> -->
                      <%= if @selected_schedule_id == schedule.id do %>
                        ✓ Selected
                      <% else %>
                        Select This Date
                      <% end %>
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% else %>
          <!-- No Schedules Available -->
          <div class="bg-gray-50 border border-gray-200 rounded-lg p-5">
            <div class="text-center">
              <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 002 2v12a2 2 0 002 2z" />
              </svg>
              <h3 class="text-lg font-semibold text-gray-900 mb-2">No Departure Dates Available</h3>
              <p class="text-gray-600 mb-4">
                This package currently doesn't have any available departure dates. Please check back later or contact us for more information.
              </p>
              <a href="/packages" class="inline-flex items-center px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                </svg>
                Browse Other Packages
              </a>
            </div>
          </div>
        <% end %>

        <!-- Itinerary Preview -->
        <%= if length(@package.itineraries) > 0 do %>
          <div class="bg-white rounded-lg shadow-lg p-5">
            <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
              <svg class="w-5 h-5 mr-2 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
              </svg>
              Itinerary Preview
            </h3>

            <div class="space-y-3">
              <%= for itinerary <- Enum.take(@package.itineraries, 3) do %>
                <div class="border-l-4 border-blue-500 pl-3 mb-3">
                  <div class="flex items-start">
                    <div class="flex-shrink-0 w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center mr-3">
                      <span class="text-xs font-semibold text-blue-600">Day <%= itinerary.day_number %></span>
                    </div>
                    <div class="flex-1">
                      <h4 class="font-medium text-gray-900 text-sm"><%= itinerary.day_title %></h4>
                      <%= if itinerary.day_description && itinerary.day_description != "" do %>
                        <p class="text-xs text-gray-600 mt-1"><%= itinerary.day_description %></p>
                      <% end %>

                      <!-- Itinerary Items -->
                      <%= if itinerary.itinerary_items && length(itinerary.itinerary_items) > 0 do %>
                        <div class="mt-2 space-y-2">
                          <%= for item <- Enum.take(itinerary.itinerary_items, 3) do %>
                            <div class="bg-gray-50 rounded-lg p-2">
                              <div class="font-medium text-xs text-gray-900"><%= item["title"] %></div>
                              <%= if item["description"] && item["description"] != "" do %>
                                <div class="text-xs text-gray-600 mt-1"><%= item["description"] %></div>
                              <% end %>
                            </div>
                          <% end %>
                          <%= if length(itinerary.itinerary_items) > 3 do %>
                            <div class="text-xs text-gray-500 text-center">
                              +<%= length(itinerary.itinerary_items) - 3 %> more activities
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if length(@package.itineraries) > 3 do %>
                <div class="text-center pt-3">
                  <p class="text-xs text-gray-500">
                    +<%= length(@package.itineraries) - 3 %> more days in the full itinerary
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Call to Action -->
        <div class="bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg shadow-lg p-6 text-center text-white">
          <h3 class="text-xl font-bold mb-3">Ready to Book Your Umrah Journey?</h3>
          <p class="text-base mb-4 opacity-90">
            Don't miss out on this amazing opportunity. Book now and secure your spot!
          </p>
            <div class="flex flex-col sm:flex-row gap-3 justify-center">
              <%= if @selected_schedule_id do %>
                <a
                  href={~p"/book/#{@package.id}/#{@selected_schedule_id}"}
                  class="bg-white text-blue-600 px-6 py-2 rounded-lg font-semibold hover:bg-gray-100 transition-colors text-sm"
                >
                  Book This Package
                </a>
              <% else %>
                <button disabled class="bg-gray-300 text-gray-500 px-6 py-2 rounded-lg font-semibold cursor-not-allowed text-sm">
                  No Schedules Available
                </button>
              <% end %>
              <button class="border-2 border-white text-white px-6 py-2 rounded-lg font-semibold hover:bg-white hover:text-blue-600 transition-colors text-sm">
                Contact Us
              </button>
            </div>
        </div>
      </div>
    </.sidebar>
    """
  end
end
