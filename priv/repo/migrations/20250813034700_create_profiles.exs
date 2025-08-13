defmodule Umrahly.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles) do
      add :identity_card, :string
      add :phone_number, :string
      add :address, :string
      add :monthly_income, :integer
      add :birthdate, :date
      add :gender, :string
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:profiles, [:user_id])
  end
end
