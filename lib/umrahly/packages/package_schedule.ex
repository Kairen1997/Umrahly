defmodule Umrahly.Packages.PackageSchedule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "package_schedules" do
    field :departure_date, :date
    field :return_date, :date
    field :quota, :integer
    field :status, :string, default: "active"
    field :price_override, :integer
    field :notes, :string

    belongs_to :package, Umrahly.Packages.Package

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(package_schedule, attrs) do
    package_schedule
    |> cast(attrs, [:departure_date, :return_date, :quota, :status, :price_override, :notes, :package_id])
    |> validate_required([:departure_date, :return_date, :quota, :status, :package_id])
    |> validate_inclusion(:status, ["active", "inactive", "cancelled", "completed"])
    |> validate_inclusion(:quota, 1..100)
    |> validate_change(:departure_date, fn _, departure_date ->
      if Date.compare(departure_date, Date.utc_today()) == :lt do
        [{:departure_date, "Departure date must be in the future"}]
      else
        []
      end
    end)
    |> validate_change(:return_date, fn _, return_date ->
      if Date.compare(return_date, Date.utc_today()) == :lt do
        [{:return_date, "Return date must be in the future"}]
      else
        []
      end
    end)
    |> validate_change(:return_date, fn _, return_date ->
      case package_schedule.departure_date do
        nil -> []
        departure_date ->
          if Date.compare(return_date, departure_date) == :lt do
            [{:return_date, "Return date must be after departure date"}]
          else
            []
          end
      end
    end)
    |> validate_number(:quota, greater_than: 0)
    |> validate_number(:price_override, greater_than: 0)
    |> foreign_key_constraint(:package_id)
  end
end
