defmodule UmrahlyWeb.PageController do
  use UmrahlyWeb, :controller

  alias Umrahly.Profiles

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def test_flash(conn, _params) do
    conn
    |> put_flash(:info, "This is an information message")
    |> put_flash(:success, "This is a success message")
    |> put_flash(:warning, "This is a warning message")
    |> put_flash(:error, "This is an error message")
    |> render(:test_flash)
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

    render(conn, :dashboard,
      current_user: current_user,
      has_profile: has_profile,
      is_admin: is_admin
    )
  end

  def download_receipt(conn, %{"id" => receipt_id}) do
    current_user = conn.assigns.current_user

    # In a real application, you would:
    # 1. Verify the receipt belongs to the current user
    # 2. Get the actual file path from the database
    # 3. Check if the file exists
    # 4. Stream the file to the client

    # For now, we'll simulate a receipt download
    case get_receipt_file(receipt_id, current_user.id) do
      {:ok, file_path, filename} ->
        # Check if file exists
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

  defp get_receipt_file(receipt_id, _user_id) do
    # This would typically query a receipts table
    # For now, returning mock data
    case receipt_id do
      "1" ->
        {:ok, "priv/static/receipts/receipt_1.txt", "receipt_BK001_#{Date.utc_today()}.txt"}
      "2" ->
        {:ok, "priv/static/receipts/receipt_2.txt", "receipt_BK002_#{Date.utc_today()}.txt"}
      _ ->
        {:error, "Invalid receipt ID"}
    end
  end
end
