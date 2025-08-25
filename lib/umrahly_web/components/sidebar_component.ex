defmodule UmrahlyWeb.SidebarComponent do
  use UmrahlyWeb, :html

  def sidebar(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-100" style="min-height: calc(100vh - 64px);">
      <!-- Sidebar -->
      <aside class="w-50 bg-gray-800 shadow-lg h-50 flex flex-col justify-between">
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
                Active Bookings
              </a>

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
            </div>
          </nav>
        </div>
      </aside>

      <!-- Main Content -->
      <div class="flex-1 flex flex-col">
        <!-- Page Content -->
        <main class="flex-1 bg-gray-50 p-6 overflow-auto">
          <!-- Page Title -->
          <div class="mb-6">
            <h1 class="text-2xl font-semibold text-gray-900">
              <%= Map.get(assigns, :page_title, "Dashboard") %>
            </h1>
          </div>
          <%= render_slot(@inner_block) %>
        </main>
      </div>
    </div>
    """
  end
end
