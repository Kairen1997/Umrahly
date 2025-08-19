defmodule UmrahlyWeb.UserProfileLive do
  use UmrahlyWeb, :live_view

  alias Umrahly.Accounts
  alias Umrahly.Profiles

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    # Profile is now part of the user, so we check if profile fields are filled
    has_profile = user.address != nil or user.identity_card_number != nil or user.phone_number != nil or
                  user.monthly_income != nil or user.birthdate != nil or user.gender != nil

    socket = assign(socket,
      user: user,
      has_profile: has_profile,
      page_title: "Profile",
      last_updated: nil
    )
    socket = if not has_profile do
      put_flash(socket, :error, "Please complete your profile first. Some features may not be available.")
    else
      socket
    end

    socket =
      socket
      |> assign(:changeset, Profiles.change_profile(user))
      |> allow_upload(:profile_photo,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 1,
        max_file_size: 5_000_000
      )

    {:ok, socket}
  end

  def handle_event("save-profile", %{"profile" => profile_params}, socket) do
    user = socket.assigns.user
    user_attrs = %{
      "full_name" => profile_params["full_name"]
    }
    profile_attrs =
      profile_params
      |> Map.drop(["full_name"])

    with {:ok, updated_user} <- Accounts.update_user(user, user_attrs),
         {:ok, updated_user_with_profile} <- Profiles.update_profile(updated_user, profile_attrs) do

      {:noreply,
       socket
       |> assign(user: updated_user_with_profile, has_profile: true, last_updated: DateTime.utc_now())
       |> put_flash(:info, "Profile updated successfully")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(profile_changeset: changeset)
         |> put_flash(:error, "Failed to update profile. Please check the form and try again.")}
    end
  end

  def handle_event("save-identity-contact", %{"profile" => profile_params}, socket) do
    user = socket.assigns.user

    # Start with a clean map using only string keys from the form
    profile_attrs = %{
      "identity_card_number" => profile_params["identity_card_number"],
      "phone_number" => profile_params["phone_number"],
      "address" => profile_params["address"],
      "monthly_income" => profile_params["monthly_income"],
      "gender" => profile_params["gender"],
      "birthdate" => profile_params["birthdate"]
    }

    # Clean up empty strings to nil
    profile_attrs = profile_attrs
    |> Map.update("identity_card_number", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("phone_number", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("address", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("monthly_income", nil, &if(&1 == "" or is_nil(&1), do: nil, else: &1))
    |> Map.update("gender", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))
    |> Map.update("birthdate", nil, &if(&1 == "" or is_nil(&1), do: nil, else: String.trim(&1)))

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
                  user.monthly_income != nil or user.birthdate != nil or user.gender != nil

    if not has_profile do
      has_values = profile_attrs
      |> Map.take(["identity_card_number", "phone_number", "address", "monthly_income", "gender", "birthdate"])
      |> Map.values()
      |> Enum.any?(&(&1 != nil))

      if not has_values do
        {:noreply,
         socket
         |> put_flash(:error, "Please fill in at least one field to create your profile.")}
      else
        continue_profile_update(socket, user, profile_attrs)
      end
    else
      continue_profile_update(socket, user, profile_attrs)
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

  def handle_event("upload-photo", _params, socket) do
    user = socket.assigns.user
    profile = socket.assigns.profile

    if is_nil(profile) do
      {:noreply, put_flash(socket, :error, "Profile not found. Please complete your profile first.")}
    else
      uploaded_files =
        consume_uploaded_entries(socket, :profile_photo, fn entry, _socket ->
          uploads_dir = Path.join(:code.priv_dir(:umrahly), "static/uploads")
          File.mkdir_p!(uploads_dir)

          extension = Path.extname(entry.client_name)
          filename = "#{user.id}_#{System.system_time()}#{extension}"
          dest_path = Path.join(uploads_dir, filename)

          case File.cp(entry.path, dest_path) do
            :ok ->
              {:ok, "/uploads/#{filename}"}

            {:error, reason} ->
              {:error, reason}
          end
        end)

      case uploaded_files do
        [photo_path | _] ->
          case Profiles.update_profile(user, %{profile_photo: photo_path}) do
            {:ok, updated_user} ->
              updated_user =
                Map.update!(updated_user, :profile_photo, fn path ->
                  path <> "?v=#{DateTime.to_unix(DateTime.utc_now())}"
                end)

              {:noreply,
               socket
               |> assign(user: updated_user)
               |> put_flash(:info, "Profile photo uploaded successfully")}

            {:error, changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to save profile: #{inspect(changeset.errors)}")}
          end

        [] ->
          {:noreply, put_flash(socket, :error, "No file uploaded")}
      end
    end
  end


  def handle_event("remove-photo", _params, socket) do
    user = socket.assigns.user

    case Profiles.update_profile(user, %{profile_photo: nil}) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(user: updated_user)
         |> put_flash(:info, "Profile photo removed successfully")}

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
  def handle_event("validate-photo", _params, socket) do

    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :profile_photo, ref)}
  end



  # Private functions
  defp continue_profile_update(socket, user, profile_attrs) do
    # Update profile
    case Profiles.update_profile(user, profile_attrs) do
      {:ok, updated_user} ->
        # Determine if this is a new profile or an update
        has_profile = user.address != nil or user.identity_card_number != nil or user.phone_number != nil or
                      user.monthly_income != nil or user.birthdate != nil or user.gender != nil

        message = if not has_profile do
          "Profile created successfully! Welcome to Umrahly!"
        else
          "Identity and contact information updated successfully!"
        end

        {:noreply,
         socket
         |> assign(user: updated_user, has_profile: true, last_updated: DateTime.utc_now())
         |> put_flash(:info, message)}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Create a more informative error message
        error_message = case changeset.errors do
          [] -> "Failed to update identity and contact information. Please check the form and try again."
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
    <div class="flex min-h-screen bg-gray-100">
      <!-- Sidebar -->
      <aside class="w-50 bg-gray-800 shadow-lg h-50 flex flex-col justify-between">
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
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-2xl font-semibold text-gray-900">
                  Profile
                </h1>
                <%= if @last_updated do %>
                  <p class="mt-1 text-sm text-gray-500">
                    Last updated: <%= Calendar.strftime(@last_updated, "%B %d, %Y at %I:%M %p") %>
                  </p>
                <% end %>
              </div>
              <%= if @profile do %>
                <div class="flex items-center space-x-2">
                  <div class="w-3 h-3 bg-green-400 rounded-full"></div>
                  <span class="text-sm text-gray-600">Profile Complete</span>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Page Content -->
        <main class="flex-1 bg-gray-50 p-6 overflow-auto">
          <div class="max-w-6xl mx-auto">

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

            <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">

              <!-- Left Column - Forms -->
              <div class="lg:col-span-2 space-y-8">

                <!-- Personal Information -->
                <div class="bg-white rounded-lg shadow p-6">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg font-semibold text-gray-900">Personal Information</h3>
                    <%= if @last_updated do %>
                      <div class="flex items-center space-x-2">
                        <div class="w-2 h-2 bg-green-400 rounded-full"></div>
                        <span class="text-xs text-green-600">Updated</span>
                      </div>
                    <% end %>
                  </div>
                  <form id="personal-info-form" phx-submit="save-personal-info" class="space-y-4">
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
                    <div class="pt-4">
                      <button type="submit" class="bg-teal-600 text-white px-6 py-3 rounded-lg hover:bg-teal-700 transition-colors phx-submit-loading:opacity-75 phx-submit-loading:cursor-not-allowed">
                        <span class="phx-submit-loading:hidden">Save Personal Info</span>
                        <span class="hidden phx-submit-loading:inline">Saving...</span>
                      </button>
                    </div>
                  </form>
                </div>

                <!-- Change Password -->
                <div class="bg-white rounded-lg shadow p-6">
                  <h3 class="text-lg font-semibold text-gray-900 mb-4">Change Password</h3>
                  <form id="change-password-form" phx-submit="change-password" class="space-y-4">
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
                        <input type="password" name="user[password_confirmation]" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus-border-transparent" placeholder="Confirm Password" required />
                      </div>
                    </div>
                    <div class="pt-4">
                      <button type="submit" class="bg-teal-600 text-white px-6 py-3 rounded-lg hover:bg-teal-700 transition-colors phx-submit-loading:opacity-75 phx-submit-loading:cursor-not-allowed">
                        <span class="phx-submit-loading:hidden">Change Password</span>
                        <span class="hidden phx-submit-loading:inline">Changing...</span>
                      </button>
                    </div>
                  </form>
                </div>

                <!-- Identity and Contact Information -->
                <div class="bg-white rounded-lg shadow p-6">
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="text-lg font-semibold text-gray-900">Identity and Contact Information</h3>
                    <%= if @last_updated do %>
                      <div class="flex items-center space-x-2">
                        <div class="w-2 h-2 bg-green-400 rounded-full"></div>
                        <span class="text-xs text-green-600">Updated</span>
                      </div>
                    <% end %>
                  </div>
                  <form id="identity-contact-form" phx-submit="save-identity-contact" phx-change="validate-identity-contact" class="space-y-4">
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
                        <input type="number" name="profile[monthly_income]" value={@profile && @profile.monthly_income} min="1" class="w-full border border-gray-300 rounded-lg p-3 bg-teal-50 focus:ring-2 focus:ring-teal-500 focus:border-transparent" placeholder="Enter Monthly Income" />
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
                      <button type="submit" class="bg-teal-600 text-white px-6 py-3 rounded-lg hover:bg-teal-700 transition-colors phx-submit-loading:opacity-75 phx-submit-loading:cursor-not-allowed">
                        <span class="phx-submit-loading:hidden">Save Identity & Contact Info</span>
                        <span class="hidden phx-submit-loading:inline">Saving...</span>
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
                        <div class="relative inline-block ">
                          <img src={@profile.profile_photo} alt="Profile Photo" class="w-32 h-32 rounded-full object-cover border-4 border-teal-200 shadow-lg" />
                          <button phx-click="remove-photo" class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center hover:bg-red-600 transition-colors">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" >
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
                    <form id="upload-photo-form" phx-submit="upload-photo" class="space-y-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Select Photo</label>
                        <div class="space-y-2">
                          <!-- Drag & Drop Zone -->
                          <div
                            class="flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-lg"
                            phx-drop-target={@uploads.profile_photo.ref}
                          >
                            <div class="space-y-1 text-center">
                              <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                                <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                              </svg>
                              <div class="flex text-sm text-gray-600">
                                <label class="relative cursor-pointer bg-white rounded-md font-medium text-teal-600 hover:text-teal-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-teal-500">
                                  <span>Upload a file</span>
                                  <.live_file_input upload={@uploads.profile_photo} class="sr-only" accept=".jpg,.jpeg,.png" />
                                </label>
                                <p class="pl-1">or drag and drop</p>
                              </div>
                              <p class="text-xs text-gray-500">PNG or JPG up to 5MB</p>
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

                          <%= for err <- upload_errors(@uploads.profile_photo) do %>
                            <p class="text-red-600 text-sm"><%= Phoenix.Naming.humanize(err) %></p>
                          <% end %>
                        </div>
                      </div>
                      <button type="submit" class="w-full bg-teal-600 text-white px-6 py-3 rounded-lg hover:bg-teal-700 transition-colors phx-submit-loading:opacity-75 phx-submit-loading:cursor-not-allowed" disabled={Enum.empty?(@uploads.profile_photo.entries)}>
                        <span class="phx-submit-loading:hidden">Upload Profile Photo</span>
                        <span class="hidden phx-submit-loading:inline">Uploading...</span>
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
