defmodule UmrahlyWeb.AdminPackageItineraryLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Packages

  def mount(%{"id" => package_id}, _session, socket) do
    try do
      package = Packages.get_package_with_schedules!(package_id)
      itineraries = Packages.list_package_itineraries(package_id)

      # Convert itineraries to form data format
      itinerary_data = if length(itineraries) > 0 do
        Enum.map(itineraries, fn itinerary ->
          %{
            day_number: itinerary.day_number,
            day_title: itinerary.day_title,
            day_description: itinerary.day_description || "",
            itinerary_items: convert_itinerary_items_to_atoms(itinerary.itinerary_items || [])
          }
        end)
      else
        # Create default itinerary structure based on package duration
        Enum.map(1..package.duration_days, fn day ->
          %{
            day_number: day,
            day_title: "Day #{day}",
            day_description: "",
            itinerary_items: []
          }
        end)
      end

      socket =
        socket
        |> assign(:package, package)
        |> assign(:current_itinerary_data, itinerary_data)
        |> assign(:current_page, "packages")
        |> assign(:has_profile, true)
        |> assign(:is_admin, true)
        |> assign(:profile, socket.assigns.current_user)

      {:ok, socket}
    rescue
      e ->
        socket =
          socket
          |> put_flash(:error, "Failed to load package itinerary: #{Exception.message(e)}")
          |> redirect(to: ~p"/admin/packages")

        {:ok, socket}
    end
  end

  def handle_event("save_itinerary", %{"itinerary" => itinerary_params}, socket) do
    package_id = socket.assigns.package.id

    # Parse the itinerary data from the form
    itinerary_data = parse_itinerary_params(itinerary_params)

    case Packages.upsert_package_itineraries(package_id, itinerary_data) do
      {:ok, _itineraries} ->
        socket =
          socket
          |> put_flash(:info, "Itinerary saved successfully!")
          |> redirect(to: ~p"/admin/packages/#{package_id}")

        {:noreply, socket}

      {:error, _reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to save itinerary. Please check the form for errors.")

        {:noreply, socket}
    end
  end

  def handle_event("add_itinerary_day", _params, socket) do
    current_data = socket.assigns.current_itinerary_data
    new_day_number = length(current_data) + 1

    new_day = %{
      day_number: new_day_number,
      day_title: "Day #{new_day_number}",
      day_description: "",
      itinerary_items: []
    }

    updated_data = current_data ++ [new_day]

    socket =
      socket
      |> assign(:current_itinerary_data, updated_data)

    {:noreply, socket}
  end

  def handle_event("remove_itinerary_day", %{"day_index" => day_index}, socket) do
    day_index = String.to_integer(day_index)
    current_data = socket.assigns.current_itinerary_data

    updated_data = List.delete_at(current_data, day_index)

    # Reorder day numbers
    updated_data = Enum.with_index(updated_data)
    |> Enum.map(fn {day, index} ->
      %{day | day_number: index + 1}
    end)

    socket =
      socket
      |> assign(:current_itinerary_data, updated_data)

    {:noreply, socket}
  end

  def handle_event("add_itinerary_item", %{"day_index" => day_index}, socket) do
    day_index = String.to_integer(day_index)
    current_data = socket.assigns.current_itinerary_data

    day = Enum.at(current_data, day_index)
    updated_day = %{day | itinerary_items: day.itinerary_items ++ [%{title: "", description: ""}]}

    updated_data = List.replace_at(current_data, day_index, updated_day)

    socket =
      socket
      |> assign(:current_itinerary_data, updated_data)

    {:noreply, socket}
  end

  def handle_event("remove_itinerary_item", %{"day_index" => day_index, "item_index" => item_index}, socket) do
    day_index = String.to_integer(day_index)
    item_index = String.to_integer(item_index)
    current_data = socket.assigns.current_itinerary_data

    day = Enum.at(current_data, day_index)
    updated_items = List.delete_at(day.itinerary_items, item_index)
    updated_day = %{day | itinerary_items: updated_items}

    updated_data = List.replace_at(current_data, day_index, updated_day)

    socket =
      socket
      |> assign(:current_itinerary_data, updated_data)

    {:noreply, socket}
  end

  def handle_event("update_itinerary_field", %{"day_index" => day_index, "field" => field, "value" => value}, socket) do
    day_index = String.to_integer(day_index)
    current_data = socket.assigns.current_itinerary_data

    day = Enum.at(current_data, day_index)
    updated_day = Map.put(day, String.to_existing_atom(field), value)

    updated_data = List.replace_at(current_data, day_index, updated_day)

    socket =
      socket
      |> assign(:current_itinerary_data, updated_data)

    {:noreply, socket}
  end

  def handle_event("update_itinerary_item_field", %{"day_index" => day_index, "item_index" => item_index, "field" => field, "value" => value}, socket) do
    day_index = String.to_integer(day_index)
    item_index = String.to_integer(item_index)
    current_data = socket.assigns.current_itinerary_data

    day = Enum.at(current_data, day_index)
    item = Enum.at(day.itinerary_items, item_index)
    updated_item = Map.put(item, String.to_existing_atom(field), value)

    updated_items = List.replace_at(day.itinerary_items, item_index, updated_item)
    updated_day = %{day | itinerary_items: updated_items}

    updated_data = List.replace_at(current_data, day_index, updated_day)

    socket =
      socket
      |> assign(:current_itinerary_data, updated_data)

    {:noreply, socket}
  end

  defp parse_itinerary_params(params) do
    # Parse the form parameters to extract itinerary data
    # The form sends data in a nested structure
    case params do
      %{"days" => days_params} when is_map(days_params) ->
        days_params
        |> Map.keys()
        |> Enum.sort()
        |> Enum.map(fn day_key ->
          day_data = days_params[day_key]
          %{
            "day_number" => String.to_integer(day_data["day_number"]),
            "day_title" => day_data["day_title"],
            "day_description" => day_data["day_description"] || "",
            "itinerary_items" => parse_itinerary_items(day_data["items"] || %{})
          }
        end)

      _ ->
        []
    end
  end

  defp parse_itinerary_items(items_params) when is_map(items_params) do
    items_params
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(fn item_key ->
      item_data = items_params[item_key]
      %{
        "title" => item_data["title"] || "",
        "description" => item_data["description"] || ""
      }
    end)
  end

  defp parse_itinerary_items(_), do: []

  defp convert_itinerary_items_to_atoms(items) when is_list(items) do
    Enum.map(items, fn item ->
      case item do
        %{"title" => title, "description" => description} ->
          %{title: title, description: description}
        %{title: title, description: description} ->
          %{title: title, description: description}
        _ ->
          %{title: "", description: ""}
      end
    end)
  end
  defp convert_itinerary_items_to_atoms(_), do: []

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <!-- Header with navigation -->
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center space-x-4">
              <a href={~p"/admin/packages/#{@package.id}"} class="text-teal-600 hover:text-teal-700">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
                </svg>
              </a>
              <div>
                <h1 class="text-2xl font-bold text-gray-900">Manage Package Itinerary</h1>
                <p class="text-gray-600">Package: <%= @package.name %></p>
              </div>
            </div>
            <div class="flex space-x-3">
              <a
                href={~p"/admin/packages/#{@package.id}"}
                class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
              >
                Back to Package
              </a>
            </div>
          </div>

          <!-- Package Summary -->
          <div class="bg-gray-50 rounded-lg p-4 mb-6">
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4 text-sm">
              <div>
                <span class="text-gray-500">Duration:</span>
                <span class="font-medium text-gray-900 ml-2"><%= @package.duration_days %> days</span>
              </div>
              <div>
                <span class="text-gray-500">Price:</span>
                <span class="font-medium text-gray-900 ml-2">RM <%= @package.price %></span>
              </div>
              <div>
                <span class="text-gray-500">Status:</span>
                <span class={[
                  "inline-flex px-2 py-1 text-xs font-semibold rounded-full ml-2",
                  case @package.status do
                    "active" -> "bg-green-100 text-green-800"
                    "inactive" -> "bg-red-100 text-red-800"
                    "draft" -> "bg-gray-100 text-gray-800"
                    _ -> "bg-gray-100 text-gray-800"
                  end
                ]}>
                  <%= @package.status %>
                </span>
              </div>
              <div>
                <span class="text-gray-500">Current Days:</span>
                <span class="font-medium text-gray-900 ml-2"><%= length(@current_itinerary_data) %></span>
              </div>
            </div>
          </div>

          <!-- Itinerary Management Form -->
          <form phx-submit="save_itinerary" class="space-y-6">
            <div class="space-y-4">
              <%= for {day, day_index} <- Enum.with_index(@current_itinerary_data) do %>
                <div class="bg-gray-50 p-6 rounded-lg border border-gray-200">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="text-xl font-semibold text-gray-900">Day <%= day.day_number %></h3>
                    <button
                      type="button"
                      phx-click="remove_itinerary_day"
                      phx-value-day_index={day_index}
                      class="text-red-600 hover:text-red-800 text-sm font-medium"
                      data-confirm="Are you sure you want to remove this day?"
                    >
                      Remove Day
                    </button>
                  </div>

                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">Day Title</label>
                      <input
                        type="text"
                        name={"itinerary[days][#{day_index}][day_title]"}
                        value={day.day_title}
                        phx-blur="update_itinerary_field"
                        phx-value-day_index={day_index}
                        phx-value-field="day_title"
                        class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        placeholder="Enter day title"
                      />
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">Day Number</label>
                      <input
                        type="number"
                        name={"itinerary[days][#{day_index}][day_number]"}
                        value={day.day_number}
                        class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        placeholder="Day number"
                        min="1"
                        readonly
                      />
                    </div>
                  </div>

                  <div class="mb-6">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Day Description</label>
                    <textarea
                      name={"itinerary[days][#{day_index}][day_description]"}
                      rows="3"
                      phx-blur="update_itinerary_field"
                      phx-value-day_index={day_index}
                      phx-value-field="day_description"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      placeholder="Enter day description..."
                    ><%= day.day_description %></textarea>
                  </div>

                  <div class="mb-4">
                    <div class="flex items-center justify-between mb-3">
                      <label class="block text-sm font-medium text-gray-700">Itinerary Items</label>
                      <button
                        type="button"
                        phx-click="add_itinerary_item"
                        phx-value-day_index={day_index}
                        class="bg-blue-600 text-white px-3 py-2 rounded text-sm hover:bg-blue-700 transition-colors"
                      >
                        Add Item
                      </button>
                    </div>

                    <div class="space-y-3">
                      <%= for {item, item_index} <- Enum.with_index(day.itinerary_items) do %>
                        <div class="bg-white p-4 rounded-lg border border-gray-200">
                          <div class="flex items-center justify-between mb-3">
                            <span class="text-sm font-medium text-gray-700">Item <%= item_index + 1 %></span>
                            <button
                              type="button"
                              phx-click="remove_itinerary_item"
                              phx-value-day_index={day_index}
                              phx-value-item_index={item_index}
                              class="text-red-600 hover:text-red-800 text-sm"
                            >
                              Remove
                            </button>
                          </div>
                          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                            <div>
                              <label class="block text-xs font-medium text-gray-600 mb-1">Title</label>
                              <input
                                type="text"
                                name={"itinerary[days][#{day_index}][items][#{item_index}][title]"}
                                value={item.title}
                                phx-blur="update_itinerary_item_field"
                                phx-value-day_index={day_index}
                                phx-value-item_index={item_index}
                                phx-value-field="title"
                                class="w-full px-3 py-2 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-transparent"
                                placeholder="Enter item title"
                              />
                            </div>
                            <div>
                              <label class="block text-xs font-medium text-gray-600 mb-1">Description</label>
                              <input
                                type="text"
                                name={"itinerary[days][#{day_index}][items][#{item_index}][description]"}
                                value={item.description}
                                phx-blur="update_itinerary_item_field"
                                phx-value-day_index={day_index}
                                phx-value-item_index={item_index}
                                phx-value-field="description"
                                class="w-full px-3 py-2 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-transparent"
                                placeholder="Enter item description"
                              />
                            </div>
                          </div>
                        </div>
                      <% end %>

                      <%= if length(day.itinerary_items) == 0 do %>
                        <div class="text-center py-6 text-gray-500 border-2 border-dashed border-gray-300 rounded-lg">
                          <svg class="mx-auto h-8 w-8 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                          </svg>
                          <p class="mt-2 text-sm">No itinerary items for this day</p>
                          <p class="text-xs">Click "Add Item" to create the first itinerary item</p>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>

            <div class="flex items-center justify-between pt-6 border-t border-gray-200">
              <button
                type="button"
                phx-click="add_itinerary_day"
                class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors"
              >
                Add New Day
              </button>

              <div class="flex space-x-3">
                <a
                  href={~p"/admin/packages/#{@package.id}"}
                  class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </a>
                <button
                  type="submit"
                  class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                >
                  Save Itinerary
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
