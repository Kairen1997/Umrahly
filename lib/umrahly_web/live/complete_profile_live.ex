defmodule UmrahlyWeb.CompleteProfileLive do
  use UmrahlyWeb, :live_view

  on_mount {UmrahlyWeb.UserAuth, :ensure_authenticated}

  alias Umrahly.Profiles
  alias Umrahly.Profiles.Profile

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    # Check if user already has a profile
    case Profiles.get_profile_by_user_id(current_user.id) do
      nil ->
        changeset = Profiles.change_profile(%Profile{user_id: current_user.id})
        {:ok, assign(socket, changeset: changeset, current_user: current_user)}

      _profile ->
        {:ok,
         socket
         |> put_flash(:info, "You already have a profile!")
         |> push_navigate(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("save", %{"profile" => profile_params}, socket) do
    current_user = socket.assigns.current_user
    profile_params = Map.put(profile_params, "user_id", current_user.id)

    case Profiles.create_profile(profile_params) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile completed successfully!")
         |> push_navigate(to: ~p"/dashboard")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true

end
