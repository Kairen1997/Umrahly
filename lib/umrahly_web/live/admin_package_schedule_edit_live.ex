defmodule UmrahlyWeb.AdminPackageScheduleEditLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages
  alias Umrahly.Packages.PackageSchedule

  def mount(%{"id" => schedule_id}, _session, socket) do
    schedule = Packages.get_package_schedule!(String.to_integer(schedule_id))
    packages = Packages.list_packages()
    changeset = Packages.change_package_schedule(schedule)

    socket =
      socket
      |> assign(:schedule, schedule)
      |> assign(:packages, packages)
      |> assign(:changeset, changeset)
      |> assign(:current_page, "package_schedules")
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns.current_user)

    {:ok, socket}
  end

  def handle_event("save", %{"package_schedule" => schedule_params}, socket) do
    case Packages.update_package_schedule(socket.assigns.schedule, schedule_params) do
      {:ok, _updated_schedule} ->
        socket =
          socket
          |> put_flash(:info, "Schedule updated successfully!")
          |> push_navigate(to: ~p"/admin/package-schedules/#{socket.assigns.schedule.id}")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket = assign(socket, :changeset, changeset)
        {:noreply, socket}
    end
  end

  def handle_event("cancel", _params, socket) do
    socket = push_navigate(socket, to: ~p"/admin/package-schedules/#{socket.assigns.schedule.id}")
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="bg-white rounded-lg shadow p-6">
        <!-- Header with back button -->
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center space-x-4">
            <a
              href={~p"/admin/package-schedules/#{@schedule.id}"}
              class="text-gray-500 hover:text-gray-700 transition-colors"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
              </svg>
            </a>
            <h1 class="text-2xl font-bold text-gray-900">Edit Schedule</h1>
          </div>
        </div>

        <div class="max-w-4xl">
          <div class="bg-gray-50 border border-gray-200 rounded-lg p-6">
            <form phx-submit="save" class="space-y-6">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Package</label>
                  <select
                    name="package_schedule[package_id]"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                    required
                  >
                    <%= for package <- @packages do %>
                      <option value={package.id} selected={@changeset.data.package_id == package.id}><%= package.name %></option>
                    <% end %>
                  </select>
                  <%= if @changeset.errors[:package_id] do %>
                    <p class="mt-1 text-sm text-red-600"><%= elem(@changeset.errors[:package_id], 0) %></p>
                  <% end %>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
                  <select
                    name="package_schedule[status]"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                    required
                  >
                    <option value="active" selected={@changeset.data.status == "active"}>Active</option>
                    <option value="inactive" selected={@changeset.data.status == "inactive"}>Inactive</option>
                    <option value="cancelled" selected={@changeset.data.status == "cancelled"}>Cancelled</option>
                    <option value="completed" selected={@changeset.data.status == "completed"}>Completed</option>
                  </select>
                  <%= if @changeset.errors[:status] do %>
                    <p class="mt-1 text-sm text-red-600"><%= elem(@changeset.errors[:status], 0) %></p>
                  <% end %>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Quota</label>
                  <input
                    type="number"
                    name="package_schedule[quota]"
                    value={@changeset.data.quota}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                    placeholder="Enter quota"
                    min="1"
                    max="100"
                    required
                  />
                  <%= if @changeset.errors[:quota] do %>
                    <p class="mt-1 text-sm text-red-600"><%= elem(@changeset.errors[:quota], 0) %></p>
                  <% end %>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Price Override (RM)</label>
                  <input
                    type="number"
                    name="package_schedule[price_override]"
                    value={@changeset.data.price_override}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                    placeholder="Leave empty to use package price"
                    min="1"
                  />
                  <%= if @changeset.errors[:price_override] do %>
                    <p class="mt-1 text-sm text-red-600"><%= elem(@changeset.errors[:price_override], 0) %></p>
                  <% end %>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Departure Date</label>
                  <input
                    type="date"
                    name="package_schedule[departure_date]"
                    value={@changeset.data.departure_date}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                    required
                  />
                  <%= if @changeset.errors[:departure_date] do %>
                    <p class="mt-1 text-sm text-red-600"><%= elem(@changeset.errors[:departure_date], 0) %></p>
                  <% end %>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Return Date</label>
                  <input
                    type="date"
                    name="package_schedule[return_date]"
                    value={@changeset.data.return_date}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                    required
                  />
                  <%= if @changeset.errors[:return_date] do %>
                    <p class="mt-1 text-sm text-red-600"><%= elem(@changeset.errors[:return_date], 0) %></p>
                  <% end %>
                </div>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Notes</label>
                <textarea
                  name="package_schedule[notes]"
                  rows="4"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Any additional notes about this schedule..."
                ><%= @changeset.data.notes || "" %></textarea>
                <%= if @changeset.errors[:notes] do %>
                  <p class="mt-1 text-sm text-red-600"><%= elem(@changeset.errors[:notes], 0) %></p>
                <% end %>
              </div>

              <div class="flex justify-end space-x-3 pt-4">
                <button
                  type="button"
                  phx-click="cancel"
                  class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-4 py-2 bg-teal-600 text-white rounded-md hover:bg-teal-700 transition-colors"
                >
                  Update Schedule
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
