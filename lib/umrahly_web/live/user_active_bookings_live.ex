defmodule UmrahlyWeb.UserActiveBookingsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    # Get all active booking flows for the current user
    active_bookings = Bookings.get_booking_flow_progress_by_user_id(socket.assigns.current_user.id)

    socket =
      socket
      |> assign(:active_bookings, active_bookings)
      |> assign(:page_title, "Active Bookings")

    {:ok, socket}
  end

  def handle_event("resume_booking", %{"id" => id}, socket) do
    # Find the booking flow progress
    case Enum.find(socket.assigns.active_bookings, &(&1.id == String.to_integer(id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Booking flow not found")}
      booking_flow ->
        # Redirect to the booking flow with the saved progress
        {:noreply, push_navigate(socket, to: ~p"/book/#{booking_flow.package_id}/#{booking_flow.package_schedule_id}?resume=true")}
    end
  end

  def handle_event("abandon_booking", %{"id" => id}, socket) do
    # Find the booking flow progress and mark it as abandoned
    case Enum.find(socket.assigns.active_bookings, &(&1.id == String.to_integer(id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Booking flow not found")}
      _booking_flow ->
        # In a real implementation, you would call Bookings.abandon_booking_flow_progress/1
        # For now, we'll just remove it from the list
        updated_bookings = Enum.reject(socket.assigns.active_bookings, &(&1.id == String.to_integer(id)))

        socket =
          socket
          |> assign(:active_bookings, updated_bookings)
          |> put_flash(:info, "Booking flow abandoned")

        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div class="max-w-4xl mx-auto space-y-6">
        <!-- Header -->
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">Active Bookings</h1>
              <p class="text-gray-600 mt-1">Resume your incomplete booking flows or start a new one</p>
            </div>
            <a
              href="/packages"
              class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
            >
              Browse Packages
            </a>
          </div>
        </div>

        <%= if Enum.empty?(@active_bookings) do %>
          <!-- No Active Bookings -->
          <div class="bg-white rounded-lg shadow p-8 text-center">
            <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No Active Bookings</h3>
            <p class="text-gray-600 mb-6">You don't have any incomplete booking flows. Start booking a package to get started!</p>
            <a
              href="/packages"
              class="inline-block bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
            >
              Browse Packages
            </a>
          </div>
        <% else %>
          <!-- Active Bookings List -->
          <div class="space-y-4">
            <%= for booking <- @active_bookings do %>
              <div class="bg-white rounded-lg shadow p-6">
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <div class="flex items-center space-x-3 mb-3">
                      <h3 class="text-lg font-semibold text-gray-900"><%= booking.package.name %></h3>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        Step <%= booking.current_step %> of <%= booking.max_steps %>
                      </span>
                    </div>

                    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm text-gray-600 mb-4">
                      <div>
                        <span class="font-medium">Travel Dates:</span>
                        <div class="mt-1">
                          <div>Departure: <%= Calendar.strftime(booking.package_schedule.departure_date, "%B %d, %Y") %></div>
                          <div>Return: <%= Calendar.strftime(booking.package_schedule.return_date, "%B %d, %Y") %></div>
                        </div>
                      </div>
                      <div>
                        <span class="font-medium">Travelers:</span>
                        <div class="mt-1"><%= booking.number_of_persons %> person(s)</div>
                      </div>
                      <div>
                        <span class="font-medium">Total Amount:</span>
                        <div class="mt-1">
                          <%= if booking.total_amount do %>
                            RM <%= booking.total_amount %>
                          <% else %>
                            Not calculated yet
                          <% end %>
                        </div>
                      </div>
                    </div>

                    <div class="text-xs text-gray-500">
                      Last updated: <%= Calendar.strftime(booking.last_updated, "%B %d, %Y at %I:%M %p") %>
                    </div>
                  </div>

                  <div class="flex flex-col space-y-2 ml-4">
                    <button
                      phx-click="resume_booking"
                      phx-value-id={booking.id}
                      class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium text-sm"
                    >
                      Resume Booking
                    </button>
                    <button
                      phx-click="abandon_booking"
                      phx-value-id={booking.id}
                      class="bg-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium text-sm"
                    >
                      Abandon
                    </button>
                  </div>
                </div>

                <!-- Progress Bar -->
                <div class="mt-4">
                  <div class="w-full bg-gray-200 rounded-full h-2">
                    <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{Float.round((booking.current_step / booking.max_steps) * 100, 1)}%"}>
                    </div>
                  </div>
                  <div class="flex justify-between text-xs text-gray-500 mt-1">
                    <span>Package Details</span>
                    <span>Travelers</span>
                    <span>Payment</span>
                    <span>Review</span>
                    <span>Success</span>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </.sidebar>
    """
  end
end
