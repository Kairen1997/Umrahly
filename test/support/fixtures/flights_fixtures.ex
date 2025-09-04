defmodule Umrahly.FlightsFixtures do
  @moduledoc """
  Test helpers for creating flights and related data.
  """

  alias Umrahly.Flights

  @doc """
  Generate a unique flight number.
  """
  def unique_flight_number do
    "MH-#{System.unique_integer([:positive])}"
  end

  @doc """
  Generate valid default attributes for a flight.
  """
  def valid_flight_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      flight_number: unique_flight_number(),
      origin: "Kuala Lumpur (KUL)",
      destination: "Jeddah (JED)",
      departure_time: ~U[2025-12-15 02:00:00Z],
      arrival_time: ~U[2025-12-15 08:30:00Z],
      aircraft: "Boeing 777",
      capacity_total: 300,
      capacity_booked: 0,
      status: "Scheduled"
    })
  end

  @doc """
  Create a flight fixture for testing.
  """
  def flight_fixture(attrs \\ %{}) do
    {:ok, flight} =
      attrs
      |> valid_flight_attrs()
      |> Flights.create_flight()

    flight
  end
end
