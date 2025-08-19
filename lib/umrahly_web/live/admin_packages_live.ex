defmodule UmrahlyWeb.AdminPackagesLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages

  def mount(_params, _session, socket) do
    packages = Packages.list_packages()

    socket =
      socket
      |> assign(:packages, packages)
      |> assign(:filtered_packages, packages)
      |> assign(:search_query, "")
      |> assign(:search_status, "")
      |> assign(:search_departure_date, "")
      |> assign(:current_page, "packages")
      |> assign(:viewing_package_id, nil)
      |> assign(:show_add_form, false)
      |> assign(:show_edit_form, false)
      |> assign(:editing_package_id, nil)
      |> assign(:package_changeset, Packages.change_package(%Umrahly.Packages.Package{}))

    {:ok, socket}
  end

  def handle_event("search_packages", %{"search" => search_params}, socket) do
    search_query = Map.get(search_params, "query", "")
    search_status = Map.get(search_params, "status", "")
    search_departure_date = Map.get(search_params, "departure_date", "")

    filtered_packages = filter_packages(socket.assigns.packages, search_query, search_status, search_departure_date)

    socket =
      socket
      |> assign(:filtered_packages, filtered_packages)
      |> assign(:search_query, search_query)
      |> assign(:search_status, search_status)
      |> assign(:search_departure_date, search_departure_date)

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:filtered_packages, socket.assigns.packages)
      |> assign(:search_query, "")
      |> assign(:search_status, "")
      |> assign(:search_departure_date, "")

    {:noreply, socket}
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
    case socket.assigns.editing_package_id do
      nil ->
        # Creating new package
        case Packages.create_package(package_params) do
          {:ok, _package} ->
            packages = Packages.list_packages()

            socket =
              socket
              |> assign(:packages, packages)
              |> assign(:filtered_packages, packages)
              |> assign(:show_add_form, false)
              |> assign(:package_changeset, Packages.change_package(%Umrahly.Packages.Package{}))
              |> put_flash(:info, "Package created successfully!")

            {:noreply, socket}

          {:error, %Ecto.Changeset{} = changeset} ->
            socket =
              socket
              |> assign(:package_changeset, changeset)

            {:noreply, socket}
        end

      package_id ->
        # Updating existing package
        package = Packages.get_package!(package_id)
        case Packages.update_package(package, package_params) do
          {:ok, _updated_package} ->
            packages = Packages.list_packages()

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
            socket =
              socket
              |> assign(:package_changeset, changeset)

            {:noreply, socket}
        end
    end
  end

  def handle_event("delete_package", %{"id" => package_id}, socket) do
    package = Packages.get_package!(package_id)
    {:ok, _} = Packages.delete_package(package)

    packages = Packages.list_packages()

    socket =
      socket
      |> assign(:packages, packages)
      |> assign(:filtered_packages, packages)
      |> assign(:viewing_package_id, nil)
      |> assign(:current_package, nil)

    {:noreply, socket}
  end

  defp filter_packages(packages, search_query, search_status, search_departure_date) do
    packages
    |> Enum.filter(fn package ->
      name_matches = search_query == "" || String.contains?(String.downcase(package.name), String.downcase(search_query))
      status_matches = search_status == "" || package.status == search_status
      date_matches = search_departure_date == "" || to_string(package.departure_date) == search_departure_date

      name_matches && status_matches && date_matches
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
              <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
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
                    <option value="">All Statuses</option>
                    <option value="active" selected={@search_status == "active"}>Active</option>
                    <option value="inactive" selected={@search_status == "inactive"}>Inactive</option>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Departure Date</label>
                  <input
                    type="date"
                    name="search[departure_date]"
                    value={@search_departure_date}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  />
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
              <%= if @search_query != "" || @search_status != "" || @search_departure_date != "" do %>
                (filtered results)
              <% end %>
            </p>
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

              <form phx-submit="save_package" class="space-y-4">
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
                    <label class="block text-sm font-medium text-gray-700 mb-1">Quota</label>
                    <input
                      type="number"
                      name="package[quota]"
                      value={@package_changeset.changes[:quota] || @package_changeset.data.quota || ""}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      placeholder="Enter quota"
                      min="1"
                      max="100"
                      required
                    />
                    <%= if @package_changeset.errors[:quota] do %>
                      <p class="text-red-500 text-xs mt-1"><%= elem(@package_changeset.errors[:quota], 0) %></p>
                    <% end %>
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Departure Date</label>
                    <input
                      type="date"
                      name="package[departure_date]"
                      value={@package_changeset.changes[:departure_date] || @package_changeset.data.departure_date || ""}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      required
                    />
                    <%= if @package_changeset.errors[:departure_date] do %>
                      <p class="text-red-500 text-xs mt-1"><%= elem(@package_changeset.errors[:departure_date], 0) %></p>
                    <% end %>
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

              <form phx-submit="save_package" class="space-y-4">
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
                    <label class="block text-sm font-medium text-gray-700 mb-1">Quota</label>
                    <input
                      type="number"
                      name="package[quota]"
                      value={@package_changeset.changes[:quota] || @package_changeset.data.quota || ""}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      placeholder="Enter quota"
                      min="1"
                      max="100"
                      required
                    />
                    <%= if @package_changeset.errors[:quota] do %>
                      <p class="text-red-500 text-xs mt-1"><%= elem(@package_changeset.errors[:quota], 0) %></p>
                    <% end %>
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Departure Date</label>
                    <input
                      type="date"
                      name="package[departure_date]"
                      value={@package_changeset.changes[:departure_date] || @package_changeset.data.departure_date || ""}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                      required
                    />
                    <%= if @package_changeset.errors[:departure_date] do %>
                      <p class="text-red-500 text-xs mt-1"><%= elem(@package_changeset.errors[:departure_date], 0) %></p>
                    <% end %>
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
                    <%= if @search_query != "" || @search_status != "" || @search_departure_date != "" do %>
                      Try adjusting your search criteria.
                    <% else %>
                      Get started by creating a new package.
                    <% end %>
                  </p>
                </div>
              </div>
            <% else %>
              <%= for package <- @filtered_packages do %>
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
