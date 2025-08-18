defmodule UmrahlyWeb.AdminPaymentsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout

  def mount(_params, _session, socket) do
    # Mock data for payments - in a real app, this would come from your database
    payments = [
      %{
        id: 1,
        user_name: "John Doe",
        amount: "RM 2,500",
        payment_method: "Bank Transfer",
        status: "Completed",
        transaction_id: "TXN-001",
        payment_date: "2024-08-15",
        booking_reference: "BK-001"
      },
      %{
        id: 2,
        user_name: "Sarah Smith",
        amount: "RM 4,500",
        payment_method: "Credit Card",
        status: "Pending",
        transaction_id: "TXN-002",
        payment_date: "2024-08-14",
        booking_reference: "BK-002"
      },
      %{
        id: 3,
        user_name: "Ahmed Hassan",
        amount: "RM 2,500",
        payment_method: "Online Banking",
        status: "Failed",
        transaction_id: "TXN-003",
        payment_date: "2024-08-13",
        booking_reference: "BK-003"
      }
    ]

    socket =
      socket
      |> assign(:payments, payments)
      |> assign(:current_page, "payments")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Payments Management</h1>
            <div class="flex space-x-2">
              <button class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors">
                Export Report
              </button>
              <button class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors">
                Process Payment
              </button>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Payment ID</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Customer</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Payment Method</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Transaction ID</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Payment Date</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for payment <- @payments do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#<%= payment.id %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= payment.user_name %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900"><%= payment.amount %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= payment.payment_method %></td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class={[
                        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                        case payment.status do
                          "Completed" -> "bg-green-100 text-green-800"
                          "Pending" -> "bg-yellow-100 text-yellow-800"
                          "Failed" -> "bg-red-100 text-red-800"
                          _ -> "bg-gray-100 text-gray-800"
                        end
                      ]}>
                        <%= payment.status %>
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= payment.transaction_id %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= payment.payment_date %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button class="text-teal-600 hover:text-teal-900 mr-3">View</button>
                      <button class="text-blue-600 hover:text-blue-900 mr-3">Process</button>
                      <button class="text-red-600 hover:text-red-900">Refund</button>
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
