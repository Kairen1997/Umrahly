defmodule Umrahly.Repo.Migrations.AddPictureToPackages do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add :picture, :string
    end
  end
end
