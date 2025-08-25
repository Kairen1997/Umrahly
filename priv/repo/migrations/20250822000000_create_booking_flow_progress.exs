defmodule Umrahly.Repo.Migrations.CreateBookingFlowProgress do
  use Ecto.Migration

  def change do
    create table(:booking_flow_progress) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :package_id, references(:packages, on_delete: :delete_all), null: false
      add :package_schedule_id, references(:package_schedules, on_delete: :delete_all), null: false
      add :current_step, :integer, default: 1, null: false
      add :max_steps, :integer, default: 4, null: false
      add :number_of_persons, :integer, default: 1, null: false
      add :is_booking_for_self, :boolean, default: true, null: false
      add :payment_method, :string, default: "bank_transfer", null: false
      add :payment_plan, :string, default: "full_payment", null: false
      add :notes, :text
      add :travelers_data, :jsonb, null: false
      add :total_amount, :decimal, precision: 10, scale: 2
      add :deposit_amount, :decimal, precision: 10, scale: 2
      add :status, :string, default: "in_progress", null: false
      add :last_updated, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:booking_flow_progress, [:user_id])
    create index(:booking_flow_progress, [:package_id])
    create index(:booking_flow_progress, [:package_schedule_id])
    create index(:booking_flow_progress, [:status])
    create index(:booking_flow_progress, [:user_id, :status])
    create unique_index(:booking_flow_progress, [:user_id, :package_schedule_id], where: "status = 'in_progress'")
  end
end
