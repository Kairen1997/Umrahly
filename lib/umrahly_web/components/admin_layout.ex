defmodule UmrahlyWeb.AdminLayout do
  use UmrahlyWeb, :html

  import UmrahlyWeb.CoreComponents

  def admin_layout(assigns) do
    assigns =
      assigns
      |> assign_new(:has_profile, fn -> false end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:profile, fn -> nil end)
      |> assign_new(:is_admin, fn -> false end)
      |> assign_new(:flash, fn -> %{} end)

    ~H"""
    <div class="flex min-h-screen bg-gray-100">
      <!-- Sidebar -->
      <aside class="w-50 bg-gray-800 shadow-lg h-50 flex flex-col justify-between">
        <!-- Navigation Menu -->
        <div>
          <nav class="mt-0">
            <div class="px-4 space-y-2">
              <!-- Dashboard -->
              <a href="/admin/dashboard" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200 bg-gray-700 text-white">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z"/>
                </svg>
                Dashboard
              </a>

              <!-- Admin navigation items -->
              <!-- Manage Bookings -->
              <a href="/admin/bookings" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.293.707l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
                Manage Bookings
              </a>

              <!-- Manage Packages with Submenu -->
              <div class="space-y-1">
                <div class={"w-full flex items-center px-4 py-3 rounded-md transition-colors duration-200 #{if @current_page in ["packages", "package_schedules"], do: "bg-gray-700 text-white", else: "text-gray-300"}"}>
                  <div class="flex items-center">
                    <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                    </svg>
                    Manage Packages
                  </div>
                </div>

                <!-- Submenu -->
                <div class="ml-4 space-y-1 border-l border-gray-600 pl-2">
                  <a href="/admin/packages" class={"flex items-center px-4 py-2 rounded-md transition-colors duration-200 text-sm #{if @current_page == "packages", do: "text-white bg-gray-700", else: "text-gray-400 hover:text-white hover:bg-gray-700"}"}>
                    <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                    </svg>
                    All Packages
                  </a>
                  <a href="/admin/package-schedules" class={"flex items-center px-4 py-2 rounded-md transition-colors duration-200 text-sm #{if @current_page == "package_schedules", do: "text-white bg-gray-700", else: "text-gray-400 hover:text-white hover:bg-gray-700"}"}>
                    <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                    </svg>
                    Package Schedules
                  </a>
                </div>
              </div>

              <!-- Manage Payments -->
              <a href="/admin/payments" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599 1"/>
                </svg>
                Manage Payments
              </a>

              <!-- Payment Proofs -->
              <a href="/admin/payment-proofs" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
                Payment Proofs
              </a>

              <!-- Flight Schedule -->
              <a href="/admin/flights" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"/>
                </svg>
                Flight Schedule
              </a>

              <!-- Activity Log -->
              <a href="/admin/activity-log" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.293.707l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
                Activity Log
              </a>

            </div>
          </nav>
        </div>
      </aside>

      <!-- Main Content -->
      <div class="flex-1 flex flex-col overflow-hidden">
        <!-- Header Bar -->
        <div class="sticky top-0 z-30 bg-white border-b border-gray-200 shadow-sm">
          <div class="px-6 py-4">
            <div class="flex items-center justify-between">
              <!-- Page Title -->
              <div class="flex items-center">
                <h1 class="text-2xl font-bold text-gray-900">
                  <%= case @current_page do %>
                    <% "dashboard" -> %>Admin Dashboard
                    <% "bookings" -> %>Manage Bookings
                    <% "packages" -> %>Manage Packages
                    <% "package_schedules" -> %>Package Schedules
                    <% "payments" -> %>Manage Payments
                    <% "flights" -> %>Flight Schedule
                    <% "activity-log" -> %>Activity Log
                    <% _ -> %>Admin Panel
                  <% end %>
                </h1>
              </div>

              <!-- Right side icons -->
              <div class="flex items-center space-x-4">
                <!-- Admin Role Badge -->
                <%= if @current_user do %>
                  <div class="bg-gradient-to-r from-purple-600 to-pink-600 text-white px-3 py-1 rounded-full text-xs font-semibold">
                    Admin
                  </div>
                <% end %>

                <!-- Profile Completion Button (if needed) -->
                <%= if @current_user && !@has_profile && !@is_admin do %>
                  <button id="show-profile-modal" class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors text-sm">
                    Complete Profile
                  </button>
                <% end %>



              </div>
            </div>
          </div>
        </div>

        <!-- Flash Messages -->
        <.flash_group flash={@flash} />

        <!-- Page Content -->
        <main class="flex-1 bg-gray-50 overflow-y-auto">
          <div class="p-6">
            <%= render_slot(@inner_block) %>
          </div>
        </main>
      </div>
    </div>

    <script>
      // Profile modal functionality
      const showProfileModal = document.getElementById('show-profile-modal');
      const profileModal = document.getElementById('profile-modal');

      if (showProfileModal && profileModal) {
        showProfileModal.addEventListener('click', () => {
          profileModal.style.display = 'flex';
          document.body.classList.add('modal-open');
        });
      }
    </script>

    <style>
      /* Smooth transitions */
      .transition-colors {
        transition: all 0.2s ease-in-out;
      }

      /* Submenu enhancements */
      .border-l {
        border-left-width: 2px;
      }
    </style>
    """
  end
end
