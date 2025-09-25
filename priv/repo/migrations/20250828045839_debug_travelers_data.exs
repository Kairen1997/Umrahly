defmodule Umrahly.Repo.Migrations.DebugTravelersData do
  use Ecto.Migration

  def up do
    # This migration is just for debugging - we'll add some test data
    # to see if the traveler data loading is working
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM users WHERE id = 1)
         AND EXISTS (SELECT 1 FROM packages WHERE id = 6)
         AND EXISTS (SELECT 1 FROM package_schedules WHERE id = 24) THEN
        INSERT INTO booking_flow_progress
        (user_id, package_id, package_schedule_id, current_step, max_steps, number_of_persons,
         is_booking_for_self, payment_method, payment_plan, travelers_data, status, last_updated, inserted_at, updated_at)
        VALUES
        (1, 6, 24, 2, 5, 1, true, 'bank_transfer', 'full_payment',
         '[{"full_name": "Test User", "identity_card_number": "123456789", "passport_number": "A12345678", "phone": "0123456789"}]',
         'in_progress', NOW(), NOW(), NOW())
        ON CONFLICT (user_id, package_schedule_id)
        DO UPDATE SET
          travelers_data = EXCLUDED.travelers_data,
          current_step = EXCLUDED.current_step,
          last_updated = NOW();
      END IF;
    END $$;
    """
  end

  def down do
    # Remove the test data
    execute "DELETE FROM booking_flow_progress WHERE user_id = 1 AND package_id = 6 AND package_schedule_id = 24;"
  end
end
