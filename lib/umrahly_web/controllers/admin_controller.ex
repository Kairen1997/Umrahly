defmodule UmrahlyWeb.AdminController do
  use UmrahlyWeb, :controller

  alias Umrahly.Profiles
  alias Umrahly.Packages

  def dashboard(conn, _params) do
    current_user = conn.assigns[:current_user]

    {has_profile, profile} = if current_user do
      profile = Profiles.get_profile_by_user_id(current_user.id)
      {profile != nil, profile}
    else
      {false, nil}
    end

    # Get real data for admin dashboard
    package_stats = Packages.get_enhanced_package_statistics()
    recent_package_activities = Packages.get_recent_package_activities(3)

    admin_stats = %{
      total_bookings: 124, # TODO: Replace with real bookings count when bookings module is implemented
      total_payments: "RM 300,000", # TODO: Replace with real payments data when payments module is implemented
      packages_available: package_stats.active_packages,
      pending_verification: 3 # TODO: Replace with real verification count when user verification is implemented
    }

    recent_activities = [
      %{
        title: "Payment",
        activity_message: "John submitted a payment (RM1,000)",
        timestamp: "Today at 9:40 AM",
        action: "View / Approve"
      },
      %{
        title: "Booking",
        activity_message: "Sarah booked Standard Package",
        timestamp: "6 Aug, 8:15 PM",
        action: "View / Confirm"
      },
      %{
        title: "Profile Update",
        activity_message: "Ahmed updated contact information",
        timestamp: "6 Aug, 6:30 PM",
        action: "View"
      }
    ]

    conn
    |> assign(:admin_stats, admin_stats)
    |> assign(:package_stats, package_stats)
    |> assign(:recent_package_activities, recent_package_activities)
    |> assign(:recent_activities, recent_activities)
    |> assign(:current_user, current_user)
    |> assign(:has_profile, has_profile)
    |> assign(:profile, profile)
    |> assign(:is_admin, true)
    |> assign(:current_page, "dashboard")
    |> render(:dashboard)
  end
end
