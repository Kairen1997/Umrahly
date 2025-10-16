defmodule Umrahly.Repo.Migrations.AddPackageIdToFlights do
  use Ecto.Migration

  def change do
    alter table(:flights) do
      add :package_id, references(:packages, on_delete: :nilify_all)
    end

    create index(:flights, [:package_id])
  end
end


