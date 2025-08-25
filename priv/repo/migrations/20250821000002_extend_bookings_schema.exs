defmodule Umrahly.Repo.Migrations.ExtendBookingsSchema do
  use Ecto.Migration

  def change do
    alter table(:bookings) do
      add :total_amount, :decimal, precision: 10, scale: 2
      add :deposit_amount, :decimal, precision: 10, scale: 2
      add :number_of_persons, :integer, default: 1
      add :payment_method, :string
      add :payment_plan, :string, default: "full_payment"
    end

    # Create indexes for the new fields
    create index(:bookings, [:payment_method])
    create index(:bookings, [:payment_plan])
    create index(:bookings, [:number_of_persons])

    # Update existing records to have default values
    execute """
    UPDATE bookings
    SET
      total_amount = COALESCE(amount, 0),
      deposit_amount = COALESCE(amount, 0),
      number_of_persons = 1,
      payment_method = 'bank_transfer',
      payment_plan = 'full_payment'
    WHERE total_amount IS NULL
    """

    # Make new fields not null after setting default values
    alter table(:bookings) do
      modify :total_amount, :decimal, precision: 10, scale: 2, null: false
      modify :deposit_amount, :decimal, precision: 10, scale: 2, null: false
      modify :number_of_persons, :integer, null: false
      modify :payment_method, :string, null: false
      modify :payment_plan, :string, null: false
    end
  end
end
