defmodule UmrahlyWeb.ProfileController do
  use UmrahlyWeb, :controller

  alias Umrahly.Profiles

  def create(conn, %{"identity_card_number" => _identity_card_number} = profile_params) do
    _current_user = conn.assigns.current_user

    case Profiles.create_profile(profile_params) do
      {:ok, _profile} ->
        conn
        |> put_status(:created)
        |> json(%{message: "Profile created successfully"})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", to_string(value))
          end)
        end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{message: "Missing required parameters"})
  end
end
