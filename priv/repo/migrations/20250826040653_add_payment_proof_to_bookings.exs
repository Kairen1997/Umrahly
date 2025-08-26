defmodule Umrahly.Repo.Migrations.AddPaymentProofToBookings do
  use Ecto.Migration

  def change do
    alter table(:bookings) do
      add :payment_proof_file, :string
      add :payment_proof_notes, :string
      add :payment_proof_submitted_at, :utc_datetime
      add :payment_proof_status, :string, default: "pending"
    end

    create index(:bookings, [:payment_proof_status])
  end
end
