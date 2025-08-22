defmodule Umrahly.Repo.Migrations.CreatePackages do
  use Ecto.Migration

  def change do
    create table(:packages) do
      add :name, :string, null: false
      add :price, :integer, null: false
      add :duration_days, :integer, null: false
      add :duration_nights, :integer, null: false
      add :quota, :integer, null: false
      add :departure_date, :date, null: false
      add :status, :string, default: "inactive"

      timestamps(type: :utc_datetime)
    end

    create index(:packages, [:name])
    create index(:packages, [:status])
    create index(:packages, [:departure_date])
  end
end
