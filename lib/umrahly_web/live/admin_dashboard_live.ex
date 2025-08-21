defmodule UmrahlyWeb.AdminDashboardLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    {has_profile, profile} = if current_user do
      # Check if user has profile information directly
      has_profile = current_user.address != nil or current_user.phone_number != nil or current_user.identity_card_number != nil
      {has_profile, current_user}
    else
      {false, nil}
    end

    # Get real data for admin dashboard
    package_stats = Packages.get_enhanced_package_statistics()
    recent_package_activities = Packages.get_recent_package_activities(3)

    admin_stats = %{
      total_bookings: 124, # TODO: Replace with real bookings count when bookings module is implemented
      total_payments: "RM 300,000", # TODO: Replace with real payments data when payments module is implemented
      packages_available: package_stats.active_packages,
      pending_verification: 3 # TODO: Replace with real verification count when user verification is implemented
    }

    recent_activities = [
      %{
        title: "Payment",
        activity_message: "John submitted a payment (RM1,000)",
        timestamp: "Today at 9:40 AM",
        action: "View / Approve"
      },
      %{
        title: "Booking",
        activity_message: "Sarah booked Standard Package",
        timestamp: "6 Aug, 8:15 PM",
        action: "View / Confirm"
      },
      %{
        title: "Profile Update",
        activity_message: "Ahmed updated contact information",
        timestamp: "6 Aug, 6:30 PM",
        action: "View"
      }
    ]

    socket =
      socket
      |> assign(:admin_stats, admin_stats)
      |> assign(:package_stats, package_stats)
      |> assign(:recent_package_activities, recent_package_activities)
      |> assign(:recent_activities, recent_activities)
      |> assign(:has_profile, has_profile)
      |> assign(:profile, profile)
      |> assign(:is_admin, true)
      |> assign(:current_page, "dashboard")
      |> assign(:show_packages_details, false)

    {:ok, socket}
  end

  def handle_event("toggle_packages_details", _params, socket) do
    socket = assign(socket, :show_packages_details, !socket.assigns.show_packages_details)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-6xl mx-auto">

        <!-- Admin Welcome Banner -->
        <div class="bg-gradient-to-r from-teal-600 to-blue-600 rounded-lg shadow-lg p-6 mb-8 text-white">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold">Welcome, <%= @current_user.full_name %></h1>
              <p class="text-teal-100 mt-2">Admin Dashboard - Manage your Umrah application</p>
            </div>
          </div>
        </div>

        <!-- Summary Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div class="bg-white rounded-lg shadow p-6 border-l-4 border-teal-500">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-teal-100 rounded-lg flex items-center justify-center">
                  <svg class="w-6 h-6 text-teal-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Total Bookings</p>
                <p class="text-4xl font-bold text-gray-900"><%= @admin_stats.total_bookings %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow p-6 border-l-4 border-green-500">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
                  <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599 1"/>
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Total Payments Received</p>
                <p class="text-2xl font-bold text-gray-900"><%= @admin_stats.total_payments %></p>
              </div>
            </div>
          </div>

          <div
            class="bg-white rounded-lg shadow p-6 border-l-4 border-blue-500 cursor-pointer hover:shadow-lg transition-shadow"
            phx-click="toggle_packages_details"
          >
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                  <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Active Packages</p>
                <p class="text-4xl font-bold text-gray-900"><%= @admin_stats.packages_available %></p>
                <p class="text-xs text-gray-500">of <%= @package_stats.total_packages %> total</p>
                <p class="text-xs text-blue-600 mt-1">
                  <%= if @show_packages_details do %>
                    Click to hide details
                  <% else %>
                    Click to view details
                  <% end %>
                </p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow p-6 border-l-4 border-yellow-500">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center">
                  <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                </div>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Pending Verification</p>
                <p class="text-4xl font-bold text-gray-900"><%= @admin_stats.pending_verification %></p>
              </div>
            </div>
          </div>
        </div>

        <%= if @show_packages_details do %>
          <!-- Packages Overview Section -->
          <div class="bg-white rounded-lg shadow mb-8">
            <div class="px-6 py-4 border-b border-gray-200">
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-semibold text-gray-900">Packages Overview</h3>
                <div class="flex items-center space-x-3">
                  <a href="/admin/packages" class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                    Manage Packages →
                  </a>
                  <a href="/admin/packages" class="bg-teal-600 text-white px-3 py-1 rounded text-sm hover:bg-teal-700 transition-colors">
                    Add Package
                  </a>
                </div>
              </div>
            </div>
            <div class="p-6">
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <!-- Total Packages -->
                <div class="text-center">
                  <div class="text-3xl font-bold text-gray-900"><%= @package_stats.total_packages %></div>
                  <div class="text-sm text-gray-600">Total Packages</div>
                </div>

                <!-- Active Packages -->
                <div class="text-center">
                  <div class="text-3xl font-bold text-green-600"><%= @package_stats.active_packages %></div>
                  <div class="text-sm text-gray-600">Active Packages</div>
                </div>

                <!-- Inactive Packages -->
                <div class="text-center">
                  <div class="text-3xl font-bold text-red-600"><%= @package_stats.inactive_packages %></div>
                  <div class="text-sm text-gray-600">Inactive Packages</div>
                </div>

                <!-- Upcoming Departures -->
                <div class="text-center">
                  <div class="text-3xl font-bold text-blue-600"><%= @package_stats.upcoming_departures %></div>
                  <div class="text-sm text-gray-600">Upcoming Departures</div>
                </div>
              </div>

              <!-- Total Quota -->
              <div class="mt-6 pt-6 border-t border-gray-200">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div class="text-center">
                    <div class="text-2xl font-bold text-purple-600"><%= @package_stats.total_quota %></div>
                    <div class="text-sm text-gray-600">Total Available Quota</div>
                  </div>
                  <div class="text-center">
                    <div class="text-2xl font-bold text-orange-600"><%= @package_stats.active_packages %></div>
                    <div class="text-sm text-gray-600">Active Package Types</div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Expiring Soon Warning -->
          <%= if @package_stats.upcoming_departures > 0 do %>
            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-8">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="w-5 h-5 text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-yellow-800">
                    Packages Departing Soon
                  </h3>
                  <div class="mt-2 text-sm text-yellow-700">
                    <p>
                      You have <strong><%= @package_stats.upcoming_departures %></strong> packages with departure dates coming up soon.
                      <a href="/admin/packages" class="font-medium underline hover:text-yellow-600">
                        Review and manage packages →
                      </a>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Low Quota Warning -->
          <%= if @package_stats.low_quota_packages > 0 do %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-8">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="w-5 h-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-red-800">
                    Low Quota Alert
                  </h3>
                  <div class="mt-2 text-sm text-red-700">
                    <p>
                      You have <strong><%= @package_stats.low_quota_packages %></strong> packages with low availability (less than 10 spots remaining).
                      <a href="/admin/packages" class="font-medium underline hover:text-red-600">
                        Review and update quotas →
                      </a>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Recent Package Activities -->
          <div class="bg-white rounded-lg shadow mb-8">
            <div class="px-6 py-4 border-b border-gray-200">
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-semibold text-gray-900">Recent Package Activities</h3>
                <a href="/admin/packages" class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                  View All →
                </a>
              </div>
            </div>
            <div class="p-6">
              <%= if length(@recent_package_activities) > 0 do %>
                <div class="space-y-4">
                  <%= for activity <- @recent_package_activities do %>
                    <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                      <div class="flex items-center space-x-3">
                        <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                          <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                          </svg>
                        </div>
                        <div>
                          <p class="text-sm font-medium text-gray-900">
                            Package "<%= activity.package_name %>" was <%= activity.action %>
                          </p>
                          <div class="flex items-center space-x-2 mt-1">
                            <span class={[
                              "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                              case activity.status do
                                "active" -> "bg-green-100 text-green-800"
                                "inactive" -> "bg-red-100 text-red-800"
                                _ -> "bg-gray-100 text-gray-800"
                              end
                            ]}>
                              <%= activity.status %>
                            </span>
                            <span class="text-xs text-gray-500">
                              <%= activity.formatted_time %>
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="text-center py-8 text-gray-500">
                  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                  </svg>
                  <p class="mt-2 text-sm">No recent package activities</p>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Recent Activities -->
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
                  <%= for activity <- @recent_activities do %>
                    <tr class="border-b border-gray-100">
                      <td class="py-3 px-4 text-sm text-gray-600">Title</td>
                      <td class="py-3 px-4 text-sm text-gray-900"><%= activity.title %></td>
                    </tr>
                    <tr class="border-b border-gray-100">
                      <td class="py-3 px-4 text-sm text-gray-600">Activity Message</td>
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

        <!-- View All Activity Logs Button -->
        <div class="mt-8 text-center">
          <button class="bg-blue-600 text-white px-8 py-3 rounded-lg hover:bg-blue-700 transition-colors shadow-lg">
            View All Activity Logs
          </button>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
