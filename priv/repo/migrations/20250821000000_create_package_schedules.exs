defmodule Umrahly.Repo.Migrations.CreatePackageSchedules do
  use Ecto.Migration

  def change do
    create table(:package_schedules) do
      add :package_id, references(:packages, on_delete: :delete_all), null: false
      add :departure_date, :date, null: false
      add :return_date, :date, null: false
      add :quota, :integer, null: false
      add :status, :string, default: "active"
      add :price_override, :integer
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:package_schedules, [:package_id])
    create index(:package_schedules, [:departure_date])
    create index(:package_schedules, [:status])
    create index(:package_schedules, [:package_id, :departure_date])
  end
end
