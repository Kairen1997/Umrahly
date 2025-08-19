defmodule Umrahly.Packages do
  @moduledoc """
  The Packages context.
  """

  import Ecto.Query, warn: false
  alias Umrahly.Repo

  alias Umrahly.Packages.Package

  @doc """
  Returns the list of packages.

  ## Examples

      iex> list_packages()
      [%Package{}, ...]

  """
  def list_packages do
    Repo.all(Package)
  end

  @doc """
  Gets a single package.

  Raises if the Package does not exist.

  ## Examples

      iex> get_package!(123)
      %Package{}

  """
  def get_package!(id), do: Repo.get!(Package, id)

  @doc """
  Creates a package.

  ## Examples

      iex> create_package(%{field: value})
      {:ok, %Package{}}

      iex> create_package(%{field: bad_value})
      {:error, ...}

  """
  def create_package(attrs \\ %{}) do
    %Package{}
    |> Package.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a package.

  ## Examples

      iex> update_package(package, %{field: new_value})
      {:ok, %Package{}}

      iex> update_package(package, %{field: bad_value})
      {:error, ...}

  """
  def update_package(%Package{} = package, attrs) do
    package
    |> Package.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Package.

  ## Examples

      iex> delete_package(package)
      {:ok, %Package{}}

      iex> delete_package(package)
      {:error, ...}

  """
  def delete_package(%Package{} = package) do
    Repo.delete(package)
  end

  @doc """
  Returns a data structure for tracking package changes.

  ## Examples

      iex> change_package(package)
      %Todo{...}

  """
  def change_package(%Package{} = package, _attrs \\ %{}) do
    Package.changeset(package, %{})
  end

  @doc """
  Returns the total count of packages.

  ## Examples

      iex> count_packages()
      6

  """
  def count_packages do
    Repo.aggregate(Package, :count, :id)
  end

  @doc """
  Returns the count of available (active) packages.

  ## Examples

      iex> count_available_packages()
      4

  """
  def count_available_packages do
    Package
    |> where([p], p.status == "active")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns the count of packages by status.

  ## Examples

      iex> count_packages_by_status("active")
      4

      iex> count_packages_by_status("inactive")
      2

  """
  def count_packages_by_status(status) do
    Package
    |> where([p], p.status == ^status)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns comprehensive package statistics for the admin dashboard.

  ## Examples

      iex> get_package_statistics()
      %{
        total_packages: 6,
        active_packages: 4,
        inactive_packages: 2,
        upcoming_departures: 3,
        total_quota: 120
      }

  """
  def get_package_statistics do
    total_packages = count_packages()
    active_packages = count_available_packages()
    inactive_packages = count_packages_by_status("inactive")

    # Count packages with departure dates in the future
    upcoming_departures = Package
    |> where([p], p.departure_date > ^Date.utc_today())
    |> Repo.aggregate(:count, :id)

    # Sum total quota across all packages
    total_quota = Package
    |> select([p], sum(p.quota))
    |> Repo.one() || 0

    %{
      total_packages: total_packages,
      active_packages: active_packages,
      inactive_packages: inactive_packages,
      upcoming_departures: upcoming_departures,
      total_quota: total_quota
    }
  end

  @doc """
  Returns recent package activities for the admin dashboard.

  ## Examples

      iex> get_recent_package_activities(5)
      [
        %{
          action: "created",
          package_name: "Premium Umrah Package",
          timestamp: ~U[2024-08-19 10:00:00Z]
        }
      ]

  """
  def get_recent_package_activities(limit \\ 5) do
    Package
    |> order_by([p], [desc: p.inserted_at])
    |> limit(^limit)
    |> select([p], %{
      action: "created",
      package_name: p.name,
      timestamp: p.inserted_at,
      status: p.status
    })
    |> Repo.all()
    |> Enum.map(fn activity ->
      # Format the timestamp for display
      formatted_time = Calendar.strftime(activity.timestamp, "%B %d, %Y at %I:%M %p")

      %{
        action: activity.action,
        package_name: activity.package_name,
        timestamp: activity.timestamp,
        formatted_time: formatted_time,
        status: activity.status
      }
    end)
  end

  @doc """
  Returns packages that are expiring soon (departure date within 30 days).

  ## Examples

      iex> get_expiring_soon_packages()
      [%Package{}, ...]

  """
  def get_expiring_soon_packages do
    thirty_days_from_now = Date.add(Date.utc_today(), 30)

    Package
    |> where([p], p.departure_date <= ^thirty_days_from_now and p.departure_date > ^Date.utc_today())
    |> order_by([p], [asc: p.departure_date])
    |> Repo.all()
  end

  @doc """
  Returns packages with low quota (less than 10 available spots).

  ## Examples

      iex> get_low_quota_packages()
      [%Package{}, ...]

  """
  def get_low_quota_packages do
    Package
    |> where([p], p.quota < 10 and p.status == "active")
    |> order_by([p], [asc: p.quota])
    |> Repo.all()
  end

  @doc """
  Returns enhanced package statistics including low quota and expiring packages.

  ## Examples

      iex> get_enhanced_package_statistics()
      %{
        total_packages: 6,
        active_packages: 4,
        inactive_packages: 2,
        upcoming_departures: 3,
        total_quota: 120,
        low_quota_packages: 2,
        expiring_soon_count: 3
      }

  """
  def get_enhanced_package_statistics do
    basic_stats = get_package_statistics()
    low_quota_count = length(get_low_quota_packages())
    expiring_soon_count = length(get_expiring_soon_packages())

    Map.merge(basic_stats, %{
      low_quota_packages: low_quota_count,
      expiring_soon_count: expiring_soon_count
    })
  end
end
