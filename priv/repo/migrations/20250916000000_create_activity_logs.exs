defmodule Umrahly.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :action, :string, null: false
      add :details, :text
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:activity_logs, [:user_id])
    create index(:activity_logs, [:inserted_at])
  end
end
