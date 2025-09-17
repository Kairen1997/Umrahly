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
  Returns an `%Ecto.Changeset{}` for tracking booking changes.
  """
  def change_booking(%Booking{} = booking, attrs \\ %{}) do
    Booking.changeset(booking, attrs)
  end

  @doc """
  Returns the list of booking flow progress records.
  """
  def list_booking_flow_progress do
    Repo.all(BookingFlowProgress)
  end

  @doc """
  Returns the list of booking flow progress records for a specific user.
  """
  def get_booking_flow_progress_by_user_id(user_id) do
    BookingFlowProgress
    |> where([bfp], bfp.user_id == ^user_id)
    |> preload([:package, :package_schedule])
    |> Repo.all()
  end

  @doc """
  Gets a single booking flow progress record.
  """
  def get_booking_flow_progress!(id), do: Repo.get!(BookingFlowProgress, id)

  @doc """
  Creates a booking flow progress record.
  """
  def create_booking_flow_progress(attrs \\ %{}) do
    %BookingFlowProgress{}
    |> BookingFlowProgress.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a booking flow progress record.
  """
  def update_booking_flow_progress(%BookingFlowProgress{} = booking_flow_progress, attrs) do
    booking_flow_progress
    |> BookingFlowProgress.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a booking flow progress record.
  """
  def delete_booking_flow_progress(%BookingFlowProgress{} = booking_flow_progress) do
    Repo.delete(booking_flow_progress)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking booking flow progress changes.
  """
  def change_booking_flow_progress(%BookingFlowProgress{} = booking_flow_progress, attrs \\ %{}) do
    BookingFlowProgress.changeset(booking_flow_progress, attrs)
  end

  @doc """
  Counts total bookings for a specific package schedule.
  """
  def count_bookings_for_schedule(schedule_id) do
    Booking
    |> where([b], b.package_schedule_id == ^schedule_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts confirmed bookings for a specific package schedule.
  """
  def count_confirmed_bookings_for_schedule(schedule_id) do
    Booking
    |> where([b], b.package_schedule_id == ^schedule_id and b.status == "confirmed")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts total bookings for a specific package.
  """
  def count_bookings_for_package(package_id) do
    Booking
    |> join(:inner, [b], ps in Umrahly.Packages.PackageSchedule, on: b.package_schedule_id == ps.id)
    |> where([b, ps], ps.package_id == ^package_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts confirmed bookings for a specific package.
  """
  def count_confirmed_bookings_for_package(package_id) do
    Booking
    |> join(:inner, [b], ps in Umrahly.Packages.PackageSchedule, on: b.package_schedule_id == ps.id)
    |> where([b, ps], ps.package_id == ^package_id and b.status == "confirmed")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets all bookings with submitted payment proofs that are pending approval.
  """
  def get_bookings_flow_progress_pending_payment_proof_approval do
    Booking
    |> join(:inner, [b], u in Umrahly.Accounts.User, on: b.user_id == u.id)
    |> join(:inner, [b, u], ps in Umrahly.Packages.PackageSchedule, on: b.package_schedule_id == ps.id)
    |> join(:inner, [b, u, ps], p in Umrahly.Packages.Package, on: ps.package_id == p.id)
    |> where([b, u, ps, p], b.payment_proof_status == "submitted")
    |> preload([b, u, ps, p], user: u, package_schedule: {ps, package: p})
    |> Repo.all()
  end

  @doc """
  Updates the payment proof status for a booking.
  """
  def update_payment_proof_status(%Booking{} = booking, status, _admin_notes) do
    attrs = %{
      "payment_proof_status" => status
    }

    case status do
      "approved" ->
        # Update status to confirmed when payment is approved
        attrs = Map.put(attrs, "status", "confirmed")
        update_booking(booking, attrs)
      "rejected" ->
        # Keep status as pending when payment is rejected
        update_booking(booking, attrs)
      _ ->
        update_booking(booking, attrs)
    end
  end

  @doc """
  Submits a payment proof for a booking.
  """
  def submit_payment_proof(%Booking{} = booking, attrs) do
    attrs = Map.put(attrs, "payment_proof_status", "submitted")
    attrs = Map.put(attrs, "payment_proof_submitted_at", DateTime.utc_now())

    update_booking(booking, attrs)
  end

  @doc """
  Gets all bookings for a specific user with payment information.
  """
  def list_user_bookings_with_payments(user_id) do
    Booking
    |> join(:inner, [b], ps in Umrahly.Packages.PackageSchedule, on: b.package_schedule_id == ps.id)
    |> join(:inner, [b, ps], p in Umrahly.Packages.Package, on: ps.package_id == p.id)
    |> where([b, ps, p], b.user_id == ^user_id)
    |> select([b, ps, p], %{
      id: b.id,
      booking_reference: fragment("'BK' || ?", b.id),
      package_name: p.name,
      status: b.status,
      total_amount: b.total_amount,
      paid_amount: b.deposit_amount,
      payment_method: b.payment_method,
      payment_plan: b.payment_plan,
      booking_date: b.booking_date
    })
    |> Repo.all()
  end

    @doc """
  Gets the latest booking flow progress for a given user + package.
  """
  def get_booking_flow_progress(user_id, package_id) do
    BookingFlowProgress
    |> where([bfp], bfp.user_id == ^user_id and bfp.package_id == ^package_id)
    |> order_by([bfp], desc: bfp.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets the latest booking flow progress for a given user + package schedule.
  """
  def get_booking_flow_progress_by_schedule(user_id, package_schedule_id) do
    BookingFlowProgress
    |> where([bfp], bfp.user_id == ^user_id and bfp.package_schedule_id == ^package_schedule_id)
    |> order_by([bfp], desc: bfp.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets or creates booking flow progress for a user + package.
  Always returns a `%BookingFlowProgress{}`.
  """
  def get_or_create_booking_flow_progress(user_id, package_id, schedule_id) do
    case get_booking_flow_progress_by_schedule(user_id, schedule_id) do
      nil ->
        create_booking_flow_progress(%{
          user_id: user_id,
          package_id: package_id,
          package_schedule_id: schedule_id,
          current_step: 1,
          max_steps: 5,
          number_of_persons: 1,
          is_booking_for_self: true,
          payment_method: "bank_transfer",
          payment_plan: "full_payment",
          status: "in_progress",
          last_updated: DateTime.utc_now()
        })
        |> case do
          {:ok, progress} -> progress
          {:error, _changeset} -> nil
        end

      progress ->
        progress
    end
  end

  @doc """
  Gets the latest booking for a given user and package schedule.
  Used by Active Bookings to show latest payment-proof status.
  """
  def get_latest_booking_for_user_schedule(user_id, package_schedule_id) do
    Booking
    |> where([b], b.user_id == ^user_id and b.package_schedule_id == ^package_schedule_id)
    |> order_by([b], desc: b.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets the latest active booking (pending/confirmed) for a user with payment info.
  Returns a map with: id, booking_reference, package_name, status, total_amount, paid_amount, payment_method, payment_plan, booking_date.
  """
  def get_latest_active_booking_with_payments(user_id) do
    Booking
    |> join(:inner, [b], ps in Umrahly.Packages.PackageSchedule, on: b.package_schedule_id == ps.id)
    |> join(:inner, [b, ps], p in Umrahly.Packages.Package, on: ps.package_id == p.id)
    |> where([b, ps, p], b.user_id == ^user_id and b.status in ["pending", "confirmed"])
    |> order_by([b], desc: b.inserted_at)
    |> limit(1)
    |> select([b, ps, p], %{
      id: b.id,
      booking_reference: fragment("'BK' || ?", b.id),
      package_name: p.name,
      status: b.status,
      total_amount: b.total_amount,
      paid_amount: b.deposit_amount,
      payment_method: b.payment_method,
      payment_plan: b.payment_plan,
      booking_date: b.booking_date
    })
    |> Repo.one()
  end

  @doc """
  Counts active bookings for a specific user.
  Here, "active" means confirmed bookings only.
  """
  def count_active_bookings_for_user(user_id) do
    Booking
    |> where([b], b.user_id == ^user_id and b.status == "confirmed")
    |> select([b], count(b.id))
    |> Repo.one()
  end

  @doc """
  Sums paid amounts for a user's bookings.
  Currently uses `deposit_amount` as the paid amount field.
  Returns 0 if there are no bookings or no paid amounts.
  """
  def sum_paid_amount_for_user(user_id) do
    sum =
      Booking
      |> where([b], b.user_id == ^user_id)
      |> select([b], coalesce(sum(b.deposit_amount), 0))
      |> Repo.one()

    sum
  end

end
