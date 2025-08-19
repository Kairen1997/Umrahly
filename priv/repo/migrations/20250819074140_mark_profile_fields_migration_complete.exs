defmodule Umrahly.Repo.Migrations.MarkProfileFieldsMigrationComplete do
  use Ecto.Migration

  def up do
    # The profile fields already exist in the users table
    # This migration is just to mark the previous migration as complete
    :ok
  end

  def down do
    # No rollback needed
    :ok
  end
end
