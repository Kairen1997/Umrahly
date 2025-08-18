defmodule UmrahlyWeb.AdminLayout do
  use UmrahlyWeb, :html

  def admin_layout(assigns) do
    assigns =
      assigns
      |> assign_new(:has_profile, fn -> false end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:profile, fn -> nil end)

    ~H"""
    <div class="flex min-h-screen bg-gray-100">
      <!-- Sidebar -->
      <aside class="w-96 bg-gray-800 shadow-lg h-screen flex flex-col justify-between">
        <!-- Navigation Menu -->
        <div>
          <nav class="mt-0">
            <div class="px-4 space-y-2">
              <!-- Dashboard -->
              <a href="/" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200 bg-gray-700 text-white">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z"/>
                </svg>
                Dashboard
              </a>

              <!-- Admin navigation items -->
              <!-- Manage Bookings -->
              <a href="/admin/bookings" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
                Manage Bookings
              </a>

              <!-- Manage Packages -->
              <a href="/admin/packages" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                </svg>
                Manage Packages
              </a>

              <!-- Manage Payments -->
              <a href="/admin/payments" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599 1"/>
                </svg>
                Manage Payments
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
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
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
                    <% "payments" -> %>Manage Payments
                    <% "flights" -> %>Flight Schedule
                    <% "activity-log" -> %>Activity Log
                    <% _ -> %>Admin Panel
                  <% end %>
                </h1>
              </div>

              <!-- Right side icons -->
              <div class="flex items-center space-x-4">
                <!-- Profile Completion Button (if needed) -->
                <%= if @current_user && !@has_profile do %>
                  <button id="show-profile-modal" class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors text-sm">
                    Complete Profile
                  </button>
                <% end %>

                <!-- User Profile Dropdown -->
                <%= if @current_user do %>
                  <div class="relative" x-data="{ open: false }">
                    <button @click="open = !open" class="flex items-center gap-2 text-gray-600 hover:text-gray-800 transition-colors">
                      <!-- Profile Photo/Avatar -->
                      <%= if @profile && @profile.profile_photo do %>
                        <img src={@profile.profile_photo} alt="Profile Photo" class="w-8 h-8 rounded-full object-cover border-2 border-gray-200" />
                      <% else %>
                        <span class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-teal-600 text-white text-sm font-semibold">
                          <%= @current_user.email |> String.first() |> String.upcase() %>
                        </span>
                      <% end %>
                      <!-- User Icon -->
                      <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                      </svg>
                    </button>

                    <!-- Dropdown Menu -->
                    <div x-show="open" @click.away="open = false" x-transition class="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg py-1 z-10">
                      <a href="/admin/profile" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">Profile</a>
                      <a href="/admin/settings" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">Setting</a>
                      <a href="/users/log_out" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">Log Out</a>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>

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
    """
  end
end
