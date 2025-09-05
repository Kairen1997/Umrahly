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
      <!-- Centering and max-width wrapper -->
      <div class="min-h-screen flex justify-center bg-gray-50 py-12 px-4">
        <div class="w-full max-w-md bg-white rounded-lg shadow-lg p-6">
          <h1 class="text-2xl font-bold text-gray-900 mb-2">Account Settings</h1>
          <p class="text-sm text-gray-600 mb-6">Manage your account email address and password settings</p>

          <!-- Email Section -->
          <form phx-submit="change_email">
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
              <input
                type="email"
                name="email"
                value={@current_user.email}
                class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm"
                required
              />
            </div>

            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Current password</label>
              <input
                type="password"
                name="current_password"
                class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm"
                required
              />
            </div>

            <div class="mb-6">
              <button type="submit" class="bg-teal-600 text-white px-4 py-2 rounded-md hover:bg-teal-700">
                Change Email
              </button>
            </div>
          </form>

          <!-- Password Change Section -->
          <form phx-submit="update_password" phx-change="validate_password">
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">New password</label>
              <input
                type="password"
                name="user[password]"
                class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm"
                required
              />
            </div>

            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Confirm new password</label>
              <input
                type="password"
                name="user[password_confirmation]"
                class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm"
                required
              />
            </div>

            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Current password</label>
              <input
                type="password"
                name="user[current_password]"
                class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm"
                required
              />
            </div>

            <div class="flex justify-end">
              <button type="submit" class="bg-teal-600 text-white px-4 py-2 rounded-md hover:bg-teal-700">
                Change Password
              </button>
            </div>
          </form>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
