defmodule UmrahlyWeb.AdminBookingsLive do
  use UmrahlyWeb, :live_view

    import UmrahlyWeb.AdminLayout
  alias Umrahly.Bookings
  alias Umrahly.Packages

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:search_term, "")
      |> assign(:current_page, "bookings")
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns.current_user)
      |> assign(:page, 1)
      |> assign(:page_size, 10)
      |> assign(:total_count, 0)
      |> assign(:total_pages, 0)
      |> assign(:show_view_modal, false)
      |> assign(:selected_booking, nil)
      |> assign(:status_filter, "all")
      |> assign(:package_filter, "all")
      |> assign(:status_options, ["all" | Bookings.get_booking_status()])
      |> assign(:package_options, Packages.list_packages() |> Enum.map(&%{id: &1.id, name: &1.name}))
      |> load_bookings()

    {:ok, socket}
  end

  def handle_event("search", %{"search_term" => search_term}, socket) do
    socket =
      socket
      |> assign(:search_term, search_term)
      |> assign(:page, 1)
      |> load_bookings()

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:search_term, "")
      |> assign(:page, 1)
      |> load_bookings()

    {:noreply, socket}
  end

  def handle_event("prev_page", _params, socket) do
    new_page = max(socket.assigns.page - 1, 1)
    socket = socket |> assign(:page, new_page) |> load_bookings()
    {:noreply, socket}
  end

  def handle_event("next_page", _params, socket) do
    new_page = min(socket.assigns.page + 1, max(socket.assigns.total_pages, 1))
    socket = socket |> assign(:page, new_page) |> load_bookings()
    {:noreply, socket}
  end

  def handle_event("first_page", _params, socket) do
    socket = socket |> assign(:page, 1) |> load_bookings()
    {:noreply, socket}
  end

  def handle_event("last_page", _params, socket) do
    last_page = max(socket.assigns.total_pages, 1)
    socket = socket |> assign(:page, last_page) |> load_bookings()
    {:noreply, socket}
  end

  def handle_event("go_to_page", %{"page" => page_str}, socket) do
    page =
      case Integer.parse(to_string(page_str)) do
        {p, _} -> p
        :error -> socket.assigns.page
      end

    page =
      page
      |> max(1)
      |> min(max(socket.assigns.total_pages, 1))

    socket = socket |> assign(:page, page) |> load_bookings()
    {:noreply, socket}
  end

  def handle_event("delete_booking", %{"id" => id}, socket) do
    try do
      booking_id =
        case id do
          i when is_integer(i) -> i
          _ -> String.to_integer(to_string(id))
        end

      booking = Umrahly.Bookings.get_booking!(booking_id)
      case Umrahly.Bookings.delete_booking(booking) do
        {:ok, _} ->
          socket =
            socket
            |> put_flash(:info, "Booking deleted successfully")
            |> assign(:show_view_modal, false)
            |> assign(:selected_booking, nil)
            |> load_bookings()

          {:noreply, socket}
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete booking")}
      end
    rescue
      _ ->
        {:noreply, put_flash(socket, :error, "Booking not found or could not be deleted")}
    end
  end

  def handle_event("view_booking", %{"id" => id}, socket) do
    booking_id =
      case id do
        i when is_integer(i) -> i
        _ -> String.to_integer(to_string(id))
      end

    selected_booking = Enum.find(socket.assigns.bookings, fn b -> b.id == booking_id end)

    socket =
      socket
      |> assign(:selected_booking, selected_booking)
      |> assign(:show_view_modal, true)

    {:noreply, socket}
  end

  def handle_event("close_view_modal", _params, socket) do
    {:noreply, socket |> assign(:show_view_modal, false) |> assign(:selected_booking, nil)}
  end

  def handle_event("filter_change", params, socket) do
    status = Map.get(params, "status", socket.assigns.status_filter) |> to_string()
    package_id = Map.get(params, "package_id", socket.assigns.package_filter) |> to_string()

    status = if status == "" do "all" else status end
    package_id = if package_id == "" do "all" else package_id end

    socket =
      socket
      |> assign(:status_filter, status)
      |> assign(:package_filter, package_id)
      |> assign(:page, 1)
      |> load_bookings()

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    socket =
      socket
      |> assign(:status_filter, "all")
      |> assign(:package_filter, "all")
      |> assign(:page, 1)
      |> load_bookings()

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="w-full mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Bookings Management</h1>
          </div>

          <!-- Search and Filter Section -->
          <div class="mb-6 space-y-4 lg:space-y-0 lg:flex lg:items-center lg:space-x-4">
            <!-- Search Bar -->
            <div class="flex-1">
              <form phx-submit="search" class="relative">
                <input
                  type="text"
                  name="search_term"
                  value={@search_term}
                  placeholder="Search by customer name, package name, or booking ID..."
                  class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-teal-500 focus:border-transparent"
                  phx-debounce="300"
                  phx-change="search"
                />
                <div class="absolute inset-y-0 left-0 pl-3 flex items-center">
                  <svg class="h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd" />
                  </svg>
                </div>
              </form>
            </div>


            <!-- Clear Search Button -->
            <div>
              <button
                type="button"
                phx-click="clear_search"
                class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
              >
                Clear Search
              </button>
            </div>

            <!-- Filters -->
            <div class="w-full lg:w-auto">
              <form phx-change="filter_change" class="flex flex-col sm:flex-row gap-2 items-stretch sm:items-center">
                <div>
                  <label for="status" class="sr-only">Status</label>
                  <select name="status" id="status" class="w-full sm:w-auto px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-teal-500">
                    <%= for status <- @status_options do %>
                      <option value={status} selected={to_string(@status_filter) == to_string(status)}><%= String.capitalize(to_string(status)) %></option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label for="package_id" class="sr-only">Package</label>
                  <select name="package_id" id="package_id" class="w-full sm:w-auto px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-teal-500">
                    <option value="all" selected={@package_filter == "all"}>All packages</option>
                    <%= for p <- @package_options do %>
                      <option value={p.id} selected={to_string(@package_filter) == to_string(p.id)}><%= p.name %></option>
                    <% end %>
                  </select>
                </div>
                <button type="button" phx-click="clear_filters" class="px-3 py-2 border rounded-lg hover:bg-gray-50">Clear Filters</button>
              </form>
            </div>
          </div>

          <!-- Results Summary -->
          <div class="mb-4 flex items-center justify-between">
            <p class="text-sm text-gray-600">
              Showing
              <%= if @total_count == 0 do %>
                0
              <% else %>
                <%= ((@page - 1) * @page_size) + 1 %>
              <% end %>
              –
              <%= min(@page * @page_size, @total_count) %>
              of <span class="font-medium"><%= @total_count %></span> booking(s)
              <%= if @search_term != "" do %>
                <span class="font-medium">
                  matching "<%= @search_term %>"
                </span>
              <% end %>
            </p>
            <div class="flex items-center space-x-2">
              <button
                type="button"
                phx-click="first_page"
                class={[
                  "px-3 py-1 rounded border text-sm",
                  (if(@page <= 1, do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-50"))
                ]}
                disabled={@page <= 1}
              >First</button>
              <button
                type="button"
                phx-click="prev_page"
                class={[
                  "px-3 py-1 rounded border text-sm",
                  (if(@page <= 1, do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-50"))
                ]}
                disabled={@page <= 1}
              >Previous</button>
              <span class="text-sm text-gray-600">Page <%= @page %> of <%= max(@total_pages, 1) %></span>
              <button
                type="button"
                phx-click="next_page"
                class={[
                  "px-3 py-1 rounded border text-sm",
                  (if(@page >= @total_pages, do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-50"))
                ]}
                disabled={@page >= @total_pages}
              >Next</button>
              <button
                type="button"
                phx-click="last_page"
                class={[
                  "px-3 py-1 rounded border text-sm",
                  (if(@page >= @total_pages, do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-50"))
                ]}
                disabled={@page >= @total_pages}
              >Last</button>
            </div>
          </div>

          <div class="max-h-[70vh] overflow-y-auto">
            <table class="w-full table-fixed divide-y divide-gray-200">
              <thead class="bg-gray-50 sticky top-0 z-10 shadow-sm">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Booking ID</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Customer</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Package</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Persons</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Payment Plan</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Method</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Deposit</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Proof Status</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Booking Date</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Travel Date</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= if length(@bookings) == 0 do %>
                  <tr>
                    <td colspan="13" class="px-6 py-12 text-center text-gray-500">
                      <div class="flex flex-col items-center">
                        <svg class="h-12 w-12 text-gray-400 mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                        </svg>
                        <p class="text-lg font-medium">No bookings found</p>
                        <p class="text-sm">Try adjusting your search or filter criteria</p>
                      </div>
                    </td>
                  </tr>
                <% else %>
                  <%= for booking <- @bookings do %>
                    <tr class="hover:bg-teal-50 transition-colors">
                      <td class="px-6 py-4 text-sm font-medium text-gray-900">#<%= booking.id %></td>
                      <td class="px-6 py-4 text-sm text-gray-900"><%= booking.user_name %></td>
                      <td class="px-6 py-4 text-sm text-gray-900"><%= booking.package %></td>
                      <td class="px-6 py-4">
                        <span class={[
                          "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                          case booking.status do
                            "Confirmed" -> "bg-green-100 text-green-800"
                            "Pending" -> "bg-yellow-100 text-yellow-800"
                            "Cancelled" -> "bg-red-100 text-red-800"
                            "Completed" -> "bg-teal-100 text-teal-800"
                            _ -> "bg-gray-100 text-gray-800"
                          end
                        ]}>
                          <%= booking.status %>
                        </span>
                      </td>
                      <td class="px-6 py-4 text-sm text-gray-900"><%= booking.amount %></td>
                      <td class="px-6 py-4 text-sm text-gray-900"><%= booking.number_of_persons %></td>
                      <td class="px-6 py-4 text-sm text-gray-900"><%= booking.payment_plan %></td>
                      <td class="px-6 py-4 text-sm text-gray-900"><%= booking.payment_method %></td>
                      <td class="px-6 py-4 text-sm text-gray-900"><%= booking.deposit_amount %></td>
                      <td class="px-6 py-4 text-sm text-gray-900"><%= booking.payment_proof_status %></td>
                      <td class="px-6 py-4 text-sm text-gray-900"><%= booking.booking_date %></td>
                      <td class="px-6 py-4 text-sm text-gray-900"><%= booking.travel_date %></td>
                      <td class="px-6 py-4 text-sm font-medium">
                        <a href="#" phx-click="view_booking" phx-value-id={booking.id} class="text-teal-600 hover:text-teal-900">View</a>
                        <span class="mx-2 text-gray-300">|</span>
                        <a href="#"
                                                      onclick={"return confirm('Are you sure you want to delete booking ###{booking.id}? This cannot be undone.')"}
                           phx-click="delete_booking" phx-value-id={booking.id}
                            class="text-red-600 hover:text-red-900">Delete</a>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>

          <!-- Bottom Pagination -->
          <div class="mt-4 flex items-center justify-between">
            <p class="text-sm text-gray-600">
              Page <span class="font-medium"><%= @page %></span> of <span class="font-medium"><%= max(@total_pages, 1) %></span>
            </p>
            <div class="flex items-center space-x-2">
              <button
                type="button"
                phx-click="first_page"
                class={[
                  "px-3 py-1 rounded border text-sm",
                  (if(@page <= 1, do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-50"))
                ]}
                disabled={@page <= 1}
              >First</button>
              <button
                type="button"
                phx-click="prev_page"
                class={[
                  "px-3 py-1 rounded border text-sm",
                  (if(@page <= 1, do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-50"))
                ]}
                disabled={@page <= 1}
              >Previous</button>
              <button
                type="button"
                phx-click="next_page"
                class={[
                  "px-3 py-1 rounded border text-sm",
                  (if(@page >= @total_pages, do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-50"))
                ]}
                disabled={@page >= @total_pages}
              >Next</button>
              <button
                type="button"
                phx-click="last_page"
                class={[
                  "px-3 py-1 rounded border text-sm",
                  (if(@page >= @total_pages, do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-50"))
                ]}
                disabled={@page >= @total_pages}
              >Last</button>
            </div>
          </div>
        </div>
      </div>
      <%= if @show_view_modal && @selected_booking do %>
        <.modal id="booking-view-modal" show={@show_view_modal} on_cancel={JS.push("close_view_modal")}>
          <div class="space-y-6">
            <div>
              <h2 class="text-xl font-semibold text-gray-900">Booking Details</h2>
              <p class="text-sm text-gray-500">Overview of booking #<%= @selected_booking.id %></p>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <div class="text-xs uppercase text-gray-500">Customer</div>
                <div class="text-gray-900"><%= @selected_booking.user_name %></div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Package</div>
                <div class="text-gray-900"><%= @selected_booking.package %></div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Status</div>
                <div class="text-gray-900"><%= @selected_booking.status %></div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Amount</div>
                <div class="text-gray-900"><%= @selected_booking.amount %></div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Persons</div>
                <div class="text-gray-900"><%= @selected_booking.number_of_persons %></div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Payment Plan</div>
                <div class="text-gray-900"><%= @selected_booking.payment_plan %></div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Method</div>
                <div class="text-gray-900"><%= @selected_booking.payment_method %></div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Deposit</div>
                <div class="text-gray-900"><%= @selected_booking.deposit_amount %></div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Proof Status</div>
                <div class="text-gray-900"><%= @selected_booking.payment_proof_status %></div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Booking Date</div>
                <div class="text-gray-900"><%= @selected_booking.booking_date %></div>
              </div>
              <div>
                <div class="text-xs uppercase text-gray-500">Travel Date</div>
                <div class="text-gray-900"><%= @selected_booking.travel_date %></div>
              </div>
            </div>

            <div class="flex justify-end gap-3">
              <button phx-click="close_view_modal" class="px-4 py-2 rounded-lg border hover:bg-gray-50">Close</button>
            </div>
          </div>
        </.modal>
      <% end %>
    </.admin_layout>
    """
  end

  defp load_bookings(socket) do
    status_param =
      case socket.assigns.status_filter do
        :all -> :all
        "all" -> :all
        "" -> :all
        other when is_binary(other) -> other
        _ -> :all
      end

    search_opts = [
      search: socket.assigns.search_term,
      page: socket.assigns.page,
      page_size: socket.assigns.page_size,
      status: status_param,
      package_id: socket.assigns.package_filter
    ]

    total_count = Bookings.count_bookings_with_details(search_opts)
    total_pages = if socket.assigns.page_size > 0, do: div(total_count + socket.assigns.page_size - 1, socket.assigns.page_size), else: 1
    current_page =
      socket.assigns.page
      |> max(1)
      |> min(max(total_pages, 1))

    search_opts = Keyword.merge(search_opts, page: current_page)

    raw_bookings = Bookings.list_bookings_with_details(search_opts)

    bookings =
      raw_bookings
      |> Enum.map(fn b ->
        %{
          id: b.id,
          user_name: b.user_name,
          package: b.package_name,
          status: b.status |> to_string() |> String.capitalize(),
          amount: format_amount(b.total_amount),
          number_of_persons: b.number_of_persons,
          payment_method: b.payment_method |> format_nil("—"),
          payment_plan: b.payment_plan |> format_nil("—") |> format_plan_label(),
          deposit_amount: format_amount(b.deposit_amount),
          payment_proof_status: (b.payment_proof_status || "pending") |> String.capitalize(),
          booking_date: format_date(b.booking_date),
          travel_date: format_date(b.travel_date)
        }
      end)

    socket
    |> assign(:bookings, bookings)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, max(total_pages, 1))
    |> assign(:page, current_page)
  end

  defp format_amount(nil), do: "RM 0.00"
  defp format_amount(%Decimal{} = amount), do: "RM " <> Decimal.to_string(amount)
  defp format_amount(amount) when is_number(amount), do: "RM " <> :erlang.float_to_binary(amount, decimals: 2)
  defp format_amount(amount) when is_binary(amount), do: amount

  defp format_date(nil), do: "—"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  defp format_date(date) when is_binary(date), do: date

  defp format_nil(nil, fallback), do: fallback
  defp format_nil(value, _fallback), do: value

  defp format_plan_label("full_payment"), do: "Full"
  defp format_plan_label("installment"), do: "Installment"
  defp format_plan_label(value), do: value
end
