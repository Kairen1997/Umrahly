defmodule UmrahlyWeb.AdminPackageSchedulesLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages
  alias Umrahly.Packages.PackageSchedule

  def mount(_params, _session, socket) do
    packages = Packages.list_packages()
    schedules = Packages.list_package_schedules_with_stats()

    socket =
      socket
      |> assign(:packages, packages)
      |> assign(:schedules, schedules)
      |> assign(:filtered_schedules, schedules)
      |> assign(:search_query, "")
      |> assign(:search_status, "")
      |> assign(:search_departure_date, "")
      |> assign(:search_return_date, "")
      |> assign(:current_page, "package_schedules")
      |> assign(:show_edit_form, false)
      |> assign(:editing_schedule_id, nil)
      |> assign(:schedule_changeset, Packages.change_package_schedule(%PackageSchedule{}))
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns.current_user)

    {:ok, socket}
  end

  def handle_event("search_schedules", %{"search" => search_params}, socket) do
    search_query = Map.get(search_params, "query", "")
    search_status = Map.get(search_params, "status", "")
    search_departure_date = Map.get(search_params, "departure_date", "")
    search_return_date = Map.get(search_params, "return_date", "")

    filtered_schedules = filter_schedules(socket.assigns.schedules, search_query, search_status, search_departure_date, search_return_date)

    socket =
      socket
      |> assign(:filtered_schedules, filtered_schedules)
      |> assign(:search_query, search_query)
      |> assign(:search_status, search_status)
      |> assign(:search_departure_date, search_departure_date)
      |> assign(:search_return_date, search_return_date)

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:filtered_schedules, socket.assigns.schedules)
      |> assign(:search_query, "")
      |> assign(:search_status, "")
      |> assign(:search_departure_date, "")
      |> assign(:search_return_date, "")

    {:noreply, socket}
  end





  def handle_event("cancel_schedule", %{"id" => schedule_id}, socket) do
    schedule = Packages.get_package_schedule!(schedule_id)

    case Packages.update_package_schedule(schedule, %{status: "cancelled"}) do
      {:ok, _updated_schedule} ->
        schedules = Packages.list_package_schedules_with_stats()

        socket =
          socket
          |> assign(:schedules, schedules)
          |> assign(:filtered_schedules, schedules)
          |> put_flash(:info, "Schedule cancelled successfully!")

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to cancel schedule")

        {:noreply, socket}
    end
  end

  def handle_event("delete_schedule", %{"id" => schedule_id}, socket) do
    schedule = Packages.get_package_schedule!(schedule_id)
    {:ok, _} = Packages.delete_package_schedule(schedule)

    schedules = Packages.list_package_schedules_with_stats()

    socket =
      socket
      |> assign(:schedules, schedules)
      |> assign(:filtered_schedules, schedules)
      |> put_flash(:info, "Schedule deleted successfully!")

    {:noreply, socket}
  end





  def handle_event("edit_schedule", %{"id" => schedule_id}, socket) do
    schedule = Packages.get_package_schedule!(schedule_id)
    changeset = Packages.change_package_schedule(schedule)

    socket =
      socket
      |> assign(:show_edit_form, true)
      |> assign(:editing_schedule_id, schedule_id)
      |> assign(:schedule_changeset, changeset)

    {:noreply, socket}
  end

  def handle_event("close_edit_form", _params, socket) do
    socket =
      socket
      |> assign(:show_edit_form, false)
      |> assign(:editing_schedule_id, nil)
      |> assign(:schedule_changeset, Packages.change_package_schedule(%PackageSchedule{}))

    {:noreply, socket}
  end

  def handle_event("save_schedule", %{"package_schedule" => schedule_params}, socket) do
    # Updating existing schedule
    schedule = Packages.get_package_schedule!(socket.assigns.editing_schedule_id)
    case Packages.update_package_schedule(schedule, schedule_params) do
      {:ok, _updated_schedule} ->
        schedules = Packages.list_package_schedules_with_stats()

        socket =
          socket
          |> assign(:schedules, schedules)
          |> assign(:filtered_schedules, schedules)
          |> assign(:show_edit_form, false)
          |> assign(:editing_schedule_id, nil)
          |> assign(:schedule_changeset, Packages.change_package_schedule(%PackageSchedule{}))
          |> put_flash(:info, "Schedule updated successfully!")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> assign(:schedule_changeset, changeset)

        {:noreply, socket}
    end
  end

  defp filter_schedules(schedules, search_query, search_status, search_departure_date, search_return_date) do
    schedules
    |> Enum.filter(fn schedule ->
      package = schedule.package
      name_matches = search_query == "" || String.contains?(String.downcase(package.name), String.downcase(search_query))
      status_matches = search_status == "" || schedule.status == search_status
      departure_date_matches = search_departure_date == "" || to_string(schedule.departure_date) == search_departure_date
      return_date_matches = search_return_date == "" || to_string(schedule.return_date) == search_return_date

      name_matches && status_matches && departure_date_matches && return_date_matches
    end)
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Package Schedules Management</h1>
            <a
              href={~p"/admin/package-schedules/new"}
              class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors">
              Add New Schedule
            </a>
          </div>

          <!-- Search Bar -->
          <div class="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-6">
            <form phx-change="search_schedules" class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Package Name</label>
                  <input
                    type="text"
                    name="search[query]"
                    value={@search_query}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                    placeholder="Search by package name..."
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
                  <select
                    name="search[status]"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  >
                    <option value="">All Status</option>
                    <option value="active" selected={@search_status == "active"}>Active</option>
                    <option value="inactive" selected={@search_status == "inactive"}>Inactive</option>
                    <option value="cancelled" selected={@search_status == "cancelled"}>Cancelled</option>
                    <option value="completed" selected={@search_status == "completed"}>Completed</option>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Departure Date</label>
                  <input
                    type="date"
                    name="search[departure_date]"
                    value={@search_departure_date}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Return Date</label>
                  <input
                    type="date"
                    name="search[return_date]"
                    value={@search_return_date}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  />
                </div>

                <div class="flex items-end">
                  <button
                    type="button"
                    phx-click="clear_search"
                    class="w-full px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
                  >
                    Clear Search
                  </button>
                </div>
              </div>
            </form>
          </div>

          <!-- Search Results Summary -->
          <div class="mb-4">
            <p class="text-sm text-gray-600">
              Showing <%= length(@filtered_schedules) %> of <%= length(@schedules) %> schedules
              <%= if @search_query != "" || @search_status != "" || @search_departure_date != "" || @search_return_date != "" do %>
                (filtered by package name, status, departure date, and return date)
              <% end %>
            </p>
          </div>







          <%= if @show_edit_form do %>
            <!-- Edit Schedule Form -->
            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-bold text-gray-900">Edit Schedule</h2>
                <button
                  phx-click="close_edit_form"
                  class="text-gray-500 hover:text-gray-700"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                  </svg>
                </button>
              </div>

              <form phx-submit="save_schedule" class="space-y-4">
                <input type="hidden" name="package_schedule[id]" value={@editing_schedule_id} />
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Package</label>
                    <select
                      name="package_schedule[package_id]"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      required
                    >
                      <%= for package <- @packages do %>
                        <option value={package.id} selected={@schedule_changeset.data.package_id == package.id}><%= package.name %></option>
                      <% end %>
                    </select>
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
                    <select
                      name="package_schedule[status]"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      required
                    >
                      <option value="active" selected={@schedule_changeset.data.status == "active"}>Active</option>
                      <option value="inactive" selected={@schedule_changeset.data.status == "inactive"}>Inactive</option>
                      <option value="cancelled" selected={@schedule_changeset.data.status == "cancelled"}>Cancelled</option>
                      <option value="completed" selected={@schedule_changeset.data.status == "completed"}>Completed</option>
                    </select>
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Quota</label>
                    <input
                      type="number"
                      name="package_schedule[quota]"
                      value={@schedule_changeset.data.quota}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      placeholder="Enter quota"
                      min="1"
                      max="100"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Price Override (RM)</label>
                    <input
                      type="number"
                      name="package_schedule[price_override]"
                      value={@schedule_changeset.data.price_override}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      placeholder="Leave empty to use package price"
                      min="1"
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Departure Date</label>
                    <input
                      type="date"
                      name="package_schedule[departure_date]"
                      value={@schedule_changeset.data.departure_date}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Return Date</label>
                    <input
                      type="date"
                      name="package_schedule[return_date]"
                      value={@schedule_changeset.data.return_date}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      required
                    />
                  </div>

                  <div class="md:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
                    <textarea
                      name="package_schedule[notes]"
                      rows="3"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      placeholder="Any additional notes about this schedule..."
                    ><%= @schedule_changeset.data.notes || "" %></textarea>
                  </div>
                </div>

                <div class="flex justify-end space-x-3 pt-4">
                  <button
                    type="button"
                    phx-click="close_edit_form"
                    class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="px-4 py-2 bg-teal-600 text-white rounded-md hover:bg-teal-700 transition-colors"
                  >
                    Save Schedule
                  </button>
                </div>
              </form>
            </div>
          <% end %>

          <!-- Schedules List -->
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= if length(@filtered_schedules) == 0 do %>
              <div class="col-span-full text-center py-12">
                <div class="text-gray-500">
                  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 12h6m-6-4h6m2 5.291A7.962 7.962 0 0112 15c-2.34 0-4.47-.881-6.08-2.33" />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No schedules found</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    <%= if @search_query != "" || @search_status != "" || @search_departure_date != "" do %>
                      Try adjusting your search criteria.
                    <% else %>
                      Get started by creating a new schedule.
                    <% end %>
                  </p>
                </div>
              </div>
            <% else %>
              <%= for schedule <- @filtered_schedules do %>
                <div class="bg-white border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
                  <div class="p-6">
                    <div class="flex items-center justify-between mb-4">
                      <h3 class="text-lg font-semibold text-gray-900"><%= schedule.package.name %></h3>
                      <span class={[
                        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                        case schedule.status do
                          "active" -> "bg-green-100 text-green-800"
                          "inactive" -> "bg-red-100 text-red-800"
                          "cancelled" -> "bg-gray-100 text-gray-800"
                          "completed" -> "bg-blue-100 text-blue-800"
                          _ -> "bg-gray-100 text-gray-800"
                        end
                      ]}>
                        <%= schedule.status %>
                      </span>
                    </div>

                    <div class="space-y-2 mb-4">
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-500">Total Price:</span>
                        <span class="text-sm font-bold text-gray-900">
                          RM <%= schedule.package.price + (if schedule.price_override, do: schedule.price_override, else: 0) %>
                        </span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-500">Quota:</span>
                        <span class="text-sm font-medium text-gray-900"><%= schedule.quota %></span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-500">Departure:</span>
                        <span class="text-sm font-medium text-gray-900"><%= schedule.departure_date %></span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-500">Return:</span>
                        <span class="text-sm font-medium text-gray-900"><%= schedule.return_date %></span>
                      </div>
                      <%= if schedule.package.accommodation_type && schedule.package.accommodation_type != "" do %>
                        <div class="flex justify-between">
                          <span class="text-sm text-gray-500">Accommodation:</span>
                          <span class="text-sm font-medium text-gray-900"><%= schedule.package.accommodation_type %></span>
                        </div>
                      <% end %>
                      <%= if schedule.package.transport_type && schedule.package.transport_type != "" do %>
                        <div class="flex justify-between">
                          <span class="text-sm text-gray-500">Transport:</span>
                          <span class="text-sm font-medium text-gray-900"><%= schedule.package.transport_type %></span>
                        </div>
                      <% end %>
                    </div>

                    <!-- Quick Booking Status -->
                    <div class="mt-3 pt-3 border-t border-gray-200">
                      <div class="flex justify-between items-center">
                        <span class="text-xs text-gray-500">Bookings:</span>
                        <span class="text-xs font-medium text-gray-900">
                          <%= schedule.booking_stats.confirmed_bookings %> / <%= schedule.quota %>
                        </span>
                      </div>
                      <div class="mt-1">
                        <div class="w-full bg-gray-200 rounded-full h-1.5">
                          <div class="bg-teal-500 h-1.5 rounded-full" style={"width: #{schedule.booking_stats.booking_percentage}%"}>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div class="flex space-x-2 mt-4">
                      <a
                        href={~p"/admin/package-schedules/#{schedule.id}"}
                        class="flex-1 bg-teal-600 text-white px-3 py-2 rounded text-sm hover:bg-teal-700 transition-colors text-center block"
                      >
                        View
                      </a>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
