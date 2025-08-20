defmodule Umrahly.Packages.Package do
  use Ecto.Schema
  import Ecto.Changeset

  schema "packages" do
    field :name, :string
    field :description, :string
    field :status, :string, default: "inactive"
    field :price, :integer
    field :duration_days, :integer
    field :duration_nights, :integer
    field :picture, :string
    field :accommodation_type, :string
    field :accommodation_details, :string
    field :transport_type, :string
    field :transport_details, :string

    has_many :package_schedules, Umrahly.Packages.PackageSchedule
    has_many :bookings, through: [:package_schedules, :bookings]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(package, attrs) do
    package
    |> cast(attrs, [:name, :description, :price, :duration_days, :duration_nights, :status, :picture, :accommodation_type, :accommodation_details, :transport_type, :transport_details])
    |> validate_required([:name, :price, :duration_days, :duration_nights, :status])
    |> validate_inclusion(:status, ["active", "inactive"])
    |> validate_inclusion(:duration_days, 1..30)
    |> validate_inclusion(:duration_nights, 1..30)
    |> validate_number(:price, greater_than: 0)
    |> validate_length(:picture, max: 255)
    |> validate_length(:accommodation_type, max: 100)
    |> validate_length(:transport_type, max: 100)
  end
end
