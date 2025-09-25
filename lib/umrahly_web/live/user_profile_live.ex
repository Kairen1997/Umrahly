defmodule UmrahlyWeb.UserProfileLive do
  use UmrahlyWeb, :live_view

  alias Umrahly.Accounts
  alias Umrahly.Profiles
  import UmrahlyWeb.SidebarComponent

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    profile = Profiles.get_profile_by_user_id(user.id)

    socket = assign(socket,
      user: user,
      profile: profile,
      page_title: "Profile",
      last_updated: nil
    )
    socket = if is_nil(profile) do
      put_flash(socket, :error, "Please complete your profile first. Some features may not be available.")
    else
      socket
    end

    socket =
      socket
      |> assign(:profile, profile)
      |> assign(:changeset, Profiles.change_profile(profile))
      |> allow_upload(:profile_photo,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 1,
        max_file_size: 5_000_000,
        auto_upload: true
      )

    {:ok, socket}
  end

  def handle_event("save-profile", %{"profile" => profile_params}, socket) do
    user = socket.assigns.user

    # Start with a clean map using only string keys from the form
    profile_attrs = %{
      "identity_card_number" => profile_params["identity_card_number"],
      "phone_number" => profile_params["phone_number"],
      "address" => profile_params["address"],
      "monthly_income" => profile_params["monthly_income"],
      "gender" => profile_params["gender"],
      "birthdate" => profile_params["birthdate"],
      "passport_number" => profile_params["passport_number"],
      "poskod" => profile_params["poskod"],
      "city" => profile_params["city"],
      "state" => profile_params["state"],
      "citizenship" => profile_params["citizenship"],
      "emergency_contact_name" => profile_params["emergency_contact_name"],
      "emergency_contact_phone" => profile_params["emergency_contact_phone"],
      "emergency_contact_relationship" => profile_params["emergency_contact_relationship"],
      "full_name" => profile_params["full_name"]
    }

    # Clean up empty strings to nil
    profile_attrs = profile_attrs
    |> Map.update("identity_card_number", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("phone_number", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("address", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("monthly_income", nil, &if(&1 == "" or is_nil(&1), do: nil, else: &1))
    |> Map.update("gender", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("birthdate", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("passport_number", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("poskod", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("city", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("state", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("citizenship", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("emergency_contact_name", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("emergency_contact_phone", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("emergency_contact_relationship", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))

    # Convert monthly_income to integer if it's a string
    profile_attrs = case profile_attrs["monthly_income"] do
      income when is_binary(income) and income != "" ->
        case Integer.parse(income) do
          {int, _} -> Map.put(profile_attrs, "monthly_income", int)
          :error -> Map.put(profile_attrs, "monthly_income", nil)
        end
      income when is_integer(income) -> profile_attrs
      _ -> Map.put(profile_attrs, "monthly_income", nil)
    end

    # Convert birthdate to Date if it's a string
    profile_attrs = case profile_attrs["birthdate"] do
      date when is_binary(date) and date != "" ->
        case Date.from_iso8601(date) do
          {:ok, parsed_date} -> Map.put(profile_attrs, "birthdate", parsed_date)
          {:error, _} -> Map.put(profile_attrs, "birthdate", nil)
        end
      date when is_struct(date, Date) -> profile_attrs
      _ -> Map.put(profile_attrs, "birthdate", nil)
    end

    # Check if at least one field has a value (for new profiles)
    has_profile = user.address != nil or user.identity_card_number != nil or user.phone_number != nil or
                  user.monthly_income != nil or user.birthdate != nil or user.gender != nil or
                  user.passport_number != nil or user.poskod != nil or user.city != nil or
                  user.state != nil or user.citizenship != nil or user.emergency_contact_name != nil or
                  user.emergency_contact_phone != nil or user.emergency_contact_relationship != nil

    if not has_profile do
      has_values = profile_attrs
      |> Map.take(["identity_card_number", "phone_number", "address", "monthly_income", "gender", "birthdate", "passport_number", "poskod", "city", "state", "citizenship", "emergency_contact_name", "emergency_contact_phone", "emergency_contact_relationship"])
      |> Map.values()
      |> Enum.any?(&(&1 != nil))

      if not has_values do
        {:noreply,
         socket
         |> put_flash(:error, "Please fill in at least one field to create your profile.")}
      else
        continue_profile_update(socket, profile_attrs)
      end
    else
      continue_profile_update(socket, profile_attrs)
    end
  end

  def handle_event("save-personal-info", %{"profile" => profile_params}, socket) do
    user = socket.assigns.user

    # Extract user fields from profile params
    user_attrs = %{
      "full_name" => profile_params["full_name"]
    }

    # Update user
    case Accounts.update_user(user, user_attrs) do
      {:ok, updated_user} ->
        _ = Umrahly.ActivityLogs.log_user_action(user.id, "Personal Info Updated", nil, %{})

        {:noreply,
         socket
         |> assign(user: updated_user, last_updated: DateTime.utc_now())
         |> put_flash(:info, "Personal information updated successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(user_changeset: changeset)
         |> put_flash(:error, "Failed to update personal information. Please check the form and try again.")}
    end
  end


  def handle_event("validate", _params, socket) do
    # Check if there are any uploads in progress
    upload_status = if length(socket.assigns.uploads.profile_photo.entries) > 0 do
      :uploading
    else
      :idle
    end

    # If there are entries, also trigger the upload processing
    socket = if length(socket.assigns.uploads.profile_photo.entries) > 0 do
      # Process the upload immediately
      handle_event("upload-photo", %{}, assign(socket, upload_status: :uploading))
    else
      assign(socket, upload_status: upload_status)
    end

    socket
  end

  def handle_event("phx:file-upload", %{"ref" => _ref}, socket) do
    # This gets called when auto_upload completes
    {:noreply, put_flash(socket, :info, "File uploaded, processing...")}
  end

  def handle_event("upload-photo", _params, socket) do
    user = socket.assigns.user
    profile = socket.assigns.profile

    if is_nil(profile) do
      {:noreply, put_flash(socket, :error, "Profile not found. Please complete your profile first.")}
    else
      uploaded_files =
        consume_uploaded_entries(socket, :profile_photo, fn %{path: path}, entry ->
          uploads_dir = Path.join(File.cwd!(), "priv/static/images")
          File.mkdir_p!(uploads_dir)

          extension = Path.extname(entry.client_name)
          filename = "profile_#{user.id}_#{System.system_time()}#{extension}"
          dest_path = Path.join(uploads_dir, filename)

          _ = Umrahly.ActivityLogs.log_user_action(user.id, "Profile Photo Uploaded", filename, %{filename: filename})

          case File.cp(path, dest_path) do
            :ok ->
              {:ok, "/images/#{filename}"}

            {:error, reason} ->
              {:error, reason}
          end
        end)
        |> Enum.map(fn
          {:ok, path} -> path
          path when is_binary(path) -> path
          _ -> nil
        end)
        |> Enum.filter(& &1)

      case uploaded_files do
        [photo_path | _] ->
          case Profiles.update_profile(profile, %{profile_photo: photo_path}) do
            {:ok, updated_profile} ->
              updated_profile =
                Map.update!(updated_profile, :profile_photo, fn path ->
                  path <> "?v=#{DateTime.to_unix(DateTime.utc_now())}"
                end)

              {:noreply,
               socket
               |> assign(profile: updated_profile)
               |> put_flash(:info, "Profile photo uploaded successfully!")}

            {:error, changeset} ->
              {:noreply,
               socket
               |> put_flash(:error, "Failed to save profile: #{inspect(changeset.errors)}")}
          end

        [] ->
          {:noreply,
           socket
           |> put_flash(:error, "No file uploaded")}
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
        {:noreply, socket |> put_flash(:error, "Failed to remove profile photo")}
    end
  end

  def handle_event("validate-identity-contact", %{"profile" => profile_params}, socket) do
    socket = case profile_params do
      %{"identity_card_number" => id_num, "phone_number" => phone, "address" => addr, "monthly_income" => income, "gender" => gender, "birthdate" => birthdate, "passport_number" => passport, "poskod" => poskod, "city" => city, "state" => state, "citizenship" => citizenship, "emergency_contact_name" => ec_name, "emergency_contact_phone" => ec_phone, "emergency_contact_relationship" => ec_rel} ->
        cond do
          id_num == "" and phone == "" and addr == "" and income == "" and gender == "" and birthdate == "" and passport == "" and poskod == "" and city == "" and state == "" and citizenship == "" and ec_name == "" and ec_phone == "" and ec_rel == "" ->
            put_flash(socket, :warning, "Please fill in at least one field")
          true ->
            socket
        end
      _ ->
        socket
    end
    {:noreply, socket}
  end
  def handle_event("validate-photo", _params, socket) do

    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :profile_photo, ref)}
  end



  # Private functions
  defp continue_profile_update(socket, profile_attrs) do
    profile = socket.assigns.profile
    user = socket.assigns.user

    # Extract user fields from profile_attrs if they exist
    user_attrs = %{
      "full_name" => profile_attrs["full_name"]
    }

    # Update both user and profile
    with {:ok, updated_user} <- Accounts.update_user(user, user_attrs),
         {:ok, updated_profile} <- Profiles.upsert_profile(profile, profile_attrs) do

      # Determine if this is a new profile or an update
      message = if is_nil(profile) do
        "Profile created successfully! Welcome to Umrahly!"
      else
        "Profile information updated successfully!"
      end

      _ = Umrahly.ActivityLogs.log_user_action(user.id, if(is_nil(profile), do: "Profile Created", else: "Profile Updated"), nil, %{section: "identity_contact"})

      {:noreply,
       socket
       |> assign(user: updated_user, profile: updated_profile, last_updated: DateTime.utc_now())
       |> put_flash(:info, message)}

    else
      {:error, %Ecto.Changeset{} = changeset} ->
        # Create a more informative error message
        error_message = case changeset.errors do
          [] -> "Failed to update profile information. Please check the form and try again."
          errors ->
            error_details = errors
            |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
            |> Enum.join(", ")
            "Validation errors: #{error_details}"
        end

        {:noreply,
         socket
         |> assign(profile_changeset: changeset)
         |> put_flash(:error, error_message)}
    end
  end



  def render(assigns) do
    ~H"""
    <.sidebar page_title="Profile" profile={@profile}>
      <!-- Profile Completion Guidance -->
      <%= if is_nil(@profile) do %>
        <div class="mb-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-yellow-800">Profile Incomplete</h3>
              <div class="mt-2 text-sm text-yellow-700">
                <p>You need to complete your profile to access all features. Please fill out the forms below or complete your profile first.</p>
              </div>
              <div class="mt-4">
                <.link href={~p"/complete-profile"} class="bg-yellow-100 text-yellow-800 px-4 py-2 rounded-md text-sm font-medium hover:bg-yellow-200 transition-colors">
                  Complete Profile
                </.link>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Profile Picture Section - Keep the resume format for this section -->
      <div class="bg-gradient-to-r from-teal-600 to-teal-800 rounded-lg shadow-lg p-8 mb-6 text-white">
        <div class="flex flex-col md:flex-row items-center md:items-start space-y-6 md:space-y-0 md:space-x-8">
          <!-- Profile Photo -->
          <div class="flex-shrink-0">
            <%= if @profile && @profile.profile_photo do %>
              <div class="relative">
                <img src={@profile.profile_photo} alt="Profile Photo" class="w-32 h-32 rounded-full object-cover border-4 border-white shadow-xl" />
                <button phx-click="remove-photo" class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-8 h-8 flex items-center justify-center hover:bg-red-600 transition-colors shadow-lg">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            <% else %>
              <div class="w-32 h-32 rounded-full bg-white bg-opacity-20 flex items-center justify-center border-4 border-white">
                <svg class="w-16 h-16 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
              </div>
            <% end %>
          </div>

          <!-- Basic Information -->
          <div class="flex-1 text-center md:text-left">
            <h1 class="text-3xl font-bold mb-2"><%= @user.full_name || "Your Name" %></h1>
            <p class="text-teal-100 text-lg mb-4"><%= @user.email %></p>

            <!-- Contact Information -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <%= if @profile && @profile.phone_number do %>
                <div class="flex items-center justify-center md:justify-start space-x-2">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                  </svg>
                  <span><%= @profile.phone_number %></span>
                </div>
              <% end %>

              <%= if @profile && @profile.address do %>
                <div class="flex items-center justify-center md:justify-start space-x-2">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                  <span><%= @profile.city %><%= if @profile.state, do: ", #{@profile.state}" %></span>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Upload Photo Button -->
          <div class="flex-shrink-0">
            <form id="upload-photo-form" phx-submit="upload-photo" class="space-y-2">
              <div class="text-center">
                <label class="cursor-pointer bg-white bg-opacity-20 hover:bg-opacity-30 text-white px-4 py-2 rounded-lg transition-colors inline-flex items-center space-x-2">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                  </svg>
                  <span>Upload Photo</span>
                  <.live_file_input upload={@uploads.profile_photo} class="sr-only" accept=".jpg,.jpeg,.png" />
                </label>
              </div>

              <!-- File progress display -->
              <%= for entry <- @uploads.profile_photo.entries do %>
                <div class="bg-white bg-opacity-20 rounded-lg p-2 text-xs">
                  <div class="flex items-center justify-between">
                    <span class="truncate"><%= entry.client_name %></span>
                    <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-red-300 hover:text-red-100">
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                  <div class="mt-1 h-1 bg-white bg-opacity-30 rounded">
                    <div class={"h-1 bg-white rounded transition-all"} style={"width: #{entry.progress}%;"}></div>
                  </div>
                </div>
              <% end %>

              <!-- Error messages -->
              <%= for err <- upload_errors(@uploads.profile_photo) do %>
                <p class="text-red-200 text-xs"><%= Phoenix.Naming.humanize(err) %></p>
              <% end %>
            </form>
          </div>
        </div>
      </div>

      <!-- Single Form for All Profile Information -->
      <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center justify-between mb-6">
          <h3 class="text-lg font-semibold text-gray-900">Profile Information</h3>
          <%= if @last_updated do %>
            <div class="flex items-center space-x-2">
              <div class="w-2 h-2 bg-green-400 rounded-full"></div>
              <span class="text-xs text-green-600">Updated</span>
            </div>
          <% end %>
        </div>

        <form id="profile-form" phx-submit="save-profile" phx-change="validate-identity-contact" class="space-y-6">
          <!-- Personal Information Section -->
          <div class="border-b border-gray-200 pb-6">
            <h4 class="text-md font-medium text-gray-800 mb-4">Personal Information</h4>
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
          </div>

          <!-- Identity Information Section -->
          <div class="border-b border-gray-200 pb-6">
            <h4 class="text-md font-medium text-gray-800 mb-4">Identity Information</h4>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Identity Card Number</label>
                <input type="text" name="profile[identity_card_number]" value={@profile && @profile.identity_card_number} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Identity Card Number" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Passport Number</label>
                <input type="text" name="profile[passport_number]" value={@profile && @profile.passport_number} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Passport Number" />
              </div>
            </div>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
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
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Citizenship</label>
                <input type="text" name="profile[citizenship]" value={@profile && @profile.citizenship || "Malaysia"} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Citizenship" />
              </div>
            </div>
          </div>

          <!-- Contact Information Section -->
          <div class="border-b border-gray-200 pb-6">
            <h4 class="text-md font-medium text-gray-800 mb-4">Contact Information</h4>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Phone Number</label>
                <input type="text" name="profile[phone_number]" value={@profile && @profile.phone_number} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Phone Number" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Monthly Income (RM)</label>
                <input type="number" name="profile[monthly_income]" value={@profile && @profile.monthly_income} min="1" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Monthly Income" />
              </div>
            </div>
            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Address</label>
              <textarea name="profile[address]" rows="3" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter full address">{@profile && @profile.address}</textarea>
            </div>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">City</label>
                <input type="text" name="profile[city]" value={@profile && @profile.city} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter City" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">State</label>
                <select name="profile[state]" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent">
                  <option value="">Select State</option>
                  <option value="Johor" selected={@profile && @profile.state == "Johor"}>Johor</option>
                  <option value="Kedah" selected={@profile && @profile.state == "Kedah"}>Kedah</option>
                  <option value="Kelantan" selected={@profile && @profile.state == "Kelantan"}>Kelantan</option>
                  <option value="Melaka" selected={@profile && @profile.state == "Melaka"}>Melaka</option>
                  <option value="Negeri Sembilan" selected={@profile && @profile.state == "Negeri Sembilan"}>Negeri Sembilan</option>
                  <option value="Pahang" selected={@profile && @profile.state == "Pahang"}>Pahang</option>
                  <option value="Perak" selected={@profile && @profile.state == "Perak"}>Perak</option>
                  <option value="Perlis" selected={@profile && @profile.state == "Perlis"}>Perlis</option>
                  <option value="Pulau Pinang" selected={@profile && @profile.state == "Pulau Pinang"}>Pulau Pinang</option>
                  <option value="Sabah" selected={@profile && @profile.state == "Sabah"}>Sabah</option>
                  <option value="Sarawak" selected={@profile && @profile.state == "Sarawak"}>Sarawak</option>
                  <option value="Selangor" selected={@profile && @profile.state == "Selangor"}>Selangor</option>
                  <option value="Terengganu" selected={@profile && @profile.state == "Terengganu"}>Terengganu</option>
                  <option value="Kuala Lumpur" selected={@profile && @profile.state == "Kuala Lumpur"}>Kuala Lumpur</option>
                  <option value="Labuan" selected={@profile && @profile.state == "Labuan"}>Labuan</option>
                  <option value="Putrajaya" selected={@profile && @profile.state == "Putrajaya"}>Putrajaya</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Postal Code</label>
                <input type="text" name="profile[poskod]" value={@profile && @profile.poskod} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Postal Code" />
              </div>
            </div>
          </div>

          <!-- Emergency Contact Section -->
          <div class="pb-6">
            <h4 class="text-md font-medium text-gray-800 mb-4">Emergency Contact</h4>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Emergency Contact Name</label>
                <input type="text" name="profile[emergency_contact_name]" value={@profile && @profile.emergency_contact_name} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Emergency Contact Name" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Emergency Contact Phone</label>
                <input type="text" name="profile[emergency_contact_phone]" value={@profile && @profile.emergency_contact_phone} class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Emergency Contact Phone" />
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Emergency Contact Relationship</label>
              <select name="profile[emergency_contact_relationship]" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent">
                <option value="">Select Relationship</option>
                <option value="spouse" selected={@profile && @profile.emergency_contact_relationship == "spouse"}>Spouse</option>
                <option value="parent" selected={@profile && @profile.emergency_contact_relationship == "parent"}>Parent</option>
                <option value="child" selected={@profile && @profile.emergency_contact_relationship == "child"}>Child</option>
                <option value="sibling" selected={@profile && @profile.emergency_contact_relationship == "sibling"}>Sibling</option>
                <option value="friend" selected={@profile && @profile.emergency_contact_relationship == "friend"}>Friend</option>
                <option value="other" selected={@profile && @profile.emergency_contact_relationship == "other"}>Other</option>
              </select>
            </div>
          </div>

          <!-- Single Save Button -->
          <div class="pt-6 border-t border-gray-200">
            <button type="submit" class="w-full bg-teal-600 text-white px-6 py-4 rounded-lg hover:bg-teal-700 transition-colors phx-submit-loading:opacity-75 phx-submit-loading:cursor-not-allowed text-lg font-medium">
              <span class="phx-submit-loading:hidden">Save All Profile Information</span>
              <span class="hidden phx-submit-loading:inline">Saving...</span>
            </button>
          </div>
        </form>
      </div>
    </.sidebar>
    """
  end
end
