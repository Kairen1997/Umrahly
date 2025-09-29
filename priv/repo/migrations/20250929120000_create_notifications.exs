defmodule Umrahly.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :message, :text, null: false
      add :read, :boolean, default: false, null: false
      add :notification_type, :string, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:read])
    create index(:notifications, [:notification_type])
    create index(:notifications, [:inserted_at])
    create index(:notifications, [:user_id, :read])
  end
end
