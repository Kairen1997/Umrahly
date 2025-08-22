defmodule UmrahlyWeb.AdminPackagesLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages

  def mount(_params, _session, socket) do
    packages = Packages.list_packages_with_schedules()

    # Calculate overall statistics once to avoid N+1 queries
    overall_stats = calculate_overall_statistics(packages)

    # Sort packages with recently viewed/edited ones at the top
    sorted_packages = sort_packages_by_recent_activity(packages)

    socket =
      socket
      |> assign(:packages, sorted_packages)
      |> assign(:filtered_packages, sorted_packages)
      |> assign(:overall_stats, overall_stats)
      |> assign(:search_query, "")
      |> assign(:search_status, "")
      |> assign(:search_sort, "recent")
      |> assign(:current_page, "packages")
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns.current_user)

    {:ok, socket}
  end

  def handle_event("search_packages", %{"search" => search_params}, socket) do
    search_query = Map.get(search_params, "query", "")
    search_status = Map.get(search_params, "status", "")
    search_sort = Map.get(search_params, "sort", "recent")

    filtered_packages = filter_packages(socket.assigns.packages, search_query, search_status)
    sorted_packages = sort_packages_by_criteria(filtered_packages, search_sort)

    socket =
      socket
      |> assign(:filtered_packages, sorted_packages)
      |> assign(:search_query, search_query)
      |> assign(:search_status, search_status)
      |> assign(:search_sort, search_sort)

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:filtered_packages, socket.assigns.packages)
      |> assign(:search_query, "")
      |> assign(:search_status, "")
      |> assign(:search_sort, "recent")

    {:noreply, socket}
  end

  def handle_event("delete_package", %{"id" => package_id}, socket) do
    package = Packages.get_package!(package_id)
    {:ok, _} = Packages.delete_package(package)

    packages = Packages.list_packages_with_schedules()
    overall_stats = calculate_overall_statistics(packages)

    # Sort packages with recently viewed/edited ones at the top
    sorted_packages = sort_packages_by_recent_activity(packages)

    socket =
      socket
      |> assign(:packages, sorted_packages)
      |> assign(:filtered_packages, sorted_packages)
      |> assign(:overall_stats, overall_stats)
      |> assign(:viewing_package_id, nil)
      |> assign(:current_package, nil)
      |> assign(:scroll_target, nil)

    {:noreply, socket}
  end

  defp filter_packages(packages, search_query, search_status) do
    packages
    |> Enum.filter(fn package ->
      name_matches = search_query == "" || String.contains?(String.downcase(package.name), String.downcase(search_query))
      status_matches = search_status == "" || package.status == search_status

      name_matches && status_matches
    end)
  end

  defp sort_packages_by_recent_activity(packages) do
    # Sort packages by updated_at timestamp (most recent first)
    # This will put recently edited packages at the top
    packages
    |> Enum.sort_by(fn package ->
      # Sort by updated_at timestamp (most recent first)
      # If updated_at is nil, put at the end
      package.updated_at || ~N[1970-01-01 00:00:00]
    end, {:desc, DateTime})
  end

  defp sort_packages_by_criteria(packages, sort_criteria) do
    case sort_criteria do
      "recent" ->
        # Sort by updated_at timestamp (most recent first)
        packages
        |> Enum.sort_by(fn package ->
          package.updated_at || ~N[1970-01-01 00:00:00]
        end, {:desc, DateTime})

      "name" ->
        # Sort by name alphabetically
        packages
        |> Enum.sort_by(fn package ->
          String.downcase(package.name)
        end, :asc)

      "price_low" ->
        # Sort by price (low to high)
        packages
        |> Enum.sort_by(fn package ->
          package.price
        end, :asc)

      "price_high" ->
        # Sort by price (high to low)
        packages
        |> Enum.sort_by(fn package ->
          package.price
        end, {:desc, :integer})

      "duration" ->
        # Sort by duration (shortest to longest)
        packages
        |> Enum.sort_by(fn package ->
          package.duration_days
        end, :asc)

      _ ->
        # Default to recent sorting
        sort_packages_by_recent_activity(packages)
    end
  end

  defp is_recently_updated?(package) do
    # Consider a package "recently updated" if it was updated within the last 24 hours
    case package.updated_at do
      nil -> false
      updated_at ->
        DateTime.diff(DateTime.utc_now(), updated_at, :hour) < 24
    end
  end


  defp calculate_overall_statistics(packages) do
    packages
    |> Enum.reduce(%{total_quota: 0, total_confirmed: 0, total_available: 0, total_percentage: 0, total_schedules: 0}, fn package, acc ->
      package_stats = package.package_schedules
      |> Enum.reduce(%{quota: 0, confirmed: 0, available: 0, percentage: 0}, fn schedule, schedule_acc ->
        if schedule.quota && schedule.quota > 0 do
          confirmed = Packages.get_package_schedule_booking_stats(schedule.id).confirmed_bookings
          available = schedule.quota - confirmed
          percentage = if schedule.quota > 0, do: (confirmed / schedule.quota) * 100, else: 0.0

          %{
            quota: schedule_acc.quota + schedule.quota,
            confirmed: schedule_acc.confirmed + confirmed,
            available: schedule_acc.available + available,
            percentage: schedule_acc.percentage + percentage
          }
        else
          schedule_acc
        end
      end)

      %{
        total_quota: acc.total_quota + package_stats.quota,
        total_confirmed: acc.total_confirmed + package_stats.confirmed,
        total_available: acc.total_available + package_stats.available,
        total_percentage: acc.total_percentage + package_stats.percentage,
        total_schedules: acc.total_schedules + length(package.package_schedules)
      }
    end)
    |> Map.update!(:total_percentage, fn total ->
      if total > 0, do: Float.round(total, 1), else: 0.0
    end)
  end



  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-white rounded-lg shadow-sm border border-gray-200">
          <!-- Header Section -->
          <div class="px-6 py-4 border-b border-gray-200">
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
              <h1 class="text-xl font-semibold text-gray-900">Packages Management</h1>
              <.link
                navigate={~p"/admin/packages/new"}
                class="bg-teal-600 text-white px-4 py-2 rounded-md hover:bg-teal-700 transition-colors text-sm font-medium self-start sm:self-auto">
                Add New Package
              </.link>
            </div>
          </div>

          <!-- Search Bar -->
          <div class="px-6 py-4 bg-gray-50 border-b border-gray-200">
            <form phx-change="search_packages" class="space-y-4">
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Package Name</label>
                  <input
                    type="text"
                    name="search[query]"
                    value={@search_query}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent text-sm"
                    placeholder="Search by package name..."
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
                  <select
                    name="search[status]"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent text-sm"
                  >
                    <option value="">All Status</option>
                    <option value="active" selected={@search_status == "active"}>Active</option>
                    <option value="inactive" selected={@search_status == "inactive"}>Inactive</option>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Sort By</label>
                  <select
                    name="search[sort]"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent text-sm"
                  >
                    <option value="recent" selected={@search_sort == "recent"}>Recently Updated</option>
                    <option value="name" selected={@search_sort == "name"}>Name A-Z</option>
                    <option value="price_low" selected={@search_sort == "price_low"}>Price Low to High</option>
                    <option value="price_high" selected={@search_sort == "price_high"}>Price High to Low</option>
                    <option value="duration" selected={@search_sort == "duration"}>Duration</option>
                  </select>
                </div>

                <div class="flex items-end">
                  <button
                    type="button"
                    phx-click="clear_search"
                    class="w-full px-3 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors text-sm font-medium"
                  >
                    Clear Search
                  </button>
                </div>
              </div>
            </form>
          </div>

          <!-- Search Results Summary -->
          <div class="px-6 py-3 bg-gray-50 border-b border-gray-200">
            <p class="text-sm text-gray-600">
              Showing <%= length(@filtered_packages) %> of <%= length(@packages) %> packages
              <%= if @search_query != "" || @search_status != "" do %>
                (filtered by package name and status)
              <% end %>
            </p>
          </div>

          <!-- Overall Booking Statistics -->
          <div class="px-6 py-4 bg-gray-50 border-b border-gray-200">
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
              <div class="bg-white border border-gray-200 rounded-lg p-3">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-6 w-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                  </div>
                  <div class="ml-2">
                    <p class="text-xs font-medium text-blue-600">Total Quota</p>
                    <p class="text-lg font-bold text-blue-900">
                      <%= @overall_stats.total_quota %>
                    </p>
                  </div>
                </div>
              </div>

              <div class="bg-white border border-gray-200 rounded-lg p-3">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-6 w-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                    </svg>
                  </div>
                  <div class="ml-2">
                    <p class="text-xs font-medium text-green-600">Confirmed</p>
                    <p class="text-lg font-bold text-green-900">
                      <%= @overall_stats.total_confirmed %>
                    </p>
                  </div>
                </div>
              </div>

              <div class="bg-white border border-gray-200 rounded-lg p-3">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-6 w-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                    </svg>
                  </div>
                  <div class="ml-2">
                    <p class="text-xs font-medium text-yellow-600">Available</p>
                    <p class="text-lg font-bold text-yellow-900">
                      <%= @overall_stats.total_available %>
                    </p>
                  </div>
                </div>
              </div>

              <div class="bg-white border border-gray-200 rounded-lg p-3">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-6 w-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                    </svg>
                  </div>
                  <div class="ml-2">
                    <p class="text-xs font-medium text-purple-600">Avg. Occupancy</p>
                    <p class="text-lg font-bold text-purple-900">
                      <%= if @overall_stats.total_schedules > 0, do: Float.round(@overall_stats.total_percentage / @overall_stats.total_schedules, 1), else: 0.0 %>%
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Packages Table -->
          <div class="overflow-hidden">
            <%= if length(@filtered_packages) == 0 do %>
              <div class="text-center py-12">
                <div class="text-gray-500">
                  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 12h6m-6-4h6m2 5.291A7.962 7.962 0 0112 15c-2.34 0-4.47-.881-6.08-2.33" />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No packages found</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    <%= if @search_query != "" || @search_status != "" do %>
                      Try adjusting your search criteria for name, description, or status.
                    <% else %>
                      Get started by creating a new package.
                    <% end %>
                  </p>
                </div>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="w-full divide-y divide-gray-200">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-1/4">
                        Package
                      </th>
                      <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-20">
                        Status
                      </th>
                      <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-24">
                        Price
                      </th>
                      <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-24">
                        Duration
                      </th>
                      <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-28">
                        Accommodation
                      </th>
                      <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-24">
                        Transport
                      </th>
                      <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-24">
                        Schedules
                      </th>
                      <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-28">
                        Last Updated
                      </th>
                      <th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-24">
                        Actions
                      </th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    <%= for package <- @filtered_packages do %>
                      <tr class="hover:bg-gray-50 transition-colors">
                        <td class="px-4 py-3">
                          <div class="flex items-center">
                            <div class="flex-shrink-0 h-10 w-10">
                              <%= if package.picture do %>
                                <img class="h-10 w-10 rounded-lg object-cover" src={package.picture} alt={"#{package.name} picture"} />
                              <% else %>
                                <div class="h-10 w-10 rounded-lg bg-gray-200 flex items-center justify-center">
                                  <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 002 2v12a2 2 0 002 2z" />
                                  </svg>
                                </div>
                              <% end %>
                            </div>
                            <div class="ml-3 min-w-0 flex-1">
                              <div class="text-sm font-medium text-gray-900 truncate"><%= package.name %></div>
                              <div class="text-xs text-gray-500 truncate">
                                <%= if package.description && package.description != "" do %>
                                  <%= package.description %>
                                <% else %>
                                  No description available
                                <% end %>
                              </div>
                              <%= if is_recently_updated?(package) do %>
                                <span class="inline-flex px-1.5 py-0.5 text-xs font-semibold rounded-full bg-blue-100 text-blue-800 mt-1">
                                  Recently Updated
                                </span>
                              <% end %>
                            </div>
                          </div>
                        </td>
                        <td class="px-3 py-3">
                          <span class={[
                            "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                            case package.status do
                              "active" -> "bg-green-100 text-green-800"
                              "inactive" -> "bg-red-100 text-red-800"
                              "draft" -> "bg-gray-100 text-gray-800"
                              _ -> "bg-gray-100 text-gray-800"
                            end
                          ]}>
                            <%= package.status %>
                          </span>
                        </td>
                        <td class="px-3 py-3">
                          <div class="text-sm font-bold text-gray-900">RM <%= package.price %></div>
                        </td>
                        <td class="px-3 py-3">
                          <div class="text-sm text-gray-900">
                            <%= package.duration_days %>d<br/>
                            <span class="text-gray-500 text-xs"><%= package.duration_nights %>n</span>
                          </div>
                        </td>
                        <td class="px-3 py-3">
                          <div class="text-sm text-gray-900">
                            <%= if package.accommodation_type && package.accommodation_type != "" do %>
                              <span class="truncate block"><%= package.accommodation_type %></span>
                            <% else %>
                              <span class="text-gray-400">-</span>
                            <% end %>
                          </div>
                        </td>
                        <td class="px-3 py-3">
                          <div class="text-sm text-gray-900">
                            <%= if package.transport_type && package.transport_type != "" do %>
                              <span class="truncate block"><%= package.transport_type %></span>
                            <% else %>
                              <span class="text-gray-400">-</span>
                            <% end %>
                          </div>
                        </td>
                        <td class="px-3 py-3">
                          <div class="text-sm text-gray-900">
                            <%= if length(package.package_schedules) > 0 do %>
                              <div class="text-center">
                                <div class="text-sm font-semibold text-blue-600"><%= length(package.package_schedules) %></div>
                                <div class="text-xs text-gray-500">schedules</div>
                              </div>
                              <%= for schedule <- Enum.take(package.package_schedules, 1) do %>
                                <div class="text-xs text-gray-500 mt-1 truncate">
                                  Next: <%= schedule.departure_date %>
                                </div>
                              <% end %>
                            <% else %>
                              <span class="text-gray-400">No schedules</span>
                            <% end %>
                          </div>
                        </td>
                        <td class="px-3 py-3">
                          <div class="text-sm text-gray-900">
                            <%= Calendar.strftime(package.updated_at, "%b %d") %>
                          </div>
                          <div class="text-xs text-gray-500">
                            <%= Calendar.strftime(package.updated_at, "%I:%M %p") %>
                          </div>
                        </td>
                        <td class="px-3 py-3 text-sm font-medium">
                          <div class="flex flex-col space-y-1">
                            <.link
                              navigate={~p"/admin/packages/#{package.id}/edit"}
                              class="bg-blue-600 text-white px-2 py-1 rounded text-xs hover:bg-blue-700 transition-colors text-center"
                            >
                              Edit
                            </.link>
                            <.link
                              navigate={~p"/admin/packages/details/#{package.id}"}
                              class="bg-teal-600 text-white px-2 py-1 rounded text-xs hover:bg-teal-700 transition-colors text-center"
                            >
                              View
                            </.link>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end

end
