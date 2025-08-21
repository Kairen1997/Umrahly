defmodule Umrahly.Repo.Migrations.MergeProfilesIntoUsers do
  use Ecto.Migration

  def change do
    # Add profile fields to users table
    alter table(:users) do
      add :address, :string
      add :identity_card_number, :string
      add :phone_number, :string
      add :monthly_income, :integer
      add :birthdate, :date
      add :gender, :string
      add :profile_photo, :string
    end

    # Create indexes for the new fields
    create index(:users, [:identity_card_number])
    create index(:users, [:phone_number])

    # Migrate existing profile data to users table
    execute """
    UPDATE users
    SET
      address = profiles.address,
      identity_card_number = profiles.identity_card_number,
      phone_number = profiles.phone_number,
      monthly_income = profiles.monthly_income,
      birthdate = profiles.birthdate,
      gender = profiles.gender,
      profile_photo = profiles.profile_photo
    FROM profiles
    WHERE users.id = profiles.user_id
    """

    # Drop the profiles table
    drop table(:profiles)
  end
end
