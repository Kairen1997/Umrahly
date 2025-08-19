defmodule UmrahlyWeb.CompleteProfileLive do
  use UmrahlyWeb, :live_view

  on_mount {UmrahlyWeb.UserAuth, :ensure_authenticated}

  alias Umrahly.Accounts

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    cond do
      Umrahly.Accounts.is_admin?(current_user) ->
        {:ok,
         socket
         |> put_flash(:info, "Admin users don't need to complete a profile!")
         |> push_navigate(to: ~p"/admin/dashboard")}

      true ->
        # Check if user has profile information directly
        has_profile = current_user.address != nil or current_user.phone_number != nil or current_user.identity_card_number != nil

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

    case Accounts.update_user_profile(current_user, profile_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile completed successfully!")
         |> push_navigate(to: ~p"/dashboard")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
