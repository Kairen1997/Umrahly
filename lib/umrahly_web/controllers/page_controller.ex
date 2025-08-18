defmodule UmrahlyWeb.PageController do
  use UmrahlyWeb, :controller

  alias Umrahly.Profiles

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    current_user = conn.assigns[:current_user]

    has_profile = if current_user do
      profile = Profiles.get_profile_by_user_id(current_user.id)
      profile != nil
    else
      false
    end

    render(conn, :home, layout: false, has_profile: has_profile, current_user: current_user)
  end

  def dashboard(conn, _params) do
    render(conn, :dashboard, current_user: conn.assigns.current_user)
  end
end
