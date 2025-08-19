defmodule UmrahlyWeb.AdminPackagesLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages

  def mount(_params, _session, socket) do
    packages = Packages.list_packages()

    socket =
      socket
      |> assign(:packages, packages)
      |> assign(:current_page, "packages")
      |> assign(:viewing_package_id, nil)

    {:ok, socket}
  end

  def handle_event("view_package", %{"id" => package_id}, socket) do
    package = Packages.get_package!(package_id)

    socket =
      socket
      |> assign(:viewing_package_id, package_id)
      |> assign(:current_package, package)

    {:noreply, socket}
  end

  def handle_event("close_package_view", _params, socket) do
    socket =
      socket
      |> assign(:viewing_package_id, nil)
      |> assign(:current_package, nil)

    {:noreply, socket}
  end

  def handle_event("delete_package", %{"id" => package_id}, socket) do
    package = Packages.get_package!(package_id)
    {:ok, _} = Packages.delete_package(package)

    packages = Packages.list_packages()

    socket =
      socket
      |> assign(:packages, packages)
      |> assign(:viewing_package_id, nil)
      |> assign(:current_package, nil)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Packages Management</h1>
            <button class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors">
              Add New Package
            </button>
          </div>

          <%= if @viewing_package_id do %>
            <!-- Package Detail View -->
            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-bold text-gray-900">Package Details</h2>
                <button
                  phx-click="close_package_view"
                  class="text-gray-500 hover:text-gray-700"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                  </svg>
                </button>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h3 class="text-lg font-semibold text-gray-900 mb-2"><%= @current_package.name %></h3>
                  <p class="text-gray-600 mb-4">No description available</p>

                  <div class="space-y-3">
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Price:</span>
                      <span class="text-sm font-medium text-gray-900">RM <%= @current_package.price %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Duration:</span>
                      <span class="text-sm font-medium text-gray-900"><%= @current_package.duration_days %> days / <%= @current_package.duration_nights %> nights</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Quota:</span>
                      <span class="text-sm font-medium text-gray-900"><%= @current_package.quota %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Departure Date:</span>
                      <span class="text-sm font-medium text-gray-900"><%= @current_package.departure_date %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Status:</span>
                      <span class={[
                        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                        case @current_package.status do
                          "active" -> "bg-green-100 text-green-800"
                          "inactive" -> "bg-red-100 text-red-800"
                          "draft" -> "bg-gray-100 text-gray-800"
                          _ -> "bg-gray-100 text-gray-800"
                        end
                      ]}>
                        <%= @current_package.status %>
                      </span>
                    </div>
                  </div>
                </div>

                <div class="flex flex-col space-y-3">
                  <button class="w-full bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors">
                    Edit Package
                  </button>
                  <button
                    phx-click="delete_package"
                    phx-value-id={@current_package.id}
                    data-confirm="Are you sure you want to delete this package?"
                    class="w-full bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors"
                  >
                    Delete Package
                  </button>
                </div>
              </div>
            </div>
          <% end %>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for package <- @packages do %>
              <div class="bg-white border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
                <div class="p-6">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg font-semibold text-gray-900"><%= package.name %></h3>
                    <span class={[
                      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                      case package.status do
                        "active" -> "bg-green-100 text-green-800"
                        "inactive" -> "bg-red-100 text-red-800"
                        "draft" -> "bg-gray-100 text-gray-800"
                        _ -> "bg-gray-100 text-gray-800"
                      end
                    ]}>
                      <%= package.status %>
                    </span>
                  </div>

                  <p class="text-gray-600 text-sm mb-4">No description available</p>

                  <div class="space-y-2 mb-4">
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Price:</span>
                      <span class="text-sm font-medium text-gray-900">RM <%= package.price %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Duration:</span>
                      <span class="text-sm font-medium text-gray-900"><%= package.duration_days %> days / <%= package.duration_nights %> nights</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Quota:</span>
                      <span class="text-sm font-medium text-gray-900"><%= package.quota %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Departure Date:</span>
                      <span class="text-sm font-medium text-gray-900"><%= package.departure_date %></span>
                    </div>
                  </div>

                  <button
                    phx-click="view_package"
                    phx-value-id={package.id}
                    class="w-full bg-teal-600 text-white px-3 py-2 rounded text-sm hover:bg-teal-700 transition-colors"
                  >
                    View Package
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
