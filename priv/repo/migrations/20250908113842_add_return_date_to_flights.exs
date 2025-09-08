defmodule Umrahly.Repo.Migrations.AddReturnDateToFlights do
  use Ecto.Migration

  def change do
    alter table(:flights) do
      add :return_date, :utc_datetime
    end
  end

end
