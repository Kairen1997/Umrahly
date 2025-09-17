defmodule Umrahly.ActivityLogs do
  @moduledoc """
  Context for recording and fetching user activity logs.
  """

  import Ecto.Query, warn: false
  alias Umrahly.Repo
  alias Umrahly.ActivityLogs.ActivityLog

  @spec log_user_action(integer(), String.t(), String.t() | nil, map() | nil) :: {:ok, ActivityLog.t()} | {:error, Ecto.Changeset.t()}
  def log_user_action(user_id, action, details \\ nil, metadata \\ %{}) do
    %ActivityLog{}
    |> ActivityLog.changeset(%{user_id: user_id, action: action, details: details, metadata: metadata || %{}})
    |> Repo.insert()
  end

  @spec recent_user_activities(integer(), pos_integer()) :: [ActivityLog.t()]
  def recent_user_activities(user_id, limit \\ 10) do
    ActivityLog
    |> where([a], a.user_id == ^user_id)
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
