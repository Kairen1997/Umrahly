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
            itinerary_content: itinerary.itinerary_content || "",
            day_photo: itinerary.day_photo || nil
          }
        end)
      else
        # Create default itinerary structure based on package duration
        Enum.map(1..package.duration_days, fn day ->
          %{
            day_number: day,
            day_title: "Day #{day}",
            day_description: "",
            itinerary_content: "",
            day_photo: nil
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
        |> assign(:profile, socket.assigns[:current_user])
        |> allow_upload(:itinerary_photos,
          accept: ~w(.jpg .jpeg .png .gif),
          max_entries: 50,
          max_file_size: 5_000_000
        )

      {:ok, socket}
    rescue
      e ->

        error_socket =
          socket
          |> put_flash(:error, "Failed to load package itinerary: #{Exception.message(e)}")
          |> redirect(to: ~p"/admin/packages")

        {:ok, error_socket}
    end
  end

  def handle_event("save_itinerary", %{"itinerary" => itinerary_params}, socket) do
    package_id = socket.assigns.package.id



    # Parse the itinerary data from the form
    itinerary_data = parse_itinerary_params(itinerary_params)


    # Validate that we have itinerary data
    if length(itinerary_data) == 0 do
      socket =
        socket
        |> put_flash(:error, "No itinerary data found. Please add at least one day.")

      {:noreply, socket}
    else
      case Packages.upsert_package_itineraries(package_id, itinerary_data) do
        {:ok, _itineraries} ->
          socket =
            socket
            |> put_flash(:info, "Itinerary saved successfully!")
            |> redirect(to: ~p"/admin/packages/details/#{package_id}")

          {:noreply, socket}

        {:error, reason} ->

          socket =
            socket
            |> put_flash(:error, "Failed to save itinerary: #{inspect(reason)}")

          {:noreply, socket}
      end
    end
  end

  def handle_event("add_itinerary_day", _params, socket) do
    try do
      current_data = socket.assigns.current_itinerary_data
      new_day_number = length(current_data) + 1

      new_day = %{
        day_number: new_day_number,
        day_title: "Day #{new_day_number}",
        day_description: "",
        itinerary_content: "",
        day_photo: nil
      }

      updated_data = current_data ++ [new_day]

      socket =
        socket
        |> assign(:current_itinerary_data, updated_data)
        |> put_flash(:info, "New day added successfully!")

      {:noreply, socket}
    rescue
      e ->
        socket =
          socket
          |> put_flash(:error, "Failed to add new day: #{Exception.message(e)}")

        {:noreply, socket}
    end
  end

  def handle_event("remove_itinerary_day", %{"day_index" => day_index}, socket) do
    try do
      day_index = String.to_integer(day_index)
      current_data = socket.assigns.current_itinerary_data

      if day_index >= 0 and day_index < length(current_data) do
        updated_data = List.delete_at(current_data, day_index)

        # Reorder day numbers
        updated_data = Enum.with_index(updated_data)
        |> Enum.map(fn {day, index} ->
          %{day | day_number: index + 1}
        end)

        socket =
          socket
          |> assign(:current_itinerary_data, updated_data)
          |> put_flash(:info, "Day removed successfully!")

        {:noreply, socket}
      else
        socket =
          socket
          |> put_flash(:error, "Invalid day index")

        {:noreply, socket}
      end
    rescue
      e ->
        socket =
          socket
          |> put_flash(:error, "Failed to remove day: #{Exception.message(e)}")

        {:noreply, socket}
    end
  end

  def handle_event("update_itinerary_field", %{"day_index" => day_index, "field" => field, "value" => value}, socket) do
    try do
      day_index = String.to_integer(day_index)
      current_data = socket.assigns.current_itinerary_data

      if day_index >= 0 and day_index < length(current_data) do
        day = Enum.at(current_data, day_index)
        updated_day = Map.put(day, String.to_existing_atom(field), value)

        updated_data = List.replace_at(current_data, day_index, updated_day)

        socket =
          socket
          |> assign(:current_itinerary_data, updated_data)

        {:noreply, socket}
      else
        socket =
          socket
          |> put_flash(:error, "Invalid day index")

        {:noreply, socket}
      end
    rescue
      e ->
        socket =
          socket
          |> put_flash(:error, "Failed to update field: #{Exception.message(e)}")

        {:noreply, socket}
    end
  end



  def handle_event("update_itinerary_content", %{"day_index" => day_index}, socket) do
    try do
      day_index = String.to_integer(day_index)
      current_data = socket.assigns.current_itinerary_data

      if day_index >= 0 and day_index < length(current_data) do
        # Content will be updated via JavaScript to the hidden input
        # This event is just for validation purposes
        {:noreply, socket}
      else
        socket =
          socket
          |> put_flash(:error, "Invalid day index")

        {:noreply, socket}
      end
    rescue
      e ->
        socket =
          socket
          |> put_flash(:error, "Failed to update content: #{Exception.message(e)}")

        {:noreply, socket}
    end
  end

  def handle_event("upload_itinerary_photo", %{"day_index" => day_index}, socket) do
    try do
      day_index = String.to_integer(day_index)
      current_data = socket.assigns.current_itinerary_data

      if day_index >= 0 and day_index < length(current_data) do
        day = Enum.at(current_data, day_index)

        # Process the uploaded photo
        photo_path = case consume_uploaded_entries(socket, :itinerary_photos, fn entry, _socket ->
          uploads_dir = Path.join(File.cwd!(), "priv/static/uploads/itinerary")
          File.mkdir_p!(uploads_dir)

          extension = Path.extname(entry.client_name)
          filename = "itinerary_#{System.system_time()}_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}#{extension}"
          dest_path = Path.join(uploads_dir, filename)

          case File.cp(entry.path, dest_path) do
            :ok ->
              {:ok, "/uploads/itinerary/#{filename}"}
            {:error, reason} ->
              {:error, reason}
          end
        end) do
          [path | _] ->
            path
          [] ->
            nil
        end

        if photo_path do
          # Update the day with the photo path
          updated_day = %{day | day_photo: photo_path}

          updated_data = List.replace_at(current_data, day_index, updated_day)

          socket =
            socket
            |> assign(:current_itinerary_data, updated_data)
            |> put_flash(:info, "Photo uploaded successfully!")

          {:noreply, socket}
        else
          {:noreply, put_flash(socket, :error, "Failed to upload photo")}
        end
      else
        socket =
          socket
          |> put_flash(:error, "Invalid day index")

        {:noreply, socket}
      end
    rescue
      e ->
        socket =
          socket
          |> put_flash(:error, "Failed to upload photo: #{Exception.message(e)}")

        {:noreply, socket}
    end
  end

  def handle_event("remove_itinerary_photo", %{"day_index" => day_index}, socket) do
    try do
      day_index = String.to_integer(day_index)
      current_data = socket.assigns.current_itinerary_data

      if day_index >= 0 and day_index < length(current_data) do
        day = Enum.at(current_data, day_index)
        updated_day = %{day | day_photo: nil}

        updated_data = List.replace_at(current_data, day_index, updated_day)

        socket =
          socket
          |> assign(:current_itinerary_data, updated_data)
          |> put_flash(:info, "Photo removed successfully!")

        {:noreply, socket}
      else
        socket =
          socket
          |> put_flash(:error, "Invalid day index")

        {:noreply, socket}
      end
    rescue
      e ->
        socket =
          socket
          |> put_flash(:error, "Failed to remove photo: #{Exception.message(e)}")

        {:noreply, socket}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    try do
      {:noreply, cancel_upload(socket, :itinerary_photos, ref)}
    rescue
      e ->
        socket =
          socket
          |> put_flash(:error, "Failed to cancel upload: #{Exception.message(e)}")

        {:noreply, socket}
    end
  end



  defp parse_itinerary_params(params) do


    # Parse the form parameters to extract itinerary data
    # The form sends data in a nested structure
    case params do
      %{"days" => days_params} when is_map(days_params) ->

        result = days_params
        |> Map.keys()
        |> Enum.sort()
        |> Enum.filter(fn day_key ->
          day_data = days_params[day_key]
          # Only include days that have at least a title
          day_data && Map.get(day_data, "day_title") && String.trim(day_data["day_title"]) != ""
        end)
        |> Enum.map(fn day_key ->
          day_data = days_params[day_key]
          %{
            "day_number" => String.to_integer(day_data["day_number"] || "1"),
            "day_title" => String.trim(day_data["day_title"] || ""),
            "day_description" => String.trim(day_data["day_description"] || ""),
            "itinerary_content" => String.trim(day_data["itinerary_content"] || ""),
            "day_photo" => day_data["day_photo"] || nil
          }
        end)


        result

      _ ->

        []
    end
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <!-- Header with navigation -->
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center space-x-4">
              <a href={~p"/admin/packages/details/#{@package.id}"} class="text-teal-600 hover:text-teal-700">
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
                href={~p"/admin/packages/details/#{@package.id}"}
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

                  <!-- WYSIWYG Editor for Itinerary Content -->
                  <div class="mb-6">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Itinerary Content</label>
                    <div class="border border-gray-300 rounded-md">
                      <div class="bg-gray-50 px-3 py-2 border-b border-gray-300">
                        <div class="flex items-center space-x-2">
                          <button type="button" class="p-2 hover:bg-gray-200 rounded transition-colors" onclick="formatText('bold')" title="Bold">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 12h8a4 4 0 100-8H6v8zm0 0h8a4 4 0 110 8H6v-8z"/>
                            </svg>
                          </button>
                          <button type="button" class="p-2 hover:bg-gray-200 rounded transition-colors" onclick="formatText('italic')" title="Italic">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"/>
                            </svg>
                          </button>
                          <button type="button" class="p-2 hover:bg-gray-200 rounded transition-colors" onclick="formatText('underline')" title="Underline">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4"/>
                            </svg>
                          </button>
                          <div class="w-px h-6 bg-gray-300"></div>
                          <button type="button" class="p-2 hover:bg-gray-200 rounded transition-colors" onclick="formatText('insertUnorderedList')" title="Bullet List">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>
                            </svg>
                          </button>
                          <button type="button" class="p-2 hover:bg-gray-200 rounded transition-colors" onclick="formatText('insertOrderedList')" title="Numbered List">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
                            </svg>
                          </button>
                          <div class="w-px h-6 bg-gray-300"></div>
                          <button type="button" class="p-2 hover:bg-gray-200 rounded transition-colors" onclick="formatText('justifyLeft')" title="Align Left">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
                            </svg>
                          </button>
                          <button type="button" class="p-2 hover:bg-gray-200 rounded transition-colors" onclick="formatText('justifyCenter')" title="Align Center">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h10M4 18h16"/>
                            </svg>
                          </button>
                          <button type="button" class="p-2 hover:bg-gray-200 rounded transition-colors" onclick="formatText('justifyRight')" title="Align Right">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h6M4 18h16"/>
                            </svg>
                          </button>
                        </div>
                      </div>
                      <div
                        id={"wysiwyg-editor-#{day_index}"}
                        class="min-h-48 p-3 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent prose prose-sm max-w-none"
                        contenteditable="true"
                        phx-blur="update_itinerary_content"
                        phx-value-day_index={day_index}
                        phx-value-content=""
                        data-content={day.itinerary_content}
                        placeholder="Enter your itinerary content here... Use the toolbar above to format your text."
                      ><%= day.itinerary_content %></div>
                    </div>
                    <input
                      type="hidden"
                      name={"itinerary[days][#{day_index}][itinerary_content]"}
                      value={day.itinerary_content}
                      id={"itinerary-content-input-#{day_index}"}
                    />
                  </div>

                  <!-- Day Photo Upload Section -->
                  <div class="mb-4">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Day Photo</label>
                    <%= if day.day_photo do %>
                      <div class="flex items-center space-x-2 mb-2">
                        <img src={day.day_photo} alt="Day Photo" class="w-16 h-16 object-cover rounded border">
                        <div class="flex flex-col space-y-1">
                          <button
                            type="button"
                            phx-click="remove_itinerary_photo"
                            phx-value-day_index={day_index}
                            class="text-red-600 hover:text-red-800 text-xs font-medium"
                          >
                            Remove Photo
                          </button>
                          <span class="text-xs text-gray-500">Current photo</span>
                        </div>
                      </div>
                    <% end %>

                    <!-- Hidden input for photo path -->
                    <input
                      type="hidden"
                      name={"itinerary[days][#{day_index}][day_photo]"}
                      value={day.day_photo || ""}
                    />

                    <!-- Photo upload form -->
                    <form phx-submit="upload_itinerary_photo" class="mt-2">
                      <input type="hidden" name="day_index" value={day_index} />
                      <div class="flex items-center space-x-2">
                        <div class="flex-1">
                          <.live_file_input
                            upload={@uploads.itinerary_photos}
                            accept={~w(.jpg .jpeg .png .gif)}
                            class="block w-full text-xs text-gray-900 border border-gray-300 rounded cursor-pointer bg-gray-50 focus:outline-none file:mr-2 file:py-1 file:px-2 file:rounded file:border-0 file:text-xs file:font-medium file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
                          />
                        </div>
                        <button
                          type="submit"
                          class="px-3 py-1 bg-blue-600 text-white text-xs rounded hover:bg-blue-700 transition-colors"
                        >
                          Upload
                        </button>
                      </div>
                    </form>

                    <!-- Upload preview -->
                    <%= if @uploads.itinerary_photos.entries != [] do %>
                      <div class="mt-2">
                        <%= for entry <- @uploads.itinerary_photos.entries do %>
                          <div class="flex items-center space-x-2 p-2 bg-gray-50 rounded text-xs">
                            <div class="w-8 h-8 bg-gray-200 rounded flex items-center justify-center overflow-hidden">
                              <%= if entry.upload_state == :complete do %>
                                <img src={entry.url} alt="Preview" class="w-full h-full object-cover" />
                              <% else %>
                                <span class="text-gray-500">P</span>
                              <% end %>
                            </div>
                            <div class="flex-1 min-w-0">
                              <p class="font-medium text-gray-900 truncate"><%= entry.client_name %></p>
                              <p class="text-gray-500">
                                <%= case entry.upload_state do %>
                                  <% :uploading -> %>
                                    Uploading...
                                  <% :complete -> %>
                                    Ready
                                  <% :error -> %>
                                    Error: <%= entry.errors |> Enum.map(&elem(&1, 1)) |> Enum.join(", ") %>
                                  <% _ -> %>
                                    Ready
                                <% end %>
                              </p>
                            </div>
                            <button
                              type="button"
                              phx-click="cancel_upload"
                              phx-value-ref={entry.ref}
                              class="text-red-600 hover:text-red-800"
                            >
                              ×
                            </button>
                          </div>
                        <% end %>
                      </div>
                    <% end %>

                    <!-- Upload errors -->
                    <%= for err <- upload_errors(@uploads.itinerary_photos) do %>
                      <p class="text-red-600 text-xs mt-2"><%= Phoenix.Naming.humanize(err) %></p>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>

            <div class="flex items-center justify-between pt-6 border-t border-gray-200">
              <button
                type="button"
                phx-click="add_itinerary_day"
                class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors"
                onclick="console.log('Add New Day button clicked');"
              >
                Add New Day
              </button>

              <div class="flex space-x-3">
                <a
                  href={~p"/admin/packages/details/#{@package.id}"}
                  class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </a>
                <button
                  type="submit"
                  class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                  onclick="console.log('Save Itinerary button clicked');"
                >
                  Save Itinerary
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>

      <script>
        function formatText(command) {
          document.execCommand(command, false, null);
        }

        // Initialize WYSIWYG editors
        document.addEventListener('DOMContentLoaded', function() {
          const editors = document.querySelectorAll('[id^="wysiwyg-editor-"]');

          editors.forEach(function(editor) {
            const dayIndex = editor.id.replace('wysiwyg-editor-', '');
            const hiddenInput = document.getElementById('itinerary-content-input-' + dayIndex);

            // Set initial content
            if (hiddenInput && hiddenInput.value) {
              editor.innerHTML = hiddenInput.value;
            }

            // Update hidden input on content change
            editor.addEventListener('input', function() {
              if (hiddenInput) {
                hiddenInput.value = editor.innerHTML;
              }
            });

            // Update hidden input on blur
            editor.addEventListener('blur', function() {
              if (hiddenInput) {
                hiddenInput.value = editor.innerHTML;
              }
            });
          });
        });

        // Handle form submission to sync content
        document.addEventListener('submit', function(event) {
          if (event.target.matches('form[phx-submit="save_itinerary"]')) {
            const editors = document.querySelectorAll('[id^="wysiwyg-editor-"]');

            editors.forEach(function(editor) {
              const dayIndex = editor.id.replace('wysiwyg-editor-', '');
              const hiddenInput = document.getElementById('itinerary-content-input-' + dayIndex);

              if (hiddenInput) {
                hiddenInput.value = editor.innerHTML;
              }
            });
          }
        });

        // Handle LiveView blur events
        document.addEventListener('phx:blur', function(event) {
          if (event.target.matches('[id^="wysiwyg-editor-"]')) {
            const dayIndex = event.target.id.replace('wysiwyg-editor-', '');
            const content = event.target.innerHTML;

            // Update the hidden input
            const hiddenInput = document.getElementById('itinerary-content-input-' + dayIndex);
            if (hiddenInput) {
              hiddenInput.value = content;
            }
          }
        });
      </script>

      <style>
        [contenteditable="true"]:empty:before {
          content: attr(placeholder);
          color: #9ca3af;
          pointer-events: none;
        }

        [contenteditable="true"]:focus {
          outline: none;
        }

        .prose {
          line-height: 1.6;
        }

        .prose p {
          margin-bottom: 0.75rem;
        }

        .prose ul, .prose ol {
          margin-bottom: 0.75rem;
          padding-left: 1.5rem;
        }

        .prose li {
          margin-bottom: 0.25rem;
        }

        .prose h1, .prose h2, .prose h3, .prose h4, .prose h5, .prose h6 {
          margin-top: 1.5rem;
          margin-bottom: 0.75rem;
          font-weight: 600;
        }
      </style>
    </.admin_layout>
    """
  end
end
