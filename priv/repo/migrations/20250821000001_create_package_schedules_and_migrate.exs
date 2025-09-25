defmodule Umrahly.Repo.Migrations.CreatePackageSchedulesAndMigrate do
  use Ecto.Migration

  def up do
    # First, create the package_schedules table
    create_if_not_exists table(:package_schedules) do
      add :package_id, references(:packages, on_delete: :delete_all), null: false
      add :departure_date, :date, null: false
      add :return_date, :date, null: false
      add :quota, :integer, null: false
      add :status, :string, default: "active"
      add :price_override, :decimal
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:package_schedules, [:package_id])
    create_if_not_exists index(:package_schedules, [:departure_date])
    create_if_not_exists index(:package_schedules, [:status])
    create_if_not_exists index(:package_schedules, [:package_id, :departure_date])

    # Migrate existing package data to package_schedules
    execute """
    INSERT INTO package_schedules (package_id, departure_date, return_date, quota, status, price_override, notes, inserted_at, updated_at)
    SELECT
      p.id as package_id,
      p.departure_date,
      p.return_date,
      p.quota,
      p.status,
      NULL as price_override,
      'Migrated from packages table' as notes,
      NOW() as inserted_at,
      NOW() as updated_at
    FROM packages p
    WHERE p.departure_date IS NOT NULL AND p.return_date IS NOT NULL AND p.quota IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM package_schedules ps WHERE ps.package_id = p.id
      )
    """

    # Add package_schedule_id to bookings table (nullable initially)
    alter table(:bookings) do
      add_if_not_exists :package_schedule_id, references(:package_schedules, on_delete: :delete_all)
    end

    create_if_not_exists index(:bookings, [:package_schedule_id])

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

    # Now ensure FK exists (without duplicating) and make package_schedule_id not null when safe
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'bookings' AND column_name = 'package_schedule_id'
      ) THEN
        -- Add FK only if it doesn't exist yet
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'bookings_package_schedule_id_fkey'
        ) THEN
          ALTER TABLE bookings
          ADD CONSTRAINT bookings_package_schedule_id_fkey
          FOREIGN KEY (package_schedule_id) REFERENCES package_schedules(id) ON DELETE CASCADE;
        END IF;

        -- Set NOT NULL only if no NULLs remain
        IF NOT EXISTS (
          SELECT 1 FROM bookings WHERE package_schedule_id IS NULL
        ) THEN
          ALTER TABLE bookings ALTER COLUMN package_schedule_id SET NOT NULL;
        END IF;
      END IF;
    END $$;
    """

    # Remove old columns from packages table (only if they exist)
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'packages' AND column_name = 'departure_date'
      ) THEN
        ALTER TABLE packages DROP COLUMN departure_date;
      END IF;
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'packages' AND column_name = 'return_date'
      ) THEN
        ALTER TABLE packages DROP COLUMN return_date;
      END IF;
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'packages' AND column_name = 'quota'
      ) THEN
        ALTER TABLE packages DROP COLUMN quota;
      END IF;
    END $$;
    """

    # Remove old columns from bookings table (only if they exist)
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'bookings' AND column_name = 'package_id'
      ) THEN
        ALTER TABLE bookings DROP COLUMN package_id;
      END IF;
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'bookings' AND column_name = 'travel_date'
      ) THEN
        ALTER TABLE bookings DROP COLUMN travel_date;
      END IF;
    END $$;
    """
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
    drop_if_exists table(:package_schedules)
  end
end
