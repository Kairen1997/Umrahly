defmodule UmrahlyWeb.AdminPackagesLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages

  def mount(_params, _session, socket) do
    packages = Packages.list_packages_with_schedules()

    socket =
      socket
      |> assign(:packages, packages)
      |> assign(:filtered_packages, packages)
      |> assign(:search_query, "")
      |> assign(:search_status, "")
      |> assign(:current_page, "packages")
      |> assign(:viewing_package_id, nil)
      |> assign(:show_add_form, false)
      |> assign(:show_edit_form, false)
      |> assign(:editing_package_id, nil)
      |> assign(:package_changeset, Packages.change_package(%Umrahly.Packages.Package{}))
      |> allow_upload(:package_picture,
        accept: ~w(.jpg .jpeg .png .gif),
        max_entries: 1,
        max_file_size: 5_000_000
      )

    {:ok, socket}
  end

  def handle_event("search_packages", %{"search" => search_params}, socket) do
    search_query = Map.get(search_params, "query", "")
    search_status = Map.get(search_params, "status", "")

    filtered_packages = filter_packages(socket.assigns.packages, search_query, search_status)

    socket =
      socket
      |> assign(:filtered_packages, filtered_packages)
      |> assign(:search_query, search_query)
      |> assign(:search_status, search_status)

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:filtered_packages, socket.assigns.packages)
      |> assign(:search_query, "")
      |> assign(:search_status, "")

    {:noreply, socket}
  end

  def handle_event("view_package", %{"id" => package_id}, socket) do
    package = Packages.get_package_with_schedules!(package_id)

    # Get the first active schedule to calculate booking stats
    first_schedule = List.first(package.package_schedules) || %{quota: 0}

    # Calculate booking stats from package schedules
    booking_stats = if first_schedule.quota && first_schedule.quota > 0 do
      total_confirmed = Packages.get_package_schedule_booking_stats(first_schedule.id).confirmed_bookings
      available_slots = first_schedule.quota - total_confirmed
      booking_percentage = if first_schedule.quota > 0, do: (total_confirmed / first_schedule.quota) * 100, else: 0.0

      %{
        confirmed_bookings: total_confirmed,
        available_slots: available_slots,
        booking_percentage: Float.round(booking_percentage, 1)
      }
    else
      %{
        confirmed_bookings: 0,
        available_slots: 0,
        booking_percentage: 0.0
      }
    end

    socket =
      socket
      |> assign(:viewing_package_id, package_id)
      |> assign(:current_package, package)
      |> assign(:current_package_booking_stats, booking_stats)

    {:noreply, socket}
  end

  def handle_event("close_package_view", _params, socket) do
    socket =
      socket
      |> assign(:viewing_package_id, nil)
      |> assign(:current_package, nil)

    {:noreply, socket}
  end

  def handle_event("add_package", _params, socket) do
    socket =
      socket
      |> assign(:show_add_form, true)
      |> assign(:show_edit_form, false)
      |> assign(:viewing_package_id, nil)
      |> assign(:current_package, nil)
      |> assign(:editing_package_id, nil)
      |> assign(:package_changeset, Packages.change_package(%Umrahly.Packages.Package{}))

    {:noreply, socket}
  end

  def handle_event("close_add_form", _params, socket) do
    socket =
      socket
      |> assign(:show_add_form, false)
      |> assign(:package_changeset, Packages.change_package(%Umrahly.Packages.Package{}))

    {:noreply, socket}
  end

  def handle_event("edit_package", %{"id" => package_id}, socket) do
    package = Packages.get_package!(package_id)
    changeset = Packages.change_package(package)

    socket =
      socket
      |> assign(:show_edit_form, true)
      |> assign(:show_add_form, false)
      |> assign(:viewing_package_id, nil)
      |> assign(:current_package, nil)
      |> assign(:editing_package_id, package_id)
      |> assign(:package_changeset, changeset)

    {:noreply, socket}
  end

  def handle_event("close_edit_form", _params, socket) do
    socket =
      socket
      |> assign(:show_edit_form, false)
      |> assign(:editing_package_id, nil)
      |> assign(:package_changeset, Packages.change_package(%Umrahly.Packages.Package{}))

    {:noreply, socket}
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
      # Keep existing picture if no new one uploaded and we're editing
      if socket.assigns.editing_package_id do
        existing_package = Packages.get_package!(socket.assigns.editing_package_id)
        Map.put(package_params, "picture", existing_package.picture)
      else
        package_params
      end
    end

    # Ensure all required fields are present and properly formatted
    package_params = package_params
      |> Map.update("price", nil, &if(is_binary(&1) && &1 != "", do: String.to_integer(&1), else: &1))
      |> Map.update("duration_days", nil, &if(is_binary(&1) && &1 != "", do: String.to_integer(&1), else: &1))
      |> Map.update("duration_nights", nil, &if(is_binary(&1) && &1 != "", do: String.to_integer(&1), else: &1))
      |> Map.update("picture", nil, &if(is_binary(&1) && &1 == "", do: nil, else: &1))
      |> Map.reject(fn {_k, v} -> is_binary(v) && v == "" end)

    # Log package params for debugging
    IO.inspect(package_params, label: "Package params before save")

    # Check if all required fields are present
    required_fields = ["name", "price", "duration_days", "duration_nights", "status"]
    missing_fields = required_fields -- Map.keys(package_params)
    if length(missing_fields) > 0 do
      IO.inspect(missing_fields, label: "Missing required fields")
    end

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

    case socket.assigns.editing_package_id do
      nil ->
        # Creating new package
        case Packages.create_package(package_params) do
          {:ok, _package} ->
            packages = Packages.list_packages_with_schedules()

            socket =
              socket
              |> assign(:packages, packages)
              |> assign(:filtered_packages, packages)
              |> assign(:show_add_form, false)
              |> assign(:package_changeset, Packages.change_package(%Umrahly.Packages.Package{}))
              |> put_flash(:info, "Package created successfully!")

            {:noreply, socket}

          {:error, %Ecto.Changeset{} = changeset} ->
            # Log validation errors for debugging
            IO.inspect(changeset.errors, label: "Package create validation errors")

            socket =
              socket
              |> assign(:package_changeset, changeset)
              |> put_flash(:error, "Failed to create package. Please check the form for errors.")

            {:noreply, socket}
        end

      package_id ->
        # Updating existing package
        package = Packages.get_package!(package_id)
        case Packages.update_package(package, package_params) do
          {:ok, _updated_package} ->
            packages = Packages.list_packages_with_schedules()

            socket =
              socket
              |> assign(:packages, packages)
              |> assign(:filtered_packages, packages)
              |> assign(:show_edit_form, false)
              |> assign(:editing_package_id, nil)
              |> assign(:package_changeset, Packages.change_package(%Umrahly.Packages.Package{}))
              |> put_flash(:info, "Package updated successfully!")

            {:noreply, socket}

          {:error, %Ecto.Changeset{} = changeset} ->
            # Log validation errors for debugging
            IO.inspect(changeset.errors, label: "Package update validation errors")

            socket =
              socket
              |> assign(:package_changeset, changeset)
              |> put_flash(:error, "Failed to update package. Please check the form for errors.")

            {:noreply, socket}
        end
    end
  end

  def handle_event("delete_package", %{"id" => package_id}, socket) do
    package = Packages.get_package!(package_id)
    {:ok, _} = Packages.delete_package(package)

    packages = Packages.list_packages_with_schedules()

    socket =
      socket
      |> assign(:packages, packages)
      |> assign(:filtered_packages, packages)
      |> assign(:viewing_package_id, nil)
      |> assign(:current_package, nil)

    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :package_picture, ref)}
  end

  def handle_event("validate", _params, socket) do
    # This will be called whenever form fields change, including file uploads
    {:noreply, socket}
  end

  defp filter_packages(packages, search_query, search_status) do
    packages
    |> Enum.filter(fn package ->
      name_matches = search_query == "" || String.contains?(String.downcase(package.name), String.downcase(search_query))
      status_matches = search_status == "" || package.status == search_status

      name_matches && status_matches
    end)
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Packages Management</h1>
            <button
              phx-click="add_package"
              class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors">
              Add New Package
            </button>
          </div>

          <!-- Search Bar -->
          <div class="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-6">
            <form phx-change="search_packages" class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Package Name</label>
                  <input
                    type="text"
                    name="search[query]"
                    value={@search_query}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                    placeholder="Search by package name..."
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
                  <select
                    name="search[status]"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  >
                    <option value="">All Status</option>
                    <option value="active" selected={@search_status == "active"}>Active</option>
                    <option value="inactive" selected={@search_status == "inactive"}>Inactive</option>
                  </select>
                </div>

                <div class="flex items-end">
                  <button
                    type="button"
                    phx-click="clear_search"
                    class="w-full px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
                  >
                    Clear Search
                  </button>
                </div>
              </div>
            </form>
          </div>

          <!-- Search Results Summary -->
          <div class="mb-4">
            <p class="text-sm text-gray-600">
              Showing <%= length(@filtered_packages) %> of <%= length(@packages) %> packages
              <%= if @search_query != "" || @search_status != "" do %>
                (filtered by package name and status)
              <% end %>
            </p>
          </div>

          <!-- Overall Booking Statistics -->
          <div class="mb-6 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-8 w-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm font-medium text-blue-600">Total Quota</p>
                  <p class="text-2xl font-bold text-blue-900">
                    <%= @packages |> Enum.reduce(0, fn package, acc ->
                      package.package_schedules |> Enum.reduce(acc, fn schedule, schedule_acc ->
                        schedule_acc + (schedule.quota || 0)
                      end)
                    end) %>
                  </p>
                </div>
              </div>
            </div>

            <div class="bg-green-50 border border-green-200 rounded-lg p-4">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-8 w-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm font-medium text-green-600">Confirmed Bookings</p>
                  <p class="text-2xl font-bold text-green-900">
                    <%= @packages |> Enum.reduce(0, fn package, acc ->
                      package.package_schedules |> Enum.reduce(acc, fn schedule, schedule_acc ->
                        schedule_acc + Packages.get_package_schedule_booking_stats(schedule.id).confirmed_bookings
                      end)
                    end) %>
                  </p>
                </div>
              </div>
            </div>

            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-8 w-8 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm font-medium text-yellow-600">Available Slots</p>
                  <p class="text-2xl font-bold text-yellow-900">
                    <%= @packages |> Enum.reduce(0, fn package, acc ->
                      package.package_schedules |> Enum.reduce(acc, fn schedule, schedule_acc ->
                        schedule_acc + Packages.get_package_schedule_booking_stats(schedule.id).available_slots
                      end)
                    end) %>
                  </p>
                </div>
              </div>
            </div>

            <div class="bg-purple-50 border border-purple-200 rounded-lg p-4">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <svg class="h-8 w-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm font-medium text-purple-600">Avg. Occupancy</p>
                  <p class="text-2xl font-bold text-purple-900">
                    <% total_percentage = @packages |> Enum.reduce(0, fn package, acc ->
                      package.package_schedules |> Enum.reduce(acc, fn schedule, schedule_acc ->
                        schedule_acc + Packages.get_package_schedule_booking_stats(schedule.id).booking_percentage
                      end)
                    end) %>
                    <% total_schedules = @packages |> Enum.reduce(0, fn package, acc ->
                      acc + length(package.package_schedules)
                    end) %>
                    <%= if total_schedules > 0, do: Float.round(total_percentage / total_schedules, 1), else: 0.0 %>%
                  </p>
                </div>
              </div>
            </div>


          </div>

          <%= if @show_add_form do %>
            <!-- Add Package Form -->
            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-bold text-gray-900">Add New Package</h2>
                <button
                  phx-click="close_add_form"
                  class="text-gray-500 hover:text-gray-700"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                  </svg>
                </button>
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
                  <button
                    type="button"
                    phx-click="close_add_form"
                    class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="px-4 py-2 bg-teal-600 text-white rounded-md hover:bg-teal-700 transition-colors"
                  >
                    Create Package
                  </button>
                </div>
              </form>
            </div>
          <% end %>

          <%= if @show_edit_form do %>
            <!-- Edit Package Form -->
            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-bold text-gray-900">Edit Package</h2>
                <button
                  phx-click="close_edit_form"
                  class="text-gray-500 hover:text-gray-700"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                  </svg>
                </button>
              </div>

              <form phx-submit="save_package" phx-change="validate" class="space-y-4">
                <input type="hidden" name="package[id]" value={@editing_package_id} />
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
                        You can manage these through the package schedules section.
                      </p>
                    </div>
                  </div>

                  <div class="md:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Package Picture</label>
                    <%= if @package_changeset.data.picture do %>
                      <div class="mb-3">
                        <p class="text-sm text-gray-600 mb-2">Current Picture:</p>
                        <img src={@package_changeset.data.picture} alt="Current package picture" class="h-32 w-32 object-cover rounded border" />
                      </div>
                    <% end %>
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
                  <button
                    type="button"
                    phx-click="close_edit_form"
                    class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="px-4 py-2 bg-teal-600 text-white rounded-md hover:bg-teal-700 transition-colors"
                  >
                    Save Package
                  </button>
                </div>
              </form>
            </div>
          <% end %>

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
                  <%= if @current_package.picture do %>
                    <div class="mb-4">
                      <img src={@current_package.picture} alt={"#{@current_package.name} picture"} class="w-full h-64 object-cover rounded-lg" />
                    </div>
                  <% end %>
                  <h3 class="text-lg font-semibold text-gray-900 mb-2"><%= @current_package.name %></h3>
                  <p class="text-gray-600 mb-4">
                    <%= if @current_package.description && @current_package.description != "" do %>
                      <%= @current_package.description %>
                    <% else %>
                      No description available
                    <% end %>
                  </p>

                  <div class="space-y-3">
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Price:</span>
                      <span class="text-sm font-medium text-gray-900">RM <%= @current_package.price %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-sm text-gray-500">Duration:</span>
                      <span class="text-sm font-medium text-gray-900"><%= @current_package.duration_days %> days / <%= @current_package.duration_nights %> nights</span>
                    </div>
                    <%= if @current_package.accommodation_type && @current_package.accommodation_type != "" do %>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-500">Accommodation:</span>
                        <span class="text-sm font-medium text-gray-900"><%= @current_package.accommodation_type %></span>
                      </div>
                      <%= if @current_package.accommodation_details && @current_package.accommodation_details != "" do %>
                        <div class="flex justify-between">
                          <span class="text-sm text-gray-500">Accommodation Details:</span>
                          <span class="text-sm font-medium text-gray-900"><%= @current_package.accommodation_details %></span>
                        </div>
                      <% end %>
                    <% end %>
                    <%= if @current_package.transport_type && @current_package.transport_type != "" do %>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-500">Transport:</span>
                        <span class="text-sm font-medium text-gray-900"><%= @current_package.transport_type %></span>
                      </div>
                      <%= if @current_package.transport_details && @current_package.transport_details != "" do %>
                        <div class="flex justify-between">
                          <span class="text-sm text-gray-500">Transport Details:</span>
                          <span class="text-sm font-medium text-gray-900"><%= @current_package.transport_details %></span>
                        </div>
                      <% end %>
                    <% end %>

                    <!-- Package Schedules Information -->
                    <%= if length(@current_package.package_schedules) > 0 do %>
                      <div class="text-sm text-gray-500 mb-2">Package Schedules:</div>
                      <%= for schedule <- @current_package.package_schedules do %>
                        <div class="bg-gray-100 p-3 rounded-lg space-y-2">
                          <div class="flex justify-between">
                            <span class="text-xs text-gray-500">Quota:</span>
                            <span class="text-xs font-medium text-gray-900"><%= schedule.quota %></span>
                          </div>
                          <div class="flex justify-between">
                            <span class="text-xs text-gray-500">Departure:</span>
                            <span class="text-xs font-medium text-gray-900"><%= schedule.departure_date %></span>
                          </div>
                          <div class="flex justify-between">
                            <span class="text-xs text-gray-500">Return:</span>
                            <span class="text-xs font-medium text-gray-900"><%= schedule.return_date %></span>
                          </div>
                          <div class="flex justify-between">
                            <span class="text-xs text-gray-500">Status:</span>
                            <span class="text-xs font-medium text-gray-900"><%= schedule.status %></span>
                          </div>
                        </div>
                      <% end %>
                    <% else %>
                      <div class="text-sm text-gray-500">No schedules available</div>
                    <% end %>

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

                  <!-- Booking Statistics -->
                  <div class="mt-6 p-4 bg-blue-50 rounded-lg border border-blue-200">
                    <h4 class="text-sm font-semibold text-blue-900 mb-3">Booking Statistics</h4>
                    <div class="grid grid-cols-2 gap-4">
                      <div class="text-center">
                        <div class="text-2xl font-bold text-blue-600"><%= @current_package_booking_stats.confirmed_bookings %></div>
                        <div class="text-xs text-blue-700">Confirmed Bookings</div>
                      </div>
                      <div class="text-center">
                        <div class="text-2xl font-bold text-green-600"><%= @current_package_booking_stats.available_slots %></div>
                        <div class="text-xs text-green-700">Available Slots</div>
                      </div>
                    </div>
                    <div class="mt-3 pt-3 border-t border-blue-200">
                      <div class="flex justify-between items-center">
                        <span class="text-sm text-blue-700">Total Quota:</span>
                        <span class="text-sm font-semibold text-blue-900">
                          <%= @current_package.package_schedules |> Enum.reduce(0, fn schedule, acc -> acc + (schedule.quota || 0) end) %>
                        </span>
                      </div>
                      <div class="flex justify-between items-center mt-1">
                        <span class="text-sm text-blue-700">Booking Percentage:</span>
                        <span class="text-sm font-semibold text-blue-900"><%= @current_package_booking_stats.booking_percentage %>%</span>
                      </div>
                      <div class="mt-2">
                        <div class="w-full bg-blue-200 rounded-full h-2">
                          <div class="bg-blue-600 h-2 rounded-full" style={"width: #{@current_package_booking_stats.booking_percentage}%"}>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="flex flex-col space-y-3">
                  <button
                    phx-click="edit_package"
                    phx-value-id={@current_package.id}
                    class="w-full bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors"
                  >
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
            <%= if length(@filtered_packages) == 0 do %>
              <div class="col-span-full text-center py-12">
                <div class="text-gray-500">
                  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 12h6m-6-4h6m2 5.291A7.962 7.962 0 0112 15c-2.34 0-4.47-.881-6.08-2.33" />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No packages found</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    <%= if @search_query != "" || @search_status != "" do %>
                      Try adjusting your search criteria for name, description, or status.
                    <% else %>
                      Get started by creating a new package.
                    <% end %>
                  </p>
                </div>
              </div>
            <% else %>
              <%= for package <- @filtered_packages do %>
                <div class="bg-white border border-gray-200 rounded-lg shadow-sm hover:shadow-md transition-shadow">
                  <%= if package.picture do %>
                    <div class="h-48 overflow-hidden rounded-t-lg">
                      <img src={package.picture} alt={"#{package.name} picture"} class="w-full h-full object-cover" />
                    </div>
                  <% else %>
                    <div class="h-48 bg-gray-200 flex items-center justify-center rounded-t-lg">
                      <svg class="w-16 h-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                    </div>
                  <% end %>
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

                    <p class="text-gray-600 text-sm mb-4">
                      <%= if package.description && package.description != "" do %>
                        <%= package.description %>
                      <% else %>
                        No description available
                      <% end %>
                    </p>

                    <div class="space-y-2 mb-4">
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-500">Price:</span>
                        <span class="text-sm font-medium text-gray-900">RM <%= package.price %></span>
                      </div>
                      <div class="flex justify-between">
                        <span class="text-sm text-gray-500">Duration:</span>
                        <span class="text-sm font-medium text-gray-900"><%= package.duration_days %> days / <%= package.duration_nights %> nights</span>
                      </div>
                      <%= if package.accommodation_type && package.accommodation_type != "" do %>
                        <div class="flex justify-between">
                          <span class="text-sm text-gray-500">Accommodation:</span>
                          <span class="text-sm font-medium text-gray-900"><%= package.accommodation_type %></span>
                        </div>
                      <% end %>
                      <%= if package.transport_type && package.transport_type != "" do %>
                        <div class="flex justify-between">
                          <span class="text-sm text-gray-500">Transport:</span>
                          <span class="text-sm font-medium text-gray-900"><%= package.transport_type %></span>
                        </div>
                      <% end %>

                      <!-- Package Schedules Summary -->
                      <%= if length(package.package_schedules) > 0 do %>
                        <div class="flex justify-between">
                          <span class="text-sm text-gray-500">Schedules:</span>
                          <span class="text-sm font-medium text-gray-900"><%= length(package.package_schedules) %></span>
                        </div>
                        <%= for schedule <- Enum.take(package.package_schedules, 1) do %>
                          <div class="flex justify-between">
                            <span class="text-sm text-gray-500">Next Departure:</span>
                            <span class="text-sm font-medium text-gray-900"><%= schedule.departure_date %></span>
                          </div>
                          <div class="flex justify-between">
                            <span class="text-sm text-gray-500">Quota:</span>
                            <span class="text-sm font-medium text-gray-900"><%= schedule.quota %></span>
                          </div>
                        <% end %>
                      <% else %>
                        <div class="text-sm text-gray-500">No schedules available</div>
                      <% end %>

                      <!-- Quick Booking Status -->
                      <%= if length(package.package_schedules) > 0 do %>
                        <div class="mt-3 pt-3 border-t border-gray-200">
                          <% first_schedule = List.first(package.package_schedules) %>
                          <% total_confirmed = Packages.get_package_schedule_booking_stats(first_schedule.id).confirmed_bookings %>
                          <% total_quota = first_schedule.quota %>
                          <% booking_percentage = if total_quota > 0, do: (total_confirmed / total_quota) * 100, else: 0.0 %>
                          <div class="flex justify-between items-center">
                            <span class="text-xs text-gray-500">Bookings:</span>
                            <span class="text-xs font-medium text-gray-900">
                              <%= total_confirmed %> / <%= total_quota %>
                            </span>
                          </div>
                          <div class="mt-1">
                            <div class="w-full bg-gray-200 rounded-full h-1.5">
                              <div class="bg-teal-500 h-1.5 rounded-full" style={"width: #{Float.round(booking_percentage, 1)}%"}>
                              </div>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>

                    <div class="flex space-x-2">
                      <button
                        phx-click="view_package"
                        phx-value-id={package.id}
                        class="flex-1 bg-teal-600 text-white px-3 py-2 rounded text-sm hover:bg-teal-700 transition-colors"
                      >
                        View
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
