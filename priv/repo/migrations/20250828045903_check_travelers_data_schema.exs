defmodule Umrahly.Repo.Migrations.CheckTravelersDataSchema do
  use Ecto.Migration

  def up do
    # Check if travelers_data column exists and has the right type
    execute """
    DO $$
    BEGIN
      -- Check if travelers_data column exists
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'booking_flow_progress'
        AND column_name = 'travelers_data'
      ) THEN
        -- Add the column if it doesn't exist
        ALTER TABLE booking_flow_progress ADD COLUMN travelers_data JSONB DEFAULT '[]'::jsonb NOT NULL;
      END IF;

      -- Check if the column type is correct
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'booking_flow_progress'
        AND column_name = 'travelers_data'
        AND data_type != 'jsonb'
      ) THEN
        -- Convert to JSONB if it's not already
        ALTER TABLE booking_flow_progress ALTER COLUMN travelers_data TYPE JSONB USING travelers_data::jsonb;
      END IF;
    END $$;
    """

    # Also ensure the column is not null and has a default
    execute """
    ALTER TABLE booking_flow_progress
    ALTER COLUMN travelers_data SET NOT NULL,
    ALTER COLUMN travelers_data SET DEFAULT '[]'::jsonb;
    """
  end

  def down do
    # This is a schema check migration, no rollback needed
  end
end
