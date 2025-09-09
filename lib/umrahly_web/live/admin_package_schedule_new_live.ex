defmodule UmrahlyWeb.AdminPackageScheduleNewLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages
  alias Umrahly.Packages.PackageSchedule
  alias Umrahly.Flights
   # Helper function to get field value from changeset
   defp get_field_value(changeset, field) do
    # First try to get the value from changes (user input)
    case Ecto.Changeset.get_change(changeset, field) do
      nil ->
        # If no change, try to get from the data (existing value)
        case Ecto.Changeset.get_field(changeset, field) do
          nil -> ""
          value ->
            # Convert Date struct to string if needed
          if is_struct(value, Date) do
            Date.to_iso8601(value)
          else
             value
          end
        end
      value ->

        # If it's a string and empty, return empty string, otherwise return the value
        if is_binary(value) && value == "", do: "", else: value
    end
  end

  def mount(params, _session, socket) do
    packages = Packages.list_packages()
    flights = Flights.list_flights()
    available_departure_dates = Packages.get_available_departure_dates()
    available_return_dates = Packages.get_available_return_dates()


    departure_date = case params["package_schedule"]["departure_date"] do
      %Date{} = d -> Date.to_iso8601(d)
      other -> other
    end
    return_date = case params["package_schedule"]["return_date"] do
      %Date{} = d -> Date.to_iso8601(d)
      other -> other
    end
    # Extract query parameters for pre-filling the form
    initial_attrs = %{
      package_id: params["package_schedule"]["package_id"],
      status: params["package_schedule"]["status"] || "active",
      quota: params["package_schedule"]["quota"],
      price_override: params["package_schedule"]["price_override"],
      departure_date: departure_date,
      return_date: return_date,
      notes: params["package_schedule"]["notes"]
    }

    # Filter out nil values
    initial_attrs = Map.filter(initial_attrs, fn {_key, value} -> value != nil and value != "" end)

    changeset = Packages.change_package_schedule(%PackageSchedule{}, initial_attrs)

    socket =
      socket
      |> assign(:packages, packages)
      |> assign(:flights, flights)
      |> assign(:available_departure_dates, available_departure_dates)
      |> assign(:available_return_dates, available_return_dates)
      |> assign(:schedule_changeset, changeset)
      |> assign(:current_page, "package_schedules")
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns[:current_user])
      |> assign(:current_user, socket.assigns[:current_user])

    {:ok, socket}
  end

  def handle_event("validate", %{"package_schedule" => schedule_params}, socket) do
    changeset =
      %PackageSchedule{}
      |> Packages.change_package_schedule(schedule_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :schedule_changeset, changeset)}
  end

  def handle_event("save_schedule", %{"package_schedule" => schedule_params}, socket) do
    case Packages.create_package_schedule(schedule_params) do
      {:ok, _schedule} ->
        socket =
          socket
          |> put_flash(:info, "Schedule created successfully!")

        {:noreply, push_navigate(socket, to: ~p"/admin/package-schedules")}

            {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> assign(:schedule_changeset, changeset)

        {:noreply, socket}
    end
  end

  def handle_event("refresh_dates", _, socket) do
    available_departure_dates = Packages.get_available_departure_dates()
    available_return_dates = Packages.get_available_return_dates()

    {:noreply,
      socket
      |> assign(:available_departure_dates, available_departure_dates)
      |> assign(:available_return_dates, available_return_dates)
      |> put_flash(:info, "Available dates refreshed!")
    }
  end

  defp render_error_messages(assigns) do
    if assigns.schedule_changeset.errors != [] do
      ~H"""
      <div class="max-w-4xl mx-auto mb-4">
        <div class="bg-red-50 border border-red-200 rounded-lg p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-red-800">Please fix the following errors:</h3>
              <div class="mt-2 text-sm text-red-700">
                <ul class="list-disc pl-5 space-y-1">
                  <%= for {field, {message, _}} <- assigns.schedule_changeset.errors do %>
                    <li><%= String.upcase("#{field}") %>: <%= message %></li>
                  <% end %>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
      """
    end
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <%= render_error_messages(assigns) %>
      <div class="max-w-4xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <!-- Header with back button -->
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center space-x-4">
              <a
                href={~p"/admin/package-schedules"}
                class="text-gray-500 hover:text-gray-700 transition-colors"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
                </svg>
              </a>
              <h1 class="text-2xl font-bold text-gray-900">Add New Schedule</h1>
            </div>
          </div>

          <!-- Add this above the form -->
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold text-gray-800">Schedule Details</h2>
            <button
              type="button"
              phx-click="refresh_dates"
              class="text-sm text-teal-600 hover:text-teal-800 flex items-center"
            >
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
              </svg>
              Refresh Available Dates
            </button>
          </div>
          <!-- Add Schedule Form -->
          <form phx-submit="save_schedule" phx-change="validate" class="space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Package *</label>
                <select
                  name="package_schedule[package_id]"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  required
                >
                  <option value="">Select a package</option>
                  <%= for package <- @packages do %>
                  <option value={package.id} selected={get_field_value(@schedule_changeset, :package_id) == package.id}><%= package.name %></option>
                  <% end %>
                </select>
                <%= if @schedule_changeset.errors[:package_id] do %>
                  <p class="mt-1 text-sm text-red-600"><%= elem(@schedule_changeset.errors[:package_id], 0) %></p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Status *</label>
                <select
                  name="package_schedule[status]"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  required
                >
                  <option value="active" selected={get_field_value(@schedule_changeset, :status) == "active"}>Active</option>
                  <option value="inactive" selected={get_field_value(@schedule_changeset, :status) == "inactive"}>Inactive</option>
                </select>
                <%= if @schedule_changeset.errors[:status] do %>
                  <p class="mt-1 text-sm text-red-600"><%= elem(@schedule_changeset.errors[:status], 0) %></p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Quota *</label>
                <input
                  type="number"
                  name="package_schedule[quota]"
                  value={get_field_value(@schedule_changeset, :quota)}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Enter quota"
                  min="1"
                  max="100"
                  required
                />
                <%= if @schedule_changeset.errors[:quota] do %>
                  <p class="mt-1 text-sm text-red-600"><%= elem(@schedule_changeset.errors[:quota], 0) %></p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Price Override (RM)</label>
                <input
                  type="number"
                  name="package_schedule[price_override]"
                  value={get_field_value(@schedule_changeset, :price_override)}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Leave empty to use package price"
                  min="1"
                  step="0.01"
                />
                <%= if @schedule_changeset.errors[:price_override] do %>
                  <p class="mt-1 text-sm text-red-600"><%= elem(@schedule_changeset.errors[:price_override], 0) %></p>
                <% end %>
              </div>
            </div>
            <!-- Enhanced departure date dropdown with custom option -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Departure Date *</label>
             <select
                name="package_schedule[departure_date]"
                id="departure-date-select"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                required
              >
                <option value="">Select departure date</option>
                <%= for date <- @available_departure_dates do %>
                  <option
                    value={Date.to_iso8601(date)}
                    selected={get_field_value(@schedule_changeset, :departure_date) == Date.to_iso8601(date)}
                  >
                    <%= Calendar.strftime(date, "%B %d, %Y (%A)") %>
                  </option>
                <% end %>
              </select>


              <%= if @schedule_changeset.errors[:departure_date] do %>
                <p class="mt-1 text-sm text-red-600"><%= elem(@schedule_changeset.errors[:departure_date], 0) %></p>
              <% end %>
            </div>

            <!-- Enhanced return date dropdown with custom option -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Return Date *</label>
              <select
                name="package_schedule[return_date]"
                id="return-date-select"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                required
              >
                <option value="">Select return date</option>
                <%= for date <- @available_return_dates do %>
                  <option
                    value={Date.to_iso8601(date)}
                    selected={get_field_value(@schedule_changeset, :return_date) == Date.to_iso8601(date)}
                  >
                    <%= Calendar.strftime(date, "%B %d, %Y (%A)") %>
                  </option>
                <% end %>
              </select>


              <%= if @schedule_changeset.errors[:return_date] do %>
                <p class="mt-1 text-sm text-red-600"><%= elem(@schedule_changeset.errors[:return_date], 0) %></p>
              <% end %>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Notes</label>
              <textarea
                name="package_schedule[notes]"
                rows="4"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                placeholder="Any additional notes about this schedule..."
              ><%= get_field_value(@schedule_changeset, :notes) || "" %></textarea>
              <%= if @schedule_changeset.errors[:notes] do %>
                <p class="mt-1 text-sm text-red-600"><%= elem(@schedule_changeset.errors[:notes], 0) %></p>
              <% end %>
            </div>

            <div class="flex justify-end space-x-3 pt-6 border-t border-gray-200">
              <a
                href={~p"/admin/package-schedules"}
                class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
              >
                Cancel
              </a>
              <button
                type="submit"
                class="px-4 py-2 bg-teal-600 text-white rounded-md hover:bg-teal-700 transition-colors"
              >
                Create Schedule
              </button>
            </div>
          </form>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
