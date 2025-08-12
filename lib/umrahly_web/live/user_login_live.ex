defmodule UmrahlyWeb.UserLoginLive do
  use UmrahlyWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto p-8 bg-amber-200 rounded-lg shadow-lg">
      <h1 class="text-3xl font-bold mb-4 text-center text-teal-700">Log in to your account</h1>

      <p class="text-center text-sm mb-6">
        Don't have an account?
        <.link navigate={~p"/users/register"} class="text-teal-600 font-semibold hover:underline">
          Sign up
        </.link>
        now.
      </p>

      <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore" class="space-y-6">
        <div>
          <label for="email" class="block mb-1 text-sm font-medium text-gray-700">Email</label>
          <.input
            field={@form[:email]}
            id="email"
            type="email"
            placeholder="you@example.com"
            required
            class="w-full rounded-md border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-teal-500"
          />
        </div>

        <div>
          <label for="password" class="block mb-1 text-sm font-medium text-gray-700">Password</label>
          <.input
            field={@form[:password]}
            id="password"
            type="password"
            placeholder="••••••••"
            required
            class="w-full rounded-md border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-teal-500"
          />
        </div>

        <div class="flex items-center justify-between text-sm text-gray-600">
          <div class="flex items-center">
            <.input field={@form[:remember_me]} type="checkbox" id="remember_me" class="mr-2" />
            <label for="remember_me" class="select-none">Keep me logged in</label>
          </div>
          <.link href={~p"/users/reset_password"} class="hover:underline">
            Forgot your password?
          </.link>
        </div>

        <div>
          <.button phx-disable-with="Logging in..." class="w-full bg-teal-600 text-white py-3 rounded-md hover:bg-teal-700 font-semibold">
            Log in <span aria-hidden="true">→</span>
          </.button>
        </div>
      </.simple_form>
    </div>
    """
  end



  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
