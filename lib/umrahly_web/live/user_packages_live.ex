defmodule UmrahlyWeb.UserPackagesLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Packages

  def mount(_params, _session, socket) do
    # Get all active packages with schedules
    packages = Packages.list_active_packages_with_schedules()

    socket =
      socket
      |> assign(:packages, packages)
      |> assign(:filtered_packages, packages)
      |> assign(:search_query, "")
      |> assign(:search_sort, "name")
      |> assign(:current_page, "packages")
      |> assign(:page_title, "Available Packages")

    {:ok, socket}
  end

  def handle_event("search_packages", %{"search" => search_params}, socket) do
    search_query = Map.get(search_params, "query", "")
    search_sort = Map.get(search_params, "sort", "name")

    filtered_packages = filter_packages(socket.assigns.packages, search_query)
    sorted_packages = sort_packages_by_criteria(filtered_packages, search_sort)

    socket =
      socket
      |> assign(:filtered_packages, sorted_packages)
      |> assign(:search_query, search_query)
      |> assign(:search_sort, search_sort)

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:filtered_packages, socket.assigns.packages)
      |> assign(:search_query, "")
      |> assign(:search_sort, "name")

    {:noreply, socket}
  end

  defp filter_packages(packages, search_query) do
    packages
    |> Enum.filter(fn package ->
      search_query == "" ||
      String.contains?(String.downcase(package.name), String.downcase(search_query)) ||
      (package.description && String.contains?(String.downcase(package.description), String.downcase(search_query)))
    end)
  end

  defp sort_packages_by_criteria(packages, sort_criteria) do
    case sort_criteria do
      "name" -> Enum.sort_by(packages, &String.downcase(&1.name))
      "price_low" -> Enum.sort_by(packages, & &1.price)
      "price_high" -> Enum.sort_by(packages, & &1.price, :desc)
      "duration" -> Enum.sort_by(packages, & &1.duration_days)
      "recent" -> Enum.sort_by(packages, & &1.inserted_at, :desc)
      _ -> packages
    end
  end

  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div class="space-y-6">
        <!-- Search and Filter Section -->
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex flex-col sm:flex-row gap-4">
            <div class="flex-1">
              <form phx-change="search_packages" class="flex gap-2">
                <div class="flex-1">
                  <input
                    type="text"
                    name="query"
                    value={@search_query}
                    placeholder="Search packages by name or description..."
                    class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
                <div>
                  <select
                    name="sort"
                    value={@search_sort}
                    class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="name">Sort by Name</option>
                    <option value="price_low">Price: Low to High</option>
                    <option value="price_high">Price: High to Low</option>
                    <option value="duration">Duration</option>
                    <option value="recent">Recently Added</option>
                  </select>
                </div>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="px-4 py-2 bg-gray-500 text-white rounded-lg hover:bg-gray-600 transition-colors"
                >
                  Clear
                </button>
              </form>
            </div>
          </div>
        </div>

        <!-- Packages Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for package <- @filtered_packages do %>
            <div class="bg-white rounded-lg shadow-lg overflow-hidden hover:shadow-xl transition-shadow duration-300">
              <!-- Package Image -->
              <div class="h-48 bg-gray-200 relative">
                <%= if package.picture do %>
                  <img
                    src={package.picture}
                    alt={"#{package.name} picture"}
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <div class="w-full h-full flex items-center justify-center">
                    <svg class="w-20 h-20 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 002 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                <% end %>

                <!-- Status Badge -->
                <div class="absolute top-3 right-3">
                  <span class={[
                    "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                    case package.status do
                      "active" -> "bg-green-100 text-green-800"
                      "inactive" -> "bg-red-100 text-red-800"
                      _ -> "bg-gray-100 text-gray-800"
                    end
                  ]}>
                    <%= package.status %>
                  </span>
                </div>
              </div>

              <!-- Package Content -->
              <div class="p-6">
                <h3 class="text-xl font-semibold text-gray-900 mb-2"><%= package.name %></h3>

                <%= if package.description && package.description != "" do %>
                  <p class="text-gray-600 text-sm mb-4 line-clamp-2"><%= package.description %></p>
                <% end %>

                <!-- Package Details -->
                <div class="space-y-3 mb-4">
                  <div class="flex items-center justify-between">
                    <span class="text-2xl font-bold text-blue-600">RM <%= package.price %></span>
                    <div class="text-right">
                      <div class="text-sm font-medium text-gray-900"><%= package.duration_days %> Days</div>
                      <div class="text-xs text-gray-500"><%= package.duration_nights %> Nights</div>
                    </div>
                  </div>

                  <%= if package.accommodation_type && package.accommodation_type != "" do %>
                    <div class="flex items-center text-sm text-gray-600">
                      <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                      </svg>
                      <span class="truncate"><%= package.accommodation_type %></span>
                    </div>
                  <% end %>

                  <%= if package.transport_type && package.transport_type != "" do %>
                    <div class="flex items-center text-sm text-gray-600">
                      <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                      <span class="truncate"><%= package.transport_type %></span>
                    </div>
                  <% end %>
                </div>

                <!-- Schedules Info -->
                <%= if length(package.package_schedules) > 0 do %>
                  <div class="bg-blue-50 rounded-lg p-3 mb-4">
                    <div class="flex items-center justify-between">
                      <span class="text-sm font-medium text-blue-900">
                        <%= length(package.package_schedules) %> Available Schedules
                      </span>
                      <a href={~p"/packages/#{package.id}"} class="text-xs text-blue-600 hover:text-blue-800">View Details</a>
                    </div>
                    <%= for schedule <- Enum.take(package.package_schedules, 1) do %>
                      <div class="text-xs text-blue-700 mt-1">
                        Next departure: <%= Calendar.strftime(schedule.departure_date, "%B %d, %Y") %>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <!-- Action Buttons -->
                <div class="flex space-x-2">
                  <a
                    href={~p"/packages/#{package.id}"}
                    class="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium text-center"
                  >
                    View Details
                  </a>
                  <button class="flex-1 bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium">
                    Book Now
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- No Packages Message -->
        <%= if length(@filtered_packages) == 0 do %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No packages found</h3>
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
