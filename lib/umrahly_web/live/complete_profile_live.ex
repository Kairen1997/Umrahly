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
          {:ok, assign(socket, changeset: changeset, current_user: current_user)}
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
