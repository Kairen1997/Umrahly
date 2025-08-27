defmodule Umrahly.Bookings.BookingFlowProgress do
  use Ecto.Schema
  import Ecto.Changeset

  schema "booking_flow_progress" do
    field :current_step, :integer, default: 1
    field :max_steps, :integer, default: 5
    field :number_of_persons, :integer, default: 1
    field :is_booking_for_self, :boolean, default: true
    field :payment_method, :string, default: "bank_transfer"
    field :payment_plan, :string, default: "full_payment"
    field :notes, :string
    field :travelers_data, :map
    field :total_amount, :decimal
    field :deposit_amount, :decimal
    field :status, :string, default: "in_progress"
    field :last_updated, :utc_datetime

    belongs_to :user, Umrahly.Accounts.User
    belongs_to :package, Umrahly.Packages.Package
    belongs_to :package_schedule, Umrahly.Packages.PackageSchedule

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(booking_flow_progress, attrs) do
    booking_flow_progress
    |> cast(attrs, [:current_step, :max_steps, :number_of_persons, :is_booking_for_self, :payment_method, :payment_plan, :notes, :travelers_data, :total_amount, :deposit_amount, :status, :last_updated, :user_id, :package_id, :package_schedule_id])
    |> validate_required([:current_step, :max_steps, :number_of_persons, :is_booking_for_self, :payment_method, :payment_plan, :status, :last_updated, :user_id, :package_id, :package_schedule_id])
    |> validate_required([:travelers_data])
    |> validate_inclusion(:status, ["in_progress", "completed", "abandoned"])
    |> validate_inclusion(:payment_plan, ["full_payment", "installment"])
    |> validate_inclusion(:payment_method, ["credit_card", "bank_transfer", "online_banking", "cash"])
    |> validate_number(:current_step, greater_than: 0, less_than_or_equal_to: 4)
    |> validate_number(:max_steps, greater_than: 0, less_than_or_equal_to: 4)
    |> validate_number(:number_of_persons, greater_than: 0, less_than_or_equal_to: 10)
    |> validate_optional_amounts()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:package_id)
    |> foreign_key_constraint(:package_schedule_id)
  end

  # Validate amounts only if they are present
  defp validate_optional_amounts(changeset) do
    total_amount = get_field(changeset, :total_amount)
    deposit_amount = get_field(changeset, :deposit_amount)

    changeset
    |> maybe_validate_number(:total_amount, total_amount, greater_than: 0)
    |> maybe_validate_number(:deposit_amount, deposit_amount, greater_than: 0)
  end

  defp maybe_validate_number(changeset, field, value, opts) when not is_nil(value) do
    validate_number(changeset, field, opts)
  end

  defp maybe_validate_number(changeset, _field, _value, _opts) do
    changeset
  end
end
