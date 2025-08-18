defmodule UmrahlyWeb.AdminBookingsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout

  def mount(_params, _session, socket) do
    # Mock data for bookings - in a real app, this would come from your database
    bookings = [
      %{
        id: 1,
        user_name: "John Doe",
        package: "Standard Package",
        status: "Confirmed",
        amount: "RM 2,500",
        booking_date: "2024-08-15",
        travel_date: "2024-12-15"
      },
      %{
        id: 2,
        user_name: "Sarah Smith",
        package: "Premium Package",
        status: "Pending",
        amount: "RM 4,500",
        booking_date: "2024-08-14",
        travel_date: "2024-11-20"
      },
      %{
        id: 3,
        user_name: "Ahmed Hassan",
        package: "Standard Package",
        status: "Cancelled",
        amount: "RM 2,500",
        booking_date: "2024-08-13",
        travel_date: "2024-10-15"
      }
    ]

    socket =
      socket
      |> assign(:bookings, bookings)
      |> assign(:current_page, "bookings")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Bookings Management</h1>
            <button class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors">
              Add New Booking
            </button>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Booking ID</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Customer</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Package</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Booking Date</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Travel Date</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for booking <- @bookings do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#<%= booking.id %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= booking.user_name %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= booking.package %></td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class={[
                        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                        case booking.status do
                          "Confirmed" -> "bg-green-100 text-green-800"
                          "Pending" -> "bg-yellow-100 text-yellow-800"
                          "Cancelled" -> "bg-red-100 text-red-800"
                          _ -> "bg-gray-100 text-gray-800"
                        end
                      ]}>
                        <%= booking.status %>
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= booking.amount %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= booking.booking_date %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= booking.travel_date %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button class="text-teal-600 hover:text-teal-900 mr-3">Edit</button>
                      <button class="text-red-600 hover:text-red-900">Delete</button>
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
