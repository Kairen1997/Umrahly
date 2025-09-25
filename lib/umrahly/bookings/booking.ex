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
    field :payment_proof_file, :string
    field :payment_proof_notes, :string
    field :payment_proof_submitted_at, :utc_datetime
    field :payment_proof_status, :string, default: "pending"
    field :is_booking_for_self, :boolean, default: true
    belongs_to :user, Umrahly.Accounts.User
    belongs_to :package_schedule, Umrahly.Packages.PackageSchedule

    timestamps(type: :utc_datetime)
  end

  @doc """
  Step 1: Package Details
  Validates: user_id, package_schedule_id, number_of_persons
  """
  def changeset_step1(booking, attrs) do
    booking
    |> cast(attrs, [:user_id, :package_schedule_id, :number_of_persons, :is_booking_for_self])
    |> validate_required([:user_id, :package_schedule_id, :number_of_persons])
    |> validate_number(:number_of_persons, greater_than: 0, less_than_or_equal_to: 10)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:package_schedule_id)
  end

  @doc """
  Step 2: Travelers
  No validation needed in this schema (traveler info is in another table)
  Returns the booking unchanged
  """
  def changeset_step2(booking, _attrs) do
    # Traveler information is handled in a separate table
    # No validation needed in this step for the booking schema
    booking
  end

  @doc """
  Step 3: Payment
  Validates: deposit_amount, payment_plan, payment_method
  Includes deposit amount validation logic
  """
  def changeset_step3(booking, attrs) do
    booking
    |> cast(attrs, [:deposit_amount, :payment_plan, :payment_method])
    |> validate_required([:deposit_amount, :payment_plan, :payment_method])
    |> validate_inclusion(:payment_plan, ["full_payment", "installment"])
    |> validate_inclusion(:payment_method, ["credit_card", "bank_transfer", "online_banking", "cash", "toyyibpay"])
    |> validate_number(:deposit_amount, greater_than: 0)
    |> validate_deposit_amount()
  end

  @doc """
  Step 4: Review & Confirm
  Validates: total_amount, booking_date, notes (optional)
  """
  def changeset_step4(booking, attrs) do
    booking
    |> cast(attrs, [:total_amount, :booking_date, :notes])
    |> validate_required([:total_amount, :booking_date])
    |> validate_number(:total_amount, greater_than: 0)
    |> validate_date(:booking_date)
  end

  @doc """
  Step 5: Success & Proof Upload
  Validates: payment_proof_file, payment_proof_notes, payment_proof_status
  """
  def changeset_step5(booking, attrs) do
    booking
    |> cast(attrs, [:payment_proof_file, :payment_proof_notes, :payment_proof_status])
    |> validate_inclusion(:payment_proof_status, ["pending", "submitted", "approved", "rejected"])
    |> validate_payment_proof()
  end

  @doc """
  Final validation for completed bookings
  Validates all required fields and business rules
  """
  def changeset_final(booking, attrs) do
    booking
    |> cast(attrs, [:status, :amount, :total_amount, :deposit_amount, :number_of_persons, :payment_method, :payment_plan, :booking_date, :notes, :payment_proof_file, :payment_proof_notes, :payment_proof_submitted_at, :payment_proof_status, :user_id, :package_schedule_id, :is_booking_for_self])
    |> validate_required([:status, :total_amount, :deposit_amount, :number_of_persons, :payment_method, :payment_plan, :booking_date, :user_id, :package_schedule_id])
    |> validate_inclusion(:status, ["pending", "confirmed", "cancelled", "completed"])
    |> validate_inclusion(:payment_plan, ["full_payment", "installment"])
    |> validate_inclusion(:payment_method, ["credit_card", "bank_transfer", "online_banking", "cash", "toyyibpay"])
    |> validate_inclusion(:payment_proof_status, ["pending", "submitted", "approved", "rejected"])
    |> validate_number(:total_amount, greater_than: 0)
    |> validate_number(:deposit_amount, greater_than: 0)
    |> validate_number(:number_of_persons, greater_than: 0, less_than_or_equal_to: 10)
    |> validate_deposit_amount()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:package_schedule_id)
  end

  @doc """
  Legacy changeset for backward compatibility
  Use the step-specific changesets for new implementations
  """
  def changeset(booking, attrs) do
    changeset_final(booking, attrs)
  end

  # Private validation functions

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

      payment_plan == "installment" and Decimal.compare(deposit_amount, Decimal.mult(total_amount, Decimal.new("0.2"))) == :lt ->
        add_error(changeset, :deposit_amount, "Deposit amount must be at least 20% of total amount")

      true ->
        changeset
    end
  end

  defp validate_date(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      date when is_struct(date, Date) ->
        if Date.compare(date, Date.utc_today()) == :gt do
          changeset
        else
          add_error(changeset, field, "Booking date must be in the future")
        end
      _ -> add_error(changeset, field, "Invalid date format")
    end
  end

  defp validate_payment_proof(changeset) do
    payment_proof_file = get_field(changeset, :payment_proof_file)
    payment_proof_status = get_field(changeset, :payment_proof_status)

    cond do
      payment_proof_status == "submitted" and is_nil(payment_proof_file) ->
        add_error(changeset, :payment_proof_file, "Payment proof file is required when status is submitted")

      payment_proof_status == "approved" and is_nil(payment_proof_file) ->
        add_error(changeset, :payment_proof_file, "Payment proof file is required when status is approved")

      true ->
        changeset
    end
  end
end
