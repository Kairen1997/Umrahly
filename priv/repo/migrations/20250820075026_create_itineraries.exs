defmodule Umrahly.Repo.Migrations.CreateItineraries do
  use Ecto.Migration

  def change do
    create table(:itineraries) do
      add :day_number, :integer, null: false
      add :day_title, :string, null: false
      add :day_description, :text, null: true
      add :itinerary_items, {:array, :map}, default: []
      add :order_index, :integer, default: 0
      add :package_id, references(:packages, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:itineraries, [:package_id])
    create index(:itineraries, [:order_index])
    create index(:itineraries, [:day_number])
  end
end
