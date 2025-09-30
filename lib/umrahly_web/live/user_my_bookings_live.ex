defmodule UmrahlyWeb.UserMyBookingsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    bookings = Bookings.list_user_bookings_with_payments(socket.assigns.current_user.id)

    socket =
      socket
      |> assign(:page_title, "My Bookings")
      |> assign(:bookings_all, bookings)
      |> assign(:page, 1)
      |> assign(:page_size, 10)
      |> assign(:total_count, length(bookings))
      |> assign_pagination()

    {:ok, socket}
  end

  def handle_event("pg-first", _params, socket) do
    socket = socket |> assign(:page, 1) |> assign_pagination()
    {:noreply, socket}
  end

  def handle_event("pg-prev", _params, socket) do
    page = max(1, socket.assigns.page - 1)
    socket = socket |> assign(:page, page) |> assign_pagination()
    {:noreply, socket}
  end

  def handle_event("pg-next", _params, socket) do
    page = min(socket.assigns.total_pages, socket.assigns.page + 1)
    socket = socket |> assign(:page, page) |> assign_pagination()
    {:noreply, socket}
  end

  def handle_event("pg-last", _params, socket) do
    last = socket.assigns.total_pages
    socket = socket |> assign(:page, last) |> assign_pagination()
    {:noreply, socket}
  end

  defp assign_pagination(socket, bookings \\ nil) do
    bookings = bookings || socket.assigns.bookings_all
    page_size = socket.assigns.page_size
    total_count = length(bookings)
    total_pages = calc_total_pages(total_count, page_size)
    page = socket.assigns.page |> min(total_pages) |> max(1)
    visible_bookings = paginate_list(bookings, page, page_size)

    socket
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
    |> assign(:page, page)
    |> assign(:visible_bookings, visible_bookings)
  end

  defp calc_total_pages(0, _page_size), do: 1
  defp calc_total_pages(total_count, page_size) when page_size > 0 do
    div(total_count + page_size - 1, page_size)
  end

  defp paginate_list(list, page, page_size) do
    start_index = (page - 1) * page_size
    Enum.slice(list, start_index, page_size)
  end

  defp format_amount(nil), do: "0.00"
  defp format_amount(%Decimal{} = amount) do
    :erlang.float_to_binary(Decimal.to_float(amount), [decimals: 2])
  end
  defp format_amount(amount) when is_number(amount), do: :erlang.float_to_binary(amount * 1.0, [decimals: 2])
  defp format_amount(amount) when is_binary(amount) do
    case Float.parse(amount) do
      {num, _} -> :erlang.float_to_binary(num, [decimals: 2])
      :error -> "0.00"
    end
  end
  defp format_amount(_), do: "0.00"

  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div class="p-6">
        <h1 class="text-2xl font-semibold text-gray-900 mb-6">My Bookings</h1>

        <%= if Enum.empty?(@bookings_all) do %>
          <div class="text-center py-16 bg-white rounded-lg border border-dashed border-gray-300">
            <div class="mx-auto w-12 h-12 rounded-full bg-gray-100 flex items-center justify-center mb-4">
              <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900">No Bookings Yet</h3>
            <p class="mt-2 text-gray-500">Start by browsing our available packages.</p>
            <a href="/packages" class="mt-6 inline-flex items-center px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700">Browse Packages</a>
          </div>
        <% else %>
          <div class="bg-white rounded-lg shadow-sm ring-1 ring-gray-200 overflow-hidden">
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50 sticky top-0 z-10">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Reference</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Package</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Total</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Paid</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for b <- @visible_bookings do %>
                    <tr class="hover:bg-teal-50 hover:shadow-sm transition-colors duration-150 cursor-pointer">
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#<%= b.booking_reference %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700"><%= b.package_name %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"> <%= format_amount(b.total_amount) %> </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-green-700"> <%= format_amount(b.paid_amount || 0) %> </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={["inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                          if(String.downcase(b.status || "") == "confirmed", do: "bg-green-100 text-green-800", else: "bg-blue-100 text-blue-800")
                        ]}>
                          <%= String.upcase(b.status || "PENDING") %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <%= if b.booking_date do %>
                          <%= UmrahlyWeb.Timezone.format_local(b.booking_date, "%b %d, %Y") %>
                        <% else %>
                          -
                        <% end %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <a href={"/bookings/#{b.id}"} class="text-blue-600 hover:text-blue-900">
                          View
                        </a>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
            <div class="px-6 py-4 bg-gray-50 flex items-center justify-between text-sm text-gray-600">
              <div>
                Need to pay remaining amount? Go to <a href="/payments" class="font-medium text-blue-600 hover:text-blue-700">Payments</a>.
              </div>
              <div class="flex items-center gap-2">
                <button phx-click="pg-first" class="px-2 py-1 rounded border bg-white hover:bg-gray-100 disabled:opacity-50" disabled={@page == 1}>« First</button>
                <button phx-click="pg-prev" class="px-2 py-1 rounded border bg-white hover:bg-gray-100 disabled:opacity-50" disabled={@page == 1}>‹ Prev</button>
                <span class="px-2">Page <%= @page %> of <%= @total_pages %></span>
                <button phx-click="pg-next" class="px-2 py-1 rounded border bg-white hover:bg-gray-100 disabled:opacity-50" disabled={@page == @total_pages}>Next ›</button>
                <button phx-click="pg-last" class="px-2 py-1 rounded border bg-white hover:bg-gray-100 disabled:opacity-50" disabled={@page == @total_pages}>Last »</button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </.sidebar>
    """
  end
end
