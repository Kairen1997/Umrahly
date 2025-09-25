defmodule Umrahly.Repo.Migrations.AddIsBookingForSelfToBookingsTable do
  use Ecto.Migration

  def change do
    alter table(:bookings) do
      add :is_booking_for_self, :boolean, default: true, null: false
    end
  end
end
