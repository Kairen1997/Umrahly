defmodule Umrahly.Repo.Migrations.UpdateBookingFlowProgressMaxSteps do
  use Ecto.Migration

  def up do
    # Update existing booking flow progress records to have 5 steps instead of 4
    execute "UPDATE booking_flow_progress SET max_steps = 5 WHERE max_steps = 4"

    # Also update any records that might have current_step = 4 to current_step = 5
    # if they are completed bookings
    execute """
    UPDATE booking_flow_progress
    SET current_step = 5
    WHERE current_step = 4 AND status = 'completed'
    """
  end

  def down do
    # Rollback: change back to 4 steps
    execute "UPDATE booking_flow_progress SET max_steps = 4 WHERE max_steps = 5"
    execute "UPDATE booking_flow_progress SET current_step = 4 WHERE current_step = 5"
  end
end
