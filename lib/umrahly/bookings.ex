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
  Returns bookings with search and filter options.
  Supports filtering by status and searching by user name or package name.
  Now supports pagination via :page and :page_size options.
  """
  def list_bookings_with_details(opts \\ []) do
    search_term = Keyword.get(opts, :search, "")
    status_filter = Keyword.get(opts, :status, :all)
    package_filter = Keyword.get(opts, :package_id, :all)
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 10)

    offset_val = max(page - 1, 0) * page_size

    base_query()
    |> apply_search_filter(search_term)
    |> apply_package_filter(package_filter)
    |> apply_status_filter(status_filter)
    |> order_by([b], desc: b.inserted_at)
    |> limit(^page_size)
    |> offset(^offset_val)
    |> Repo.all()
  end

  defp base_query do
    Booking
    |> join(:inner, [b], u in Umrahly.Accounts.User, on: b.user_id == u.id)
    |> join(:inner, [b, u], ps in Umrahly.Packages.PackageSchedule, on: b.package_schedule_id == ps.id)
    |> join(:inner, [b, u, ps], p in Umrahly.Packages.Package, on: ps.package_id == p.id)
    |> select([b, u, ps, p], %{
      id: b.id,
      user_name: u.full_name,
      package_id: p.id,
      package_name: p.name,
      status: b.status,
      total_amount: b.total_amount,
      booking_date: b.booking_date,
      travel_date: ps.departure_date,
      number_of_persons: b.number_of_persons,
      payment_method: b.payment_method,
      payment_plan: b.payment_plan,
      deposit_amount: b.deposit_amount,
      payment_proof_status: b.payment_proof_status
    })
  end

  defp apply_search_filter(query, "") do
    query
  end

  defp apply_search_filter(query, search_term) when is_binary(search_term) do
    search_pattern = "%#{search_term}%"

    query
    |> where([b, u, ps, p],
      ilike(u.full_name, ^search_pattern) or
      ilike(p.name, ^search_pattern) or
      fragment("CAST(? AS TEXT) ILIKE ?", b.id, ^search_pattern)
    )
  end

  defp apply_status_filter(query, :all) do
    query
  end

  defp apply_status_filter(query, status) when is_binary(status) do
    status = String.downcase(status)
    where(query, [b, _u, _ps, _p], b.status == ^status)
  end

  defp apply_package_filter(query, :all) do
    query
  end

  defp apply_package_filter(query, package_id) when is_integer(package_id) do
    where(query, [_b, _u, _ps, p], p.id == ^package_id)
  end

  defp apply_package_filter(query, package_id) when is_binary(package_id) do
    case Integer.parse(package_id) do
      {id, _} -> where(query, [_b, _u, _ps, p], p.id == ^id)
      :error -> query
    end
  end

  @doc """
  Get available booking status for filter dropdown
  """
  def get_booking_status do
    ["pending", "confirmed", "cancelled"]
  end

  @doc """
  Returns the total count of bookings matching the same filters as list_bookings_with_details/1.
  """
  def count_bookings_with_details(opts \\ []) do
    search_term = Keyword.get(opts, :search, "")
    status_filter = Keyword.get(opts, :status, :all)
    package_filter = Keyword.get(opts, :package_id, :all)

    Booking
    |> join(:inner, [b], u in Umrahly.Accounts.User, on: b.user_id == u.id)
    |> join(:inner, [b, u], ps in Umrahly.Packages.PackageSchedule, on: b.package_schedule_id == ps.id)
    |> join(:inner, [b, u, ps], p in Umrahly.Packages.Package, on: ps.package_id == p.id)
    |> apply_search_filter(search_term)
    |> apply_package_filter(package_filter)
    |> apply_status_filter(status_filter)
    |> select([b, _u, _ps, _p], b.id)
    |> Repo.aggregate(:count, :id)
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
  Also removes any related booking_flow_progress rows for the same user and schedule so it no longer appears in Manage Payments.
  """
  def delete_booking(%Booking{} = booking) do
    Repo.transaction(fn ->
      from(bfp in BookingFlowProgress,
        where: bfp.user_id == ^booking.user_id and bfp.package_schedule_id == ^booking.package_schedule_id
      )
      |> Repo.delete_all()

      case Repo.delete(booking) do
        {:ok, deleted} -> deleted
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, deleted} ->
        Phoenix.PubSub.broadcast(Umrahly.PubSub, "admin:payments", {:payments_changed})
        {:ok, deleted}
      {:error, changeset} -> {:error, changeset}
    end
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
  def update_payment_proof_status(booking_id, status) do
    booking = Repo.get!(Booking, booking_id)
    booking
    |> Ecto.Changeset.change(payment_proof_status: status)
    |> Repo.update()
  end

  # Backward-compatible 3-arg version used by admin payment proofs live
  def update_payment_proof_status(%Booking{} = booking, status, _admin_notes) do
    attrs = %{"payment_proof_status" => status}

    attrs =
      case status do
        "approved" -> Map.put(attrs, "status", "confirmed")
        _ -> attrs
      end

    update_booking(booking, attrs)
  end

  @doc """
  Updates booking payment fields and attaches payment proof without requiring all booking validations.
  Safe for partial updates after user submits an offline payment proof.
  """
  def update_booking_payment_with_proof(%Booking{} = booking, attrs) when is_map(attrs) do
    booking
    |> Ecto.Changeset.change(attrs)
    |> Repo.update()
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

  @doc """
  Returns the total payments received across all bookings that are confirmed or completed.
  Uses `deposit_amount` as the received payment value.
  Returns a Decimal (0 if none).
  """
  def sum_total_payments_received do
    Booking
    |> where([b], b.status in ["confirmed", "completed"])
    |> select([b], coalesce(sum(b.deposit_amount), 0))
    |> Repo.one()
  end

  @doc """
  Counts bookings with payment proofs submitted and pending approval.
  """
  def count_pending_payment_proof_approvals do
    Booking
    |> where([b], b.payment_proof_status == "submitted")
    |> select([b], count(b.id))
    |> Repo.one()
  end

  @doc """
  Deletes all booking flow progress entries that are marked as "abandoned".

  Returns {count, nil} where count is the number of rows removed.
  """
  def delete_abandoned_booking_progress do
    BookingFlowProgress
    |> where([bfp], bfp.status == "abandoned")
    |> Repo.delete_all()
  end

end
