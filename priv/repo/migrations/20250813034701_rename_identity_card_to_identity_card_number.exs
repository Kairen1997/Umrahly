defmodule Umrahly.Repo.Migrations.RenameIdentityCardToIdentityCardNumber do
  use Ecto.Migration

  def change do
    rename table(:profiles), :identity_card, to: :identity_card_number
  end
end
