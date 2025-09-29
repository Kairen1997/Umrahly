defmodule Umrahly.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias Umrahly.Repo
  alias Umrahly.Notifications.Notification

  @doc """
  Returns the list of notifications for a user.
  """
  def list_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    unread_only = Keyword.get(opts, :unread_only, false)

    query = from n in Notification,
            where: n.user_id == ^user_id,
            order_by: [desc: n.inserted_at]

    query = if unread_only do
      where(query, [n], n.read == false)
    else
      query
    end

    query
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets a single notification.
  """
  def get_notification!(id), do: Repo.get!(Notification, id)

  @doc """
  Creates a notification.
  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a notification.
  """
  def update_notification(%Notification{} = notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a notification.
  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Marks a notification as read.
  """
  def mark_as_read(%Notification{} = notification) do
    update_notification(notification, %{read: true})
  end

  @doc """
  Marks all notifications as read for a user.
  """
  def mark_all_as_read(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and n.read == false)
    |> Repo.update_all(set: [read: true])
  end

  @doc """
  Gets the count of unread notifications for a user.
  """
  def unread_count(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and n.read == false)
    |> Repo.aggregate(:count)
  end

  @doc """
  Creates a booking notification.
  """
  def create_booking_notification(user_id, booking, type) do
    {title, message} = case type do
      :created ->
        {"Booking Created", "Your booking for #{booking.package_name} has been created successfully."}
      :cancelled ->
        {"Booking Cancelled", "Your booking for #{booking.package_name} has been cancelled."}
      :confirmed ->
        {"Booking Confirmed", "Your booking for #{booking.package_name} has been confirmed."}
    end

    create_notification(%{
      user_id: user_id,
      title: title,
      message: message,
      notification_type: "booking_#{type}",
      metadata: %{
        booking_id: booking.id,
        package_name: booking.package_name,
        booking_reference: booking.booking_reference
      }
    })
  end

  @doc """
  Creates a payment notification.
  """
  def create_payment_notification(user_id, payment, type) do
    {title, message} = case type do
      :received ->
        {"Payment Received", "Payment of #{payment.amount} has been received for your booking."}
      :approved ->
        {"Payment Approved", "Your payment of #{payment.amount} has been approved."}
      :rejected ->
        {"Payment Rejected", "Your payment of #{payment.amount} has been rejected. Please contact support."}
    end

    create_notification(%{
      user_id: user_id,
      title: title,
      message: message,
      notification_type: "payment_#{type}",
      metadata: %{
        payment_id: payment.id,
        amount: payment.amount,
        booking_reference: payment.booking_reference
      }
    })
  end

  @doc """
  Creates an admin notification.
  """
  def create_admin_notification(admin_id, title, message, metadata \\ %{}) do
    create_notification(%{
      user_id: admin_id,
      title: title,
      message: message,
      notification_type: "admin_alert",
      metadata: metadata
    })
  end

  @doc """
  Creates a package update notification for all users with bookings.
  """
  def create_package_update_notification(package_id, package_name, update_type) do
    # Get all users who have bookings for this package
    users_with_bookings = from(
      b in Umrahly.Bookings.Booking,
      where: b.package_id == ^package_id,
      select: b.user_id,
      distinct: true
    ) |> Repo.all()

    {title, message} = case update_type do
      :schedule_changed ->
        {"Package Schedule Updated", "The schedule for #{package_name} has been updated."}
      :price_changed ->
        {"Package Price Updated", "The price for #{package_name} has been updated."}
      :cancelled ->
        {"Package Cancelled", "#{package_name} has been cancelled. Please contact support."}
    end

    # Create notifications for all affected users
    Enum.each(users_with_bookings, fn user_id ->
      create_notification(%{
        user_id: user_id,
        title: title,
        message: message,
        notification_type: "package_updated",
        metadata: %{
          package_id: package_id,
          package_name: package_name,
          update_type: update_type
        }
      })
    end)
  end
end
