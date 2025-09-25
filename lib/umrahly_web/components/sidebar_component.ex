defmodule UmrahlyWeb.SidebarComponent do
  use UmrahlyWeb, :html

  def sidebar(assigns) do
    ~H"""
    <div x-data="{ open: true }" class="flex min-h-screen bg-gray-100" style="min-height: calc(100vh - 64px);">
      <!-- Sidebar -->
      <aside x-cloak x-show="open" x-transition:enter="transition ease-out duration-300 transform" x-transition:enter-start="-translate-x-full opacity-0" x-transition:enter-end="translate-x-0 opacity-100" x-transition:leave="transition ease-in duration-200 transform" x-transition:leave-start="translate-x-0 opacity-100" x-transition:leave-end="-translate-x-full opacity-0" class="w-50 bg-gray-800 shadow-lg h-50 flex flex-col justify-between sticky top-0 h-screen">
        <!-- Navigation Menu -->
        <div class="sticky top-0">
          <nav class="mt-0">
            <div class="px-4 space-y-2 py-4">
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

              <!-- Payments -->
              <a href="/payments" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599 1"/>
                </svg>
                Payments
              </a>
              <div class="ml-8 space-y-1">
                <a href="/payments?tab=installment" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• Installment Payment Plan</a>
                <a href="/payments?tab=history" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• Payment History</a>
                <a href="/payments?tab=receipts" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• Receipts</a>
              </div>
            </div>
          </nav>
        </div>
      </aside>

      <!-- Main Content -->
      <div class="flex-1 flex flex-col">
        <!-- Top bar with burger -->
        <div class="bg-gray-50 px-4 py-3 border-b border-gray-200 flex items-center justify-between sticky top-0 z-40">
          <div class="flex items-center">
            <button type="button" class="mr-3 inline-flex items-center justify-center rounded-md text-gray-700 hover:text-gray-900 hover:bg-gray-200 p-2 focus:outline-none focus:ring-2 focus:ring-indigo-500" @click="open = !open" aria-label="Toggle sidebar">
              <svg x-cloak x-show="!open" x-transition.opacity class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
              <svg x-cloak x-show="open" x-transition.opacity class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
            <!-- Page Title -->
            <div class="mb-0">
              <h1 class="text-2xl font-semibold text-gray-900">
                <%= Map.get(assigns, :page_title, "Dashboard") %>
              </h1>
            </div>
          </div>
          <%= if profile_complete?(assigns) do %>
            <div class="inline-flex items-center gap-3 rounded-lg border border-green-200 bg-green-50 px-4 py-2 shadow-sm">
              <div class="rounded-md bg-green-100 p-1.5 text-green-700">
                <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div>
                <div class="text-sm font-medium text-green-800">Profile Complete</div>
                <div class="text-xs text-green-700">Ready to book your Umrah</div>
              </div>
            </div>
          <% end %>
        </div>
        <!-- Page Content -->
        <main class="flex-1 bg-gray-50 p-6 overflow-auto">
          <%= render_slot(@inner_block) %>
        </main>
      </div>
    </div>
    """
  end

  # Determines if the user's profile is considered complete.
  # Priority: explicit :profile_complete assign -> derive from :profile -> derive from :user or :current_user -> false
  defp profile_complete?(assigns) do
    explicit = Map.get(assigns, :profile_complete)
    profile = Map.get(assigns, :profile)
    user = Map.get(assigns, :user) || Map.get(assigns, :current_user)

    cond do
      is_boolean(explicit) -> explicit
      profile_complete_from_profile?(profile) -> true
      profile_complete_from_user?(user) -> true
      true -> false
    end
  end

  defp present?(value) do
    not is_nil(value) and to_string(value) != ""
  end

  # Consider profile complete when key fields are present
  defp profile_complete_from_profile?(nil), do: false
  defp profile_complete_from_profile?(profile) do
    present?(Map.get(profile, :identity_card_number)) and
    present?(Map.get(profile, :phone_number)) and
    present?(Map.get(profile, :address)) and
    present?(Map.get(profile, :gender)) and
    present?(Map.get(profile, :birthdate)) and
    present?(Map.get(profile, :citizenship))
  end

  # Backward compatibility: consider complete from user record (older flow)
  defp profile_complete_from_user?(nil), do: false
  defp profile_complete_from_user?(user) do
    not is_nil(user.address) or
    not is_nil(user.identity_card_number) or
    not is_nil(user.phone_number) or
    not is_nil(user.monthly_income) or
    not is_nil(user.birthdate) or
    not is_nil(user.gender)
  end
end
