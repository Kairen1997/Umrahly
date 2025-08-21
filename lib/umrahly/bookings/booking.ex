defmodule Umrahly.Bookings.Booking do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bookings" do
    field :status, :string, default: "pending"
    field :amount, :decimal
    field :booking_date, :date
    field :notes, :string

    belongs_to :user, Umrahly.Accounts.User
    belongs_to :package, Umrahly.Packages.Package
    belongs_to :package_schedule, Umrahly.Packages.PackageSchedule

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(booking, attrs) do
    booking
    |> cast(attrs, [:status, :amount, :booking_date, :notes, :user_id, :package_id, :package_schedule_id])
    |> validate_required([:status, :amount, :booking_date, :user_id, :package_id, :package_schedule_id])
    |> validate_inclusion(:status, ["pending", "confirmed", "cancelled", "completed"])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:package_id)
    |> foreign_key_constraint(:package_schedule_id)
  end
end
