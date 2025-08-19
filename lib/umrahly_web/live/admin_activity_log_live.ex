defmodule UmrahlyWeb.AdminActivityLogLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout

  def mount(_params, _session, socket) do
    # Mock data for activity logs - in a real app, this would come from your database
    activities = [
      %{
        id: 1,
        user_name: "John Doe",
        action: "Payment Submitted",
        details: "Submitted payment of RM 2,500 for Standard Package",
        timestamp: "2024-08-15 09:40:00",
        ip_address: "192.168.1.100",
        user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
        status: "Success"
      },
      %{
        id: 2,
        user_name: "Sarah Smith",
        action: "Profile Updated",
        details: "Updated contact information and address",
        timestamp: "2024-08-15 08:15:00",
        ip_address: "192.168.1.101",
        user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1)",
        status: "Success"
      },
      %{
        id: 3,
        user_name: "Ahmed Hassan",
        action: "Login Attempt",
        details: "Failed login attempt with incorrect password",
        timestamp: "2024-08-15 07:30:00",
        ip_address: "192.168.1.102",
        user_agent: "Mozilla/5.0 (Android 11; Mobile)",
        status: "Failed"
      },
      %{
        id: 4,
        user_name: "Admin User",
        action: "User Management",
        details: "Created new user account for jane@example.com",
        timestamp: "2024-08-15 06:45:00",
        ip_address: "192.168.1.50",
        user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
        status: "Success"
      }
    ]

    socket =
      socket
      |> assign(:activities, activities)
      |> assign(:current_page, "activity-log")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Activity Log</h1>
            <div class="flex space-x-2">
              <button class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors">
                Export Logs
              </button>
              <button class="bg-gray-600 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors">
                Clear Old Logs
              </button>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Timestamp</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Action</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Details</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">IP Address</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for activity <- @activities do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= activity.timestamp %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900"><%= activity.user_name %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= activity.action %></td>
                    <td class="px-6 py-4 text-sm text-gray-900 max-w-xs truncate" title={activity.details}>
                      <%= activity.details %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class={[
                        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                        case activity.status do
                          "Success" -> "bg-green-100 text-green-800"
                          "Failed" -> "bg-red-100 text-red-800"
                          "Warning" -> "bg-yellow-100 text-yellow-800"
                          _ -> "bg-gray-100 text-gray-800"
                        end
                      ]}>
                        <%= activity.status %>
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= activity.ip_address %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button class="text-teal-600 hover:text-teal-900 mr-3">View</button>
                      <button class="text-blue-600 hover:text-blue-900">Details</button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <!-- Pagination -->
          <div class="mt-6 flex items-center justify-between">
            <div class="text-sm text-gray-700">
              Showing <span class="font-medium">1</span> to <span class="font-medium">4</span> of <span class="font-medium">4</span> results
            </div>
            <div class="flex space-x-2">
              <button class="px-3 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed" disabled>
                Previous
              </button>
              <button class="px-3 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed" disabled>
                Next
              </button>
            </div>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
