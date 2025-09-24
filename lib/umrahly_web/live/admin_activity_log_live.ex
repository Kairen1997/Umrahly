defmodule UmrahlyWeb.AdminActivityLogLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.ActivityLogs

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

  def handle_event("export_logs", _params, socket) do
    csv = build_csv(ActivityLogs.list_all_detailed_activities())
    filename = "activity_logs_" <> (Date.utc_today() |> Date.to_iso8601()) <> ".csv"

    {:noreply,
     Phoenix.LiveView.send_download(socket, {:binary, csv}, filename: filename, content_type: "text/csv")}
  end

  defp build_csv(rows) do
    header = ["Timestamp","User","Action","Details","Status","IP Address","User Agent"]

    data_lines =
      rows
      |> Enum.map(fn r ->
        [r.timestamp, r.user_name, r.action, r.details, r.status, r.ip_address, r.user_agent]
        |> Enum.map(&escape_csv/1)
        |> Enum.join(",")
      end)

    Enum.join([Enum.join(header, ",") | data_lines], "\n")
  end

  defp escape_csv(nil), do: ""
  defp escape_csv(value) when is_binary(value) do
    escaped = String.replace(value, "\"", "\"\"")
    if String.contains?(escaped, [",", "\n", "\r", "\""]) do
      "\"" <> escaped <> "\""
    else
      escaped
    end
  end
  defp escape_csv(value), do: to_string(value)

  defp total_pages(total, page_size) do
    case {total, page_size} do
      {0, _} -> 1
      {t, ps} -> div(t + ps - 1, ps)
    end
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Activity Log</h1>
            <div class="flex space-x-2">
              <button phx-click="export_logs" class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors">
                Export Logs
              </button>
              <button class="bg-gray-600 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors">
                Clear Old Logs
              </button>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Timestamp</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Action</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Details</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">IP Address</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for activity <- @activities do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= activity.timestamp %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900"><%= activity.user_name %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= activity.action %></td>
                    <td class="px-6 py-4 text-sm text-gray-900 max-w-xs truncate" title={activity.details}>
                      <%= activity.details %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
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
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= activity.ip_address %></td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button class="text-teal-600 hover:text-teal-900 mr-3">View</button>
                      <button class="text-blue-600 hover:text-blue-900">Details</button>
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
    </.admin_layout>
    """
  end
end
