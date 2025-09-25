defmodule UmrahlyWeb.UserLoginLive do
  use UmrahlyWeb, :live_view

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
          <form id="login_form" action={~p"/users/log_in"} method="post" phx-update="ignore" class="space-y-4">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
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

            <.button phx-disable-with="Logging in..." class="w-full bg-[#00897B] text-white py-3 rounded-md hover:bg-[#00796B] font-semibold">
              Login
            </.button>
          </form>

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
end
