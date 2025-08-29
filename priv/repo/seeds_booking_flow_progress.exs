# Add sample booking flow progress data for testing admin payments
alias Umrahly.Repo
alias Umrahly.Bookings.BookingFlowProgress
alias Umrahly.Packages.Package
alias Umrahly.Packages.PackageSchedule
alias Umrahly.Accounts.User
import Ecto.Query, warn: false

# Get the first package and user for testing
package = Repo.get_by(Package, name: "Standard Package") || Repo.get_by(Package, name: "Premium Package") || List.first(Repo.all(Package))
user = Repo.get_by(User, email: "john@example.com") || Repo.get_by(User, email: "jane@example.com") || List.first(Repo.all(User))
admin_user = Repo.get_by(User, email: "admin@umrahly.com") || List.first(Repo.all(User))

if package && user && admin_user do
  # Get the first package schedule for this package
  package_schedule = case Repo.all(from ps in PackageSchedule, where: ps.package_id == ^package.id, limit: 1) do
    [schedule | _] -> schedule
    [] ->
      # Create a package schedule if none exists
      {:ok, schedule} = Umrahly.Packages.create_package_schedule(%{
        package_id: package.id,
        departure_date: ~D[2025-12-01],
        return_date: ~D[2025-12-07],
        quota: 50,
        status: "active"
      })
      schedule
  end

  # Create sample booking flow progress records
  sample_progress_records = [
    %{
      user_id: user.id,
      package_id: package.id,
      package_schedule_id: package_schedule.id,
      current_step: 4,
      max_steps: 4,
      number_of_persons: 2,
      is_booking_for_self: true,
      payment_method: "bank_transfer",
      payment_plan: "full_payment",
      notes: "Sample completed booking",
      travelers_data: [
        %{
          "full_name" => "John Doe",
          "passport_number" => "A12345678",
          "date_of_birth" => "1990-01-01",
          "nationality" => "Malaysian"
        },
        %{
          "full_name" => "Jane Doe",
          "passport_number" => "B87654321",
          "date_of_birth" => "1992-05-15",
          "nationality" => "Malaysian"
        }
      ],
      total_amount: Decimal.new("5000.00"),
      deposit_amount: nil,
      status: "completed",
      last_updated: DateTime.utc_now()
    },
    %{
      user_id: admin_user.id,
      package_id: package.id,
      package_schedule_id: package_schedule.id,
      current_step: 2,
      max_steps: 4,
      number_of_persons: 1,
      is_booking_for_self: true,
      payment_method: "credit_card",
      payment_plan: "installment",
      notes: "Sample in-progress booking",
      travelers_data: [
        %{
          "full_name" => "Admin User",
          "passport_number" => "C11223344",
          "date_of_birth" => "1985-03-20",
          "nationality" => "Malaysian"
        }
      ],
      total_amount: Decimal.new("2500.00"),
      deposit_amount: Decimal.new("500.00"),
      status: "in_progress",
      last_updated: DateTime.utc_now()
    },
    %{
      user_id: user.id,
      package_id: package.id,
      package_schedule_id: package_schedule.id,
      current_step: 1,
      max_steps: 4,
      number_of_persons: 3,
      is_booking_for_self: false,
      payment_method: "online_banking",
      payment_plan: "full_payment",
      notes: "Sample abandoned booking",
      travelers_data: [
        %{
          "full_name" => "Ahmed Hassan",
          "passport_number" => "D55667788",
          "date_of_birth" => "1988-07-10",
          "nationality" => "Malaysian"
        },
        %{
          "full_name" => "Fatima Hassan",
          "passport_number" => "E99887766",
          "date_of_birth" => "1990-12-25",
          "nationality" => "Malaysian"
        },
        %{
          "full_name" => "Omar Hassan",
          "passport_number" => "F44332211",
          "date_of_birth" => "1995-04-18",
          "nationality" => "Malaysian"
        }
      ],
      total_amount: Decimal.new("7500.00"),
      deposit_amount: nil,
      status: "abandoned",
      last_updated: DateTime.utc_now()
    }
  ]

  Enum.each(sample_progress_records, fn progress_attrs ->
    case Repo.get_by(BookingFlowProgress,
      user_id: progress_attrs.user_id,
      package_schedule_id: progress_attrs.package_schedule_id,
      status: progress_attrs.status
    ) do
      nil ->
        %BookingFlowProgress{}
        |> BookingFlowProgress.changeset(progress_attrs)
        |> Repo.insert!()
        IO.puts("Created booking flow progress for user: #{progress_attrs.user_id}, status: #{progress_attrs.status}")
      _existing ->
        IO.puts("Booking flow progress already exists for this user, package schedule, and status")
    end
  end)
else
  IO.puts("No package, user, or admin user found. Please run the main seeds.exs first.")
end

IO.puts("\nBooking flow progress seeding completed!")
