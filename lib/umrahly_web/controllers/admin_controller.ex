defmodule UmrahlyWeb.AdminController do
  use UmrahlyWeb, :controller

  def dashboard(conn, _params) do
    current_user = conn.assigns[:current_user]

    {has_profile, profile_data} = if current_user do
      # Profile data is now part of the user
      profile_data = %{
        address: current_user.address,
        identity_card_number: current_user.identity_card_number,
        phone_number: current_user.phone_number,
        monthly_income: current_user.monthly_income,
        birthdate: current_user.birthdate,
        gender: current_user.gender,
        profile_photo: current_user.profile_photo
      }

      has_profile = current_user.address != nil or current_user.identity_card_number != nil or
                    current_user.phone_number != nil or current_user.monthly_income != nil or
                    current_user.birthdate != nil or current_user.gender != nil

      {has_profile, profile_data}
    else
      {false, nil}
    end

    # Mock data for admin dashboard - in a real app, this would come from your database
    admin_stats = %{
      total_bookings: 124,
      total_payments: "RM 300,000",
      packages_available: 6,
      pending_verification: 3
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
    |> assign(:recent_activities, recent_activities)
    |> assign(:current_user, current_user)
    |> assign(:has_profile, has_profile)
    |> assign(:profile, profile_data)
    |> assign(:is_admin, true)
    |> assign(:current_page, "dashboard")
    |> render(:dashboard)
  end
end
