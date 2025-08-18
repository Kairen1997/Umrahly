defmodule UmrahlyWeb.UserRegistrationLive do
  use UmrahlyWeb, :live_view

  alias Umrahly.Accounts
  alias Umrahly.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="flex justify-center items-center min-h-screen bg-[#F9FAF5]">
      <!-- Form Container -->
      <div class="bg-[#EAD4AB] p-8 rounded-lg shadow-lg w-full max-w-md">

        <!-- Tabs -->
        <div class="flex justify-center mb-6 space-x-8 text-sm font-medium">
          <span class="text-[#00897B] cursor-pointer border-b-2 border-[#00897B] pb-1">Register</span>
          <.link navigate={~p"/users/log_in"} class="text-gray-500 hover:text-[#00897B]">Login</.link>
        </div>

        <!-- Form -->
        <.simple_form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
          action={~p"/users/log_in?_action=registered"}
          method="post"
          class="space-y-4"
        >
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input
            field={@form[:full_name]}
            type="text"
            label="Full Name"
            placeholder="Enter your full name"
            required
            class="w-full rounded-md border border-gray-300 px-3 py-2 bg-white"
          />

          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            placeholder="Enter your email"
            required
            class="w-full rounded-md border border-gray-300 px-3 py-2 bg-white"
          />

          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            placeholder="Enter your Password"
            required
            class="w-full rounded-md border border-gray-300 px-3 py-2 bg-white"
          />

          <div class="space-y-2">
            <label class="block text-sm font-medium text-gray-700">Account Type</label>
            <div class="flex space-x-4">
              <label class={"flex items-center p-2 rounded-lg border-2 transition-colors #{if !@selected_role, do: "border-teal-500 bg-teal-50", else: "border-gray-200"}"}>
                <input type="radio" name="user[is_admin]" value="false" checked={!@selected_role} class="mr-2" phx-click="select_role" phx-value-role="false" />
                <span class={"text-sm font-medium #{if !@selected_role, do: "text-teal-700", else: "text-gray-700"}"}>Regular User</span>
              </label>
              <label class={"flex items-center p-2 rounded-lg border-2 transition-colors #{if @selected_role, do: "border-purple-500 bg-purple-50", else: "border-gray-200"}"}>
                <input type="radio" name="user[is_admin]" value="true" checked={@selected_role} class="mr-2" phx-click="select_role" phx-value-role="true" />
                <span class={"text-sm font-medium #{if @selected_role, do: "text-purple-700", else: "text-gray-700"}"}>Admin</span>
              </label>
            </div>
            <p class="text-xs text-gray-500 mt-1">
              <%= if @selected_role do %>
                <span class="text-purple-600">✓ Admin account selected - You'll have access to the admin dashboard</span>
              <% else %>
                <span class="text-teal-600">✓ Regular user account selected - You'll need to complete your profile</span>
              <% end %>
            </p>
          </div>

          <:actions>
            <.button phx-disable-with="Registering..." class="w-full bg-[#00897B] text-white py-3 rounded-md hover:bg-[#00796B] font-semibold">
              Register
            </.button>
          </:actions>
        </.simple_form>

        <!-- Bottom text -->
        <p class="mt-4 text-center text-sm text-gray-700">
          Already have an account?
          <.link navigate={~p"/users/log_in"} class="text-[#00897B] hover:underline">Login</.link>
        </p>
      </div>
    </div>
    """
  end


  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign(selected_role: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

      def handle_event("save", %{"user" => user_params}, socket) do
    # Use the selected role from the socket
    user_params = Map.put(user_params, "is_admin", socket.assigns.selected_role)

    # Debug logging
    IO.inspect(user_params, label: "User params being submitted")
    IO.inspect(socket.assigns.selected_role, label: "Selected role from socket")

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        # Redirect to login with appropriate message based on account type
        message = if user.is_admin do
          "Admin registration successful! Please log in to access the admin dashboard."
        else
          "Registration successful! Please log in to complete your profile."
        end

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> push_navigate(to: ~p"/users/log_in?complete_profile=true")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("select_role", %{"role" => role}, socket) do
    selected_role = role == "true"
    {:noreply, assign(socket, selected_role: selected_role)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
