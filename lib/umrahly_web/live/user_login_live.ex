defmodule UmrahlyWeb.UserLoginLive do
  use UmrahlyWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="w-[542px] h-[542px] flex flex-col items-center justify-center bg-amber-200 shadow-lg rounded-lg">
      <div class="max-w-md w-full bg-[#EAD4AB] rounded-lg p-8 shadow-lg">
        <h2 class="text-center text-xl font-semibold mb-6">Login to your account</h2>
        <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore" class="space-y-6">
          <div>
            <label for="email" class="block mb-1 text-sm font-medium text-gray-900">Email</label>
            <.input
              field={@form[:email]}
              id="email"
              type="email"
              placeholder="Enter your email"
              required
              class="w-full rounded-md border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-teal-600"
            />
          </div>

          <div>
            <label for="password" class="block mb-1 text-sm font-medium text-gray-900">Password</label>
            <.input
              field={@form[:password]}
              id="password"
              type="password"
              placeholder="Enter your password"
              required
              class="w-full rounded-md border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-teal-600"
            />
          </div>

          <:actions>
            <.button phx-disable-with="Logging in..." class="w-full bg-[#00897B] text-white py-3 rounded-md hover:bg-[#00796B] font-semibold">
              Login
            </.button>
          </:actions>
        </.simple_form>

        <p class="mt-4 text-center text-sm text-gray-700">
          Don't have an account?
          <.link navigate={~p"/users/register"} class="text-teal-700 hover:underline">Register</.link>
        </p>
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
