defmodule Umrahly.Repo.Migrations.AddDurationDaysToFlights do
  use Ecto.Migration

  def change do
    alter table(:flights) do
      add :duration_days, :integer
    end
  end
end
