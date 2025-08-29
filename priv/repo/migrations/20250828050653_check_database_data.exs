defmodule Umrahly.Repo.Migrations.CheckDatabaseData do
  use Ecto.Migration

  def up do
    # Check what's currently in the database
    execute """
    SELECT
      id,
      user_id,
      package_id,
      package_schedule_id,
      travelers_data,
      pg_typeof(travelers_data) as data_type
    FROM booking_flow_progress
    WHERE user_id = 1 AND package_id = 6 AND package_schedule_id = 24;
    """

    # Fix the data format - ensure it's a proper JSONB array
    execute """
    UPDATE booking_flow_progress
    SET travelers_data = '[{"full_name": "Test User", "identity_card_number": "123456789", "passport_number": "A12345678", "phone": "0123456789"}]'::jsonb
    WHERE user_id = 1 AND package_id = 6 AND package_schedule_id = 24;
    """

    # Verify the fix
    execute """
    SELECT
      id,
      user_id,
      package_id,
      package_schedule_id,
      travelers_data,
      pg_typeof(travelers_data) as data_type,
      jsonb_array_length(travelers_data) as array_length
    FROM booking_flow_progress
    WHERE user_id = 1 AND package_id = 6 AND package_schedule_id = 24;
    """
  end

  def down do
    # No rollback needed for this debug migration
  end
end
