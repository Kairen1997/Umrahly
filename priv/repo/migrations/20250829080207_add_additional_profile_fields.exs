defmodule Umrahly.Repo.Migrations.AddAdditionalProfileFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :passport_number, :string
      add :poskod, :string
      add :city, :string
      add :state, :string
      add :citizenship, :string
      add :emergency_contact_name, :string
      add :emergency_contact_phone, :string
      add :emergency_contact_relationship, :string
    end

    # Create indexes for the new fields
    create index(:users, [:passport_number])
    create index(:users, [:city])
    create index(:users, [:state])
  end
end
