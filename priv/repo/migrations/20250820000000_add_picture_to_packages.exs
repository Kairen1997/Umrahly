defmodule Umrahly.Repo.Migrations.AddPictureToPackages do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add :picture, :string, null: true
    end
  end
end
