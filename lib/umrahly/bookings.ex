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
    # Since we don't have package_schedule_id yet, we'll get bookings by package_id
    # This is a temporary workaround until the schema is properly migrated
    Repo.all(from b in Booking, where: b.package_id == ^schedule_id)
  end

  @doc """
  Gets confirmed bookings for a specific package schedule.
  """
  def get_confirmed_bookings_for_schedule(schedule_id) do
    # Since we don't have package_schedule_id yet, we'll get bookings by package_id
    # This is a temporary workaround until the schema is properly migrated
    Repo.all(from b in Booking, where: b.package_id == ^schedule_id and b.status == "confirmed")
  end

  @doc """
  Counts total bookings for a package schedule.
  """
  def count_bookings_for_schedule(schedule_id) do
    # Since we don't have package_schedule_id yet, we'll count bookings by package_id
    # This is a temporary workaround until the schema is properly migrated
    Repo.aggregate(
      from(b in Booking, where: b.package_id == ^schedule_id),
      :count,
      :id
    )
  end

  @doc """
  Counts confirmed bookings for a package schedule.
  """
  def count_confirmed_bookings_for_schedule(schedule_id) do
    # Since we don't have package_schedule_id yet, we'll count bookings by package_id
    # This is a temporary workaround until the schema is properly migrated
    Repo.aggregate(
      from(b in Booking, where: b.package_id == ^schedule_id and b.status == "confirmed"),
      :count,
      :id
    )
  end

  @doc """
  Gets all bookings for a specific package (across all schedules).
  """
  def get_bookings_for_package(package_id) do
    # Since we don't have package_schedules yet, we'll get bookings directly by package_id
    Repo.all(from b in Booking, where: b.package_id == ^package_id)
  end

  @doc """
  Gets confirmed bookings for a specific package (across all schedules).
  """
  def get_confirmed_bookings_for_package(package_id) do
    # Since we don't have package_schedules yet, we'll get bookings directly by package_id
    Repo.all(from b in Booking, where: b.package_id == ^package_id and b.status == "confirmed")
  end

  @doc """
  Counts total bookings for a package (across all schedules).
  """
  def count_bookings_for_package(package_id) do
    # Since we don't have package_schedules yet, we'll count bookings directly by package_id
    Repo.aggregate(
      from(b in Booking, where: b.package_id == ^package_id),
      :count,
      :id
    )
  end

  @doc """
  Counts confirmed bookings for a package (across all schedules).
  """
  def count_confirmed_bookings_for_package(package_id) do
    # Since we don't have package_schedules yet, we'll count bookings directly by package_id
    Repo.aggregate(
      from(b in Booking, where: b.package_id == ^package_id and b.status == "confirmed"),
      :count,
      :id
    )
  end
end
