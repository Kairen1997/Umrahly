defmodule Umrahly.Bookings do
  @moduledoc """
  The Bookings context.
  """

  import Ecto.Query, warn: false
  alias Umrahly.Repo
  alias Umrahly.Bookings.Booking

  @doc """
  Returns the list of bookings.
  """
  def list_bookings do
    Repo.all(Booking)
  end

  @doc """
  Gets a single booking.
  """
  def get_booking!(id), do: Repo.get!(Booking, id)

  @doc """
  Creates a booking.
  """
  def create_booking(attrs \\ %{}) do
    %Booking{}
    |> Booking.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a booking.
  """
  def update_booking(%Booking{} = booking, attrs) do
    booking
    |> Booking.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a booking.
  """
  def delete_booking(%Booking{} = booking) do
    Repo.delete(booking)
  end

  @doc """
  Returns a data structure for tracking booking changes.
  """
  def change_booking(%Booking{} = booking, _attrs \\ %{}) do
    Booking.changeset(booking, %{})
  end

  @doc """
  Gets all bookings for a specific package schedule.
  """
  def get_bookings_for_schedule(schedule_id) do
    Repo.all(from b in Booking, where: b.package_schedule_id == ^schedule_id)
  end

  @doc """
  Gets confirmed bookings for a specific package schedule.
  """
  def get_confirmed_bookings_for_schedule(schedule_id) do
    Repo.all(from b in Booking, where: b.package_schedule_id == ^schedule_id and b.status == "confirmed")
  end

  @doc """
  Counts total bookings for a package schedule.
  """
  def count_bookings_for_schedule(schedule_id) do
    Repo.aggregate(
      from(b in Booking, where: b.package_schedule_id == ^schedule_id),
      :count,
      :id
    )
  end

  @doc """
  Counts confirmed bookings for a specific package schedule.
  """
  def count_confirmed_bookings_for_schedule(schedule_id) do
    Repo.aggregate(
      from(b in Booking, where: b.package_schedule_id == ^schedule_id and b.status == "confirmed"),
      :count,
      :id
    )
  end

  @doc """
  Gets all bookings for a specific package (across all schedules).
  """
  def get_bookings_for_package(package_id) do
    # Get all package schedules for this package, then get bookings for those schedules
    alias Umrahly.Packages

    package_schedules = Packages.get_package_schedules(package_id)
    schedule_ids = Enum.map(package_schedules, & &1.id)

    if length(schedule_ids) > 0 do
      Repo.all(from b in Booking, where: b.package_schedule_id in ^schedule_ids)
    else
      []
    end
  end

  @doc """
  Gets confirmed bookings for a specific package (across all schedules).
  """
  def get_confirmed_bookings_for_package(package_id) do
    # Get all package schedules for this package, then get confirmed bookings for those schedules
    alias Umrahly.Packages

    package_schedules = Packages.get_package_schedules(package_id)
    schedule_ids = Enum.map(package_schedules, & &1.id)

    if length(schedule_ids) > 0 do
      Repo.all(from b in Booking, where: b.package_schedule_id in ^schedule_ids and b.status == "confirmed")
    else
      []
    end
  end

  @doc """
  Counts total bookings for a package (across all schedules).
  """
  def count_bookings_for_package(package_id) do
    # Get all package schedules for this package, then count bookings for those schedules
    alias Umrahly.Packages

    package_schedules = Packages.get_package_schedules(package_id)
    schedule_ids = Enum.map(package_schedules, & &1.id)

    if length(schedule_ids) > 0 do
      Repo.aggregate(from(b in Booking, where: b.package_schedule_id in ^schedule_ids), :count, :id)
    else
      0
    end
  end

  @doc """
  Counts confirmed bookings for a package (across all schedules).
  """
  def count_confirmed_bookings_for_package(package_id) do
    # Get all package schedules for this package, then count confirmed bookings for those schedules
    alias Umrahly.Packages

    package_schedules = Packages.get_package_schedules(package_id)
    schedule_ids = Enum.map(package_schedules, & &1.id)

    if length(schedule_ids) > 0 do
      Repo.aggregate(from(b in Booking, where: b.package_schedule_id in ^schedule_ids and b.status == "confirmed"), :count, :id)
    else
      0
    end
  end
end
