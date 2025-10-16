defmodule Umrahly.Repo.Migrations.AddContentAndPhotoToItineraries do
  use Ecto.Migration

  def change do
    alter table(:itineraries) do
      add :itinerary_content, :text
      add :day_photo, :string
    end

    create index(:itineraries, [:package_id, :order_index])
  end
end
