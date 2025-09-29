defmodule UmrahlyWeb.UserLoginLive do
  use UmrahlyWeb, :live_view

  alias Umrahly.Accounts

  def render(assigns) do
    ~H"""
    <div class="relative min-h-screen">
      <video autoplay muted loop playsinline class="absolute inset-0 w-full h-full object-cover">
        <source src={~p"/images/tawaf.mp4"} type="video/mp4" />
      </video>
      <div class="absolute inset-0 bg-black/40"></div>

      <div class="relative flex justify-center items-center min-h-screen">
        <div class="w-full max-w-md p-8 rounded-2xl text-white shadow-2xl border border-white/20 bg-white/10 backdrop-blur-md">
          <div class="flex justify-center mb-6 space-x-8 text-sm font-medium">
            <.link navigate={~p"/users/register"} class="text-white/80 hover:text-white">Register</.link>
            <span class="text-white cursor-pointer border-b-2 border-white pb-1">Login</span>
          </div>
          <.form for={@form} id="login_form" phx-submit="login" class="space-y-4">
            <div>
              <label for="email" class="block mb-1 text-sm font-medium text-white/90">Email</label>
              <.input
                field={@form[:email]}
                id="email"
                type="email"
                placeholder="Enter your email"
                required
                class="w-full rounded-md border border-white/30 bg-white/20 text-white placeholder-white/70 px-3 py-2 focus:border-white/50 focus:ring-white/40"
              />
            </div>

            <div>
              <label for="password" class="block mb-1 text-sm font-medium text-white/90">Password</label>
              <.input
                field={@form[:password]}
                id="password"
                type="password"
                placeholder="Enter your password"
                required
                class="w-full rounded-md border border-white/30 bg-white/20 text-white placeholder-white/70 px-3 py-2 focus:border-white/50 focus:ring-white/40"
              />
            </div>

            <.button type="submit" class="w-full bg-[#00897B] text-white py-3 rounded-md hover:bg-[#00796B] font-semibold">
              Login
            </.button>
          </.form>

          <p class="mt-4 text-center text-sm text-white/80">
            Don't have an account?
            <.link navigate={~p"/users/register"} class="text-white hover:underline">Register</.link>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end

  def handle_event("login", %{"user" => user_params}, socket) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      # Determine redirect path
      redirect_path = if Umrahly.Accounts.is_admin?(user) do
        ~p"/admin/dashboard"
      else
        ~p"/dashboard"
      end

      # Use the existing log_in_confirm endpoint which handles the session properly
      {:noreply,
       socket
       |> put_flash(:info, "Welcome back!")
       |> redirect(external: ~p"/users/log_in_confirm?email=#{email}&redirect=#{redirect_path}")
      }
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      {:noreply,
       socket
       |> put_flash(:error, "Invalid email or password")
       |> put_flash(:email, String.slice(email, 0, 160))
       |> assign(form: to_form(%{"email" => email}, as: "user"))
      }
    end
  end
end
