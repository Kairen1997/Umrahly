defmodule Umrahly.Repo.Migrations.AddAccommodationTransportToPackages do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add :accommodation_type, :string
      add :accommodation_details, :text
      add :transport_type, :string
      add :transport_details, :text
    end
  end
end
