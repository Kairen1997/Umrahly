defmodule Umrahly.Repo.Migrations.FixPackageDepartureDateIndex do
  use Ecto.Migration

  def change do
    drop index(:packages, [:departure_date])
    create index(:packages, [:departure_date])
  end
end
