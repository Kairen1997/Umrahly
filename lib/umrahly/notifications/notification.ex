defmodule Umrahly.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :title, :string
    field :message, :string
    field :read, :boolean, default: false
    field :notification_type, :string
    field :metadata, :map, default: %{}

    belongs_to :user, Umrahly.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:title, :message, :read, :notification_type, :metadata, :user_id])
    |> validate_required([:title, :message, :notification_type, :user_id])
    |> validate_inclusion(:notification_type, [
      "booking_created", "booking_cancelled", "payment_received",
      "payment_approved", "payment_rejected", "package_updated",
      "booking_confirmed", "booking_reminder", "admin_alert"
    ])
    |> foreign_key_constraint(:user_id)
  end
end
