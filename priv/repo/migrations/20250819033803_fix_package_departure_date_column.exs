defmodule Umrahly.Repo.Migrations.FixPackageDepartureDateColumn do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE packages RENAME COLUMN depature_date TO departure_date"
  end
end
