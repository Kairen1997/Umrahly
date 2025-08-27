defmodule Umrahly.Bookings do
  @moduledoc """
  The Bookings context.
  """

  import Ecto.Query, warn: false
  alias Umrahly.Repo
  alias Umrahly.Bookings.{Booking, BookingFlowProgress, TravelerDetail}

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

  # Traveler Details functions

  @doc """
  Returns the list of traveler details for a specific booking.
  """
  def list_traveler_details_by_booking(booking_id) do
    Repo.all(from td in TravelerDetail, where: td.booking_id == ^booking_id)
  end

  @doc """
  Returns the list of traveler details for a specific user.
  """
  def list_traveler_details_by_user(user_id) do
    Repo.all(from td in TravelerDetail, where: td.user_id == ^user_id)
  end

  @doc """
  Gets a single traveler detail.
  """
  def get_traveler_detail!(id), do: Repo.get!(TravelerDetail, id)

  @doc """
  Creates a traveler detail with Phase 1 (MVP) fields.
  """
  def create_traveler_detail_phase1(attrs \\ %{}) do
    %TravelerDetail{}
    |> TravelerDetail.phase1_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a complete traveler detail with all fields.
  """
  def create_traveler_detail(attrs \\ %{}) do
    %TravelerDetail{}
    |> TravelerDetail.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a traveler detail with Phase 2 fields.
  """
  def update_traveler_detail_phase2(%TravelerDetail{} = traveler_detail, attrs) do
    traveler_detail
    |> TravelerDetail.phase2_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a traveler detail with Phase 3 fields.
  """
  def update_traveler_detail_phase3(%TravelerDetail{} = traveler_detail, attrs) do
    traveler_detail
    |> TravelerDetail.phase3_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a traveler detail with all fields.
  """
  def update_traveler_detail(%TravelerDetail{} = traveler_detail, attrs) do
    traveler_detail
    |> TravelerDetail.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a traveler detail.
  """
  def delete_traveler_detail(%TravelerDetail{} = traveler_detail) do
    Repo.delete(traveler_detail)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking traveler detail changes.
  """
  def change_traveler_detail(%TravelerDetail{} = traveler_detail, attrs \\ %{}) do
    TravelerDetail.changeset(traveler_detail, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for Phase 1 traveler detail changes.
  """
  def change_traveler_detail_phase1(%TravelerDetail{} = traveler_detail, attrs \\ %{}) do
    TravelerDetail.phase1_changeset(traveler_detail, attrs)
  end

  @doc """
  Creates multiple traveler details for a booking.
  """
  def create_multiple_traveler_details(booking_id, user_id, travelers_data) do
    Repo.transaction(fn ->
      Enum.map_join(travelers_data, fn traveler_data ->
        create_traveler_detail_phase1(
          Map.merge(traveler_data, %{
            "booking_id" => booking_id,
            "user_id" => user_id
          })
        )
      end)
    end)
  end

  @doc """
  Checks if a booking has all required traveler details.
  """
  def booking_has_complete_traveler_details?(booking_id) do
    booking = get_booking!(booking_id)
    traveler_count = Repo.aggregate(
      from td in TravelerDetail, where: td.booking_id == ^booking_id,
      select: count(td.id)
    )

    traveler_count == booking.number_of_persons
  end
end
