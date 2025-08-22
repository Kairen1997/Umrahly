defmodule Umrahly.Repo.Migrations.AddReturnDateToPackages do
  use Ecto.Migration

  def change do
    # First add the column as nullable
    alter table(:packages) do
      add :return_date, :date, null: true
    end

    # Update existing packages to have a return date (departure date + duration days)
    execute """
    UPDATE packages
    SET return_date = departure_date + duration_days
    WHERE return_date IS NULL
    """

    # Now make the column non-nullable
    alter table(:packages) do
      modify :return_date, :date, null: false
    end

    create index(:packages, [:return_date])
  end
end
