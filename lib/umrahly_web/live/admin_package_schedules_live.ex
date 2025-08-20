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
      |> assign(:viewing_schedule_id, nil)
      |> assign(:show_add_form, false)
      |> assign(:show_edit_form, false)
      |> assign(:editing_schedule_id, nil)
      |> assign(:schedule_changeset, Packages.change_package_schedule(%PackageSchedule{}))

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

  def handle_event("view_schedule", %{"id" => schedule_id}, socket) do
    schedule = Enum.find(socket.assigns.schedules, & &1.id == String.to_integer(schedule_id))

    socket =
      socket
      |> assign(:viewing_schedule_id, schedule_id)
      |> assign(:current_schedule, schedule)

    {:noreply, socket}
  end

  def handle_event("close_schedule_view", _params, socket) do
    socket =
      socket
      |> assign(:viewing_schedule_id, nil)
      |> assign(:current_schedule, nil)

    {:noreply, socket}
  end

  def handle_event("add_schedule", _params, socket) do
    socket =
      socket
      |> assign(:show_add_form, true)
      |> assign(:show_edit_form, false)
      |> assign(:viewing_schedule_id, nil)
      |> assign(:current_schedule, nil)
      |> assign(:editing_schedule_id, nil)
      |> assign(:schedule_changeset, Packages.change_package_schedule(%PackageSchedule{}))

    {:noreply, socket}
  end

  def handle_event("close_add_form", _params, socket) do
    socket =
      socket
      |> assign(:show_add_form, false)
      |> assign(:schedule_changeset, Packages.change_package_schedule(%PackageSchedule{}))

    {:noreply, socket}
  end

  def handle_event("edit_schedule", %{"id" => schedule_id}, socket) do
    schedule = Packages.get_package_schedule!(schedule_id)
    changeset = Packages.change_package_schedule(schedule)

    socket =
      socket
      |> assign(:show_edit_form, true)
      |> assign(:show_add_form, false)
      |> assign(:viewing_schedule_id, nil)
      |> assign(:current_schedule, nil)
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
    case socket.assigns.editing_schedule_id do
      nil ->
        # Creating new schedule
        case Packages.create_package_schedule(schedule_params) do
          {:ok, _schedule} ->
            schedules = Packages.list_package_schedules_with_stats()

            socket =
              socket
              |> assign(:schedules, schedules)
              |> assign(:filtered_schedules, schedules)
              |> assign(:show_add_form, false)
              |> assign(:schedule_changeset, Packages.change_package_schedule(%PackageSchedule{}))
              |> put_flash(:info, "Schedule created successfully!")

            {:noreply, socket}

          {:error, %Ecto.Changeset{} = changeset} ->
            socket =
              socket
              |> assign(:schedule_changeset, changeset)

            {:noreply, socket}
        end

      schedule_id ->
        # Updating existing schedule
        schedule = Packages.get_package_schedule!(schedule_id)
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
  end

  def handle_event("delete_schedule", %{"id" => schedule_id}, socket) do
    schedule = Packages.get_package_schedule!(schedule_id)
    {:ok, _} = Packages.delete_package_schedule(schedule)

    schedules = Packages.list_package_schedules_with_stats()

    socket =
      socket
      |> assign(:schedules, schedules)
      |> assign(:filtered_schedules, schedules)
      |> assign(:viewing_schedule_id, nil)
      |> assign(:current_schedule, nil)

    {:noreply, socket}
  end

  def handle_event("cancel_schedule", %{"id" => schedule_id}, socket) do
    schedule = Packages.get_package_schedule!(schedule_id)
    {:ok, _} = Packages.update_package_schedule(schedule, %{status: "cancelled"})

    schedules = Packages.list_package_schedules_with_stats()

    socket =
      socket
      |> assign(:schedules, schedules)
      |> assign(:filtered_schedules, schedules)

    {:noreply, socket}
  end

  defp filter_schedules(schedules, search_query, search_status, search_departure_date, search_return_date) do
    schedules
    |> Enum.filter(fn schedule ->
      package = schedule.package
      name_matches = search_query == "" || String.contains?(String.downcase(package.name), String.downcase(search_query))
      description_matches = search_query == "" || (package.description && String.contains?(String.downcase(package.description), String.downcase(search_query)))
      status_matches = search_status == "" || schedule.status == search_status
      departure_date_matches = search_departure_date == "" || to_string(schedule.departure_date) == search_departure_date
      return_date_matches = search_return_date == "" || to_string(schedule.return_date) == search_return_date

      (name_matches || description_matches) && status_matches && departure_date_matches && return_date_matches
    end)
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Package Schedules Management</h1>
            <button
              phx-click="add_schedule"
              class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors">
              Add New Schedule
            </button>
          </div>

          <!-- Search Bar -->
          <div class="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-6">
            <form phx-change="search_schedules" class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Package Name or Description</label>
                  <input
                    type="text"
                    name="search[query]"
                    value={@search_query}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                    placeholder="Search by package name or description..."
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
                (filtered by name, description, status, departure date, and return date)
              <% end %>
            </p>
          </div>

          <!-- Overall Statistics -->
          <div class="mb-6 grid grid-cols-1 md:grid-cols-4 gap-4">
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-8 w-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm font-medium text-blue-600">Total Quota</p>
                  <p class="text-2xl font-bold text-blue-900">
                    <%= @schedules |> Enum.filter(&(&1.status == "active")) |> Enum.reduce(0, fn s, acc -> acc + s.quota end) %>
                  </p>
                </div>
              </div>
            </div>

            <div class="bg-green-50 border border-green-200 rounded-lg p-4">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-8 w-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm font-medium text-green-600">Active Schedules</p>
                  <p class="text-2xl font-bold text-green-900">
                    <%= @schedules |> Enum.filter(&(&1.status == "active")) |> length() %>
                  </p>
                </div>
              </div>
            </div>

            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-8 w-8 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm font-medium text-yellow-600">Upcoming Departures</p>
                  <p class="text-2xl font-bold text-yellow-900">
                    <%= @schedules |> Enum.filter(fn s -> s.status == "active" and Date.compare(s.departure_date, Date.utc_today()) == :gt end) |> length() %>
                  </p>
                </div>
              </div>
            </div>

            <div class="bg-purple-50 border border-purple-200 rounded-lg p-4">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-8 w-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm font-medium text-purple-600">Total Schedules</p>
                  <p class="text-2xl font-bold text-purple-900">
                    <%= length(@schedules) %>
                  </p>
                </div>
              </div>
            </div>
          </div>

          <%= if @show_add_form do %>
            <!-- Add Schedule Form -->
            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-bold text-gray-900">Add New Schedule</h2>
                <button
                  phx-click="close_add_form"
                  class="text-gray-500 hover:text-gray-700"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                  </svg>
                </button>
              </div>

              <form phx-submit="save_schedule" class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Package</label>
                    <select
                      name="package_schedule[package_id]"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      required
                    >
                      <option value="">Select a package</option>
                      <%= for package <- @packages do %>
                        <option value={package.id}><%= package.name %></option>
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
                      <option value="active">Active</option>
                      <option value="inactive">Inactive</option>
                    </select>
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Quota</label>
                    <input
                      type="number"
                      name="package_schedule[quota]"
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
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      required
                    />
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Return Date</label>
                    <input
                      type="date"
                      name="package_schedule[return_date]"
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
                    ></textarea>
                  </div>
                </div>

                <div class="flex justify-end space-x-3 pt-4">
                  <button
                    type="button"
                    phx-click="close_add_form"
                    class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="px-4 py-2 bg-teal-600 text-white rounded-md hover:bg-teal-700 transition-colors"
                  >
                    Create Schedule
                  </button>
                </div>
              </form>
            </div>
          <% end %>

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

          <%= if @viewing_schedule_id do %>
            <!-- Schedule Detail View -->
            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-bold text-gray-900">Schedule Details</h2>
                <button
                  phx-click="close_schedule_view"
                  class="text-gray-500 hover:text-gray-700"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                  </svg>
                </button>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h3 class="text-lg font-semibold text-gray-900 mb-2"><%= @current_schedule.package.name %></h3>
                  <p class="text-gray-600 mb-4">
                    <%= if @current_schedule.package.description && @current_schedule.package.description != "" do %>
                      <%= @current_schedule.package.description %>
                    <% else %>
                      No description available
                    <% end %>
                  </p>

                  <div class="space-y-3">
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Base Price:</span>
                      <span class="text-sm font-medium text-gray-900">RM <%= @current_schedule.package.price %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Schedule Price:</span>
                      <span class="text-sm font-medium text-gray-900">
                        <%= if @current_schedule.price_override do %>
                          RM <%= @current_schedule.price_override %>
                        <% else %>
                          RM <%= @current_schedule.package.price %> (base price)
                        <% end %>
                      </span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Duration:</span>
                      <span class="text-sm font-medium text-gray-900"><%= @current_schedule.package.duration_days %> days / <%= @current_schedule.package.duration_nights %> nights</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Quota:</span>
                      <span class="text-sm font-medium text-gray-900"><%= @current_schedule.quota %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Departure Date:</span>
                      <span class="text-sm font-medium text-gray-900"><%= @current_schedule.departure_date %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Return Date:</span>
                      <span class="text-sm font-medium text-gray-900"><%= @current_schedule.return_date %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Status:</span>
                      <span class={[
                        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                        case @current_schedule.status do
                          "active" -> "bg-green-100 text-green-800"
                          "inactive" -> "bg-red-100 text-red-800"
                          "cancelled" -> "bg-gray-100 text-gray-800"
                          "completed" -> "bg-blue-100 text-blue-800"
                          _ -> "bg-gray-100 text-gray-800"
                        end
                      ]}>
                        <%= @current_schedule.status %>
                      </span>
                    </div>
                    <%= if @current_schedule.notes && @current_schedule.notes != "" do %>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-500">Notes:</span>
                        <span class="text-sm font-medium text-gray-900"><%= @current_schedule.notes %></span>
                      </div>
                    <% end %>
                  </div>

                  <!-- Booking Statistics -->
                  <div class="mt-6 p-4 bg-blue-50 rounded-lg border border-blue-200">
                    <h4 class="text-sm font-semibold text-blue-900 mb-3">Booking Statistics</h4>
                    <div class="grid grid-cols-2 gap-4">
                      <div class="text-center">
                        <div class="text-2xl font-bold text-blue-600"><%= @current_schedule.booking_stats.confirmed_bookings %></div>
                        <div class="text-xs text-blue-700">Confirmed Bookings</div>
                      </div>
                      <div class="text-center">
                        <div class="text-2xl font-bold text-green-600"><%= @current_schedule.booking_stats.available_slots %></div>
                        <div class="text-xs text-green-700">Available Slots</div>
                      </div>
                    </div>
                    <div class="mt-3 pt-3 border-t border-blue-200">
                      <div class="flex justify-between items-center">
                        <span class="text-sm text-blue-700">Total Quota:</span>
                        <span class="text-sm font-semibold text-blue-900"><%= @current_schedule.quota %></span>
                      </div>
                      <div class="flex justify-between items-center mt-1">
                        <span class="text-sm text-blue-700">Booking Percentage:</span>
                        <span class="text-sm font-semibold text-blue-900"><%= @current_schedule.booking_stats.booking_percentage %>%</span>
                      </div>
                      <div class="mt-2">
                        <div class="w-full bg-blue-200 rounded-full h-2">
                          <div class="bg-blue-600 h-2 rounded-full" style={"width: #{@current_schedule.booking_stats.booking_percentage}%"}>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="flex flex-col space-y-3">
                  <div class="bg-white p-4 rounded-lg border border-gray-200">
                    <h4 class="text-sm font-semibold text-gray-900 mb-3">Quick Actions</h4>
                    <div class="space-y-2">
                      <button
                        phx-click="edit_schedule"
                        phx-value-id={@current_schedule.id}
                        class="w-full bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium"
                      >
                      Edit Schedule
                      </button>
                      <%= if @current_schedule.status == "active" do %>
                        <button
                          phx-click="cancel_schedule"
                          phx-value-id={@current_schedule.id}
                          data-confirm="Are you sure you want to cancel this schedule?"
                          class="w-full bg-yellow-600 text-white px-4 py-2 rounded-lg hover:bg-yellow-700 transition-colors text-sm font-medium"
                        >
                          Cancel Schedule
                        </button>
                      <% end %>
                      <button
                        phx-click="delete_schedule"
                        phx-value-id={@current_schedule.id}
                        data-confirm="Are you sure you want to delete this schedule? This will also delete all associated bookings."
                        class="w-full bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors text-sm font-medium"
                      >
                        Delete Schedule
                      </button>
                    </div>
                  </div>
                </div>
              </div>
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
                        <span class="text-sm text-gray-500">Price:</span>
                        <span class="text-sm font-medium text-gray-900">
                          <%= if schedule.price_override do %>
                            RM <%= schedule.price_override %>
                          <% else %>
                            RM <%= schedule.package.price %>
                          <% end %>
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
                      <button
                        phx-click="view_schedule"
                        phx-value-id={schedule.id}
                        class="flex-1 bg-teal-600 text-white px-3 py-2 rounded text-sm hover:bg-teal-700 transition-colors"
                      >
                        View
                      </button>
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
