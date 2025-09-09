defmodule Umrahly.FlightsTest do
  use Umrahly.DataCase

  alias Umrahly.Flights

  describe "flights" do
    alias Umrahly.Flights.Flight

    import Umrahly.FlightsFixtures

    @invalid_attrs %{status: nil, origin: nil, destination: nil, flight_number: nil, departure_time: nil, arrival_time: nil, aircraft: nil, capacity_total: nil, capacity_booked: nil}

    test "list_flights/0 returns all flights" do
      flight = flight_fixture()
      assert Flights.list_flights() == [flight]
    end

    test "get_flight!/1 returns the flight with given id" do
      flight = flight_fixture()
      assert Flights.get_flight!(flight.id) == flight
    end

    test "create_flight/1 with valid data creates a flight" do
      valid_attrs = %{status: "some status", origin: "some origin", destination: "some destination", flight_number: "some flight_number", departure_time: ~U[2025-09-03 12:54:00Z], arrival_time: ~U[2025-09-03 12:54:00Z], aircraft: "some aircraft", capacity_total: 42, capacity_booked: 42}

      assert {:ok, %Flight{} = flight} = Flights.create_flight(valid_attrs)
      assert flight.status == "some status"
      assert flight.origin == "some origin"
      assert flight.destination == "some destination"
      assert flight.flight_number == "some flight_number"
      assert flight.departure_time == ~U[2025-09-03 12:54:00Z]
      assert flight.arrival_time == ~U[2025-09-03 12:54:00Z]
      assert flight.aircraft == "some aircraft"
      assert flight.capacity_total == 42
      assert flight.capacity_booked == 42
    end

    test "create_flight/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Flights.create_flight(@invalid_attrs)
    end

    test "update_flight/2 with valid data updates the flight" do
      flight = flight_fixture()
      update_attrs = %{status: "some updated status", origin: "some updated origin", destination: "some updated destination", flight_number: "some updated flight_number", departure_time: ~U[2025-09-04 12:54:00Z], arrival_time: ~U[2025-09-04 12:54:00Z], aircraft: "some updated aircraft", capacity_total: 43, capacity_booked: 43}

      assert {:ok, %Flight{} = flight} = Flights.update_flight(flight, update_attrs)
      assert flight.status == "some updated status"
      assert flight.origin == "some updated origin"
      assert flight.destination == "some updated destination"
      assert flight.flight_number == "some updated flight_number"
      assert flight.departure_time == ~U[2025-09-04 12:54:00Z]
      assert flight.arrival_time == ~U[2025-09-04 12:54:00Z]
      assert flight.aircraft == "some updated aircraft"
      assert flight.capacity_total == 43
      assert flight.capacity_booked == 43
    end

    test "update_flight/2 with invalid data returns error changeset" do
      flight = flight_fixture()
      assert {:error, %Ecto.Changeset{}} = Flights.update_flight(flight, @invalid_attrs)
      assert flight == Flights.get_flight!(flight.id)
    end

    test "delete_flight/1 deletes the flight" do
      flight = flight_fixture()
      assert {:ok, %Flight{}} = Flights.delete_flight(flight)
      assert_raise Ecto.NoResultsError, fn -> Flights.get_flight!(flight.id) end
    end

    test "change_flight/1 returns a flight changeset" do
      flight = flight_fixture()
      assert %Ecto.Changeset{} = Flights.change_flight(flight)
    end
  end

  describe "flights" do
    alias Umrahly.Flights.Flight

    import Umrahly.FlightsFixtures

    @invalid_attrs %{status: nil, origin: nil, destination: nil, flight_number: nil, departure_time: nil, arrival_time: nil, aircraft: nil, capacity_total: nil, capacity_booked: nil}

    test "list_flights/0 returns all flights" do
      flight = flight_fixture()
      assert Flights.list_flights() == [flight]
    end

    test "get_flight!/1 returns the flight with given id" do
      flight = flight_fixture()
      assert Flights.get_flight!(flight.id) == flight
    end

    test "create_flight/1 with valid data creates a flight" do
      valid_attrs = %{status: "some status", origin: "some origin", destination: "some destination", flight_number: "some flight_number", departure_time: ~U[2025-09-03 12:59:00Z], arrival_time: ~U[2025-09-03 12:59:00Z], aircraft: "some aircraft", capacity_total: 42, capacity_booked: 42}

      assert {:ok, %Flight{} = flight} = Flights.create_flight(valid_attrs)
      assert flight.status == "some status"
      assert flight.origin == "some origin"
      assert flight.destination == "some destination"
      assert flight.flight_number == "some flight_number"
      assert flight.departure_time == ~U[2025-09-03 12:59:00Z]
      assert flight.arrival_time == ~U[2025-09-03 12:59:00Z]
      assert flight.aircraft == "some aircraft"
      assert flight.capacity_total == 42
      assert flight.capacity_booked == 42
    end

    test "create_flight/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Flights.create_flight(@invalid_attrs)
    end

    test "update_flight/2 with valid data updates the flight" do
      flight = flight_fixture()
      update_attrs = %{status: "some updated status", origin: "some updated origin", destination: "some updated destination", flight_number: "some updated flight_number", departure_time: ~U[2025-09-04 12:59:00Z], arrival_time: ~U[2025-09-04 12:59:00Z], aircraft: "some updated aircraft", capacity_total: 43, capacity_booked: 43}

      assert {:ok, %Flight{} = flight} = Flights.update_flight(flight, update_attrs)
      assert flight.status == "some updated status"
      assert flight.origin == "some updated origin"
      assert flight.destination == "some updated destination"
      assert flight.flight_number == "some updated flight_number"
      assert flight.departure_time == ~U[2025-09-04 12:59:00Z]
      assert flight.arrival_time == ~U[2025-09-04 12:59:00Z]
      assert flight.aircraft == "some updated aircraft"
      assert flight.capacity_total == 43
      assert flight.capacity_booked == 43
    end

    test "update_flight/2 with invalid data returns error changeset" do
      flight = flight_fixture()
      assert {:error, %Ecto.Changeset{}} = Flights.update_flight(flight, @invalid_attrs)
      assert flight == Flights.get_flight!(flight.id)
    end

    test "delete_flight/1 deletes the flight" do
      flight = flight_fixture()
      assert {:ok, %Flight{}} = Flights.delete_flight(flight)
      assert_raise Ecto.NoResultsError, fn -> Flights.get_flight!(flight.id) end
    end

    test "change_flight/1 returns a flight changeset" do
      flight = flight_fixture()
      assert %Ecto.Changeset{} = Flights.change_flight(flight)
    end
  end
end
