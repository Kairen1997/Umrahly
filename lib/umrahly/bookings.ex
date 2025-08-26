defmodule Umrahly.Bookings do
  @moduledoc """
  The Bookings context.
  """

  import Ecto.Query, warn: false
  alias Umrahly.Repo
  alias Umrahly.Bookings.Booking
  alias Umrahly.Bookings.BookingFlowProgress

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

  # Booking Flow Progress Functions

  @doc """
  Gets or creates a booking flow progress record for a user and package schedule.
  """
  def get_or_create_booking_flow_progress(user_id, package_id, package_schedule_id) do
    try do
      # First try to get existing progress with more specific query
      case Repo.get_by(BookingFlowProgress,
        user_id: user_id,
        package_schedule_id: package_schedule_id,
        status: "in_progress"
      ) do
        nil ->
          # Also check if there's any progress record for this user/schedule regardless of status
          case Repo.get_by(BookingFlowProgress,
            user_id: user_id,
            package_schedule_id: package_schedule_id
          ) do
            nil ->
              # No existing record found, create a new one
              %BookingFlowProgress{}
              |> BookingFlowProgress.changeset(%{
                user_id: user_id,
                package_id: package_id,
                package_schedule_id: package_schedule_id,
                current_step: 1,
                max_steps: 4,
                number_of_persons: 1,
                is_booking_for_self: true,
                payment_method: "bank_transfer",
                payment_plan: "full_payment",
                notes: "",
                travelers_data: [],
                total_amount: nil,
                deposit_amount: nil,
                status: "in_progress",
                last_updated: DateTime.utc_now()
              })
              |> Repo.insert()

            existing_progress when not is_nil(existing_progress) ->
              # If there's an existing record but it's not in_progress, reactivate it
              case Repo.update(existing_progress
                |> BookingFlowProgress.changeset(%{
                  status: "in_progress",
                  last_updated: DateTime.utc_now()
                })) do
                {:ok, updated_progress} ->
                  {:ok, updated_progress}
                {:error, _changeset} ->
                  # If reactivation fails, create a new one
                  %BookingFlowProgress{}
                  |> BookingFlowProgress.changeset(%{
                    user_id: user_id,
                    package_id: package_id,
                    package_schedule_id: package_schedule_id,
                    current_step: 1,
                    max_steps: 4,
                    number_of_persons: 1,
                    is_booking_for_self: true,
                    payment_method: "bank_transfer",
                    payment_plan: "full_payment",
                    notes: "",
                    travelers_data: [],
                    total_amount: nil,
                    deposit_amount: nil,
                    status: "in_progress",
                    last_updated: DateTime.utc_now()
                  })
                  |> Repo.insert()
              end
          end
        progress ->
          {:ok, progress}
      end
    rescue
      _ ->
        # Return error instead of crashing
        {:error, "Failed to get or create booking flow progress"}
    end
  end

  @doc """
  Updates the booking flow progress.
  """
  def update_booking_flow_progress(%BookingFlowProgress{} = progress, attrs) do
    progress
    |> BookingFlowProgress.changeset(Map.merge(attrs, %{last_updated: DateTime.utc_now()}))
    |> Repo.update()
  end

  @doc """
  Gets all in-progress booking flows for a user.
  """
  def get_user_booking_flows(user_id) do
    Repo.all(
      from p in BookingFlowProgress,
      join: pack in Umrahly.Packages.Package, on: p.package_id == pack.id,
      join: ps in Umrahly.Packages.PackageSchedule, on: p.package_schedule_id == ps.id,
      where: p.user_id == ^user_id and p.status == "in_progress",
      select: %{
        id: p.id,
        current_step: p.current_step,
        max_steps: p.max_steps,
        package_name: pack.name,
        package_id: pack.id,
        schedule_departure: ps.departure_date,
        schedule_return: ps.return_date,
        number_of_persons: p.number_of_persons,
        total_amount: p.total_amount,
        last_updated: p.last_updated
      },
      order_by: [desc: p.last_updated]
    )
  end

  @doc """
  Completes a booking flow progress (marks as completed).
  """
  def complete_booking_flow_progress(%BookingFlowProgress{} = progress) do
    progress
    |> BookingFlowProgress.changeset(%{status: "completed"})
    |> Repo.update()
  end

  @doc """
  Abandons a booking flow progress (marks as abandoned).
  """
  def abandon_booking_flow_progress(%BookingFlowProgress{} = progress) do
    progress
    |> BookingFlowProgress.changeset(%{status: "abandoned"})
    |> Repo.update()
  end
end
