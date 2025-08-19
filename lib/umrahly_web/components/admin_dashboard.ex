defmodule UmrahlyWeb.AdminDashboard do
  use UmrahlyWeb, :html

  def summary_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6 border-l-4 border-{@color}-500">
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <div class="w-12 h-12 bg-{@color}-100 rounded-lg flex items-center justify-center">
            <svg class="w-6 h-6 text-{@color}-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <%= Phoenix.HTML.raw(@icon) %>
            </svg>
          </div>
        </div>
        <div class="ml-4">
          <p class="text-sm font-medium text-gray-600"><%= @title %></p>
          <p class="text-2xl font-bold text-gray-900"><%= @value %></p>
        </div>
      </div>
    </div>
    """
  end

  def recent_activities_table(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow">
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">Recent Activities</h3>
      </div>
      <div class="p-6">
        <div class="overflow-x-auto">
          <table class="min-w-full">
            <thead>
              <tr class="border-b border-gray-200">
                <th class="text-left py-3 px-4 font-medium text-gray-700">Element</th>
                <th class="text-left py-3 px-4 font-medium text-gray-700">Activity</th>
              </tr>
            </thead>
            <tbody>
              <%= for activity <- @activities do %>
                <tr class="border-b border-gray-100">
                  <td class="py-3 px-4 text-sm text-gray-600">Title</td>
                  <td class="py-3 px-4 text-sm text-gray-900"><%= activity.title %></td>
                </tr>
                <tr class="border-b border-gray-100">
                  <td class="py-3 px-4 text-sm text-gray-600">Activity Massage</td>
                  <td class="py-3 px-4 text-sm text-gray-900"><%= activity.activity_message %></td>
                </tr>
                <tr class="border-b border-gray-100">
                  <td class="py-3 px-4 text-sm text-gray-600">Timestamp</td>
                  <td class="py-3 px-4 text-sm text-gray-900"><%= activity.timestamp %></td>
                </tr>
                <tr class="border-b border-gray-100">
                  <td class="py-3 px-4 text-sm text-gray-600">Action</td>
                  <td class="py-3 px-4 text-sm text-gray-900">
                    <span class="text-blue-600 hover:text-blue-800 cursor-pointer">
                      <%= activity.action %>
                    </span>
                  </td>
                </tr>
                <tr class="h-4"></tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
