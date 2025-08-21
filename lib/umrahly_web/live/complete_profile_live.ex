defmodule UmrahlyWeb.CompleteProfileLive do
  use UmrahlyWeb, :live_view

  on_mount {UmrahlyWeb.UserAuth, :ensure_authenticated}

  alias Umrahly.Profiles
  alias Umrahly.Profiles.Profile

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    cond do
      Umrahly.Accounts.is_admin?(current_user) ->
        {:ok,
         socket
         |> put_flash(:info, "Admin users don't need to complete a profile!")
         |> push_navigate(to: ~p"/admin/dashboard")}

      true ->
        case Profiles.get_profile_by_user_id(current_user.id) do
          nil ->
            changeset = Profiles.change_profile(%Profile{user_id: current_user.id})
            {:ok, assign(socket, changeset: changeset, current_user: current_user)}

        if has_profile do
          {:ok,
           socket
           |> put_flash(:info, "You already have a profile!")
           |> push_navigate(to: ~p"/dashboard")}
        else
          changeset = Accounts.change_user_profile(current_user)
          {:ok, assign(socket, changeset: changeset, current_user: current_user)}
        end
    end
  end

  def handle_event("save", %{"profile" => profile_params}, socket) do
    current_user = socket.assigns.current_user

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
end
