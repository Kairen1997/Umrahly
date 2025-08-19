defmodule Umrahly.ProfilesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Umrahly.Profiles` context.
  """

  alias Umrahly.AccountsFixtures

  @doc """
  Generate a user with profile information.
  """
  def user_with_profile_fixture(attrs \\ %{}) do
    user = AccountsFixtures.user_fixture()

    profile_attrs = Enum.into(attrs, %{
      address: "123 Main St",
      phone_number: "1234567890",
      identity_card_number: "A123456789",
      monthly_income: 5000,
      birthdate: ~D[1990-01-01],
      gender: "male"
    })

    {:ok, user_with_profile} = Umrahly.Profiles.update_profile(user, profile_attrs)
    user_with_profile
  end

  @doc """
  Generate a profile (backward compatibility).
  """
  def profile_fixture(attrs \\ %{}) do
    user_with_profile_fixture(attrs)
  end
end
