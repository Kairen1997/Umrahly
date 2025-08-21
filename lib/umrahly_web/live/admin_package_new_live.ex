defmodule UmrahlyWeb.AdminPackageNewLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_page, "packages")
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns.current_user)
      |> assign(:package_changeset, Packages.change_package(%Umrahly.Packages.Package{}))
      |> allow_upload(:package_picture,
        accept: ~w(.jpg .jpeg .png .gif),
        max_entries: 1,
        max_file_size: 5_000_000
      )

    {:ok, socket}
  end

  def handle_event("save_package", %{"package" => package_params}, socket) do
    # Process picture upload if any
    picture_path = case consume_uploaded_entries(socket, :package_picture, fn entry, _socket ->
      # Use a more reliable path for uploads
      uploads_dir = Path.join(File.cwd!(), "priv/static/images")
      File.mkdir_p!(uploads_dir)

      extension = Path.extname(entry.client_name)
      filename = "package_#{System.system_time()}#{extension}"
      dest_path = Path.join(uploads_dir, filename)

      case File.cp(entry.path, dest_path) do
        :ok ->
          {:ok, "/images/#{filename}"}
        {:error, reason} ->
          {:error, reason}
      end
    end) do
      [path | _] ->
        path
      [] ->
        nil
    end

    # Add picture path to package params if uploaded
    package_params = if picture_path do
      Map.put(package_params, "picture", picture_path)
    else
      package_params
    end

    # Ensure all required fields are present and properly formatted
    package_params = package_params
      |> Map.update("price", nil, &if(is_binary(&1) && &1 != "", do: String.to_integer(&1), else: &1))
      |> Map.update("duration_days", nil, &if(is_binary(&1) && &1 != "", do: String.to_integer(&1), else: &1))
      |> Map.update("duration_nights", nil, &if(is_binary(&1) && &1 != "", do: String.to_integer(&1), else: &1))
      |> Map.update("picture", nil, &if(is_binary(&1) && &1 == "", do: nil, else: &1))
      |> Map.reject(fn {_k, v} -> is_binary(v) && v == "" end)

    # Ensure all required fields have values
    package_params = package_params
      |> Map.put_new("name", "")
      |> Map.put_new("price", 0)
      |> Map.put_new("duration_days", 1)
      |> Map.put_new("duration_nights", 1)
      |> Map.put_new("status", "inactive")
      |> Map.update("name", "", &if(is_binary(&1) && &1 == "", do: nil, else: &1))
      |> Map.update("description", "", &if(is_binary(&1) && &1 == "", do: nil, else: &1))
      |> Map.update("status", "inactive", &if(is_binary(&1) && &1 == "", do: "inactive", else: &1))
      |> Map.update("price", 0, &if(is_binary(&1) && &1 == "", do: 0, else: &1))
      |> Map.update("duration_days", 1, &if(is_binary(&1) && &1 == "", do: 1, else: &1))
      |> Map.update("duration_nights", 1, &if(is_binary(&1) && &1 == "", do: 1, else: &1))
      |> Map.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.put("name", package_params["name"] || "")
      |> Map.put("price", package_params["price"] || 0)
      |> Map.put("duration_days", package_params["duration_days"] || 1)
      |> Map.put("duration_nights", package_params["duration_nights"] || 1)
      |> Map.put("status", package_params["status"] || "inactive")

    # Creating new package
    case Packages.create_package(package_params) do
      {:ok, _package} ->
        {:noreply,
         socket
         |> put_flash(:info, "Package created successfully!")
         |> push_navigate(to: ~p"/admin/packages")}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> assign(:package_changeset, changeset)
          |> put_flash(:error, "Failed to create package. Please check the form for errors.")

        {:noreply, socket}
    end
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :package_picture, ref)}
  end

  def handle_event("validate", _params, socket) do
    # This will be called whenever form fields change, including file uploads
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-4xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Add New Package</h1>
            <.link
              navigate={~p"/admin/packages"}
              class="text-gray-500 hover:text-gray-700 flex items-center"
            >
              <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
              </svg>
              Back to Packages
            </.link>
          </div>

          <form phx-submit="save_package" phx-change="validate" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Package Name</label>
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

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
                <textarea
                  name="package[description]"
                  rows="3"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Enter package description..."
                ><%= @package_changeset.changes[:description] || @package_changeset.data.description || "" %></textarea>
                <%= if @package_changeset.errors[:description] do %>
                  <p class="text-red-500 text-xs mt-1"><%= elem(@package_changeset.errors[:description], 0) %></p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
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
                <label class="block text-sm font-medium text-gray-700 mb-1">Price (RM)</label>
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
                <label class="block text-sm font-medium text-gray-700 mb-1">Duration (Days)</label>
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
                <label class="block text-sm font-medium text-gray-700 mb-1">Duration (Nights)</label>
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
                <label class="block text-sm font-medium text-gray-700 mb-1">Accommodation Type</label>
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
                <label class="block text-sm font-medium text-gray-700 mb-1">Transport Type</label>
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

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">Accommodation Details</label>
                <textarea
                  name="package[accommodation_details]"
                  rows="2"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Enter accommodation details (e.g., hotel name, room type, amenities)..."
                ><%= @package_changeset.changes[:accommodation_details] || @package_changeset.data.accommodation_details || "" %></textarea>
              </div>

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">Transport Details</label>
                <textarea
                  name="package[transport_details]"
                  rows="2"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  placeholder="Enter transport details (e.g., flight details, pickup times, vehicle info)..."
                ><%= @package_changeset.changes[:transport_details] || @package_changeset.data.transport_details || "" %></textarea>
              </div>

              <div class="md:col-span-2">
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-3">
                  <p class="text-sm text-blue-800">
                    <strong>Note:</strong> Quota, departure date, and return date are managed through package schedules.
                    After creating this package, you can add specific schedules with departure dates, return dates, and quotas.
                  </p>
                </div>
              </div>

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">Package Picture</label>
                <div class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md" phx-drop-target={@uploads.package_picture.ref}>
                  <div class="space-y-1 text-center">
                    <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48" aria-hidden="true">
                      <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                    </svg>
                    <div class="flex text-sm text-gray-600">
                      <label class="relative cursor-pointer bg-white rounded-md font-medium text-teal-600 hover:text-teal-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-teal-500 px-3 py-1 rounded border border-teal-300 hover:bg-teal-50 transition-colors">
                        <span>Upload a file</span>
                        <.live_file_input upload={@uploads.package_picture} accept="image/*" class="hidden" />
                      </label>
                      <p class="pl-1">or drag and drop</p>
                    </div>
                    <p class="text-xs text-gray-500">PNG, JPG, GIF up to 5MB</p>
                  </div>
                </div>
                <div class="mt-2">
                  <%= for entry <- @uploads.package_picture.entries do %>
                    <div class="flex items-center space-x-2 p-2 bg-gray-50 rounded-lg">
                      <div class="flex-shrink-0">
                        <div class="w-20 h-20 bg-gray-200 rounded flex items-center justify-center overflow-hidden">
                          <%= if entry.upload_state == :complete do %>
                            <img src={entry.url} alt="Preview" class="w-full h-full object-cover" />
                          <% else %>
                            <span class="text-xs text-gray-500">Preview</span>
                          <% end %>
                        </div>
                      </div>
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-medium text-gray-900 truncate"><%= entry.client_name %></p>
                        <p class="text-sm text-gray-500">
                          <%= case entry.upload_state do %>
                            <% :uploading -> %>
                              Uploading...
                            <% :complete -> %>
                              Ready to save
                            <% :error -> %>
                              Error: <%= entry.errors |> Enum.map(&elem(&1, 1)) |> Enum.join(", ") %>
                            <% _ -> %>
                              Ready
                          <% end %>
                        </p>
                      </div>
                      <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-red-600 hover:text-red-800">
                        Remove
                      </button>
                    </div>
                  <% end %>

                  <%= for err <- upload_errors(@uploads.package_picture) do %>
                    <p class="text-red-600 text-sm mt-2"><%= Phoenix.Naming.humanize(err) %></p>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="flex justify-end space-x-3 pt-4">
              <.link
                navigate={~p"/admin/packages"}
                class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
              >
                Cancel
              </.link>
              <button
                type="submit"
                class="px-4 py-2 bg-teal-600 text-white rounded-md hover:bg-teal-700 transition-colors"
              >
                Create Package
              </button>
            </div>
          </form>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
