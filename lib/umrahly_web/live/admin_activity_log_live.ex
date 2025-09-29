defmodule UmrahlyWeb.AdminActivityLogLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.ActivityLogs
  alias Phoenix.LiveView.JS

  @page_size 10

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:activities, [])
      |> assign(:page, 1)
      |> assign(:page_size, @page_size)
      |> assign(:total, 0)
      |> assign(:current_page, "activity-log")
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns.current_user)
      |> assign(:selected_activity, nil)
      |> assign(:show_activity_modal, false)

    {:ok, socket, temporary_assigns: [activities: []]}
  end

  def handle_params(params, _uri, socket) do
    page =
      case Map.get(params, "page") do
        nil -> 1
        p when is_binary(p) ->
          case Integer.parse(p) do
            {n, _} when n > 0 -> n
            _ -> 1
          end
        p when is_integer(p) and p > 0 -> p
        _ -> 1
      end

    %{entries: entries, total: total, page: page, page_size: page_size} =
      ActivityLogs.list_detailed_activities_paginated(page, @page_size)

    {:noreply,
     socket
     |> assign(:activities, entries)
     |> assign(:total, total)
     |> assign(:page, page)
     |> assign(:page_size, page_size)}
  end

  defp total_pages(total, page_size) do
    case {total, page_size} do
      {0, _} -> 1
      {t, ps} -> div(t + ps - 1, ps)
    end
  end

  # Actions: View & Details
  def handle_event("view_activity", %{"id" => id}, socket) do
    {:noreply, show_activity_modal(socket, id)}
  end

  def handle_event("details_activity", %{"id" => id}, socket) do
    {:noreply, show_activity_modal(socket, id)}
  end

  def handle_event("close_activity_modal", _params, socket) do
    {:noreply, socket |> assign(:show_activity_modal, false) |> assign(:selected_activity, nil)}
  end

  defp show_activity_modal(socket, id) do
    {int_id, _} = Integer.parse(to_string(id))
    activity = Enum.find(socket.assigns.activities, fn a -> a.id == int_id end)

    socket
    |> assign(:selected_activity, activity)
    |> assign(:show_activity_modal, true)
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Activity Log</h1>
            <div class="flex space-x-2">
              <button class="bg-gray-600 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors">
                Clear Old Logs
              </button>
            </div>
          </div>

          <div>
            <table class="w-full table-fixed divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-40">Timestamp</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-48">User</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-48">Action</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Details</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-28">Status</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-40">IP Address</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-32">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for activity <- @activities do %>
                  <tr class="hover:bg-teal-50">
                    <td class="px-6 py-4 text-sm text-gray-900"><%= activity.timestamp %></td>
                    <td class="px-6 py-4 text-sm font-medium text-gray-900"><%= activity.user_name %></td>
                    <td class="px-6 py-4 text-sm text-gray-900"><%= activity.action %></td>
                    <td class="px-6 py-4 text-sm text-gray-900 whitespace-normal break-words"><%= activity.details %></td>
                    <td class="px-6 py-4">
                      <%= if activity.status do %>
                        <span class={[
                          "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                          case activity.status do
                            "Success" -> "bg-green-100 text-green-800"
                            "Failed" -> "bg-red-100 text-red-800"
                            "Warning" -> "bg-yellow-100 text-yellow-800"
                            _ -> "bg-gray-100 text-gray-800"
                          end
                        ]}>
                          <%= activity.status %>
                        </span>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-900"><%= activity.ip_address %></td>
                    <td class="px-6 py-4 text-sm font-medium">
                      <button phx-click="view_activity" phx-value-id={activity.id} class="text-teal-600 hover:text-teal-900 mr-3">View</button>
                      <button phx-click="details_activity" phx-value-id={activity.id} class="text-blue-600 hover:text-blue-900">Details</button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <!-- Pagination -->
          <div class="mt-6 flex items-center justify-between">
            <div class="text-sm text-gray-700">
              <%=
                first_item = if @total == 0, do: 0, else: ((@page - 1) * @page_size) + 1
                last_item = min(@page * @page_size, @total)
              %>
              Showing <span class="font-medium"><%= first_item %></span> to <span class="font-medium"><%= last_item %></span> of <span class="font-medium"><%= @total %></span> results
            </div>
            <div class="flex space-x-2">
              <.link navigate={~p"/admin/activity-log?page=#{@page - 1}"} class="px-3 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed" aria-disabled={@page <= 1}>
                Previous
              </.link>
              <.link navigate={~p"/admin/activity-log?page=#{@page + 1}"} class="px-3 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed" aria-disabled={@page >= total_pages(@total, @page_size)}>
                Next
              </.link>
            </div>
          </div>
        </div>
      </div>

      <!-- Activity Modal -->
      <.modal :if={@show_activity_modal} id="activity-modal" show={true} on_cancel={JS.push("close_activity_modal")}>
        <div class="space-y-4">
          <h2 class="text-xl font-semibold text-gray-900">Activity Details</h2>
          <%= if @selected_activity do %>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
              <div>
                <div class="text-gray-500">User</div>
                <div class="text-gray-900 font-medium"><%= @selected_activity.user_name %></div>
              </div>
              <div>
                <div class="text-gray-500">Timestamp</div>
                <div class="text-gray-900"><%= @selected_activity.timestamp %></div>
              </div>
              <div>
                <div class="text-gray-500">Action</div>
                <div class="text-gray-900"><%= @selected_activity.action %></div>
              </div>
              <div>
                <div class="text-gray-500">Status</div>
                <div class="text-gray-900"><%= @selected_activity.status || "-" %></div>
              </div>
              <div>
                <div class="text-gray-500">IP Address</div>
                <div class="text-gray-900"><%= @selected_activity.ip_address || "-" %></div>
              </div>
              <div class="sm:col-span-2">
                <div class="text-gray-500">Details</div>
                <div class="text-gray-900 whitespace-pre-wrap break-words"><%= @selected_activity.details %></div>
              </div>
            </div>
          <% else %>
            <div class="text-gray-600">Activity not found.</div>
          <% end %>
          <div class="pt-4 flex justify-end">
            <button phx-click={JS.push("close_activity_modal")} class="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700">Close</button>
          </div>
        </div>
      </.modal>
    </.admin_layout>
    """
  end
end
