defmodule Umrahly.Repo.Migrations.CreateTravelerDetails do
  use Ecto.Migration

  def change do
    create table(:traveler_details) do
      # Phase 1 (MVP - required for booking)
      add :full_name, :string, null: false
      add :identity_card_number, :string, null: false
      add :passport_number, :string, null: false
      add :passport_expiry_date, :date, null: false
      add :phone_number, :string, null: false
      add :email_address, :string, null: false
      add :gender, :string, null: false
      add :date_of_birth, :date, null: false

      # Phase 2 (for compliance & better management)
      add :nationality, :string
      add :emergency_contact_name, :string
      add :emergency_contact_phone, :string
      add :emergency_contact_relationship, :string
      add :room_preference, :string
      add :vaccination_record, :string
      add :medical_conditions, :text

      # Phase 3 (optional but valuable)
      add :mahram_info, :text
      add :special_needs_requests, :text

      # Relationships
      add :booking_id, references(:bookings, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # Indexes for better performance
    create index(:traveler_details, [:booking_id])
    create index(:traveler_details, [:user_id])
    create index(:traveler_details, [:passport_number])
    create index(:traveler_details, [:identity_card_number])
    create index(:traveler_details, [:email_address])

    # Add constraint for gender values
    create constraint(:traveler_details, :gender_check, check: "gender IN ('male', 'female', 'other')")
  end
end
