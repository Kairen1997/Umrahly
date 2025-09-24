defmodule UmrahlyWeb.UserPackagesLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Packages

  # Add authentication mount to ensure current_user is available
  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    # Get all active packages with schedules
    packages = Packages.list_active_packages_with_schedules()

    # Get current user for income-based recommendations
    current_user = socket.assigns.current_user

    # Mark packages as recommended based on user income
    packages_with_recommendations = mark_recommended_packages(packages, current_user)

    # Apply initial sorting by name (default sort)
    sorted_packages = sort_packages_by_criteria(packages_with_recommendations, "name")

    socket =
      socket
      |> assign(:packages, packages_with_recommendations)
      |> assign(:filtered_packages, sorted_packages)
      |> assign(:search_query, "")
      |> assign(:search_sort, "name")
      |> assign(:current_page, "packages")
      |> assign(:page_title, "Available Packages")
      |> assign(:current_page_number, 1)
      |> assign(:packages_per_page, 6)
      |> assign(:total_pages, :math.ceil(length(sorted_packages) / 6) |> trunc)

    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    # Read requested page from URL params, default to 1
    requested_page =
      case Map.get(params, "page") do
        nil -> 1
        page_str when is_binary(page_str) ->
          case Integer.parse(page_str) do
            {num, _} -> num
            :error -> 1
          end
      end

    total_pages = socket.assigns.total_pages
    safe_total_pages = if is_integer(total_pages) and total_pages > 0 do
      total_pages
    else
      1
    end

    valid_page = max(1, min(requested_page, safe_total_pages))

    {:noreply, assign(socket, :current_page_number, valid_page)}
  end

  def handle_event("search_packages", %{"query" => search_query, "sort" => search_sort}, socket) do
    # First filter, then sort the filtered results
    filtered_packages = filter_packages(socket.assigns.packages, search_query)
    sorted_packages = sort_packages_by_criteria(filtered_packages, search_sort)
    # Reset to first page when searching
    total_pages = :math.ceil(length(sorted_packages) / socket.assigns.packages_per_page) |> trunc

    socket =
      socket
      |> assign(:filtered_packages, sorted_packages)
      |> assign(:search_query, search_query)
      |> assign(:search_sort, search_sort)
      |> assign(:current_page_number, 1)
      |> assign(:total_pages, total_pages)

    {:noreply, push_patch(socket, to: ~p"/packages?page=1")}
  end

    # Handle case where only query is provided (when typing in search box)
  def handle_event("search_packages", %{"query" => search_query}, socket) do
    # Use current sort value from socket
    current_sort = socket.assigns.search_sort

    # First filter, then sort the filtered results
    filtered_packages = filter_packages(socket.assigns.packages, search_query)
    sorted_packages = sort_packages_by_criteria(filtered_packages, current_sort)
    # Reset to first page when searching
    total_pages = :math.ceil(length(sorted_packages) / socket.assigns.packages_per_page) |> trunc

    socket =
      socket
      |> assign(:filtered_packages, sorted_packages)
      |> assign(:search_query, search_query)
      |> assign(:current_page_number, 1)
      |> assign(:total_pages, total_pages)

    {:noreply, push_patch(socket, to: ~p"/packages?page=1")}
  end

  def handle_event("clear_search", _params, socket) do
    # Apply default sorting when clearing
    sorted_packages = sort_packages_by_criteria(socket.assigns.packages, "name")

    # Reset to first page when clearing
    total_pages = :math.ceil(length(sorted_packages) / socket.assigns.packages_per_page) |> trunc

    socket =
      socket
      |> assign(:filtered_packages, sorted_packages)
      |> assign(:search_query, "")
      |> assign(:search_sort, "name")
      |> assign(:current_page_number, 1)
      |> assign(:total_pages, total_pages)

    {:noreply, push_patch(socket, to: ~p"/packages?page=1")}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page_number = String.to_integer(page)

    # Ensure page number is within valid range
    valid_page = max(1, min(page_number, socket.assigns.total_pages))

    # Navigate via URL patch so the browser shows the page number
    {:noreply, push_patch(socket, to: ~p"/packages?page=#{valid_page}")}
  end

  defp filter_packages(packages, search_query) do


    filtered = packages
    |> Enum.filter(fn package ->
      cond do
        search_query == "" ->
          true
        package.name && String.contains?(String.downcase(package.name), String.downcase(search_query)) ->
          true
        true ->
          false
      end
    end)

    filtered
  end

  defp sort_packages_by_criteria(packages, sort_criteria) do
    # First, separate recommended and non-recommended packages
    {recommended_packages, non_recommended_packages} =
      Enum.split_with(packages, & &1.is_recommended)

    # Sort each group by the selected criteria
    sorted_recommended = sort_packages_by_criteria_internal(recommended_packages, sort_criteria)
    sorted_non_recommended = sort_packages_by_criteria_internal(non_recommended_packages, sort_criteria)

    # Combine: recommended packages first, then non-recommended packages
    sorted_recommended ++ sorted_non_recommended
  end

  # Internal sorting function for packages within each group
  defp sort_packages_by_criteria_internal(packages, sort_criteria) do
    case sort_criteria do
      "name" -> Enum.sort_by(packages, &String.downcase(&1.name))
      "price_low" -> Enum.sort_by(packages, & &1.price)
      "price_high" -> Enum.sort_by(packages, & &1.price, :desc)
      "duration" -> Enum.sort_by(packages, & &1.duration_days)
      "recent" -> Enum.sort_by(packages, & &1.inserted_at, :desc)
      _ -> packages
    end
  end

  # Mark packages as recommended based on user's monthly income
  defp mark_recommended_packages(packages, current_user) do
    case current_user && current_user.monthly_income do
      nil ->
        # If no user or no income info, no packages are recommended
        Enum.map(packages, &Map.put(&1, :is_recommended, false))

      monthly_income when is_integer(monthly_income) and monthly_income > 0 ->
        Enum.map(packages, fn package ->
          is_recommended = is_package_recommended_for_income?(package, monthly_income)
          Map.put(package, :is_recommended, is_recommended)
        end)

      _ ->
        # Invalid income data, no packages are recommended
        Enum.map(packages, &Map.put(&1, :is_recommended, false))
    end
  end

  # Determine if a package is recommended based on user's monthly income
  defp is_package_recommended_for_income?(package, monthly_income) do
    # Calculate affordability ratio: package price / monthly income
    affordability_ratio = package.price / monthly_income

    # Package is recommended if:
    # 1. Price is less than 50% of monthly income (very affordable)
    # 2. Price is less than 80% of monthly income (affordable)
    # 3. Price is less than 120% of monthly income (manageable with savings)

    cond do
      affordability_ratio <= 0.5 -> true    # Very affordable
      affordability_ratio <= 0.8 -> true    # Affordable
      affordability_ratio <= 1.2 -> true    # Manageable with savings
      true -> false                          # May be too expensive
    end
  end

    # Get paginated packages for the current page
  defp get_paginated_packages(packages, current_page, packages_per_page) do
    start_index = (current_page - 1) * packages_per_page
    result = packages
    |> Enum.slice(start_index, packages_per_page)
    result
  end

  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-8">
        <!-- Search and Filter Section -->
        <div class="bg-white/90 backdrop-blur rounded-xl shadow-sm ring-1 ring-gray-200">
          <div class="p-6">
            <div class="flex flex-col lg:flex-row gap-4 lg:items-end">
              <div class="flex-1">
                <form phx-change="search_packages" class="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div class="sm:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
                    <div class="relative">
                      <span class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3 text-gray-400">
                        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-4.35-4.35M17 10a7 7 0 11-14 0 7 7 0 0114 0z" />
                        </svg>
                      </span>
                      <input
                        type="text"
                        name="query"
                        value={@search_query}
                        placeholder="Search packages by name..."
                        class="w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:border-teal-500 placeholder:text-gray-400"
                      />
                    </div>
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Sort</label>
                    <select
                      name="sort"
                      value={@search_sort}
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:border-teal-500 bg-white"
                    >
                      <option value="name">Sort by Name</option>
                      <option value="price_low">Price: Low to High</option>
                      <option value="price_high">Price: High to Low</option>
                      <option value="duration">Duration</option>
                      <option value="recent">Recently Added</option>
                    </select>
                  </div>

                  <div class="flex items-end">
                    <button
                      type="button"
                      phx-click="clear_search"
                      class="inline-flex items-center justify-center w-full px-4 py-2 text-sm font-medium rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 transition-colors"
                    >
                      Clear
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>

        <!-- Packages Grid -->
        <div id={"packages-grid-page-#{@current_page_number}"} class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for package <- get_paginated_packages(@filtered_packages, @current_page_number, @packages_per_page) do %>
            <div class="group relative bg-white rounded-xl shadow-sm ring-1 ring-gray-200 overflow-hidden transition-all duration-200 hover:shadow-md hover:ring-teal-300 focus-within:ring-2 focus-within:ring-teal-400">
              <!-- Clickable Overlay for full-card interaction -->
              <a href={~p"/packages/#{package.id}"} aria-label={"View details for #{package.name}"} class="absolute inset-0 z-10" title={"View #{package.name} details"}></a>

              <!-- Image / Header -->
              <div class="relative h-48 bg-gray-100 overflow-hidden">
                <%= if package.picture do %>
                  <img
                    src={package.picture}
                    alt={"#{package.name} picture"}
                    class="w-full h-full object-cover transform transition-transform duration-300 ease-out group-hover:scale-105"
                  />
                <% else %>
                  <div class="w-full h-full flex items-center justify-center">
                    <svg class="w-16 h-16 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                <% end %>

                <!-- Gradient overlay on hover -->
                <div class="pointer-events-none absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300 bg-gradient-to-t from-teal-600/20 via-teal-500/10 to-transparent"></div>

                <!-- Status Badge -->
                <div class="absolute top-3 right-3">
                  <span class={[
                    "inline-flex px-2.5 py-1 text-xs font-semibold rounded-full shadow-sm ring-1 ring-inset backdrop-blur-sm",
                    case package.status do
                      "active" -> "bg-green-50/90 text-green-700 ring-green-200"
                      "inactive" -> "bg-red-50/90 text-red-700 ring-red-200"
                      _ -> "bg-gray-50/90 text-gray-700 ring-gray-200"
                    end
                  ]}>
                    <%= package.status %>
                  </span>
                </div>

                <!-- Recommended / Income Badge -->
                <%= if package.is_recommended do %>
                  <div class="absolute top-3 left-3 z-10">
                    <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold text-white shadow-lg bg-gradient-to-r from-emerald-500 to-teal-600">
                      <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                      Recommended
                    </div>
                  </div>
                <% else %>
                  <%= if @current_user && is_integer(@current_user.monthly_income) && @current_user.monthly_income > 0 do %>
                    <div class="absolute top-3 left-3 z-10">
                      <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold text-white shadow-lg bg-gradient-to-r from-amber-500 to-orange-500">
                        <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.721-1.36 3.486 0l6.518 11.59c.75 1.334-.213 2.991-1.742 2.991H3.48c-1.53 0-2.492-1.657-1.743-2.991l6.52-11.59zM11 13a1 1 0 10-2 0 1 1 0 002 0zm-1-2a1 1 0 01-1-1V7a1 1 0 112 0v3a1 1 0 01-1 1z" clip-rule="evenodd" />
                        </svg>
                        May exceed your income
                      </div>
                    </div>
                  <% end %>
                <% end %>

                <!-- Quick action revealed on hover -->
                <div class="pointer-events-none absolute bottom-3 left-3 right-3 flex justify-end opacity-0 translate-y-2 transition-all duration-300 group-hover:opacity-100 group-hover:translate-y-0">
                  <span class="pointer-events-auto inline-flex items-center gap-1.5 px-3 py-1 text-xs font-medium rounded-md bg-white/90 text-teal-800 ring-1 ring-teal-200 shadow-sm">
                    View details
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
                  </span>
                </div>
              </div>

              <!-- Package Content -->
              <div class="p-6 transition-colors duration-200 group-hover:bg-teal-50/30">
                <h3 class="text-lg font-semibold text-gray-900 mb-1 line-clamp-1"><%= package.name %></h3>

                <%= if package.description && package.description != "" do %>
                  <p class="text-gray-600 text-sm mb-4 line-clamp-2"><%= package.description %></p>
                <% end %>

                <!-- Package Details -->
                <div class="space-y-3 mb-5">
                  <div class="flex items-center justify-between">
                    <span class="text-2xl font-bold text-blue-600 tracking-tight transition-colors group-hover:text-teal-700">RM <%= package.price %></span>
                    <div class="text-right">
                      <div class="text-sm font-medium text-gray-900"><%= package.duration_days %> Days</div>
                      <div class="text-xs text-gray-500"><%= package.duration_nights %> Nights</div>
                    </div>
                  </div>

                  <%= if package.accommodation_type && package.accommodation_type != "" do %>
                    <div class="flex items-center text-sm text-gray-600">
                      <svg class="w-4 h-4 mr-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                      </svg>
                      <span class="truncate" title={package.accommodation_type}><%= package.accommodation_type %></span>
                    </div>
                  <% end %>

                  <%= if package.transport_type && package.transport_type != "" do %>
                    <div class="flex items-center text-sm text-gray-600">
                      <svg class="w-4 h-4 mr-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                      <span class="truncate" title={package.transport_type}><%= package.transport_type %></span>
                    </div>
                  <% end %>
                </div>

                <!-- Schedules Info -->
                <%= if length(package.package_schedules) > 0 do %>
                  <div class="bg-blue-50 rounded-lg p-3 mb-5 ring-1 ring-inset ring-blue-100">
                    <div class="flex items-center justify-between">
                      <span class="text-sm font-medium text-blue-900">
                        <%= length(package.package_schedules) %> Available Schedules
                      </span>
                      <a href={~p"/packages/#{package.id}"} class="relative z-20 text-xs font-medium text-blue-600 hover:text-blue-800">View Details</a>
                    </div>
                    <%= for schedule <- Enum.take(package.package_schedules, 1) do %>
                      <div class="text-xs text-blue-700 mt-1">
                        Next departure: <%= Calendar.strftime(schedule.departure_date, "%B %d, %Y") %>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <!-- Action Button -->
                <div class="flex">
                  <a
                    href={~p"/packages/#{package.id}"}
                    class="relative z-20 w-full inline-flex items-center justify-center bg-blue-600 text-white px-4 py-2.5 rounded-lg hover:bg-blue-700 focus:ring-2 focus:ring-offset-2 focus:ring-teal-500 transition-colors font-medium"
                  >
                    View Details
                  </a>
                </div>
              </div>

              <!-- Subtle lift on hover -->
              <div class="pointer-events-none absolute inset-0 translate-y-0 group-hover:-translate-y-0.5 transition-transform duration-200"></div>
            </div>
          <% end %>
        </div>

        <!-- Pagination Controls -->
        <%= if @total_pages > 1 do %>
          <div class="flex items-center justify-center gap-2 py-6">
            <!-- Previous Page Button -->
            <button
              phx-click="change_page"
              phx-value-page={@current_page_number - 1}
              disabled={@current_page_number <= 1}
              class={[
                "px-3 py-2 text-sm font-medium rounded-md transition-colors",
                if @current_page_number <= 1 do
                  "bg-gray-100 text-gray-400 cursor-not-allowed"
                else
                  "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                end
              ]}
            >
              Previous
            </button>

            <!-- Page Numbers -->
            <div class="flex items-center gap-1">
              <%= for page_num <- 1..@total_pages do %>
                <button
                  phx-click="change_page"
                  phx-value-page={page_num}
                  class={[
                    "px-3 py-2 text-sm font-medium rounded-md transition-colors",
                    if page_num == @current_page_number do
                      "bg-blue-600 text-white shadow"
                    else
                      "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                    end
                  ]}
                >
                  <%= page_num %>
                </button>
              <% end %>
            </div>

            <!-- Next Page Button -->
            <button
              phx-click="change_page"
              phx-value-page={@current_page_number + 1}
              disabled={@current_page_number >= @total_pages}
              class={[
                "px-3 py-2 text-sm font-medium rounded-md transition-colors",
                if @current_page_number >= @total_pages do
                  "bg-gray-100 text-gray-400 cursor-not-allowed"
                else
                  "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                end
              ]}
            >
              Next
            </button>
          </div>

          <!-- Page Info -->
          <div class="text-center text-sm text-gray-600">
            Showing <%= (@current_page_number - 1) * @packages_per_page + 1 %> to <%= if @current_page_number * @packages_per_page > length(@filtered_packages), do: length(@filtered_packages), else: @current_page_number * @packages_per_page %> of <%= length(@filtered_packages) %> packages
          </div>
        <% end %>

        <!-- No Packages Message -->
        <%= if length(@filtered_packages) == 0 do %>
          <div class="text-center py-16">
            <div class="mx-auto w-16 h-16 rounded-full bg-gray-100 flex items-center justify-center shadow-sm">
              <svg class="h-8 w-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
              </svg>
            </div>
            <h3 class="mt-4 text-base font-semibold text-gray-900">No packages found</h3>
            <p class="mt-1 text-sm text-gray-500">
              <%= if @search_query != "" do %>
                No packages match your search criteria. Try adjusting your search terms.
              <% else %>
                There are currently no packages available. Please check back later.
              <% end %>
            </p>
          </div>
        <% end %>
      </div>
    </.sidebar>
    """
  end
end
