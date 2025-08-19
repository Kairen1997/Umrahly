defmodule Umrahly.Repo.Migrations.AddDescriptionToPackages do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add :description, :text
    end
  end
end
