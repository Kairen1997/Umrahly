defmodule UmrahlyWeb.AdminPackageScheduleViewLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages

  def mount(%{"id" => schedule_id}, _session, socket) do
    # Try to get the schedule with all necessary details
    schedule = try do
      Packages.get_package_schedule!(String.to_integer(schedule_id))
    rescue
      Ecto.QueryError -> nil
      Ecto.NoResultsError -> nil
      _ -> nil
    end

    if schedule && schedule.package do
      # Ensure the schedule has booking stats
      schedule = if Map.has_key?(schedule, :booking_stats) do
        schedule
      else
        # Calculate booking stats for this schedule
        try do
          stats = Packages.get_package_schedule_booking_stats(schedule.id)
          Map.put(schedule, :booking_stats, stats)
        rescue
          _ ->
            # If we can't get booking stats, provide default values
            Map.put(schedule, :booking_stats, %{
              total_bookings: 0,
              confirmed_bookings: 0,
              available_slots: schedule.quota,
              booking_percentage: 0.0
            })
        end
      end

      socket =
        socket
        |> assign(:current_schedule, schedule)
        |> assign(:current_page, "package_schedules")
        |> assign(:has_profile, true)
        |> assign(:is_admin, true)
        |> assign(:profile, socket.assigns.current_user)

      {:ok, socket}
    else
      {:ok,
        socket
        |> assign(:current_schedule, nil)
        |> assign(:current_page, "package_schedules")
        |> assign(:has_profile, true)
        |> assign(:is_admin, true)
        |> assign(:profile, socket.assigns.current_user)
        |> put_flash(:error, "Schedule not found or is missing package details")
      }
    end
  end

  def handle_event("cancel_schedule", %{"id" => schedule_id}, socket) do
    schedule = Packages.get_package_schedule!(String.to_integer(schedule_id))

    case Packages.update_package_schedule(schedule, %{status: "cancelled"}) do
      {:ok, updated_schedule} ->
        # Refresh the schedule data with updated status
        updated_schedule = Map.put(updated_schedule, :booking_stats, socket.assigns.current_schedule.booking_stats)

        socket =
          socket
          |> assign(:current_schedule, updated_schedule)
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
    schedule = Packages.get_package_schedule!(String.to_integer(schedule_id))

    case Packages.delete_package_schedule(schedule) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Schedule deleted successfully!")
          |> push_navigate(to: ~p"/admin/package-schedules")

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to delete schedule")

        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-6xl mx-auto">
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
              <h1 class="text-2xl font-bold text-gray-900">Schedule Details</h1>
            </div>
          </div>

          <%= if @current_schedule do %>
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
                    <span class="text-sm text-gray-500">Package Price:</span>
                    <span class="text-sm font-medium text-gray-900">RM <%= @current_schedule.package.price %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-sm text-gray-500">Schedule Price:</span>
                    <span class="text-sm font-medium text-gray-900">
                      RM <%= @current_schedule.package.price %> (base price)
                    </span>
                  </div>
                  <div class="flex justify-between border-t border-gray-200 pt-2">
                    <span class="text-sm font-semibold text-gray-700">Total Price:</span>
                    <span class="text-sm font-bold text-gray-900">
                      RM <%= @current_schedule.package.price %>
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
                  <%= if @current_schedule.package.accommodation_type && @current_schedule.package.accommodation_type != "" do %>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Accommodation:</span>
                      <span class="text-sm font-medium text-gray-900"><%= @current_schedule.package.accommodation_type %></span>
                    </div>
                    <%= if @current_schedule.package.accommodation_details && @current_schedule.package.accommodation_details != "" do %>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-500">Accommodation Details:</span>
                        <span class="text-sm font-medium text-gray-900"><%= @current_schedule.package.accommodation_details %></span>
                      </div>
                    <% end %>
                  <% end %>
                  <%= if @current_schedule.package.transport_type && @current_schedule.package.transport_type != "" do %>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Transport:</span>
                      <span class="text-sm font-medium text-gray-900"><%= @current_schedule.package.transport_type %></span>
                    </div>
                    <%= if @current_schedule.package.transport_details && @current_schedule.package.transport_details != "" do %>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-500">Transport Details:</span>
                        <span class="text-sm font-medium text-gray-900"><%= @current_schedule.package.transport_details %></span>
                      </div>
                    <% end %>
                  <% end %>
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
                    <a
                      href={~p"/admin/package-schedules/#{@current_schedule.id}/edit"}
                      class="w-full bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium text-center block"
                    >
                      Edit Schedule
                    </a>
                    <%= if @current_schedule.status == "active" do %>
                      <button
                        phx-click="cancel_schedule"
                        phx-value-id={@current_schedule.id}
                        data-confirm="Are you sure you want to cancel this schedule?"
                        class="w-full bg-yellow-600 text-white px-4 py-2 rounded-lg hover:bg-yellow-700 transition-colors text-sm font-medium text-center"
                      >
                        Cancel Schedule
                      </button>
                    <% end %>
                    <button
                      phx-click="delete_schedule"
                      phx-value-id={@current_schedule.id}
                      data-confirm="Are you sure you want to delete this schedule? This will also delete all associated bookings."
                      class="w-full bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors text-sm font-medium text-center"
                    >
                      Delete Schedule
                    </button>
                  </div>
                </div>
              </div>
            </div>
          <% else %>
            <!-- Schedule not found message -->
            <div class="bg-red-50 border border-red-200 rounded-lg p-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-bold text-red-900">Schedule Not Found</h2>
              </div>
              <p class="text-red-700">The requested schedule could not be found or loaded. Please try again or contact support if the problem persists.</p>
              <div class="mt-4">
                <button
                  phx-click="go_back"
                  class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors"
                >
                  Go Back to Schedules
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
