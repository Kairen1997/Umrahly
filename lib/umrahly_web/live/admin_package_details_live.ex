defmodule UmrahlyWeb.AdminPackageDetailsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages

  def mount(%{"id" => package_id}, session, socket) do
    try do
      # Get package with schedules and itineraries preloaded
      package = Packages.get_package_with_schedules!(package_id)

      # Convert itinerary items to atom keys for consistent access
      package = %{package | itineraries: convert_itinerary_items_to_atoms(package.itineraries || [])}

      # Calculate booking stats for this specific package
      package_booking_stats = calculate_package_booking_stats(package)

      # Check if current_user exists in assigns
      current_user = socket.assigns[:current_user]

      socket =
        socket
        |> assign(:package, package)
        |> assign(:package_booking_stats, package_booking_stats)
        |> assign(:current_page, "packages")
        |> assign(:has_profile, true)
        |> assign(:is_admin, true)
        |> assign(:current_user, current_user)
        |> assign(:profile, current_user)

      {:ok, socket}
    rescue
      e ->
        socket =
          socket
          |> put_flash(:error, "Failed to load package details: #{Exception.message(e)}")
          |> redirect(to: ~p"/admin/packages")

        {:ok, socket}
    end
  end

  def handle_event("delete_package", %{"id" => package_id}, socket) do
    try do
      package = Packages.get_package!(package_id)

      {:ok, _} = Packages.delete_package(package)

      socket =
        socket
        |> put_flash(:info, "Package deleted successfully!")
        |> redirect(to: ~p"/admin/packages")

      {:noreply, socket}
    rescue
      e ->
        socket =
          socket
          |> put_flash(:error, "Failed to delete package: #{Exception.message(e)}")

        {:noreply, socket}
    end
  end





  defp calculate_package_booking_stats(package) do
    package.package_schedules
    |> Enum.reduce(%{confirmed_bookings: 0, available_slots: 0, booking_percentage: 0.0, total_quota: 0}, fn schedule, acc ->
      if schedule.quota && schedule.quota > 0 do
        confirmed = Packages.get_package_schedule_booking_stats(schedule.id).confirmed_bookings
        available = schedule.quota - confirmed
        percentage = if schedule.quota > 0, do: (confirmed / schedule.quota) * 100, else: 0.0

        %{
          confirmed_bookings: acc.confirmed_bookings + confirmed,
          available_slots: acc.available_slots + available,
          booking_percentage: acc.booking_percentage + percentage,
          total_quota: acc.total_quota + schedule.quota
        }
      else
        acc
      end
    end)
    |> Map.update!(:booking_percentage, fn total ->
      if total > 0, do: Float.round(total, 1), else: 0.0
    end)
  end

  defp convert_itinerary_items_to_atoms(itineraries) when is_list(itineraries) do
    Enum.map(itineraries, fn itinerary ->
      %{itinerary | itinerary_items: convert_items_to_atoms(itinerary.itinerary_items || [])}
    end)
  end
  defp convert_itinerary_items_to_atoms(_), do: []

  defp convert_items_to_atoms(items) when is_list(items) do
    Enum.map(items, fn item ->
      case item do
        %{"title" => title, "description" => description} ->
          %{title: title, description: description}
        %{title: title, description: description} ->
          %{title: title, description: description}
        _ ->
          %{title: "", description: ""}
      end
    end)
  end
  defp convert_items_to_atoms(_), do: []

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <!-- Header with navigation -->
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center space-x-4">
              <a href="/admin/packages" class="text-teal-600 hover:text-teal-700">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
                </svg>
              </a>
              <h1 class="text-2xl font-bold text-gray-900">Package Details</h1>
            </div>

          </div>

          <!-- Package Information -->
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <!-- Main Package Info -->
            <div class="lg:col-span-2">
              <div class="bg-gray-50 rounded-lg p-6">
                <div class="flex items-start space-x-6">
                  <%= if @package.picture do %>
                    <div class="flex-shrink-0">
                      <img src={@package.picture} alt={"#{@package.name} picture"} class="w-64 h-48 object-cover rounded-lg" />
                    </div>
                  <% end %>
                  <div class="flex-1">
                    <h2 class="text-2xl font-bold text-gray-900 mb-4"><%= @package.name %></h2>

                    <div class="space-y-4">
                      <div>
                        <h3 class="text-sm font-medium text-gray-500 mb-2">Description</h3>
                        <p class="text-gray-900">
                          <%= if @package.description && @package.description != "" do %>
                            <%= @package.description %>
                          <% else %>
                            No description available
                          <% end %>
                        </p>
                      </div>

                      <div class="grid grid-cols-2 gap-4">
                        <div>
                          <span class="text-sm font-medium text-gray-500">Price:</span>
                          <span class="text-lg font-bold text-gray-900 ml-2">RM <%= @package.price %></span>
                        </div>
                        <div>
                          <span class="text-sm font-medium text-gray-500">Duration:</span>
                          <span class="text-lg font-bold text-gray-900 ml-2">
                            <%= @package.duration_days %> days / <%= @package.duration_nights %> nights
                          </span>
                        </div>
                      </div>

                      <%= if @package.accommodation_type && @package.accommodation_type != "" do %>
                        <div>
                          <span class="text-sm font-medium text-gray-500">Accommodation:</span>
                          <span class="text-gray-900 ml-2"><%= @package.accommodation_type %></span>
                          <%= if @package.accommodation_details && @package.accommodation_details != "" do %>
                            <p class="text-sm text-gray-600 mt-1 ml-4"><%= @package.accommodation_details %></p>
                          <% end %>
                        </div>
                      <% end %>

                      <%= if @package.transport_type && @package.transport_type != "" do %>
                        <div>
                          <span class="text-sm font-medium text-gray-500">Transport:</span>
                          <span class="text-gray-900 ml-2"><%= @package.transport_type %></span>
                          <%= if @package.transport_details && @package.transport_details != "" do %>
                            <p class="text-sm text-gray-600 mt-1 ml-4"><%= @package.transport_details %></p>
                          <% end %>
                        </div>
                      <% end %>

                      <div>
                        <span class="text-sm font-medium text-gray-500">Status:</span>
                        <span class={[
                          "inline-flex px-3 py-1 text-sm font-semibold rounded-full ml-2",
                          case @package.status do
                            "active" -> "bg-green-100 text-green-800"
                            "inactive" -> "bg-red-100 text-red-800"
                            "draft" -> "bg-gray-100 text-gray-800"
                            _ -> "bg-gray-100 text-gray-800"
                          end
                        ]}>
                          <%= @package.status %>
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Package Schedules -->
              <div class="mt-6 bg-gray-50 rounded-lg p-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-4">Package Schedules</h3>
                <%= if @package.package_schedules && length(@package.package_schedules) > 0 do %>
                  <div class="space-y-4">
                    <%= for schedule <- @package.package_schedules do %>
                      <div class="bg-white p-4 rounded-lg border border-gray-200">
                        <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
                          <div>
                            <span class="text-sm font-medium text-gray-500">Quota:</span>
                            <span class="text-lg font-bold text-gray-900 ml-2"><%= schedule.quota %></span>
                          </div>
                          <div>
                            <span class="text-sm font-medium text-gray-500">Departure:</span>
                            <span class="text-gray-900 ml-2"><%= schedule.departure_date %></span>
                          </div>
                          <div>
                            <span class="text-sm font-medium text-gray-500">Return:</span>
                            <span class="text-gray-900 ml-2"><%= schedule.return_date %></span>
                          </div>
                          <div>
                            <span class="text-sm font-medium text-gray-500">Total Price:</span>
                            <span class="text-lg font-bold text-green-600 ml-2">
                              RM <%= @package.price + (if schedule.price_override, do: schedule.price_override, else: 0) %>
                            </span>
                          </div>
                          <div>
                            <span class="text-sm font-medium text-gray-500">Status:</span>
                            <span class={[
                              "inline-flex px-2 py-1 text-xs font-semibold rounded-full ml-2",
                              case schedule.status do
                                "active" -> "bg-green-100 text-green-800"
                                "inactive" -> "bg-red-100 text-red-800"
                                "draft" -> "bg-gray-100 text-gray-800"
                                _ -> "bg-gray-100 text-gray-800"
                              end
                            ]}>
                              <%= schedule.status %>
                            </span>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <div class="text-center py-8 text-gray-500">
                    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                    </svg>
                    <h3 class="mt-2 text-sm font-medium text-gray-900">No schedules available</h3>
                    <p class="mt-1 text-sm text-gray-500">Create package schedules to manage departure dates and quotas.</p>
                  </div>
                <% end %>
              </div>

              <!-- Package Itinerary Summary -->
              <div class="mt-6 bg-gray-50 rounded-lg p-6">
                <div class="flex items-center justify-between mb-4">
                  <h3 class="text-lg font-semibold text-gray-900">Package Itinerary</h3>
                  <a
                    href={~p"/admin/packages/#{@package.id}/itinerary"}
                    class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm"
                  >
                    Manage Itinerary
                  </a>
                </div>

                <%= if @package.itineraries && length(@package.itineraries) > 0 do %>
                  <div class="bg-white rounded-lg border border-gray-200 p-4">
                    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-center">
                      <div>
                        <div class="text-2xl font-bold text-blue-600"><%= length(@package.itineraries) %></div>
                        <div class="text-sm text-gray-600">Total Days</div>
                      </div>
                      <div>
                        <div class="text-2xl font-bold text-green-600">
                          <%= @package.itineraries |> Enum.filter(fn i -> i.day_title && i.day_title != "" end) |> length() %>
                        </div>
                        <div class="text-sm text-gray-600">Days with Titles</div>
                      </div>
                      <div>
                        <div class="text-2xl font-bold text-purple-600">
                          <%= @package.itineraries |> Enum.filter(fn i -> i.day_description && i.day_description != "" end) |> length() %>
                        </div>
                        <div class="text-sm text-gray-600">Days with Descriptions</div>
                      </div>
                    </div>

                    <div class="mt-4 pt-4 border-t border-gray-200">
                      <div class="text-sm text-gray-600 mb-2">Recent Days:</div>
                      <div class="flex flex-wrap gap-2">
                        <%= for itinerary <- Enum.take(@package.itineraries, 5) do %>
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            Day <%= itinerary.day_number %>: <%= String.slice(itinerary.day_title || "Untitled", 0, 20) %><%= if String.length(itinerary.day_title || "") > 20, do: "...", else: "" %>
                          </span>
                        <% end %>
                        <%= if length(@package.itineraries) > 5 do %>
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-600">
                            +<%= length(@package.itineraries) - 5 %> more
                          </span>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <div class="text-center py-8 text-gray-500">
                    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 00-2 2v2h2V5z"/>
                    </svg>
                    <h3 class="mt-2 text-sm font-medium text-gray-900">No itinerary available</h3>
                    <p class="mt-1 text-sm text-gray-500">Create a detailed itinerary for this package.</p>
                    <div class="mt-4">
                      <a
                        href={~p"/admin/packages/#{@package.id}/itinerary"}
                        class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
                      >
                        Create Itinerary
                      </a>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Sidebar with stats and actions -->
            <div class="space-y-6">
              <!-- Booking Statistics -->
              <div class="bg-blue-50 rounded-lg p-6 border border-blue-200">
                <h4 class="text-lg font-semibold text-blue-900 mb-4">Booking Statistics</h4>
                <div class="space-y-4">
                  <div class="text-center">
                    <div class="text-3xl font-bold text-blue-600"><%= @package_booking_stats.confirmed_bookings %></div>
                    <div class="text-sm text-blue-700">Confirmed Bookings</div>
                  </div>
                  <div class="text-center">
                    <div class="text-3xl font-bold text-green-600"><%= @package_booking_stats.available_slots %></div>
                    <div class="text-sm text-green-700">Available Slots</div>
                  </div>
                  <div class="text-center">
                    <div class="text-3xl font-bold text-purple-600"><%= @package_booking_stats.total_quota %></div>
                    <div class="text-sm text-purple-700">Total Quota</div>
                  </div>
                </div>

                <div class="mt-4 pt-4 border-t border-blue-200">
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm text-blue-700">Booking Percentage:</span>
                    <span class="text-sm font-semibold text-blue-900"><%= @package_booking_stats.booking_percentage %>%</span>
                  </div>
                  <div class="w-full bg-blue-200 rounded-full h-3">
                    <div class="bg-blue-600 h-3 rounded-full" style={"width: #{@package_booking_stats.booking_percentage}%"}>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Quick Actions -->
              <div class="bg-gray-50 rounded-lg p-6">
                <h4 class="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h4>
                <div class="space-y-3">
                  <a
                    href={~p"/admin/packages/#{@package.id}/itinerary"}
                    class="w-full bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-center block"
                  >
                    Manage Itinerary
                  </a>
                  <.link
                    navigate={~p"/admin/packages/#{@package.id}/edit"}
                    class="w-full bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors text-center block"
                  >
                    Edit Package
                  </.link>

                  <button
                    phx-click="delete_package"
                    phx-value-id={@package.id}
                    phx-debounce="100"
                    data-confirm="Are you sure you want to delete this package? This action cannot be undone."
                    class="w-full bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors"
                  >
                    Delete Package
                  </button>
                </div>
              </div>

              <!-- Package Meta -->
              <div class="bg-gray-50 rounded-lg p-6">
                <h4 class="text-lg font-semibold text-gray-900 mb-4">Package Information</h4>
                <div class="space-y-3 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-500">Created:</span>
                    <span class="text-gray-900"><%= @package.inserted_at %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-500">Last Updated:</span>
                    <span class="text-gray-900"><%= @package.updated_at %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-500">Schedules:</span>
                    <span class="text-gray-900"><%= length(@package.package_schedules) %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-500">Itinerary Days:</span>
                    <span class="text-gray-900"><%= if @package.itineraries, do: length(@package.itineraries), else: 0 %></span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
