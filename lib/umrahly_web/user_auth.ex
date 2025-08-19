defmodule UmrahlyWeb.UserAuth do
  use UmrahlyWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Umrahly.Accounts

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_umrahly_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)
    redirect_path = if user_return_to do
      user_return_to
    else
      if Umrahly.Accounts.is_admin?(user) do
        ~p"/admin/dashboard"
      else
        # Check if user has profile information
        has_profile = user.address != nil or user.identity_card_number != nil or user.phone_number != nil or
                      user.monthly_income != nil or user.birthdate != nil or user.gender != nil

        if not has_profile do
          ~p"/complete-profile"
        else
          ~p"/dashboard"
        end
      end
    end

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: redirect_path)
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      UmrahlyWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)

    # Set has_profile assign for the root layout
    has_profile = if user do
      # Check if user has profile information
      user.address != nil or user.identity_card_number != nil or user.phone_number != nil or
      user.monthly_income != nil or user.birthdate != nil or user.gender != nil
    else
      false
    end

    conn
    |> assign(:current_user, user)
    |> assign(:has_profile, has_profile)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule UmrahlyWeb.PageLive do
        use UmrahlyWeb, :live_view

        on_mount {UmrahlyWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{UmrahlyWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    socket = Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session["user_token"] do
        Accounts.get_user_by_session_token(user_token)
      end
    end)

    # Set has_profile assign for LiveViews
    Phoenix.Component.assign_new(socket, :has_profile, fn ->
      if user = socket.assigns.current_user do
        # Check if user has profile information
        user.address != nil or user.identity_card_number != nil or user.phone_number != nil or
        user.monthly_income != nil or user.birthdate != nil or user.gender != nil
      else
        false
      end
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
    def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
        |> put_flash(:error, "You must log in to access this page.")
        |> maybe_store_return_to()
        |> redirect(to: ~p"/users/log_in")
        |> halt()
    end
  end

  def require_admin_user(conn, _opts) do
    current_user = conn.assigns[:current_user]

    if current_user && Umrahly.Accounts.is_admin?(current_user) do
      conn
    else
      conn
        |> Phoenix.Controller.put_flash(:error, "You must be an admin to access this page.")
        |> Phoenix.Controller.redirect(to: ~p"/dashboard")
        |> halt()
    end
  end

  def require_regular_user(conn, _opts) do
    current_user = conn.assigns[:current_user]

    if current_user && !Umrahly.Accounts.is_admin?(current_user) do
      conn
    else
      conn
        |> Phoenix.Controller.put_flash(:error, "This page is only for regular users.")
        |> Phoenix.Controller.redirect(to: ~p"/admin/dashboard")
        |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(conn) do
    user = conn.assigns[:current_user]
    if user do
      # Check if user is admin or has a profile
      if Umrahly.Accounts.is_admin?(user) do
        ~p"/admin/dashboard"
      else
        # Check if user has profile information
        has_profile = user.address != nil or user.identity_card_number != nil or user.phone_number != nil or
                      user.monthly_income != nil or user.birthdate != nil or user.gender != nil

        if not has_profile do
          ~p"/complete-profile"
        else
          ~p"/dashboard"
        end
      end
    else
      ~p"/dashboard"
    end
  end
end
