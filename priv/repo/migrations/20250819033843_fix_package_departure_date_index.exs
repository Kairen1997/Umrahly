defmodule Umrahly.Repo.Migrations.FixPackageDepartureDateIndex do
  use Ecto.Migration

  def change do
    create index(:packages, [:departure_date])
  end
end
