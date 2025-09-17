defmodule UmrahlyWeb.UserLoginLive do
  use UmrahlyWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="flex justify-center items-center min-h-screen bg-[#F9FAF5]">
      <div class="bg-[#EAD4AB] p-8 rounded-lg shadow-lg w-full max-w-md">
        <div class="flex justify-center mb-6 space-x-8 text-sm font-medium">
          <.link navigate={~p"/users/register"} class="text-gray-500 hover:text-[#00897B]">Register</.link>
          <span class="text-[#00897B] cursor-pointer border-b-2 border-[#00897B] pb-1">Login</span>
        </div>
        <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore" class="space-y-4">
          <div>
            <label for="email" class="block mb-1 text-sm font-medium text-gray-800">Email</label>
            <.input
              field={@form[:email]}
              id="email"
              type="email"
              placeholder="Enter your email"
              required
              class="w-full rounded-md border border-gray-300 bg-[#FFF3D6] text-gray-900 placeholder-gray-600 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
            />
          </div>

          <div>
            <label for="password" class="block mb-1 text-sm font-medium text-gray-800">Password</label>
            <.input
              field={@form[:password]}
              id="password"
              type="password"
              placeholder="Enter your password"
              required
              class="w-full rounded-md border border-gray-300 bg-[#FFF3D6] text-gray-900 placeholder-gray-600 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
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
          <.link navigate={~p"/users/register"} class="text-[#00897B] hover:underline">Register</.link>
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
