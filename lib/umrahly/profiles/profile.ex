defmodule Umrahly.Profiles.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profiles" do
    field :address, :string
    field :identity_card_number, :string
    field :phone_number, :string
    field :monthly_income, :integer
    field :birthdate, :date
    field :gender, :string
    field :profile_photo, :string

    belongs_to :user, Umrahly.Accounts.User
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:user_id, :identity_card_number, :phone_number, :address, :monthly_income, :birthdate, :gender, :profile_photo])
    |> validate_required([:user_id])
    |> validate_monthly_income()
    |> validate_gender()
    |> validate_length(:profile_photo, max: 255)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_monthly_income(changeset) do
    case get_field(changeset, :monthly_income) do
      nil -> changeset
      income when is_integer(income) and income > 0 -> changeset
      _ -> add_error(changeset, :monthly_income, "must be a positive integer")
    end
  end

  defp validate_gender(changeset) do
    case get_field(changeset, :gender) do
      nil -> changeset
      gender when gender in ["male", "female"] -> changeset
      _ -> add_error(changeset, :gender, "must be either male or female")
    end
  end


end
