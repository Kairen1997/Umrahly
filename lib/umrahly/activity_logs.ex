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
    |> Enum.map(&format_activity/1)
  end

  # Added: Detailed list for admin activity log page
  @doc """
  Fetch detailed activity logs for the admin activity log page.
  Pulls metadata fields like status, ip_address, and user_agent when available.
  """
  @spec list_detailed_activities(pos_integer()) :: [map()]
  def list_detailed_activities(limit \\ 100) do
    ActivityLog
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
    |> Enum.map(&format_activity/1)
  end

  @doc """
  Paginated detailed activity logs with total count for table pagination.
  Returns a map: %{entries: [...], total: integer, page: integer, page_size: integer}
  """
  @spec list_detailed_activities_paginated(pos_integer(), pos_integer()) :: %{entries: [map()], total: non_neg_integer(), page: pos_integer(), page_size: pos_integer()}
  def list_detailed_activities_paginated(page \\ 1, page_size \\ 10) do
    safe_page = max(page, 1)
    safe_page_size = max(page_size, 1)
    offset_val = (safe_page - 1) * safe_page_size

    total = Repo.aggregate(ActivityLog, :count, :id)

    entries =
      ActivityLog
      |> order_by([a], desc: a.inserted_at)
      |> limit(^safe_page_size)
      |> offset(^offset_val)
      |> preload(:user)
      |> Repo.all()
      |> Enum.map(&format_activity/1)

    %{
      entries: entries,
      total: total,
      page: safe_page,
      page_size: safe_page_size
    }
  end

  @doc """
  Fetch all detailed activities (not paginated), newest first. Intended for exports.
  """
  @spec list_all_detailed_activities() :: [map()]
  def list_all_detailed_activities do
    ActivityLog
    |> order_by([a], desc: a.inserted_at)
    |> preload(:user)
    |> Repo.all()
    |> Enum.map(&format_activity/1)
  end

  defp format_activity(activity) do
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
          ndt |> DateTime.from_naive!("Etc/UTC") |> UmrahlyWeb.Timezone.to_local() |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
        %DateTime{} = dt ->
          UmrahlyWeb.Timezone.format_local(dt, "%Y-%m-%d %H:%M:%S")
        _ ->
          ""
      end

    metadata = activity.metadata || %{}

    %{
      id: activity.id,
      user_name: user_name,
      action: activity.action,
      details: activity.details || "",
      timestamp: formatted_time,
      ip_address: Map.get(metadata, "ip_address") || Map.get(metadata, :ip_address),
      user_agent: Map.get(metadata, "user_agent") || Map.get(metadata, :user_agent),
      status: Map.get(metadata, "status") || Map.get(metadata, :status)
    }
  end
end
