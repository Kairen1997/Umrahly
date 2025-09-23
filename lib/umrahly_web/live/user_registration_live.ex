defmodule UmrahlyWeb.UserRegistrationLive do
  use UmrahlyWeb, :live_view

  alias Umrahly.Accounts
  alias Umrahly.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="relative min-h-screen">
    <video autoplay muted loop playsinline class="absolute inset-0 w-full h-full object-cover">
        <source src={~p"/images/login.video.mp4"} type="video/mp4" />
      </video>
      <div class="absolute inset-0 bg-black/40"></div>

      <div class="relative flex justify-center items-center min-h-screen">
      <!-- Form Container -->
      <div class="w-full max-w-md p-8 rounded-2xl text-white shadow-2xl border border-white/20 bg-white/10 backdrop-blur-md">

        <!-- Tabs -->
        <div class="flex justify-center mb-6 space-x-8 text-sm font-medium">
          <span class="cursor-pointer border-b-2 border-white text-white pb-1">Register</span>
          <.link navigate={~p"/users/log_in"} class="text-white/80 hover:text-white">Login</.link>
        </div>

        <!-- Form -->
        <form
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
          action={~p"/users/log_in?_action=registered"}
          method="post"
          class="space-y-4"
        >
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <label for="full_name" class="block mb-1 text-sm font-medium text-white/90">Full Name</label>
          <.input
            field={@form[:full_name]}
            id="full_name"
            type="text"
            placeholder="Enter your full name"
            required
            class="w-full rounded-md border border-white/30 px-3 py-2 bg-white/20 text-white placeholder-white/70 focus:border-white/50 focus:ring-white/40"
          />
          <label for="email" class="block mb-1 text-sm font-medium text-white/90">Email</label>
          <.input
            field={@form[:email]}
            id="email"
            type="email"
            placeholder="Enter your email"
            required
            class="w-full rounded-md border border-white/30 px-3 py-2 bg-white/20 text-white placeholder-white/70 focus:border-white/50 focus:ring-white/40"
          />

          <label for="password" class="block mb-1 text-sm font-medium text-white/90">Password</label>
          <.input
            field={@form[:password]}
            id="password"
            type="password"
            placeholder="Enter your Password"
            required
            class="w-full rounded-md border border-white/30 px-3 py-2 bg-white/20 text-white placeholder-white/70 focus:border-white/50 focus:ring-white/40"
          />

          <.button phx-disable-with="Registering..." class="w-full bg-[#00897B] text-white py-3 rounded-md hover:bg-[#00796B] font-semibold">
            Register
          </.button>
        </form>

        <!-- Bottom text -->
        <p class="mt-4 text-center text-sm text-white/80">
          Already have an account?
          <.link navigate={~p"/users/log_in"} class="text-white hover:underline">Login</.link>
        </p>
      </div>
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
    user_params = Map.put(user_params, "is_admin", false)


    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        message = "Registration successful! Please log in to complete your profile."

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> push_navigate(to: ~p"/users/log_in?complete_profile=true")}

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
