defmodule Umrahly.ActivityLogs do
  @moduledoc """
  Context for recording and fetching user activity logs.
  """

  import Ecto.Query, warn: false
  alias Umrahly.Repo
  alias Umrahly.ActivityLogs.ActivityLog

  @type activity_log :: %ActivityLog{}

  @spec log_user_action(integer(), String.t(), String.t() | nil, map() | nil) :: {:ok, activity_log()} | {:error, Ecto.Changeset.t()}
  def log_user_action(user_id, action, details \\ nil, metadata \\ %{}) do
    %ActivityLog{}
    |> ActivityLog.changeset(%{user_id: user_id, action: action, details: details, metadata: metadata || %{}})
    |> Repo.insert()
  end

  @spec recent_user_activities(integer(), pos_integer()) :: [activity_log()]
  def recent_user_activities(user_id, limit \\ 10) do
    ActivityLog
    |> where([a], a.user_id == ^user_id)
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Fetch recent activities across all users, formatted for admin dashboard.
  """
  @spec recent_activities(pos_integer()) :: [map()]
  def recent_activities(limit \\ 10) do
    ActivityLog
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
    |> Enum.map(fn activity ->
      user = Map.get(activity, :user)
      user_name =
        cond do
          match?(%{full_name: name} when is_binary(name), user) and String.trim(user.full_name) != "" -> user.full_name
          match?(%{email: email} when is_binary(email), user) -> user.email
          true -> "User #{activity.user_id}"
        end

      formatted_time =
        case activity.inserted_at do
          %NaiveDateTime{} = ndt ->
            ndt |> UmrahlyWeb.Timezone.to_local() |> Calendar.strftime("%B %d, %Y at %I:%M %p")
          %DateTime{} = dt ->
            UmrahlyWeb.Timezone.format_local(dt, "%B %d, %Y at %I:%M %p")
          _ ->
            ""
        end

      %{
        title: user_name,
        activity_message: activity.details || activity.action,
        timestamp: formatted_time,
        action: activity.action
      }
    end)
  end
end
