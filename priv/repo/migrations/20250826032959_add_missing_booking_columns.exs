defmodule Umrahly.Repo.Migrations.AddMissingBookingColumns do
  use Ecto.Migration

  def change do
    # Add only the missing columns that are causing the error
    alter table(:bookings) do
      # Add deposit_amount column if it doesn't exist
      add_if_not_exists :deposit_amount, :decimal, precision: 10, scale: 2

      # Add total_amount column if it doesn't exist
      add_if_not_exists :total_amount, :decimal, precision: 10, scale: 2

      # Add number_of_persons column if it doesn't exist
      add_if_not_exists :number_of_persons, :integer, default: 1

      # Add payment_method column if it doesn't exist
      add_if_not_exists :payment_method, :string

      # Add payment_plan column if it doesn't exist
      add_if_not_exists :payment_plan, :string, default: "full_payment"
    end

    # Update existing records to have default values
    execute """
    UPDATE bookings
    SET
      total_amount = COALESCE(amount, 0),
      deposit_amount = COALESCE(amount, 0),
      number_of_persons = 1,
      payment_method = 'bank_transfer',
      payment_plan = 'full_payment'
    WHERE total_amount IS NULL OR deposit_amount IS NULL
    """
  end
end
