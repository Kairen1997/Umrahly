defmodule Umrahly.ProfilesTest do
  use Umrahly.DataCase

  alias Umrahly.Profiles
  alias Umrahly.Accounts.User

  describe "profiles" do
    import Umrahly.AccountsFixtures

    @invalid_attrs %{}

    test "list_users_with_profiles/0 returns all users with profiles" do
      user = user_fixture()
      assert Profiles.list_users_with_profiles() == [user]
    end

    test "get_user_with_profile!/1 returns the user with given id" do
      user = user_fixture()
      assert Profiles.get_user_with_profile!(user.id) == user
    end

    test "create_profile/1 with valid data creates a profile for a user" do
      user = user_fixture()
      valid_attrs = %{address: "123 Main St", phone_number: "1234567890"}

      assert {:ok, %User{} = updated_user} = Profiles.create_profile(valid_attrs)
      assert updated_user.address == "123 Main St"
      assert updated_user.phone_number == "1234567890"
    end

    test "create_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Profiles.create_profile(@invalid_attrs)
    end

    test "update_profile/2 with valid data updates the profile" do
      user = user_fixture()
      update_attrs = %{address: "456 Oak St"}

      assert {:ok, %User{} = updated_user} = Profiles.update_profile(user, update_attrs)
      assert updated_user.address == "456 Oak St"
    end

    test "update_profile/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Profiles.update_profile(user, @invalid_attrs)
      assert user == Profiles.get_user_with_profile!(user.id)
    end

    test "delete_profile/1 deletes the profile information" do
      user = user_fixture()
      # First add some profile data
      {:ok, user_with_profile} = Profiles.update_profile(user, %{address: "123 Main St", phone_number: "1234567890"})

      assert {:ok, %User{} = updated_user} = Profiles.delete_profile(user_with_profile)
      assert updated_user.address == nil
      assert updated_user.phone_number == nil
    end

    test "change_profile/1 returns a profile changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Profiles.change_profile(user)
    end

    # Backward compatibility tests
    test "list_profiles/0 returns all users with profiles" do
      user = user_fixture()
      assert Profiles.list_profiles() == [user]
    end

    test "get_profile!/1 returns the user with given id" do
      user = user_fixture()
      assert Profiles.get_profile!(user.id) == user
    end
  end
end
