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
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
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
