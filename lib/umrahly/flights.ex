defmodule Umrahly.Flights do
  @moduledoc """
  The Flights context.
  """

  import Ecto.Query, warn: false
  alias Umrahly.Repo

  alias Umrahly.Flights.Flight

  # Calculate duration in days between departure_time and return_date
  @doc """
  Calculates the duration in days between departure_time and return_date.
  Returns nil if return_date is not present.
  """
  def calculate_duration_days(departure_time, return_date) do
    case return_date do
      nil -> nil
      return_date ->
        departure_date = DateTime.to_date(departure_time)
        return_date_only = DateTime.to_date(return_date)
        Date.diff(return_date_only, departure_date)
    end
  end


  @doc """
  Returns the list of flights.

  ## Examples

      iex> list_flights()
      [%Flight{}, ...]

  """
  def list_flights do
    Repo.all(Flight)
  end

  @doc """
  Gets a single flight.

  Raises `Ecto.NoResultsError` if the Flight does not exist.

  ## Examples

      iex> get_flight!(123)
      %Flight{}

      iex> get_flight!(456)
      ** (Ecto.NoResultsError)

  """
  def get_flight!(id), do: Repo.get!(Flight, id)

  @doc """
  Creates a flight.

  ## Examples

      iex> create_flight(%{field: value})
      {:ok, %Flight{}}

      iex> create_flight(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_flight(attrs \\ %{}) do
    %Flight{}
    |> Flight.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a flight.

  ## Examples

      iex> update_flight(flight, %{field: new_value})
      {:ok, %Flight{}}

      iex> update_flight(flight, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_flight(%Flight{} = flight, attrs) do
    flight
    |> Flight.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a flight.

  ## Examples

      iex> delete_flight(flight)
      {:ok, %Flight{}}

      iex> delete_flight(flight)
      {:error, %Ecto.Changeset{}}

  """
  def delete_flight(%Flight{} = flight) do
    Repo.delete(flight)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking flight changes.

  ## Examples

      iex> change_flight(flight)
      %Ecto.Changeset{data: %Flight{}}

  """
  def change_flight(%Flight{} = flight, attrs \\ %{}) do
    Flight.changeset(flight, attrs)
  end

  @doc """
  Gets a flight by departure date.
  Returns the flight that has the specified departure date.

  ## Examples

      iex> get_flight_by_departure_date(~D[2024-01-15])
      %Flight{}

      iex> get_flight_by_departure_date(~D[2024-01-15])
      nil

  """
  def get_flight_by_departure_date(departure_date) do
    Flight
    |> where([f], fragment("DATE(?)", f.departure_time) == ^departure_date)
    |> Repo.one()
  end
end
