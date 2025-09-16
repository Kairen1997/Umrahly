defmodule Umrahly.ActivityLogs.ActivityLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id
  schema "activity_logs" do
    field :action, :string
    field :details, :string
    field :metadata, :map, default: %{}

    belongs_to :user, Umrahly.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(activity_log, attrs) do
    activity_log
    |> cast(attrs, [:user_id, :action, :details, :metadata])
    |> validate_required([:user_id, :action])
    |> validate_length(:action, max: 255)
  end
end
