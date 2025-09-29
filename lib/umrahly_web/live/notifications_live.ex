defmodule UmrahlyWeb.NotificationsLive do
  use UmrahlyWeb, :live_view

  alias Umrahly.Notifications

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    notifications = Notifications.list_notifications(current_user.id)
    unread_count = Notifications.unread_count(current_user.id)

    socket =
      socket
      |> assign(:notifications, notifications)
      |> assign(:unread_count, unread_count)

    {:ok, socket}
  end

  def handle_event("mark_as_read", %{"id" => id}, socket) do
    notification = Notifications.get_notification!(id)
    {:ok, _} = Notifications.mark_as_read(notification)

    # Update the notification in the list
    updated_notifications = Enum.map(socket.assigns.notifications, fn n ->
      if n.id == String.to_integer(id) do
        %{n | read: true}
      else
        n
      end
    end)

    unread_count = socket.assigns.unread_count - 1

    socket =
      socket
      |> assign(:notifications, updated_notifications)
      |> assign(:unread_count, unread_count)

    {:noreply, socket}
  end

  def handle_event("mark_all_read", _params, socket) do
    {:ok, _} = Notifications.mark_all_as_read(socket.assigns.current_user.id)

    # Update all notifications to read
    updated_notifications = Enum.map(socket.assigns.notifications, &%{&1 | read: true})

    socket =
      socket
      |> assign(:notifications, updated_notifications)
      |> assign(:unread_count, 0)

    {:noreply, socket}
  end

  def handle_event("delete_notification", %{"id" => id}, socket) do
    notification = Notifications.get_notification!(id)
    {:ok, _} = Notifications.delete_notification(notification)

    # Remove from the list
    updated_notifications = Enum.reject(socket.assigns.notifications, &(&1.id == String.to_integer(id)))

    # Update unread count if it was unread
    unread_count = if notification.read, do: socket.assigns.unread_count, else: socket.assigns.unread_count - 1

    socket =
      socket
      |> assign(:notifications, updated_notifications)
      |> assign(:unread_count, unread_count)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <!-- Header -->
      <div class="bg-white rounded-lg shadow mb-6">
        <div class="px-6 py-4 border-b border-gray-200">
          <div class="flex items-center justify-between">
            <h1 class="text-2xl font-bold text-gray-900">Notifications</h1>
            <div class="flex items-center space-x-3">
              <%= if @unread_count > 0 do %>
                <button
                  phx-click="mark_all_read"
                  class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm"
                >
                  Mark All as Read
                </button>
              <% end %>
              <div class="text-sm text-gray-600">
                <%= @unread_count %> unread
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Notifications List -->
      <div class="bg-white rounded-lg shadow">
        <%= if @notifications == [] do %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No notifications</h3>
            <p class="mt-1 text-sm text-gray-500">You don't have any notifications yet.</p>
          </div>
        <% else %>
          <div class="divide-y divide-gray-200">
            <%= for notification <- @notifications do %>
              <div class={[
                "p-6 hover:bg-gray-50 transition-colors",
                if(notification.read, do: "bg-gray-50", else: "bg-blue-50")
              ]}>
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <div class="flex items-center space-x-3">
                      <%= if not notification.read do %>
                        <div class="w-2 h-2 bg-blue-500 rounded-full"></div>
                      <% end %>
                      <h3 class="text-sm font-medium text-gray-900">
                        <%= notification.title %>
                      </h3>
                      <span class={[
                        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                        case notification.notification_type do
                          "booking_created" -> "bg-green-100 text-green-800"
                          "booking_cancelled" -> "bg-red-100 text-red-800"
                          "payment_received" -> "bg-blue-100 text-blue-800"
                          "payment_approved" -> "bg-green-100 text-green-800"
                          "payment_rejected" -> "bg-red-100 text-red-800"
                          "package_updated" -> "bg-yellow-100 text-yellow-800"
                          "admin_alert" -> "bg-purple-100 text-purple-800"
                          _ -> "bg-gray-100 text-gray-800"
                        end
                      ]}>
                        <%= String.replace(notification.notification_type, "_", " ") |> String.capitalize() %>
                      </span>
                    </div>
                    <p class="mt-2 text-sm text-gray-600">
                      <%= notification.message %>
                    </p>
                    <p class="mt-2 text-xs text-gray-500">
                      <%= Calendar.strftime(notification.inserted_at, "%B %d, %Y at %I:%M %p") %>
                    </p>
                  </div>
                  <div class="flex items-center space-x-2 ml-4">
                    <%= if not notification.read do %>
                      <button
                        phx-click="mark_as_read"
                        phx-value-id={notification.id}
                        class="text-blue-600 hover:text-blue-800 text-sm font-medium"
                      >
                        Mark as read
                      </button>
                    <% end %>
                    <button
                      phx-click="delete_notification"
                      phx-value-id={notification.id}
                      class="text-red-600 hover:text-red-800 text-sm font-medium"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
