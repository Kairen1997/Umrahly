defmodule UmrahlyWeb.AdminPaymentsLiveTest do
  use UmrahlyWeb.ConnCase

  import Umrahly.AccountsFixtures
  import Umrahly.PackagesFixtures
  import Umrahly.BookingsFixtures

  alias Umrahly.Accounts
  alias Umrahly.Packages
  alias Umrahly.Bookings

  @create_attrs %{
    current_step: 1,
    max_steps: 4,
    number_of_persons: 2,
    is_booking_for_self: true,
    payment_method: "bank_transfer",
    payment_plan: "full_payment",
    notes: "some notes",
    travelers_data: [%{name: "John Doe", age: 30}],
    total_amount: "2500.00",
    deposit_amount: "500.00",
    status: "in_progress",
    last_updated: ~U[2024-08-15 10:00:00Z]
  }

  setup do
    %{user: user_fixture()}
  end

  describe "Admin Payments Live" do
    test "renders payments table for admin users", %{conn: conn, user: user} do
      # Make user an admin
      {:ok, admin_user} = Accounts.update_user(user, %{is_admin: true})

      # Create a package
      package = package_fixture()

      # Create a package schedule
      package_schedule = package_schedule_fixture(%{package_id: package.id})

      # Create booking flow progress
      {:ok, booking_flow_progress} = Bookings.create_booking_flow_progress(
        @create_attrs
        |> Map.put(:user_id, admin_user.id)
        |> Map.put(:package_id, package.id)
        |> Map.put(:package_schedule_id, package_schedule.id)
      )

      # Test the live view
      {:ok, _view, html} = live(conn, ~p"/admin/payments")

      assert html =~ "Payments Management"
      assert html =~ admin_user.full_name
      assert html =~ package.name
      assert html =~ "RM 2,500"
      assert html =~ "Bank Transfer"
      assert html =~ "In Progress"
    end

    test "filters payments by status", %{conn: conn, user: user} do
      # Make user an admin
      {:ok, admin_user} = Accounts.update_user(user, %{is_admin: true})

      # Create packages and schedules
      package1 = package_fixture()
      package2 = package_fixture()
      package_schedule1 = package_schedule_fixture(%{package_id: package1.id})
      package_schedule2 = package_schedule_fixture(%{package_id: package2.id})

      # Create completed and in-progress bookings
      {:ok, _completed} = Bookings.create_booking_flow_progress(
        @create_attrs
        |> Map.put(:user_id, admin_user.id)
        |> Map.put(:package_id, package1.id)
        |> Map.put(:package_schedule_id, package_schedule1.id)
        |> Map.put(:status, "completed")
      )

      {:ok, _in_progress} = Bookings.create_booking_flow_progress(
        @create_attrs
        |> Map.put(:user_id, admin_user.id)
        |> Map.put(:package_id, package2.id)
        |> Map.put(:package_schedule_id, package_schedule2.id)
        |> Map.put(:status, "in_progress")
      )

      # Test filtering
      {:ok, view, _html} = live(conn, ~p"/admin/payments")

      # Filter by completed
      view |> element("button[phx-value-status='completed']") |> render_click()
      assert has_element?(view, "td", "Completed")

      # Filter by in progress
      view |> element("button[phx-value-status='in_progress']") |> render_click()
      assert has_element?(view, "td", "In Progress")
    end

    test "searches payments by customer name", %{conn: conn, user: user} do
      # Make user an admin
      {:ok, admin_user} = Accounts.update_user(user, %{is_admin: true})

      # Create package and schedule
      package = package_fixture()
      package_schedule = package_schedule_fixture(%{package_id: package.id})

      # Create booking flow progress
      {:ok, _booking_flow_progress} = Bookings.create_booking_flow_progress(
        @create_attrs
        |> Map.put(:user_id, admin_user.id)
        |> Map.put(:package_id, package.id)
        |> Map.put(:package_schedule_id, package_schedule.id)
      )

      # Test search
      {:ok, view, _html} = live(conn, ~p"/admin/payments")

      # Search by customer name
      view |> form("form[phx-submit='search_payments']", search: admin_user.full_name) |> render_submit()
      assert has_element?(view, "td", admin_user.full_name)
    end
  end
end
