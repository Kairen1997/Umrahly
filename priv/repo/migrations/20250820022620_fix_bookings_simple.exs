defmodule Umrahly.Repo.Migrations.FixBookingsSimple do
  use Ecto.Migration

  def change do
    # Just add the package_schedule_id column if it doesn't exist
    # We'll handle the data migration separately
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
  end
end
