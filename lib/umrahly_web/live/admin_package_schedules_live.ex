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
      |> assign(:page, 1)
      |> assign(:per_page, 10)
      |> assign(:total_pages, Float.ceil(length(schedules) / 10.0, 0) |> trunc)

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
      |> assign(:page, 1)
      |> assign(:total_pages, Float.ceil(length(filtered_schedules) / socket.assigns.per_page, 0) |> trunc)

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
      |> assign(:page, 1)
      |> assign(:total_pages, Float.ceil(length(socket.assigns.schedules) / socket.assigns.per_page, 0) |> trunc)

    {:noreply, socket}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page = String.to_integer(page)
    total_pages = socket.assigns.total_pages

    # Ensure page is within valid range
    page = max(1, min(page, total_pages))

    socket = assign(socket, :page, page)
    {:noreply, socket}
  end





  def handle_event("cancel_schedule", %{"id" => schedule_id}, socket) do
    schedule = Packages.get_package_schedule!(schedule_id)

    case Packages.update_package_schedule(schedule, %{status: "cancelled"}) do
      {:ok, _updated_schedule} ->
        schedules = Packages.list_package_schedules_with_stats()

        # Recalculate filtered schedules and pagination
        filtered_schedules = filter_schedules(schedules, socket.assigns.search_query, socket.assigns.search_status, socket.assigns.search_departure_date, socket.assigns.search_return_date)
        total_pages = Float.ceil(length(filtered_schedules) / socket.assigns.per_page, 0) |> trunc

        # Reset to page 1 if current page is beyond the new total
        new_page = if socket.assigns.page > total_pages, do: 1, else: socket.assigns.page

        socket =
          socket
          |> assign(:schedules, schedules)
          |> assign(:filtered_schedules, filtered_schedules)
          |> assign(:total_pages, total_pages)
          |> assign(:page, new_page)
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

    # Recalculate filtered schedules and pagination
    filtered_schedules = filter_schedules(schedules, socket.assigns.search_query, socket.assigns.search_status, socket.assigns.search_departure_date, socket.assigns.search_return_date)
    total_pages = Float.ceil(length(filtered_schedules) / socket.assigns.per_page, 0) |> trunc

    # Reset to page 1 if current page is beyond the new total
    new_page = if socket.assigns.page > total_pages, do: 1, else: socket.assigns.page

    socket =
      socket
      |> assign(:schedules, schedules)
      |> assign(:filtered_schedules, filtered_schedules)
      |> assign(:total_pages, total_pages)
      |> assign(:page, new_page)
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

        # Recalculate filtered schedules and pagination
        filtered_schedules = filter_schedules(schedules, socket.assigns.search_query, socket.assigns.search_status, socket.assigns.search_departure_date, socket.assigns.search_return_date)
        total_pages = Float.ceil(length(filtered_schedules) / socket.assigns.per_page, 0) |> trunc

        # Reset to page 1 if current page is beyond the new total
        new_page = if socket.assigns.page > total_pages, do: 1, else: socket.assigns.page

        socket =
          socket
          |> assign(:schedules, schedules)
          |> assign(:filtered_schedules, filtered_schedules)
          |> assign(:total_pages, total_pages)
          |> assign(:page, new_page)
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

  defp get_paginated_schedules(schedules, page, per_page) do
    start_index = (page - 1) * per_page
    schedules
    |> Enum.slice(start_index, per_page)
  end

  defp get_schedule_remarks(schedule) do
    cond do
      schedule.status == "cancelled" ->
        "Schedule cancelled"
      schedule.status == "completed" ->
        "Schedule completed"
      schedule.status == "inactive" ->
        "Schedule inactive"
      schedule.updated_at != schedule.inserted_at ->
        "Last modified: #{format_datetime(schedule.updated_at)}"
      true ->
        "No changes"
    end
  end

  defp format_datetime(datetime) do
    case datetime do
      %DateTime{} ->
        Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
      %NaiveDateTime{} ->
        Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
      _ ->
        "Unknown"
    end
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
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
        <div class="overflow-x-auto">
          <table class="min-w-full bg-white border border-gray-200 rounded-lg shadow-sm">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                  Package Name
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                  Status
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                  Total Price
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                  Quota
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                  Bookings
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                  Departure Date
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                  Return Date
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                  Accommodation
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                  Transport
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                  Actions
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                  Remarks
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <%= if length(@filtered_schedules) == 0 do %>
                <tr>
                  <td colspan="11" class="px-6 py-12 text-center">
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
                  </td>
                </tr>
              <% else %>
                <%= for schedule <- get_paginated_schedules(@filtered_schedules, @page, @per_page) do %>
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-medium text-gray-900"><%= schedule.package.name %></div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
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
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-bold text-gray-900">
                        RM <%=
                          base_price = schedule.package.price
                          override_price = if schedule.price_override, do: Decimal.to_integer(schedule.price_override), else: 0
                          base_price + override_price
                        %>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900"><%= schedule.quota %></div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">
                        <%= schedule.booking_stats.confirmed_bookings %> / <%= schedule.quota %>
                      </div>
                      <div class="mt-1 w-20">
                        <div class="w-full bg-gray-200 rounded-full h-1.5">
                          <div class="bg-teal-500 h-1.5 rounded-full" style={"width: #{schedule.booking_stats.booking_percentage}%"}>
                          </div>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900"><%= schedule.departure_date %></div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900"><%= schedule.return_date %></div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">
                        <%= if schedule.package.accommodation_type && schedule.package.accommodation_type != "" do %>
                          <%= schedule.package.accommodation_type %>
                        <% else %>
                          <span class="text-gray-400">-</span>
                        <% end %>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">
                        <%= if schedule.package.transport_type && schedule.package.transport_type != "" do %>
                          <%= schedule.package.transport_type %>
                        <% else %>
                          <span class="text-gray-400">-</span>
                        <% end %>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <a
                        href={~p"/admin/package-schedules/#{schedule.id}"}
                        class="bg-teal-600 text-white px-3 py-2 rounded text-sm hover:bg-teal-700 transition-colors"
                      >
                        View Details
                      </a>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">
                        <%= get_schedule_remarks(schedule) %>
                      </div>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>

        <!-- Pagination Controls -->
        <%= if @total_pages > 1 do %>
          <div class="mt-6 flex items-center justify-between">
            <div class="text-sm text-gray-700">
              Showing <%= (@page - 1) * @per_page + 1 %> to <%= min(@page * @per_page, length(@filtered_schedules)) %> of <%= length(@filtered_schedules) %> results
            </div>

            <div class="flex items-center space-x-2">
              <!-- Previous Page Button -->
              <button
                phx-click="change_page"
                phx-value-page={@page - 1}
                disabled={@page <= 1}
                class={[
                  "px-3 py-2 text-sm font-medium rounded-md",
                  if @page <= 1 do
                    "text-gray-400 bg-gray-100 cursor-not-allowed"
                  else
                    "text-gray-700 bg-white border border-gray-300 hover:bg-gray-50"
                  end
                ]}
              >
                Previous
              </button>

              <!-- Page Numbers -->
              <div class="flex items-center space-x-1">
                <%= for page_num <- max(1, @page - 2)..min(@total_pages, @page + 2) do %>
                  <button
                    phx-click="change_page"
                    phx-value-page={page_num}
                    class={[
                      "px-3 py-2 text-sm font-medium rounded-md",
                      if page_num == @page do
                        "bg-teal-600 text-white"
                      else
                        "text-gray-700 bg-white border border-gray-300 hover:bg-gray-50"
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
                phx-value-page={@page + 1}
                disabled={@page >= @total_pages}
                class={[
                  "px-3 py-2 text-sm font-medium rounded-md",
                  if @page >= @total_pages do
                    "text-gray-400 bg-gray-100 cursor-not-allowed"
                  else
                    "text-gray-700 bg-white border border-gray-300 hover:bg-gray-50"
                  end
                ]}
              >
                Next
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </.admin_layout>
    """
  end
end
