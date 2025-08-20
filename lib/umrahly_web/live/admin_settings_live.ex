defmodule UmrahlyWeb.AdminSettingsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Accounts

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(:current_page, "settings")
      |> assign(:has_profile, true)
      |> assign(:profile, current_user)
      |> assign(:is_admin, true)
      |> assign(:password_changeset, Accounts.change_user_password(current_user))

    {:ok, socket}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    current_user = socket.assigns.current_user

    case Accounts.update_user_password(current_user, password, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password updated successfully!")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:password_changeset, changeset)
         |> put_flash(:error, "Failed to update password. Please check the form and try again.")}
    end
  end

  def handle_event("validate_password", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_password(socket.assigns.current_user, user_params)
    {:noreply, assign(socket, :password_changeset, Map.put(changeset, :action, :validate))}
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-4xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Account Settings</h1>
            <p class="text-gray-600 mt-2">Manage your account security and preferences</p>
          </div>

          <div class="space-y-6">
            <!-- Password Change Section -->
            <div class="bg-gray-50 rounded-lg p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Change Password</h3>
              <form phx-submit="update_password" phx-change="validate_password" class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Current Password</label>
                    <input
                      type="password"
                      name="user[current_password]"
                      required
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      placeholder="Enter current password"
                    />
                    <%= if @password_changeset.errors[:current_password] do %>
                      <p class="text-red-500 text-xs mt-1"><%= elem(@password_changeset.errors[:current_password], 0) %></p>
                    <% end %>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">New Password</label>
                    <input
                      type="password"
                      name="user[password]"
                      required
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      placeholder="Enter new password"
                    />
                    <%= if @password_changeset.errors[:password] do %>
                      <p class="text-red-500 text-xs mt-1"><%= elem(@password_changeset.errors[:password], 0) %></p>
                    <% end %>
                  </div>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Confirm New Password</label>
                  <input
                    type="password"
                    name="user[password_confirmation]"
                    required
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                    placeholder="Confirm new password"
                  />
                  <%= if @password_changeset.errors[:password_confirmation] do %>
                    <p class="text-red-500 text-xs mt-1"><%= elem(@password_changeset.errors[:password_confirmation], 0) %></p>
                  <% end %>
                </div>
                <div class="flex justify-end">
                  <button
                    type="submit"
                    class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors"
                  >
                    Update Password
                  </button>
                </div>
              </form>
            </div>

            <!-- Account Information Section -->
            <div class="bg-gray-50 rounded-lg p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Account Information</h3>
              <div class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">User ID</label>
                    <input
                      type="text"
                      value={@current_user.id}
                      disabled
                      class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100 text-gray-500 cursor-not-allowed"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Account Type</label>
                    <input
                      type="text"
                      value="Administrator"
                      disabled
                      class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100 text-gray-500 cursor-not-allowed"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
                    <input
                      type="email"
                      value={@current_user.email}
                      disabled
                      class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100 text-gray-500 cursor-not-allowed"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Member Since</label>
                    <input
                      type="text"
                      value={@current_user.inserted_at |> Calendar.strftime("%B %d, %Y")}
                      disabled
                      class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100 text-gray-500 cursor-not-allowed"
                    />
                  </div>
                </div>
              </div>
            </div>

            <!-- Security Tips Section -->
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-6">
              <h3 class="text-lg font-semibold text-blue-900 mb-4">Security Tips</h3>
              <div class="space-y-3 text-blue-800">
                <div class="flex items-start">
                  <svg class="w-5 h-5 text-blue-600 mt-0.5 mr-2 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <p class="text-sm">Use a strong password with at least 8 characters, including uppercase, lowercase, numbers, and symbols.</p>
                </div>
                <div class="flex items-start">
                  <svg class="w-5 h-5 text-blue-600 mt-0.5 mr-2 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <p class="text-sm">Never share your password with anyone, including support staff.</p>
                </div>
                <div class="flex items-start">
                  <svg class="w-5 h-5 text-blue-600 mt-0.5 mr-2 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <p class="text-sm">Change your password regularly and avoid reusing passwords from other accounts.</p>
                </div>
                <div class="flex items-start">
                  <svg class="w-5 h-5 text-blue-600 mt-0.5 mr-2 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <p class="text-sm">Always log out when using shared computers or devices.</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
