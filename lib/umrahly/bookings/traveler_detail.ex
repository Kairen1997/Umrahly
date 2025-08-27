defmodule Umrahly.Bookings.TravelerDetail do
  use Ecto.Schema
  import Ecto.Changeset

  schema "traveler_details" do
    # Phase 1 (MVP - required for booking)
    field :full_name, :string
    field :identity_card_number, :string
    field :passport_number, :string
    field :passport_expiry_date, :date
    field :phone_number, :string
    field :email_address, :string
    field :gender, :string
    field :date_of_birth, :date

    # Phase 2 (for compliance & better management)
    field :nationality, :string
    field :emergency_contact_name, :string
    field :emergency_contact_phone, :string
    field :emergency_contact_relationship, :string
    field :room_preference, :string
    field :vaccination_record, :string
    field :medical_conditions, :string

    # Phase 3 (optional but valuable)
    field :mahram_info, :string
    field :special_needs_requests, :string

    # Relationships
    belongs_to :booking, Umrahly.Bookings.Booking
    belongs_to :user, Umrahly.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(traveler_detail, attrs) do
    traveler_detail
    |> cast(attrs, [
      :full_name, :identity_card_number, :passport_number, :passport_expiry_date,
      :phone_number, :email_address, :gender, :date_of_birth, :nationality,
      :emergency_contact_name, :emergency_contact_phone, :emergency_contact_relationship,
      :room_preference, :vaccination_record, :medical_conditions, :mahram_info,
      :special_needs_requests, :booking_id, :user_id
    ])
    |> validate_required([
      :full_name, :identity_card_number, :passport_number, :passport_expiry_date,
      :phone_number, :email_address, :gender, :date_of_birth, :booking_id, :user_id
    ])
    |> validate_inclusion(:gender, ["male", "female", "other"])
    |> validate_format(:email_address, ~r/@/)
    |> validate_passport_expiry_date()
    |> validate_date_of_birth()
    |> foreign_key_constraint(:booking_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for Phase 1 (MVP) fields only
  """
  def phase1_changeset(traveler_detail, attrs) do
    traveler_detail
    |> cast(attrs, [
      :full_name, :identity_card_number, :passport_number, :passport_expiry_date,
      :phone_number, :email_address, :gender, :date_of_birth, :booking_id, :user_id
    ])
    |> validate_required([
      :full_name, :identity_card_number, :passport_number, :passport_expiry_date,
      :phone_number, :email_address, :gender, :date_of_birth, :booking_id, :user_id
    ])
    |> validate_inclusion(:gender, ["male", "female", "other"])
    |> validate_format(:email_address, ~r/@/)
    |> validate_passport_expiry_date()
    |> validate_date_of_birth()
    |> foreign_key_constraint(:booking_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for updating Phase 2 fields
  """
  def phase2_changeset(traveler_detail, attrs) do
    traveler_detail
    |> cast(attrs, [
      :nationality, :emergency_contact_name, :emergency_contact_phone,
      :emergency_contact_relationship, :room_preference, :vaccination_record, :medical_conditions
    ])
    |> validate_required([:nationality])
  end

  @doc """
  Changeset for updating Phase 3 fields
  """
  def phase3_changeset(traveler_detail, attrs) do
    traveler_detail
    |> cast(attrs, [:mahram_info, :special_needs_requests])
  end

  defp validate_passport_expiry_date(changeset) do
    case get_change(changeset, :passport_expiry_date) do
      nil -> changeset
      expiry_date ->
        if Date.compare(expiry_date, Date.utc_today()) == :gt do
          changeset
        else
          add_error(changeset, :passport_expiry_date, "Passport must be valid (not expired)")
        end
    end
  end

  defp validate_date_of_birth(changeset) do
    case get_change(changeset, :date_of_birth) do
      nil -> changeset
      birth_date ->
        today = Date.utc_today()
        age = Date.diff(today, birth_date)
        if age >= 0 and age <= 120 do
          changeset
        else
          add_error(changeset, :date_of_birth, "Date of birth must be valid")
        end
    end
  end
end
