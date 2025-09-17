defmodule Umrahly.Packages.PackageSchedule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "package_schedules" do
    field :departure_date, :date
    field :return_date, :date
    field :quota, :integer
    field :status, :string, default: "active"
    field :price_override, :decimal
    field :notes, :string
    field :duration_days, :integer, virtual: true

    belongs_to :package, Umrahly.Packages.Package

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(package_schedule, attrs) do
    package_schedule
    |> cast(attrs, [:departure_date, :return_date, :quota, :status, :price_override, :notes, :package_id, :duration_days])
    |> validate_required([:departure_date, :return_date, :quota, :status, :package_id])
    |> validate_inclusion(:status, ["active", "inactive", "cancelled", "completed"])
    |> validate_inclusion(:quota, 1..100)
    |> validate_price_override()
    |> validate_future_dates()
    |> validate_dates()
    |> foreign_key_constraint(:package_id)
  end

  defp validate_future_dates(changeset) do
    # Only validate future dates if this is a new record or if dates are being changed
    is_new_record = changeset.data.id == nil
    has_departure_change = Map.has_key?(changeset.changes, :departure_date)
    has_return_change = Map.has_key?(changeset.changes, :return_date)

    if is_new_record or has_departure_change or has_return_change do
      departure = get_field(changeset, :departure_date)
      return = get_field(changeset, :return_date)

      departure_error = if departure, do: Date.compare(departure, Date.utc_today()) == :lt, else: false
      return_error = if return, do: Date.compare(return, Date.utc_today()) == :lt, else: false

      changeset
      |> maybe_add_error(:departure_date, departure_error, "Departure date must be in the future")
      |> maybe_add_error(:return_date, return_error, "Return date must be in the future")
    else
      changeset
    end
  end

  defp validate_dates(changeset) do
    departure = get_field(changeset, :departure_date)
    return = get_field(changeset, :return_date)

    if departure && return && Date.compare(return, departure) == :lt do
      add_error(changeset, :return_date, "Return date must be after departure date")
    else
      changeset
    end
  end

  defp maybe_add_error(changeset, _field, false, _msg), do: changeset
  defp maybe_add_error(changeset, field, true, msg), do: add_error(changeset, field, msg)

  defp validate_price_override(changeset) do
    price_override = get_field(changeset, :price_override)

    if price_override && price_override < 0 do
      add_error(changeset, :price_override, "Price override must be greater than 0")
    else
      changeset
    end
  end


end
