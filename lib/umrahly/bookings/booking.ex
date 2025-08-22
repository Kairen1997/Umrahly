defmodule Umrahly.Bookings.Booking do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bookings" do
    field :status, :string, default: "pending"
    field :amount, :decimal
    field :total_amount, :decimal
    field :deposit_amount, :decimal
    field :number_of_persons, :integer, default: 1
    field :payment_method, :string
    field :payment_plan, :string, default: "full_payment"
    field :booking_date, :date
    field :notes, :string

    belongs_to :user, Umrahly.Accounts.User
    belongs_to :package_schedule, Umrahly.Packages.PackageSchedule

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(booking, attrs) do
    booking
    |> cast(attrs, [:status, :amount, :total_amount, :deposit_amount, :number_of_persons, :payment_method, :payment_plan, :booking_date, :notes, :user_id, :package_schedule_id])
    |> validate_required([:status, :total_amount, :deposit_amount, :number_of_persons, :payment_method, :payment_plan, :booking_date, :user_id, :package_schedule_id])
    |> validate_inclusion(:status, ["pending", "confirmed", "cancelled", "completed"])
    |> validate_inclusion(:payment_plan, ["full_payment", "installment"])
    |> validate_inclusion(:payment_method, ["credit_card", "bank_transfer", "online_banking", "cash"])
    |> validate_number(:total_amount, greater_than: 0)
    |> validate_number(:deposit_amount, greater_than: 0)
    |> validate_number(:number_of_persons, greater_than: 0, less_than_or_equal_to: 10)
    |> validate_deposit_amount()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:package_schedule_id)
  end

  defp validate_deposit_amount(changeset) do
    total_amount = get_field(changeset, :total_amount)
    deposit_amount = get_field(changeset, :deposit_amount)
    payment_plan = get_field(changeset, :payment_plan)

    cond do
      is_nil(total_amount) or is_nil(deposit_amount) ->
        changeset

      payment_plan == "full_payment" and Decimal.compare(deposit_amount, total_amount) != :eq ->
        add_error(changeset, :deposit_amount, "Deposit amount must equal total amount for full payment")

      payment_plan == "installment" and Decimal.compare(deposit_amount, total_amount) == :gt ->
        add_error(changeset, :deposit_amount, "Deposit amount cannot exceed total amount")

      payment_plan == "installment" and Decimal.compare(deposit_amount, Decimal.mult(total_amount, Decimal.new("0.1"))) == :lt ->
        add_error(changeset, :deposit_amount, "Deposit amount must be at least 10% of total amount")

      true ->
        changeset
    end
  end
end
