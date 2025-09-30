defmodule UmrahlyWeb.PageController do
  use UmrahlyWeb, :controller

  alias Umrahly.Profiles
  alias Umrahly.Repo
  alias Umrahly.Bookings.Booking

  def home(conn, _params) do
    # Fetch active packages for the landing page
    packages = Umrahly.Packages.list_active_packages_with_schedules()

    # Limit to 3 packages for the landing page (or however many you want)
    featured_packages = packages |> Enum.take(3)

    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false, packages: featured_packages)
  end

  def test_flash(conn, _params) do
    conn
    |> put_flash(:info, "This is an information message")
    |> put_flash(:success, "This is a success message")
    |> put_flash(:warning, "This is a warning message")
    |> put_flash(:error, "This is an error message")
    |> render(:test_flash)
  end

  def faq(conn, _params) do
    render(conn, :faq, layout: false)
  end

  def terms(conn, _params) do
    render(conn, :terms, layout: false)
  end

  def privacy(conn, _params) do
    render(conn, :privacy, layout: false)
  end

  def dashboard(conn, _params) do
    current_user = conn.assigns.current_user

    {has_profile, is_admin} = if current_user do
      is_admin = Umrahly.Accounts.is_admin?(current_user)
      has_profile = if is_admin do
        true  # Admin users are considered to have "complete" profiles
      else
        profile = Profiles.get_profile_by_user_id(current_user.id)
        profile != nil
      end
      {has_profile, is_admin}
    else
      {false, false}
    end

    # Latest active booking with payments for dashboard widgets
    latest_booking = if current_user, do: Umrahly.Bookings.get_latest_active_booking_with_payments(current_user.id), else: nil

    # Recent user activities
    recent_activities = if current_user, do: Umrahly.ActivityLogs.recent_user_activities(current_user.id, 10), else: []

    # Compute user stats
    user_stats = if current_user do
      %{
        active_bookings: Umrahly.Bookings.count_active_bookings_for_user(current_user.id),
        total_paid: Umrahly.Bookings.sum_paid_amount_for_user(current_user.id)
      }
    else
      %{
        active_bookings: 0,
        total_paid: 0
      }
    end

    render(conn, :dashboard,
      current_user: current_user,
      has_profile: has_profile,
      is_admin: is_admin,
      latest_booking: latest_booking,
      recent_activities: recent_activities,
      user_stats: user_stats
    )
  end

  def view_receipt(conn, %{"id" => receipt_id}) do
    current_user = conn.assigns.current_user

    with {id, _} <- Integer.parse(to_string(receipt_id)),
         %Booking{} = booking <- Repo.get(Booking, id) |> Repo.preload([:package_schedule, package_schedule: :package]),
         true <- booking.user_id == current_user.id do
      total = booking.total_amount || Decimal.new(0)
      paid = booking.deposit_amount || Decimal.new(0)
      booking_ref = "BK" <> Integer.to_string(booking.id)

      render(conn, :receipt_a4,
        layout: {UmrahlyWeb.Layouts, :app},
        booking: booking,
        booking_ref: booking_ref,
        total: total,
        paid: paid,
        generated_date: Date.utc_today(),
        current_user: current_user
      )
    else
      _ ->
        conn
        |> put_flash(:error, "Invalid or unauthorized receipt")
        |> redirect(to: ~p"/payments")
    end
  end

  def download_receipt(conn, %{"id" => receipt_id}) do
    current_user = conn.assigns.current_user

    case get_receipt_file(receipt_id, current_user.id) do
      {:ok, file_path, filename} ->
        if File.exists?(file_path) do
          conn
          |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
          |> put_resp_content_type("text/plain")
          |> send_file(200, file_path)
        else
          conn
          |> put_flash(:error, "Receipt file not found")
          |> redirect(to: ~p"/payments")
        end
      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to download receipt: #{reason}")
        |> redirect(to: ~p"/payments")
    end
  end

  defp get_receipt_file(receipt_id, user_id) do
    with {id, _} <- Integer.parse(to_string(receipt_id)),
         booking when not is_nil(booking) <- Repo.get(Booking, id),
         true <- booking.user_id == user_id do
      # Ensure receipt directory
      receipt_dir = Path.join(["priv", "static", "receipts"]) |> tap(&File.mkdir_p!/1)

      booking_ref = "BK" <> Integer.to_string(booking.id)
      filename = "receipt_#{booking_ref}_#{Date.utc_today()}.txt"
      file_path = Path.join(receipt_dir, filename)

      # Generate a simple text receipt if it doesn't exist
      unless File.exists?(file_path) do
        total = booking.total_amount || Decimal.new(0)
        paid = booking.deposit_amount || Decimal.new(0)
        content = [
          "Umrahly Payment Receipt\n",
          "=======================\n",
          "Date: #{Date.utc_today()}\n",
          "Booking Reference: ##{booking_ref}\n",
          "Payment Method: #{booking.payment_method || "unknown"}\n",
          "Status: #{booking.status}\n",
          "Total Amount (RM): #{Decimal.to_string(total)}\n",
          "Paid Amount (RM): #{Decimal.to_string(paid)}\n"
        ] |> IO.iodata_to_binary()

        File.write!(file_path, content)
      end

      {:ok, file_path, filename}
    else
      _ -> {:error, "Invalid or unauthorized receipt"}
    end
  end
end
