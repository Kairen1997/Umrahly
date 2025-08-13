defmodule Umrahly.Profiles do
  @moduledoc """
  The Profiles context.
  """

  import Ecto.Query, warn: false
  alias Umrahly.Repo

  alias Umrahly.Profiles.Profile

  @doc """
  Returns the list of profiles.

  ## Examples

      iex> list_profiles()
      [%Profile{}, ...]

  """
  def list_profiles do
    Repo.all(Profile)
  end

  @doc """
  Gets a single profile.

  Raises if the Profile does not exist.

  ## Examples

      iex> get_profile!(123)
      %Profile{}

  """
  def get_profile!(id), do: Repo.get!(Profile, id)

  @doc """
  Gets a profile by user_id.

  Returns nil if the Profile does not exist.

  ## Examples

      iex> get_profile_by_user_id(123)
      %Profile{}

      iex> get_profile_by_user_id(999)
      nil

  """
  def get_profile_by_user_id(user_id) do
    Repo.get_by(Profile, user_id: user_id)
  end

  @doc """
  Creates a profile.

  ## Examples

      iex> create_profile(%{field: value})
      {:ok, %Profile{}}

      iex> create_profile(%{field: bad_value})
      {:error, ...}

  """
  def create_profile(attrs \\ %{}) do
    %Profile{}
    |> Profile.changeset(attrs)
    |> Repo.insert()
  end


  @doc """
  Updates a profile.

  ## Examples

      iex> update_profile(profile, %{field: new_value})
      {:ok, %Profile{}}

      iex> update_profile(profile, %{field: bad_value})
      {:error, ...}

  """
  def update_profile(%Profile{} = profile, attrs) do
    profile
    |> Profile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Profile.

  ## Examples

      iex> delete_profile(profile)
      {:ok, %Profile{}}

      iex> delete_profile(profile)
      {:error, ...}

  """
  def delete_profile(%Profile{} = profile) do
    Repo.delete(profile)
  end

  @doc """
  Returns a data structure for tracking profile changes.

  ## Examples

      iex> change_profile(profile)
      %Ecto.Changeset{...}

  """
  def change_profile(%Profile{} = profile, attrs \\ %{}) do
    Profile.changeset(profile, attrs)
  end

  @doc """
  Creates or updates a profile (upsert).

  ## Examples

      iex> upsert_profile(profile, %{field: new_value})
      {:ok, %Profile{}}

      iex> upsert_profile(nil, %{user_id: 123, field: value})
      {:ok, %Profile{}}

  """
  def upsert_profile(%Profile{} = profile, attrs) do
    update_profile(profile, attrs)
  end

  def upsert_profile(nil, attrs) do
    create_profile(attrs)
  end
end
