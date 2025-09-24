defmodule Umrahly.Repo.Migrations.FixPackageDepartureDateColumn do
  use Ecto.Migration

  def up do
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'packages' AND column_name = 'depature_date'
      ) THEN
        ALTER TABLE packages RENAME COLUMN depature_date TO departure_date;
      END IF;
    END$$;
    """
  end

  def down do
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'packages' AND column_name = 'departure_date'
      ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'packages' AND column_name = 'depature_date'
      ) THEN
        ALTER TABLE packages RENAME COLUMN departure_date TO depature_date;
      END IF;
    END$$;
    """
  end
end
