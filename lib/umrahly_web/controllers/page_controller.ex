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
end
