defmodule UmrahlyWeb.SidebarComponent do
  use UmrahlyWeb, :html

  def sidebar(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-100" style="min-height: calc(100vh - 64px);">
      <!-- Sidebar -->
      <aside class="w-96 bg-blue-900 shadow-lg h-full flex flex-col justify-between">
        <!-- Navigation Menu -->
        <div>
          <nav class="mt-0">
            <div class="px-4 space-y-2">
              <!-- Dashboard -->
              <a href="/dashboard" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z"/>
                </svg>
                Dashboard
              </a>

              <!-- My Bookings -->
              <a href="/bookings" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
                My Bookings
              </a>
              <div class="ml-8 space-y-1">
                <a href="/bookings/details" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• Booking Details</a>
              </div>

              <!-- Packages -->
              <a href="/packages" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                </svg>
                Packages
              </a>
              <div class="ml-8 space-y-1">
                <a href="/packages/details" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• View Details</a>
              </div>

              <!-- Payments -->
              <a href="/payments" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"/>
                </svg>
                Payments
              </a>
              <div class="ml-8 space-y-1">
                <a href="/payments/installment" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• Installment Payment Plan</a>
                <a href="/payments/history" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• Payment History</a>
                <a href="/payments/receipts" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• Receipts</a>
              </div>

              <!-- Profile -->
              <a href="/profile" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                </svg>
                Profile
              </a>

              <!-- Settings -->
              <a href="/users/settings" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
                Settings
              </a>

            </div>
          </nav>
        </div>

        <!-- User Menu at Bottom -->
        <%= if @current_user do %>
          <div class="border-t border-gray-700 p-4">
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-teal-600 rounded-full flex items-center justify-center text-white text-sm font-semibold">
                <%= String.first(@current_user.email) |> String.upcase() %>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-white truncate"><%= @current_user.email %></p>
              </div>
            </div>
            <div class="mt-3">
              <.link href={~p"/users/log_out"} method="delete" class="w-full flex items-center px-3 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/>
                </svg>
                Log out
              </.link>
            </div>
          </div>
        <% end %>
      </aside>

      <!-- Main Content -->
      <div class="flex-1 flex flex-col">
        <!-- Page Content -->
        <main class="flex-1 bg-gray-50 p-6 overflow-auto">
          <!-- Page Title -->
          <div class="mb-6">
            <h1 class="text-2xl font-semibold text-gray-900">
              <%= @page_title || "Dashboard" %>
            </h1>
          </div>
          <%= render_slot(@inner_block) %>
        </main>
      </div>
    </div>
    """
  end
end
