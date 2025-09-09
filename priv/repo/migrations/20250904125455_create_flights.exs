defmodule Umrahly.Repo.Migrations.CreateFlights do
  use Ecto.Migration

  def change do
    create table(:flights) do
      add :flight_number, :string
      add :origin, :string
      add :destination, :string
      add :departure_time, :utc_datetime
      add :arrival_time, :utc_datetime
      add :aircraft, :string
      add :capacity_total, :integer
      add :capacity_booked, :integer
      add :status, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:flights, [:flight_number])
  end
end
