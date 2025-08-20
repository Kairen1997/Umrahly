defmodule Umrahly.Repo.Migrations.CreatePackageSchedulesAndMigrate do
  use Ecto.Migration

  def up do
    # First, create the package_schedules table
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

    # Migrate existing package data to package_schedules
    execute """
    INSERT INTO package_schedules (package_id, departure_date, return_date, quota, status, price_override, notes, inserted_at, updated_at)
    SELECT
      id as package_id,
      departure_date,
      return_date,
      quota,
      status,
      NULL as price_override,
      'Migrated from packages table' as notes,
      NOW() as inserted_at,
      NOW() as updated_at
    FROM packages
    WHERE departure_date IS NOT NULL AND return_date IS NOT NULL AND quota IS NOT NULL
    """

    # Add package_schedule_id to bookings table (nullable initially)
    alter table(:bookings) do
      add :package_schedule_id, references(:package_schedules, on_delete: :delete_all)
    end

    create index(:bookings, [:package_schedule_id])

    # Update existing bookings to reference the new package_schedules
    execute """
    UPDATE bookings
    SET package_schedule_id = (
      SELECT ps.id
      FROM package_schedules ps
      WHERE ps.package_id = bookings.package_id
      LIMIT 1
    )
    WHERE package_schedule_id IS NULL
    """

    # Now make package_schedule_id not null
    alter table(:bookings) do
      modify :package_schedule_id, references(:package_schedules, on_delete: :delete_all), null: false
    end

    # Remove old columns from packages table
    alter table(:packages) do
      remove :departure_date
      remove :return_date
      remove :quota
    end

    # Remove old columns from bookings table
    alter table(:bookings) do
      remove :package_id
      remove :travel_date
    end
  end

  def down do
    # Add back the old columns to packages
    alter table(:packages) do
      add :departure_date, :date
      add :return_date, :date
      add :quota, :integer
    end

    # Add back the old columns to bookings
    alter table(:bookings) do
      add :package_id, references(:packages, on_delete: :delete_all)
      add :travel_date, :date
    end

    # Migrate data back from package_schedules to packages
    execute """
    UPDATE packages
    SET
      departure_date = (
        SELECT departure_date
        FROM package_schedules
        WHERE package_schedules.package_id = packages.id
        LIMIT 1
      ),
      return_date = (
        SELECT return_date
        FROM package_schedules
        WHERE package_schedules.package_id = packages.id
        LIMIT 1
      ),
      quota = (
        SELECT quota
        FROM package_schedules
        WHERE package_schedules.package_id = packages.id
        LIMIT 1
      )
    """

    # Update bookings to reference packages again
    execute """
    UPDATE bookings
    SET package_id = (
      SELECT package_id
      FROM package_schedules
      WHERE package_schedules.id = bookings.package_schedule_id
    )
    """

    # Remove package_schedule_id from bookings
    alter table(:bookings) do
      remove :package_schedule_id
    end

    # Drop package_schedules table
    drop table(:package_schedules)
  end
end
