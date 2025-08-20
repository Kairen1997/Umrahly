defmodule UmrahlyWeb.AdminProfileLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Accounts

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(:current_page, "profile")
      |> assign(:has_profile, true)
      |> assign(:profile, current_user)
      |> assign(:is_admin, true)
      |> assign(:changeset, Accounts.change_user_profile(current_user))
      |> allow_upload(:profile_photo,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 1,
        max_file_size: 5_000_000
      )

    {:ok, socket}
  end

  def handle_event("save-profile", %{"profile" => profile_params}, socket) do
    current_user = socket.assigns.current_user

    case Accounts.update_user_profile(current_user, profile_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:profile, updated_user)
         |> put_flash(:info, "Profile updated successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> put_flash(:error, "Failed to update profile. Please check the form and try again.")}
    end
  end

  def handle_event("save-identity-contact", %{"profile" => profile_params}, socket) do
    current_user = socket.assigns.current_user

    case Accounts.update_user_profile(current_user, profile_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:profile, updated_user)
         |> put_flash(:info, "Identity and contact information updated successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> put_flash(:error, "Failed to update identity and contact information. Please check the form and try again.")}
    end
  end

  def handle_event("save-photo", %{"profile" => profile_params}, socket) do
    current_user = socket.assigns.current_user

    case consume_uploaded_entries(socket, :profile_photo, fn entry, _socket ->
      uploads_dir = Path.join(File.cwd!(), "priv/static/uploads")
      File.mkdir_p!(uploads_dir)

      extension = Path.extname(entry.client_name)
      filename = "profile_#{current_user.id}_#{System.system_time()}#{extension}"
      dest_path = Path.join(uploads_dir, filename)

      case File.cp(entry.path, dest_path) do
        :ok ->
          {:ok, "/uploads/#{filename}"}
        {:error, reason} ->
          {:error, reason}
      end
    end) do
      [path | _] ->
        profile_attrs = Map.put(profile_params, "profile_photo", path)

        case Accounts.update_user_profile(current_user, profile_attrs) do
          {:ok, updated_user} ->
            {:noreply,
             socket
             |> assign(:profile, updated_user)
             |> put_flash(:info, "Profile photo uploaded successfully!")}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:changeset, changeset)
             |> put_flash(:error, "Failed to save profile: #{inspect(changeset.errors)}")}
        end

      [] ->
        {:noreply, put_flash(socket, :error, "No file uploaded")}
    end
  end

  def handle_event("remove-photo", _params, socket) do
    current_user = socket.assigns.current_user

    case Accounts.update_user_profile(current_user, %{profile_photo: nil}) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:profile, updated_user)
         |> put_flash(:info, "Profile photo removed successfully!")}

      {:error, _changeset} ->
        {:noreply, socket |> put_flash(:error, "Failed to remove profile photo")}
    end
  end

  def handle_event("validate-identity-contact", %{"profile" => profile_params}, socket) do
    socket = case profile_params do
      %{"identity_card_number" => id_num, "phone_number" => phone, "address" => addr, "monthly_income" => income, "gender" => gender, "birthdate" => birthdate} ->
        cond do
          id_num == "" and phone == "" and addr == "" and income == "" and gender == "" and birthdate == "" ->
            put_flash(socket, :warning, "Please fill in at least one field")
          true ->
            socket
        end
      _ ->
        socket
    end
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :profile_photo, ref)}
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-4xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Admin Profile Settings</h1>
            <p class="text-gray-600 mt-2">Manage your personal information and account settings</p>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <!-- Profile Photo Section -->
            <div class="lg:col-span-1">
              <div class="bg-gray-50 rounded-lg p-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-4">Profile Photo</h3>

                <%= if @profile.profile_photo do %>
                  <div class="mb-4">
                    <img src={@profile.profile_photo} alt="Profile Photo" class="w-32 h-32 rounded-full object-cover mx-auto border-4 border-white shadow-lg" />
                  </div>
                  <button
                    phx-click="remove-photo"
                    class="w-full bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors"
                  >
                    Remove Photo
                  </button>
                <% else %>
                  <div class="mb-4">
                    <div class="w-32 h-32 rounded-full bg-gray-200 flex items-center justify-center mx-auto border-4 border-white shadow-lg">
                      <svg class="w-16 h-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                      </svg>
                    </div>
                  </div>
                <% end %>

                <form phx-submit="save-photo" phx-change="validate" class="space-y-4">
                  <div class="mt-4">
                    <label class="block text-sm font-medium text-gray-700 mb-2">Upload New Photo</label>
                    <div class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md" phx-drop-target={@uploads.profile_photo.ref}>
                      <div class="space-y-1 text-center">
                        <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48" aria-hidden="true">
                          <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                        </svg>
                        <div class="flex text-sm text-gray-600">
                          <label class="relative cursor-pointer bg-white rounded-md font-medium text-teal-600 hover:text-teal-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-teal-500 px-3 py-1 rounded border border-teal-300 hover:bg-teal-50 transition-colors">
                            <span>Upload a file</span>
                            <.live_file_input upload={@uploads.profile_photo} accept="image/*" class="hidden" />
                          </label>
                          <p class="pl-1">or drag and drop</p>
                        </div>
                        <p class="text-xs text-gray-500">PNG, JPG up to 5MB</p>
                      </div>
                    </div>
                    <div class="mt-2">
                      <%= for entry <- @uploads.profile_photo.entries do %>
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
                    </div>
                    <button
                      type="submit"
                      class="w-full mt-4 bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors"
                    >
                      Save Photo
                    </button>
                  </div>
                </form>
              </div>
            </div>

            <!-- Profile Information Section -->
            <div class="lg:col-span-2">
              <div class="space-y-6">
                <!-- Basic Information -->
                <div class="bg-gray-50 rounded-lg p-6">
                  <h3 class="text-lg font-semibold text-gray-900 mb-4">Basic Information</h3>
                  <form phx-submit="save-profile" class="space-y-4">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                        <input
                          type="text"
                          name="profile[full_name]"
                          value={@profile.full_name || ""}
                          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                          placeholder="Enter your full name"
                        />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
                        <input
                          type="email"
                          value={@current_user.email}
                          disabled
                          class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100 text-gray-500 cursor-not-allowed"
                        />
                        <p class="text-xs text-gray-500 mt-1">Email cannot be changed</p>
                      </div>
                    </div>
                    <div class="flex justify-end">
                      <button
                        type="submit"
                        class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors"
                      >
                        Save Basic Info
                      </button>
                    </div>
                  </form>
                </div>

                <!-- Identity and Contact Information -->
                <div class="bg-gray-50 rounded-lg p-6">
                  <h3 class="text-lg font-semibold text-gray-900 mb-4">Identity & Contact Information</h3>
                  <form phx-submit="save-identity-contact" phx-change="validate-identity-contact" class="space-y-4">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Identity Card Number</label>
                        <input
                          type="text"
                          name="profile[identity_card_number]"
                          value={@profile.identity_card_number || ""}
                          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                          placeholder="Enter IC number"
                        />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Phone Number</label>
                        <input
                          type="tel"
                          name="profile[phone_number]"
                          value={@profile.phone_number || ""}
                          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                          placeholder="Enter phone number"
                        />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Monthly Income (RM)</label>
                        <input
                          type="number"
                          name="profile[monthly_income]"
                          value={@profile.monthly_income || ""}
                          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                          placeholder="Enter monthly income"
                        />
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Gender</label>
                        <select
                          name="profile[gender]"
                          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                        >
                          <option value="">Select gender</option>
                          <option value="male" selected={@profile.gender == "male"}>Male</option>
                          <option value="female" selected={@profile.gender == "female"}>Female</option>
                        </select>
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Birth Date</label>
                        <input
                          type="date"
                          name="profile[birthdate]"
                          value={@profile.birthdate || ""}
                          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                        />
                      </div>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">Address</label>
                      <textarea
                        name="profile[address]"
                        rows="3"
                        class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                        placeholder="Enter your address"
                      ><%= @profile.address || "" %></textarea>
                    </div>
                    <div class="flex justify-end">
                      <button
                        type="submit"
                        class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors"
                      >
                        Save Contact Info
                      </button>
                    </div>
                  </form>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
