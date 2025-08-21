defmodule UmrahlyWeb.PageController do
  use UmrahlyWeb, :controller

  def home(conn, _params) do
    current_user = conn.assigns[:current_user]

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

    render(conn, :home,
      has_profile: has_profile,
      current_user: current_user,
      is_admin: is_admin
    )
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
