defmodule UmrahlyWeb.AdminPackageEditLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages

    def mount(%{"id" => package_id}, _session, socket) do
    package = Packages.get_package!(package_id)
    changeset = Packages.change_package(package)

    socket =
      socket
      |> assign(:package, package)
      |> assign(:package_changeset, changeset)
      |> assign(:current_page, "packages")
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns.current_user)

    {:ok, socket}
  end



  def handle_event("validate", %{"package" => package_params}, socket) do
    changeset =
      socket.assigns.package
      |> Packages.change_package(package_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :package_changeset, changeset)}
  end

    def handle_event("save_package", %{"package" => package_params}, socket) do
    # Convert numeric fields from strings to integers
    package_params = package_params
      |> Map.update("price", nil, &if(is_binary(&1) && &1 != "", do: String.to_integer(&1), else: &1))
      |> Map.update("duration_days", nil, &if(is_binary(&1) && &1 != "", do: String.to_integer(&1), else: &1))
      |> Map.update("duration_nights", nil, &if(is_binary(&1) && &1 != "", do: String.to_integer(&1), else: &1))

    # Updating existing package
    case Packages.update_package(socket.assigns.package, package_params) do
      {:ok, _updated_package} ->
        {:noreply,
         socket
         |> put_flash(:info, "Package updated successfully!")
         |> redirect(to: ~p"/admin/packages")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:package_changeset, changeset)
         |> put_flash(:error, "Failed to update package. Please check the form for errors.")}
    end
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-4xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold text-gray-900">Edit Package</h1>
          <.link
            navigate={~p"/admin/packages"}
            class="text-gray-600 hover:text-gray-800 flex items-center space-x-2"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
            </svg>
            <span>Back to Packages</span>
          </.link>
        </div>

          <form
            phx-change="validate"
            phx-submit="save_package"
            class="space-y-6"
          >
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Package Name</label>
                <input
                  type="text"
                  name="package[name]"
                  value={@package_changeset.changes[:name] || @package_changeset.data.name || ""}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Enter package name"
                  required
                />
                <%= if @package_changeset.errors[:name] do %>
                  <p class="text-red-500 text-xs mt-1"><%= elem(@package_changeset.errors[:name], 0) %></p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
                <select
                  name="package[status]"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  required
                >
                  <option value="inactive" selected={@package_changeset.changes[:status] == "inactive" || @package_changeset.data.status == "inactive"}>Inactive</option>
                  <option value="active" selected={@package_changeset.changes[:status] == "active" || @package_changeset.data.status == "active"}>Active</option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Price (RM)</label>
                <input
                  type="number"
                  name="package[price]"
                  value={@package_changeset.changes[:price] || @package_changeset.data.price || ""}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Enter price"
                  min="1"
                  required
                />
                <%= if @package_changeset.errors[:price] do %>
                  <p class="text-red-500 text-xs mt-1"><%= elem(@package_changeset.errors[:price], 0) %></p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Duration (Days)</label>
                <input
                  type="number"
                  name="package[duration_days]"
                  value={@package_changeset.changes[:duration_days] || @package_changeset.data.duration_days || ""}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Enter duration in days"
                  min="1"
                  max="30"
                  required
                />
                <%= if @package_changeset.errors[:duration_days] do %>
                  <p class="text-red-500 text-xs mt-1"><%= elem(@package_changeset.errors[:duration_days], 0) %></p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Duration (Nights)</label>
                <input
                  type="number"
                  name="package[duration_nights]"
                  value={@package_changeset.changes[:duration_nights] || @package_changeset.data.duration_nights || ""}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Enter duration in nights"
                  min="1"
                  max="30"
                  required
                />
                <%= if @package_changeset.errors[:duration_nights] do %>
                  <p class="text-red-500 text-xs mt-1"><%= elem(@package_changeset.errors[:duration_nights], 0) %></p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Accommodation Type</label>
                <select
                  name="package[accommodation_type]"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                >
                  <option value="">Select accommodation type</option>
                  <option value="3 Star Hotel" selected={@package_changeset.changes[:accommodation_type] == "3 Star Hotel" || @package_changeset.data.accommodation_type == "3 Star Hotel"}>3 Star Hotel</option>
                  <option value="4 Star Hotel" selected={@package_changeset.changes[:accommodation_type] == "4 Star Hotel" || @package_changeset.data.accommodation_type == "4 Star Hotel"}>4 Star Hotel</option>
                  <option value="5 Star Hotel" selected={@package_changeset.changes[:accommodation_type] == "5 Star Hotel" || @package_changeset.data.accommodation_type == "5 Star Hotel"}>5 Star Hotel</option>
                  <option value="Apartment" selected={@package_changeset.changes[:accommodation_type] == "Apartment" || @package_changeset.data.accommodation_type == "Apartment"}>Apartment</option>
                  <option value="Villa" selected={@package_changeset.changes[:accommodation_type] == "Villa" || @package_changeset.data.accommodation_type == "Villa"}>Villa</option>
                  <option value="Guest House" selected={@package_changeset.changes[:accommodation_type] == "Guest House" || @package_changeset.data.accommodation_type == "Guest House"}>Guest House</option>
                  <option value="Not Included" selected={@package_changeset.changes[:accommodation_type] == "Not Included" || @package_changeset.data.accommodation_type == "Not Included"}>Not Included</option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Transport Type</label>
                <select
                  name="package[transport_type]"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                >
                  <option value="">Select transport type</option>
                  <option value="Flight" selected={@package_changeset.changes[:transport_type] == "Flight" || @package_changeset.data.transport_type == "Flight"}>Flight</option>
                  <option value="Bus" selected={@package_changeset.changes[:transport_type] == "Bus" || @package_changeset.data.transport_type == "Bus"}>Bus</option>
                  <option value="Train" selected={@package_changeset.changes[:transport_type] == "Train" || @package_changeset.data.transport_type == "Train"}>Train</option>
                  <option value="Private Car" selected={@package_changeset.changes[:transport_type] == "Private Car" || @package_changeset.data.transport_type == "Private Car"}>Private Car</option>
                  <option value="Shared Transport" selected={@package_changeset.changes[:transport_type] == "Shared Transport" || @package_changeset.data.transport_type == "Shared Transport"}>Shared Transport</option>
                  <option value="Not Included" selected={@package_changeset.changes[:transport_type] == "Not Included" || @package_changeset.data.transport_type == "Not Included"}>Not Included</option>
                </select>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
              <textarea
                name="package[description]"
                rows="4"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                placeholder="Enter package description..."
              ><%= @package_changeset.changes[:description] || @package_changeset.data.description || "" %></textarea>
              <%= if @package_changeset.errors[:description] do %>
                <p class="text-red-500 text-xs mt-1"><%= elem(@package_changeset.errors[:description], 0) %></p>
              <% end %>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Accommodation Details</label>
                <textarea
                  name="package[accommodation_details]"
                  rows="3"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Enter accommodation details (e.g., hotel name, room type, amenities)..."
                ><%= @package_changeset.changes[:accommodation_details] || @package_changeset.data.accommodation_details || "" %></textarea>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Transport Details</label>
                <textarea
                  name="package[transport_details]"
                  rows="3"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Enter transport details (e.g., flight details, pickup times, vehicle info)..."
                ><%= @package_changeset.changes[:transport_details] || @package_changeset.data.transport_details || "" %></textarea>
              </div>
            </div>

            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <p class="text-sm text-blue-800">
                <strong>Note:</strong> Quota, departure date, and return date are managed through package schedules.
                You can manage these through the package schedules section.
              </p>
            </div>

            <div class="flex justify-end space-x-3 pt-6">
              <.link
                navigate={~p"/admin/packages"}
                class="px-6 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
              >
                Cancel
              </.link>
              <button
                type="submit"
                class="px-6 py-2 bg-teal-600 text-white rounded-md hover:bg-teal-700 transition-colors"
              >
                Save Package
              </button>
            </div>
          </form>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
