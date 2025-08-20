# Add sample bookings for testing
alias Umrahly.Repo
alias Umrahly.Bookings.Booking
alias Umrahly.Packages.Package
alias Umrahly.Accounts.User

# Get the first package and user for testing
package = Repo.get_by(Package, name: "Standard Package") || Repo.get_by(Package, name: "Premium Package") || List.first(Repo.all(Package))
user = Repo.get_by(User, email: "admin@example.com") || List.first(Repo.all(User))

if package && user do
  # Create some sample bookings
  sample_bookings = [
    %{
      status: "confirmed",
      amount: Decimal.new("2500.00"),
      booking_date: ~D[2024-08-15],
      travel_date: package.departure_date,
      notes: "Sample confirmed booking",
      user_id: user.id,
      package_id: package.id
    },
    %{
      status: "confirmed",
      amount: Decimal.new("2500.00"),
      booking_date: ~D[2024-08-16],
      travel_date: package.departure_date,
      notes: "Another confirmed booking",
      user_id: user.id,
      package_id: package.id
    },
    %{
      status: "pending",
      amount: Decimal.new("2500.00"),
      booking_date: ~D[2024-08-17],
      travel_date: package.departure_date,
      notes: "Pending booking",
      user_id: user.id,
      package_id: package.id
    }
  ]

  Enum.each(sample_bookings, fn booking_attrs ->
    case Repo.get_by(Booking, user_id: booking_attrs.user_id, package_id: booking_attrs.package_id, booking_date: booking_attrs.booking_date) do
      nil ->
        %Booking{}
        |> Booking.changeset(booking_attrs)
        |> Repo.insert!()
        IO.puts("Created booking for package: #{package.name}")
      _existing ->
        IO.puts("Booking already exists for this user, package, and date")
    end
  end)
else
  IO.puts("No package or user found. Please run the main seeds.exs first.")
end
