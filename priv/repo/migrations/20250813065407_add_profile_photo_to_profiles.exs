defmodule Umrahly.Repo.Migrations.AddProfilePhotoToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :profile_photo, :string
    end
  end
end
