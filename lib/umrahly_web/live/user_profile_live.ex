defmodule UmrahlyWeb.UserProfileLive do
  use UmrahlyWeb, :live_view

  alias Umrahly.Accounts
  alias Umrahly.Profiles

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    profile = Profiles.get_profile_by_user_id(user.id)

    socket = assign(socket,
      user: user,
      profile: profile,
      page_title: "Profile"
    )

    socket = allow_upload(socket, :profile_photo,
      accept: ~w(.jpg .jpeg .png .gif),
      max_entries: 1,
      max_file_size: 10_000_000,
      chunk_size: 64_000
    )

    {:ok, socket}
  end

  def handle_event("save-profile", %{"profile" => profile_params}, socket) do
    user = socket.assigns.user
    profile = socket.assigns.profile

    # Extract user fields from profile params
    user_attrs = %{
      "full_name" => profile_params["full_name"]
    }

    # Extract profile fields, excluding user fields
    profile_attrs = Map.drop(profile_params, ["full_name"])
    profile_attrs = Map.put(profile_attrs, :user_id, user.id)

    # Update both user and profile
    with {:ok, updated_user} <- Accounts.update_user(user, user_attrs),
         {:ok, updated_profile} <- Profiles.upsert_profile(profile, profile_attrs) do

      {:noreply,
       socket
       |> assign(user: updated_user, profile: updated_profile)
       |> put_flash(:info, "Profile updated successfully")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, profile_changeset: changeset)}
    end
  end

  def handle_event("change-password", %{"user" => user_params}, socket) do
    user = socket.assigns.user
    current_password = user_params["current_password"]
    new_password = user_params["password"]

    case Accounts.update_user_password(user, current_password, %{password: new_password}) do
      {:ok, _updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password changed successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, password_changeset: changeset)}
    end
  end

  def handle_event("upload-photo", params, socket) do
    IO.inspect(params, label: "upload-photo params")
    IO.inspect(socket.assigns.uploads.profile_photo, label: "uploads state in upload-photo")

    user = socket.assigns.user
    profile = socket.assigns.profile

    if is_nil(profile) do
      {:noreply,
       socket
       |> put_flash(:error, "Profile not found. Please complete your profile first.")}
    else
      case handle_upload(socket.assigns.uploads.profile_photo, user, profile) do
        {:ok, updated_profile} ->
          {:noreply,
           socket
           |> assign(profile: updated_profile)
           |> put_flash(:info, "Profile photo uploaded successfully")}

        {:error, message} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to upload photo: #{message}")}
      end
    end
  end



  def handle_event("remove-photo", _params, socket) do
    profile = socket.assigns.profile

    case Profiles.update_profile(profile, %{profile_photo: nil}) do
      {:ok, updated_profile} ->
        {:noreply,
         socket
         |> assign(profile: updated_profile)
         |> put_flash(:info, "Profile photo removed successfully")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to remove profile photo")}
    end
  end

  def handle_event("validate-photo", params, socket) do
    IO.inspect(params, label: "validate-photo params")
    IO.inspect(socket.assigns.uploads.profile_photo, label: "uploads state in validate-photo")
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :profile_photo, ref)}
  end

  @spec handle_upload(Phoenix.LiveView.UploadConfig.t(), map(), map()) :: {:ok, map()} | {:error, String.t()}
    def handle_upload(uploads, user, profile) do
    case uploads.entries do
      [entry] ->
        # Create uploads directory if it doesn't exist
        uploads_dir = Path.join(:code.priv_dir(:umrahly), "static/uploads")
        File.mkdir_p!(uploads_dir)

        # Generate unique filename
        extension = Path.extname(entry.client_name)
        filename = "#{user.id}_#{System.system_time()}#{extension}"
        filepath = Path.join(uploads_dir, filename)

        # Copy uploaded file to uploads directory
        case File.cp(entry.path, filepath) do
          :ok ->
            # Update profile with new photo path
            photo_path = "/uploads/#{filename}"
            case Profiles.update_profile(profile, %{profile_photo: photo_path}) do
              {:ok, updated_profile} ->
                {:ok, updated_profile}
              {:error, changeset} ->
                {:error, "Failed to update profile: #{inspect(changeset.errors)}"}
            end

          {:error, reason} ->
            {:error, "Failed to save file: #{reason}"}
        end

      [] ->
        {:error, "No file selected"}
      _ ->
        {:error, "Please select only one file"}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-100">
      <!-- Sidebar -->
      <aside class="w-96 bg-gray-800 shadow-lg h-screen flex flex-col justify-between">
        <!-- Navigation Menu -->
        <div>
          <nav class="mt-0">
            <div class="px-4 space-y-2">
              <!-- Dashboard -->
              <a href="/dashboard" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z"/>
                </svg>
                Dashboard
              </a>

              <!-- My Bookings -->
              <a href="/bookings" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
                My Bookings
              </a>
              <div class="ml-8 space-y-1">
                <a href="/bookings/details" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• Booking Details</a>
              </div>

              <!-- Packages -->
              <a href="/packages" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                </svg>
                Packages
              </a>
              <div class="ml-8 space-y-1">
                <a href="/packages/details" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• View Details</a>
              </div>

              <!-- Payments -->
              <a href="/payments" class="flex items-center px-4 py-3 text-gray-300 hover:bg-gray-700 hover:text-white rounded-md transition-colors duration-200">
                <svg class="h-5 w-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"/>
                </svg>
                Payments
              </a>
              <div class="ml-8 space-y-1">
                <a href="/payments/installment" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• Installment Payment Plan</a>
                <a href="/payments/history" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• Payment History</a>
                <a href="/payments/receipts" class="block px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors duration-200">• Receipts</a>
              </div>
            </div>
          </nav>
        </div>
      </aside>

      <!-- Main Content -->
      <div class="flex-1 flex flex-col">
        <!-- Content Header -->
        <div class="bg-white border-b border-gray-200">
          <div class="px-6 py-4">
            <h1 class="text-2xl font-semibold text-gray-900">
              Profile
            </h1>
          </div>
        </div>

        <!-- Page Content -->
        <main class="flex-1 bg-gray-50 p-6 overflow-auto">
          <div class="max-w-6xl mx-auto">
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">

              <!-- Left Column - Forms -->
              <div class="lg:col-span-2 space-y-8">

                <!-- Personal Information -->
                <div class="bg-white rounded-lg shadow p-6">
                  <h3 class="text-lg font-semibold text-gray-900 mb-4">Personal Information</h3>
                  <form phx-submit="save-profile" class="space-y-4">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                        <input type="text" name="profile[full_name]" value={@user.full_name} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Name" />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
                        <input type="email" value={@user.email} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50" placeholder="Email Read Only" disabled />
                      </div>
                    </div>
                  </form>
                </div>

                <!-- Change Password -->
                <div class="bg-white rounded-lg shadow p-6">
                  <h3 class="text-lg font-semibold text-gray-900 mb-4">Change Password</h3>
                  <form phx-submit="change-password" class="space-y-4">
                    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Current Password</label>
                        <input type="password" name="user[current_password]" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Current password" required />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">New Password</label>
                        <input type="password" name="user[password]" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="New Password" required />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Confirm Password</label>
                        <input type="password" name="user[password_confirmation]" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Confirm Password" required />
                      </div>
                    </div>
                    <div class="pt-4">
                      <button type="submit" class="bg-teal-600 text-white px-6 py-3 rounded-lg hover:bg-teal-700 transition-colors">
                        Change Password
                      </button>
                    </div>
                  </form>
                </div>

                <!-- Identity and Contact Information -->
                <div class="bg-white rounded-lg shadow p-6">
                  <h3 class="text-lg font-semibold text-gray-900 mb-4">Identity and Contact Information</h3>
                  <form phx-submit="save-profile" class="space-y-4">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Identity Card Number</label>
                        <input type="text" name="profile[identity_card_number]" value={@profile && @profile.identity_card_number} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Identity Card Number" />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Phone Number</label>
                        <input type="text" name="profile[phone_number]" value={@profile && @profile.phone_number} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Phone Number" />
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">Address</label>
                      <textarea name="profile[address]" rows="3" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter full address">{@profile && @profile.address}</textarea>
                    </div>
                    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Monthly Income</label>
                        <input type="number" name="profile[monthly_income]" value={@profile && @profile.monthly_income} step="0.01" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Monthly Income" />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Gender</label>
                        <select name="profile[gender]" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent">
                          <option value="">Select Gender</option>
                          <option value="male" selected={@profile && @profile.gender == "male"}>Male</option>
                          <option value="female" selected={@profile && @profile.gender == "female"}>Female</option>
                        </select>
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Birthdate</label>
                        <input type="date" name="profile[birthdate]" value={@profile && @profile.birthdate} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" />
                      </div>
                    </div>
                    <div class="pt-4">
                      <button type="submit" class="bg-teal-600 text-white px-6 py-3 rounded-lg hover:bg-teal-700 transition-colors">
                        Save Profile
                      </button>
                    </div>
                  </form>
                </div>
              </div>

              <!-- Right Column - Profile Photo -->
              <div class="lg:col-span-1">
                <div class="bg-white rounded-lg shadow p-6">
                  <h3 class="text-lg font-semibold text-gray-900 mb-4">Profile Picture</h3>
                  <div class="space-y-4">
                    <!-- Profile Photo Display -->
                    <div class="text-center">
                      <%= if @profile && @profile.profile_photo do %>
                        <div class="relative inline-block">
                          <img src={@profile.profile_photo} alt="Profile Photo" class="w-32 h-32 rounded-full object-cover border-4 border-teal-200 shadow-lg" />
                          <button phx-click="remove-photo" class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center hover:bg-red-600 transition-colors">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                            </svg>
                          </button>
                        </div>
                      <% else %>
                        <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center bg-gray-50">
                          <div class="text-gray-500">
                            <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                              <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                            </svg>
                            <p class="mt-2 text-sm">No Profile Photo</p>
                          </div>
                        </div>
                      <% end %>
                    </div>

                    <!-- Upload Form -->
                    <form phx-submit="upload-photo" phx-upload class="space-y-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Select Photo</label>
                        <div class="space-y-2">
                          <div class="flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-lg">
                            <div class="space-y-1 text-center">
                              <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                                <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                              </svg>
                              <div class="flex text-sm text-gray-600">
                                <label for={@uploads.profile_photo.ref} class="relative cursor-pointer bg-white rounded-md font-medium text-teal-600 hover:text-teal-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-teal-500">
                                  <span>Upload a file</span>
                                  <input id={@uploads.profile_photo.ref} type="file" class="sr-only" accept=".jpg,.jpeg,.png,.gif" phx-upload phx-hook="FileUploadHook" />
                                </label>
                                <p class="pl-1">or drag and drop</p>
                              </div>
                              <p class="text-xs text-gray-500">PNG, JPG, GIF up to 10MB</p>
                            </div>
                          </div>

                          <%= for entry <- @uploads.profile_photo.entries do %>
                            <div class="flex items-center space-x-2 p-2 bg-gray-50 rounded-lg">
                              <div class="flex-shrink-0">
                                <div class="w-8 h-8 bg-teal-100 rounded flex items-center justify-center">
                                  <svg class="w-4 h-4 text-teal-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                                  </svg>
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
                              <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-red-500 hover:text-red-700">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                                </svg>
                              </button>
                            </div>
                          <% end %>
                        </div>
                      </div>
                      <button type="submit" class="w-full bg-teal-600 text-white px-6 py-3 rounded-lg hover:bg-teal-700 transition-colors" disabled={Enum.empty?(@uploads.profile_photo.entries)}>
                        Upload Profile Photo
                      </button>
                    </form>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
    """
  end
end
