defmodule Umrahly.Packages.Itinerary do
  use Ecto.Schema
  import Ecto.Changeset

  schema "itineraries" do
    field :day_number, :integer
    field :day_title, :string
    field :day_description, :string
    field :itinerary_items, {:array, :map}
    field :order_index, :integer

    belongs_to :package, Umrahly.Packages.Package

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(itinerary, attrs) do
    itinerary
    |> cast(attrs, [:day_number, :day_title, :day_description, :itinerary_items, :order_index, :package_id])
    |> validate_required([:day_number, :day_title, :package_id])
    |> validate_number(:day_number, greater_than: 0)
    |> validate_number(:order_index, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:package_id)
  end
end
