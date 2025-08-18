defmodule Umrahly.Repo.Migrations.AddAdminRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_admin, :boolean, default: false, null: false
    end

    create index(:users, [:is_admin])
  end
end
