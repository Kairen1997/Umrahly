defmodule UmrahlyWeb.CompleteProfileLive do
  use UmrahlyWeb, :live_view

  alias Umrahly.Profiles
  alias Umrahly.Profiles.Profile

  @impl true
  def mount(_params, _session, socket) do
    # Get current user from the session/connection
    current_user = get_current_user(socket)

    # Check if user already has a profile
    case Profiles.get_profile_by_user_id(current_user.id) do
      nil ->
        changeset = Profiles.change_profile(%Profile{user_id: current_user.id})
        {:ok, assign(socket, changeset: changeset, current_user: current_user, show_modal: true)}

      _profile ->
        {:ok,
         socket
         |> put_flash(:info, "You already have a profile!")
         |> push_navigate(to: "/dashboard")}
    end
  end

  @impl true
  def handle_event("save", params, socket) do
    current_user = socket.assigns.current_user
    profile_params = Map.put(params, "user_id", current_user.id)

    case Profiles.create_profile(profile_params) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile completed successfully!")
         |> push_navigate(to: "/dashboard")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    # Don't allow closing the modal - profile completion is compulsory
    {:noreply, socket}
  end

  # Helper function to get current user from socket
  defp get_current_user(socket) do
    # Try to get from assigns first, then from session
    socket.assigns[:current_user] ||
    socket.assigns[:user] ||
    %{id: socket.assigns[:user_id]}
  end
end
