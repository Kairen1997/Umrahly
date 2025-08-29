defmodule Umrahly.Repo.Migrations.FixAmountColumnConstraint do
  use Ecto.Migration

  def change do
    # First, update any null amount values to use total_amount
    execute """
    UPDATE bookings
    SET amount = total_amount
    WHERE amount IS NULL AND total_amount IS NOT NULL
    """

    # Make amount column nullable since it's not required anymore
    alter table(:bookings) do
      modify :amount, :decimal, precision: 10, scale: 2, null: true
    end

    # Set default value for amount to match total_amount for new records
    execute """
    ALTER TABLE bookings
    ALTER COLUMN amount SET DEFAULT 0
    """
  end
end
