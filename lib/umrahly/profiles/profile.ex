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
    |> validate_required([:user_id, :identity_card_number, :phone_number, :address, :monthly_income, :birthdate, :gender])
    |> foreign_key_constraint(:user_id)
  end
end
