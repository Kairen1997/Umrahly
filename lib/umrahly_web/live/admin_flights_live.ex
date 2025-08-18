defmodule UmrahlyWeb.AdminFlightsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout

  def mount(_params, _session, socket) do
    # Mock data for flights - in a real app, this would come from your database
    flights = [
      %{
        id: 1,
        flight_number: "MH-001",
        origin: "Kuala Lumpur (KUL)",
        destination: "Jeddah (JED)",
        departure_time: "2024-12-15 02:00",
        arrival_time: "2024-12-15 08:30",
        aircraft: "Boeing 777",
        capacity: 300,
        booked_seats: 245,
        status: "Scheduled"
      },
      %{
        id: 2,
        flight_number: "MH-002",
        origin: "Jeddah (JED)",
        destination: "Kuala Lumpur (KUL)",
        departure_time: "2024-12-22 10:00",
        arrival_time: "2024-12-22 16:30",
        aircraft: "Boeing 777",
        capacity: 300,
        booked_seats: 198,
        status: "Scheduled"
      },
      %{
        id: 3,
        flight_number: "MH-003",
        origin: "Kuala Lumpur (KUL)",
        destination: "Medina (MED)",
        departure_time: "2024-12-16 01:30",
        arrival_time: "2024-12-16 07:45",
        aircraft: "Airbus A330",
        capacity: 250,
        booked_seats: 180,
        status: "Scheduled"
      }
    ]

    socket =
      socket
      |> assign(:flights, flights)
      |> assign(:current_page, "flights")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Flights Management</h1>
            <button class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors">
              Add New Flight
            </button>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Flight Number</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Route</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Departure</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Arrival</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Aircraft</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Capacity</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for flight <- @flights do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900"><%= flight.flight_number %></td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">
                        <div><%= flight.origin %></div>
                        <div class="text-gray-500">→</div>
                        <div><%= flight.destination %></div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= flight.departure_time %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= flight.arrival_time %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= flight.aircraft %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <div class="flex items-center">
                        <span class="mr-2"><%= flight.booked_seats %>/<%= flight.capacity %></span>
                        <div class="w-16 bg-gray-200 rounded-full h-2">
                          <div class="bg-teal-600 h-2 rounded-full" style={"width: #{flight.booked_seats / flight.capacity * 100}%"}>
                          </div>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class={[
                        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                        case flight.status do
                          "Scheduled" -> "bg-green-100 text-green-800"
                          "Delayed" -> "bg-yellow-100 text-yellow-800"
                          "Cancelled" -> "bg-red-100 text-red-800"
                          "Boarding" -> "bg-blue-100 text-blue-800"
                          _ -> "bg-gray-100 text-gray-800"
                        end
                      ]}>
                        <%= flight.status %>
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button class="text-teal-600 hover:text-teal-900 mr-3">Edit</button>
                      <button class="text-blue-600 hover:text-blue-900 mr-3">Manage</button>
                      <button class="text-red-600 hover:text-red-900">Cancel</button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
