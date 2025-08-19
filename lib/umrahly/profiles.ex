defmodule Umrahly.Profiles do
  @moduledoc """
  The Profiles context.
  """

  import Ecto.Query, warn: false
  alias Umrahly.Repo

  alias Umrahly.Accounts.User

  @doc """
  Returns the list of users with profile information.
  """
  def list_users_with_profiles do
    Repo.all(User)
  end

  @doc """
  Gets a single user with profile information.
  Raises if the User does not exist.
  """
  def get_user_with_profile!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user with profile information by user_id.
  Returns nil if the User does not exist.
  """
  def get_user_with_profile_by_id(user_id) do
    Repo.get_by(User, id: user_id)
  end

  @doc """
  Creates a profile for a user.
  """
  def create_profile(attrs \\ %{}) do
    %User{}
    |> User.profile_update_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user's profile information.
  """
  def update_profile(%User{} = user, attrs) do
    user
    |> User.profile_update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user's profile information (sets fields to nil).
  """
  def delete_profile(%User{} = user) do
    user
    |> User.profile_update_changeset(%{
      address: nil,
      identity_card_number: nil,
      phone_number: nil,
      monthly_income: nil,
      birthdate: nil,
      gender: nil,
      profile_photo: nil
    })
    |> Repo.update()
  end

  @doc """
  Returns a data structure for tracking profile changes.
  """
  def change_profile(%User{} = user, attrs \\ %{}) do
    User.profile_update_changeset(user, attrs)
  end

  @doc """
  Creates or updates a profile (upsert).
  """
  def upsert_profile(%User{} = user, attrs) do
    update_profile(user, attrs)
  end

  def upsert_profile(nil, attrs) do
    create_profile(attrs)
  end

  # Backward compatibility functions
  def list_profiles, do: list_users_with_profiles()
  def get_profile!(id), do: get_user_with_profile!(id)
  def get_profile_by_user_id(user_id), do: get_user_with_profile_by_id(user_id)
end
