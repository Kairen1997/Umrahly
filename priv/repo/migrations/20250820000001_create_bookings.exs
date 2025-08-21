defmodule Umrahly.Repo.Migrations.CreateBookings do
  use Ecto.Migration

  def change do
    create table(:bookings) do
      add :status, :string, default: "pending", null: false
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :booking_date, :date, null: false
      add :travel_date, :date, null: false
      add :notes, :text
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :package_id, references(:packages, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:bookings, [:user_id])
    create index(:bookings, [:package_id])
    create index(:bookings, [:status])
    create index(:bookings, [:booking_date])
  end
end
