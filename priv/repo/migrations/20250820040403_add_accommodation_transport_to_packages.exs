defmodule Umrahly.Repo.Migrations.AddAccommodationTransportToPackages do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add :accommodation_type, :string, null: true
      add :accommodation_details, :text, null: true
      add :transport_type, :string, null: true
      add :transport_details, :text, null: true
    end
  end
end
