defmodule Umrahly.Packages.Package do
  use Ecto.Schema
  import Ecto.Changeset

  schema "packages" do
    field :name, :string
    field :status, :string, default: "inactive"
    field :price, :integer
    field :duration_days, :integer
    field :duration_nights, :integer
    field :quota, :integer
    field :departure_date, :date

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(package, attrs) do
    package
    |> cast(attrs, [:name, :price, :duration_days, :duration_nights, :quota, :departure_date, :status])
    |> validate_required([:name, :price, :duration_days, :duration_nights, :quota, :departure_date, :status])
    |> validate_inclusion(:status, ["active", "inactive"])
    |> validate_inclusion(:duration_days, 1..30)
    |> validate_inclusion(:duration_nights, 1..30)
    |> validate_inclusion(:quota, 1..100)
    |> validate_change(:departure_date, fn _, departure_date ->
      if Date.compare(departure_date, Date.utc_today()) == :lt do
        [{:departure_date, "Departure date must be in the future"}]
      else
        []
      end
    end)
    |> validate_number(:price, greater_than: 0)
  end
end
