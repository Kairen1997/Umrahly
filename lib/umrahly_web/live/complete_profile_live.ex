defmodule UmrahlyWeb.CompleteProfileLive do
  use UmrahlyWeb, :live_view

  on_mount {UmrahlyWeb.UserAuth, :ensure_authenticated}

  alias Umrahly.Accounts
  alias Umrahly.Accounts.User

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    cond do
      Accounts.is_admin?(current_user) ->
        {:ok,
         socket
         |> put_flash(:info, "Admin users don't need to complete a profile!")
         |> push_navigate(to: ~p"/admin/dashboard")}

      true ->
        # Check if user already has profile information
        has_profile = user_has_profile?(current_user)

        if has_profile do
          {:ok,
           socket
           |> put_flash(:info, "You already have a profile!")
           |> push_navigate(to: ~p"/dashboard")}
        else
          changeset = User.profile_changeset(current_user, %{})
          
          socket = 
            socket
            |> assign(changeset: changeset, current_user: current_user)
            |> allow_upload(:profile_photo,
              accept: ~w(.jpg .jpeg .png),
              max_entries: 1,
              max_file_size: 5_000_000,
              auto_upload: true
            )
          
          {:ok, socket}
        end
    end
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    current_user = socket.assigns.current_user

    case Accounts.update_user(current_user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile completed successfully!")
         |> push_navigate(to: ~p"/dashboard")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("validate", _params, socket) do
    # Check if there are any uploads in progress
    upload_status = if length(socket.assigns.uploads.profile_photo.entries) > 0 do
      :uploading
    else
      :idle
    end

    {:noreply, assign(socket, upload_status: upload_status)}
  end

  def handle_event("phx:file-upload", %{"ref" => _ref}, socket) do
    # This gets called when auto_upload completes
    # Process the uploaded file immediately
    handle_event("upload-photo", %{}, socket)
  end

  def handle_event("upload-photo", _params, socket) do
    current_user = socket.assigns.current_user

    uploaded_files =
      consume_uploaded_entries(socket, :profile_photo, fn %{path: path}, entry ->
        uploads_dir = Path.join(File.cwd!(), "priv/static/images")
        File.mkdir_p!(uploads_dir)

        extension = Path.extname(entry.client_name)
        filename = "profile_#{current_user.id}_#{System.system_time()}#{extension}"
        dest_path = Path.join(uploads_dir, filename)

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
        # Update user with photo path
        case Accounts.update_user(current_user, %{profile_photo: photo_path}) do
          {:ok, updated_user} ->
            {:noreply,
             socket
             |> assign(current_user: updated_user)
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

  def handle_event("remove-photo", _params, socket) do
    current_user = socket.assigns.current_user

    case Accounts.update_user(current_user, %{profile_photo: nil}) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(current_user: updated_user)
         |> put_flash(:info, "Profile photo removed successfully")}

      {:error, _changeset} ->
        {:noreply, socket |> put_flash(:error, "Failed to remove profile photo")}
    end
  end

  def handle_event("phx:file-upload-cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :profile_photo, ref)}
  end

  # Helper function to check if user has profile information
  defp user_has_profile?(user) do
    not is_nil(user.address) or
    not is_nil(user.identity_card_number) or
    not is_nil(user.phone_number) or
    not is_nil(user.monthly_income) or
    not is_nil(user.birthdate) or
    not is_nil(user.gender)
  end
end
