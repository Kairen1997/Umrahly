defmodule Umrahly.Packages do
  @moduledoc """
  The Packages context.
  """

  import Ecto.Query, warn: false
  alias Umrahly.Repo

  alias Umrahly.Packages.Package
  alias Umrahly.Packages.PackageSchedule

  @doc """
  Returns the list of packages.
  """
  def list_packages do
    Repo.all(Package)
  end

  @doc """
  Returns the list of packages with their schedules.
  """
  def list_packages_with_schedules do
    Package
    |> preload([:package_schedules])
    |> Repo.all()
  end

  @doc """
  Gets a single package.
  """
  def get_package!(id), do: Repo.get!(Package, id)

  @doc """
  Gets a single package with schedules.
  """
  def get_package_with_schedules!(id) do
    Package
    |> where([p], p.id == ^id)
    |> preload([:package_schedules])
    |> Repo.one!()
  end

  @doc """
  Creates a package.
  """
  def create_package(attrs \\ %{}) do
    %Package{}
    |> Package.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a package.
  """
  def update_package(%Package{} = package, attrs) do
    package
    |> Package.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Package.
  """
  def delete_package(%Package{} = package) do
    Repo.delete(package)
  end

  @doc """
  Returns a data structure for tracking package changes.
  """
  def change_package(%Package{} = package, _attrs \\ %{}) do
    Package.changeset(package, %{})
  end

  @doc """
  Returns the total count of packages.
  """
  def count_packages do
    Repo.aggregate(Package, :count, :id)
  end

  @doc """
  Returns the count of available (active) packages.
  """
  def count_available_packages do
    Package
    |> where([p], p.status == "active")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns the count of packages by status.
  """
  def count_packages_by_status(status) do
    Package
    |> where([p], p.status == ^status)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns comprehensive package statistics for the admin dashboard.
  """
  def get_package_statistics do
    total_packages = count_packages()
    active_packages = count_available_packages()
    inactive_packages = count_packages_by_status("inactive")

    # Count schedules with departure dates in the future
    upcoming_departures = PackageSchedule
    |> where([ps], ps.departure_date > ^Date.utc_today() and ps.status == "active")
    |> Repo.aggregate(:count, :id)

    # Sum total quota across all active schedules
    total_quota = PackageSchedule
    |> where([ps], ps.status == "active")
    |> select([ps], sum(ps.quota))
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
  """
  def get_expiring_soon_packages do
    thirty_days_from_now = Date.add(Date.utc_today(), 30)

    PackageSchedule
    |> where([ps], ps.departure_date <= ^thirty_days_from_now and ps.departure_date > ^Date.utc_today() and ps.status == "active")
    |> order_by([ps], [asc: ps.departure_date])
    |> preload([:package])
    |> Repo.all()
  end

  @doc """
  Returns packages with low quota (less than 10 available spots).
  """
  def get_low_quota_packages do
    PackageSchedule
    |> where([ps], ps.quota < 10 and ps.status == "active")
    |> order_by([ps], [asc: ps.quota])
    |> preload([:package])
    |> Repo.all()
  end

  @doc """
  Returns enhanced package statistics including low quota and expiring packages.
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

  # Package Schedule functions

  @doc """
  Returns the list of package schedules.
  """
  def list_package_schedules do
    PackageSchedule
    |> preload([:package])
    |> Repo.all()
  end

  @doc """
  Gets a single package schedule.
  """
  def get_package_schedule!(id), do: Repo.get!(PackageSchedule, id)

  @doc """
  Creates a package schedule.
  """
  def create_package_schedule(attrs \\ %{}) do
    %PackageSchedule{}
    |> PackageSchedule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a package schedule.
  """
  def update_package_schedule(%PackageSchedule{} = package_schedule, attrs) do
    package_schedule
    |> PackageSchedule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a package schedule.
  """
  def delete_package_schedule(%PackageSchedule{} = package_schedule) do
    Repo.delete(package_schedule)
  end

  @doc """
  Returns a data structure for tracking package schedule changes.
  """
  def change_package_schedule(%PackageSchedule{} = package_schedule, _attrs \\ %{}) do
    PackageSchedule.changeset(package_schedule, %{})
  end

  @doc """
  Returns booking statistics for a specific package schedule.
  """
  def get_package_schedule_booking_stats(schedule_id) do
    alias Umrahly.Bookings

    package_schedule = get_package_schedule!(schedule_id)
    total_bookings = Bookings.count_bookings_for_schedule(schedule_id)
    confirmed_bookings = Bookings.count_confirmed_bookings_for_schedule(schedule_id)

    # Use package_schedule.quota since quota is now in package_schedules
    available_slots = package_schedule.quota - confirmed_bookings
    booking_percentage = if package_schedule.quota > 0, do: (confirmed_bookings / package_schedule.quota) * 100, else: 0.0

    %{
      total_bookings: total_bookings,
      confirmed_bookings: confirmed_bookings,
      available_slots: available_slots,
      booking_percentage: Float.round(booking_percentage, 1)
    }
  end

  @doc """
  Returns all schedules for a specific package.
  """
  def get_package_schedules(package_id) do
    PackageSchedule
    |> where([ps], ps.package_id == ^package_id)
    |> order_by([ps], [asc: ps.departure_date])
    |> Repo.all()
  end

  @doc """
  Returns booking statistics for a specific package.
  """
  def get_package_booking_stats(package_id) do
    alias Umrahly.Bookings

    # Get all active schedules for this package to calculate total quota
    active_schedules = get_active_package_schedules(package_id)
    total_quota = Enum.reduce(active_schedules, 0, fn schedule, acc -> acc + schedule.quota end)

    total_bookings = Bookings.count_bookings_for_package(package_id)
    confirmed_bookings = Bookings.count_confirmed_bookings_for_package(package_id)
    available_slots = total_quota - confirmed_bookings
    booking_percentage = if total_quota > 0, do: (confirmed_bookings / total_quota) * 100, else: 0.0

    %{
      total_bookings: total_bookings,
      confirmed_bookings: confirmed_bookings,
      available_slots: available_slots,
      booking_percentage: Float.round(booking_percentage, 1)
    }
  end

  @doc """
  Returns active schedules for a specific package.
  """
  def get_active_package_schedules(package_id) do
    PackageSchedule
    |> where([ps], ps.package_id == ^package_id and ps.status == "active")
    |> order_by([ps], [asc: ps.departure_date])
    |> Repo.all()
  end

  @doc """
  Returns schedules with departure dates in the future.
  """
  def get_upcoming_schedules do
    PackageSchedule
    |> where([ps], ps.departure_date > ^Date.utc_today() and ps.status == "active")
    |> order_by([ps], [asc: ps.departure_date])
    |> preload([:package])
    |> Repo.all()
  end
end
