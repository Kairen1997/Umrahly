defmodule Umrahly.Flights.Flight do
  use Ecto.Schema
  import Ecto.Changeset

  schema "flights" do
    field :status, :string
    field :origin, :string
    field :destination, :string
    field :flight_number, :string
    field :departure_time, :utc_datetime
    field :arrival_time, :utc_datetime
    field :aircraft, :string
    field :capacity_total, :integer
    field :capacity_booked, :integer
    field :return_date, :utc_datetime

    belongs_to :package, Umrahly.Packages.Package
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(flight, attrs) do
    flight
    |> cast(attrs, [:flight_number, :origin, :destination, :departure_time, :arrival_time, :aircraft, :capacity_total, :capacity_booked, :status, :return_date, :package_id])
    |> validate_required([:flight_number, :origin, :destination, :departure_time, :arrival_time, :aircraft, :capacity_total, :capacity_booked, :status, :return_date])
    |> unique_constraint(:flight_number)
    |> foreign_key_constraint(:package_id)
  end
end
