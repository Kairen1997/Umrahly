defmodule Umrahly.ProfilesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Umrahly.Profiles` context.
  """

  @doc """
  Generate a profile.
  """
  def profile_fixture(attrs \\ %{}) do
    {:ok, profile} =
      attrs
      |> Enum.into(%{

      })
      |> Umrahly.Profiles.create_profile()

    profile
  end
end
