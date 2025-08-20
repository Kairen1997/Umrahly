defmodule Umrahly.Repo.Migrations.FixBookingsSchemaGracefully do
  use Ecto.Migration

  def change do
    # First, let's check if we have any existing bookings that might cause issues
    execute """
    DO $$
    DECLARE
      existing_bookings_count INTEGER;
      package_schedules_count INTEGER;
    BEGIN
      -- Count existing bookings
      SELECT COUNT(*) INTO existing_bookings_count FROM bookings;

      -- Count package schedules
      SELECT COUNT(*) INTO package_schedules_count FROM package_schedules;

      -- If we have bookings but no package schedules, we need to handle this
      IF existing_bookings_count > 0 AND package_schedules_count = 0 THEN
        -- Create a default package schedule for existing packages
        INSERT INTO package_schedules (package_id, departure_date, return_date, quota, status, inserted_at, updated_at)
        SELECT DISTINCT
          p.id,
          COALESCE(p.departure_date, CURRENT_DATE + INTERVAL '30 days'),
          COALESCE(p.return_date, CURRENT_DATE + INTERVAL '37 days'),
          COALESCE(p.quota, 50),
          'active',
          NOW(),
          NOW()
        FROM packages p
        WHERE p.id IN (SELECT DISTINCT package_id FROM bookings WHERE package_id IS NOT NULL);
      END IF;
    END $$;
    """

    # Add package_schedule_id column if it doesn't exist
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'bookings' AND column_name = 'package_schedule_id'
      ) THEN
        ALTER TABLE bookings ADD COLUMN package_schedule_id INTEGER REFERENCES package_schedules(id) ON DELETE CASCADE;
      END IF;
    END $$;
    """

    # Create index for package_schedule_id if it doesn't exist
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'bookings' AND indexname = 'bookings_package_schedule_id_index'
      ) THEN
        CREATE INDEX bookings_package_schedule_id_index ON bookings(package_schedule_id);
      END IF;
    END $$;
    """

    # Update existing bookings to reference package_schedules
    execute """
    UPDATE bookings
    SET package_schedule_id = (
      SELECT ps.id
      FROM package_schedules ps
      WHERE ps.package_id = bookings.package_id
      LIMIT 1
    )
    WHERE package_schedule_id IS NULL AND package_id IS NOT NULL;
    """

    # Only make package_schedule_id not null if all records have been updated successfully
    execute """
    DO $$
    DECLARE
      null_count INTEGER;
    BEGIN
      -- Check if there are any remaining null values
      SELECT COUNT(*) INTO null_count
      FROM bookings
      WHERE package_schedule_id IS NULL;

      -- Only set NOT NULL if all records have been updated
      IF null_count = 0 THEN
        ALTER TABLE bookings ALTER COLUMN package_schedule_id SET NOT NULL;
      END IF;
    END $$;
    """

    # Remove old package_id column if it exists and package_schedule_id is not null
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'bookings' AND column_name = 'package_id'
      ) AND NOT EXISTS (
        SELECT 1 FROM bookings WHERE package_schedule_id IS NULL
      ) THEN
        ALTER TABLE bookings DROP COLUMN package_id;
      END IF;
    END $$;
    """

    # Remove travel_date column if it exists
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'bookings' AND column_name = 'travel_date'
      ) THEN
        ALTER TABLE bookings DROP COLUMN travel_date;
      END IF;
    END $$;
    """
  end
end
