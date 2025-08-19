defmodule UmrahlyWeb.AdminPackagesLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout

  def mount(_params, _session, socket) do
    # Mock data for packages - in a real app, this would come from your database
    packages = [
      %{
        id: 1,
        name: "Standard Package",
        description: "Basic Umrah package with essential services",
        price: "RM 2,500",
        duration: "7 days",
        status: "Active",
        capacity: 50,
        current_bookings: 35
      },
      %{
        id: 2,
        name: "Premium Package",
        description: "Luxury Umrah package with premium accommodations",
        price: "RM 4,500",
        duration: "10 days",
        status: "Active",
        capacity: 30,
        current_bookings: 22
      },
      %{
        id: 3,
        name: "Family Package",
        description: "Special package designed for families",
        price: "RM 3,500",
        duration: "8 days",
        status: "Active",
        capacity: 25,
        current_bookings: 18
      }
    ]

    socket =
      socket
      |> assign(:packages, packages)
      |> assign(:current_page, "packages")

    {:ok, socket}
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

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for package <- @packages do %>
              <div class="bg-white border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
                <div class="p-6">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg font-semibold text-gray-900"><%= package.name %></h3>
                    <span class={[
                      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                      case package.status do
                        "Active" -> "bg-green-100 text-green-800"
                        "Inactive" -> "bg-red-100 text-red-800"
                        "Draft" -> "bg-gray-100 text-gray-800"
                        _ -> "bg-gray-100 text-gray-800"
                      end
                    ]}>
                      <%= package.status %>
                    </span>
                  </div>

                  <p class="text-gray-600 text-sm mb-4"><%= package.description %></p>

                  <div class="space-y-2 mb-4">
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Price:</span>
                      <span class="text-sm font-medium text-gray-900"><%= package.price %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Duration:</span>
                      <span class="text-sm font-medium text-gray-900"><%= package.duration %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Capacity:</span>
                      <span class="text-sm font-medium text-gray-900"><%= package.current_bookings %>/<%= package.capacity %></span>
                    </div>
                  </div>

                  <div class="flex space-x-2">
                    <button class="flex-1 bg-teal-600 text-white px-3 py-2 rounded text-sm hover:bg-teal-700 transition-colors">
                      Edit
                    </button>
                    <button class="flex-1 bg-red-600 text-white px-3 py-2 rounded text-sm hover:bg-red-700 transition-colors">
                      Delete
                    </button>
                  </div>
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
