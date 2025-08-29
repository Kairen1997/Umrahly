defmodule UmrahlyWeb.AdminPaymentsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  import Ecto.Query, warn: false
  alias Umrahly.Repo
  alias Umrahly.Bookings.BookingFlowProgress
  alias Umrahly.Accounts.User
  alias Umrahly.Packages.Package

  def mount(_params, _session, socket) do
    payments = get_payments_data()

    socket =
      socket
      |> assign(:payments, payments)
      |> assign(:current_page, "payments")
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns.current_user)
      |> assign(:filter_status, "all")
      |> assign(:search_term, "")

    {:ok, socket}
  end

  def handle_event("refresh_payments", _params, socket) do
    payments = get_payments_data(socket.assigns.filter_status)
    {:noreply, assign(socket, :payments, payments)}
  end

  def handle_event("filter_by_status", %{"status" => status}, socket) do
    payments = get_payments_data(status)
    {:noreply, socket |> assign(:payments, payments) |> assign(:filter_status, status)}
  end

  def handle_event("search_payments", %{"search" => search_term}, socket) do
    payments = search_payments(search_term, socket.assigns.filter_status)
    {:noreply, socket |> assign(:payments, payments) |> assign(:search_term, search_term)}
  end

  def handle_event("view_payment", %{"id" => _id}, socket) do
    # TODO: Implement payment detail view
    {:noreply, socket}
  end

  def handle_event("process_payment", %{"id" => _id}, socket) do
    # TODO: Implement payment processing
    {:noreply, socket}
  end

  def handle_event("refund_payment", %{"id" => _id}, socket) do
    # TODO: Implement payment refund
    {:noreply, socket}
  end

  defp calculate_progress_percentage(current_step, max_steps) do
    case {current_step, max_steps} do
      {current, max} when is_integer(current) and is_integer(max) and max > 0 ->
        min(100, max(0, round(current / max * 100)))
      _ ->
        0
    end
  end

  defp get_payments_data(status_filter \\ "all") do
    try do
      base_query =
        BookingFlowProgress
        |> join(:inner, [bfp], u in User, on: bfp.user_id == u.id)
        |> join(:inner, [bfp, u], p in Package, on: bfp.package_id == p.id)

      filtered_query =
        case status_filter do
          "all" -> base_query
          "completed" -> base_query |> where([bfp, u, p], bfp.status == "completed")
          "in_progress" -> base_query |> where([bfp, u, p], bfp.status == "in_progress")
          "abandoned" -> base_query |> where([bfp, u, p], bfp.status == "abandoned")
          _ -> base_query
        end

      filtered_query
      |> select([bfp, u, p], %{
        id: bfp.id,
        user_name: fragment("COALESCE(?, 'Unknown')", u.full_name),
        user_email: fragment("COALESCE(?, 'No email')", u.email),
        package_name: fragment("COALESCE(?, 'Unknown Package')", p.name),
        amount: fragment("CASE WHEN ? IS NOT NULL THEN CONCAT('RM ', FORMAT(?, 0)) ELSE 'RM 0' END", bfp.total_amount, bfp.total_amount),
        raw_amount: bfp.total_amount,
        payment_method: fragment("COALESCE(?, 'Not specified')", bfp.payment_method),
        payment_plan: fragment("COALESCE(?, 'Not specified')", bfp.payment_plan),
        status: fragment("COALESCE(?, 'unknown')", bfp.status),
        transaction_id: fragment("CONCAT('TXN-', LPAD(?, 6, '0'))", bfp.id),
        payment_date: fragment("DATE_FORMAT(?, '%Y-%m-%d')", bfp.inserted_at),
        booking_reference: fragment("CONCAT('BK-', LPAD(?, 6, '0'))", bfp.id),
        number_of_persons: fragment("COALESCE(?, 1)", bfp.number_of_persons),
        current_step: fragment("COALESCE(?, 1)", bfp.current_step),
        max_steps: fragment("COALESCE(?, 4)", bfp.max_steps),
        inserted_at: bfp.inserted_at,
        updated_at: bfp.updated_at
      })
      |> order_by([bfp, u, p], [desc: bfp.inserted_at])
      |> Repo.all()
    rescue
      e ->
        IO.inspect(e, label: "Error fetching payments data")
        []
    end
  end

  defp search_payments(search_term, status_filter) when byte_size(search_term) > 0 do
    try do
      search_pattern = "%#{search_term}%"

      base_query =
        BookingFlowProgress
        |> join(:inner, [bfp], u in User, on: bfp.user_id == u.id)
        |> join(:inner, [bfp, u], p in Package, on: bfp.package_id == p.id)
        |> where([bfp, u, p],
          ilike(u.full_name, ^search_pattern) or
          ilike(u.email, ^search_pattern) or
          ilike(p.name, ^search_pattern)
        )

      filtered_query =
        case status_filter do
          "all" -> base_query
          "completed" -> base_query |> where([bfp, u, p], bfp.status == "completed")
          "in_progress" -> base_query |> where([bfp, u, p], bfp.status == "in_progress")
          "abandoned" -> base_query |> where([bfp, u, p], bfp.status == "abandoned")
          _ -> base_query
        end

      filtered_query
      |> select([bfp, u, p], %{
        id: bfp.id,
        user_name: fragment("COALESCE(?, 'Unknown')", u.full_name),
        user_email: fragment("COALESCE(?, 'No email')", u.email),
        package_name: fragment("COALESCE(?, 'Unknown Package')", p.name),
        amount: fragment("CASE WHEN ? IS NOT NULL THEN CONCAT('RM ', FORMAT(?, 0)) ELSE 'RM 0' END", bfp.total_amount, bfp.total_amount),
        raw_amount: bfp.total_amount,
        payment_method: fragment("COALESCE(?, 'Not specified')", bfp.payment_method),
        payment_plan: fragment("COALESCE(?, 'Not specified')", bfp.payment_plan),
        status: fragment("COALESCE(?, 'unknown')", bfp.status),
        transaction_id: fragment("CONCAT('TXN-', LPAD(?, 6, '0'))", bfp.id),
        payment_date: fragment("DATE_FORMAT(?, '%Y-%m-%d')", bfp.inserted_at),
        booking_reference: fragment("CONCAT('BK-', LPAD(?, 6, '0'))", bfp.id),
        number_of_persons: fragment("COALESCE(?, 1)", bfp.number_of_persons),
        current_step: fragment("COALESCE(?, 1)", bfp.current_step),
        max_steps: fragment("COALESCE(?, 4)", bfp.max_steps),
        inserted_at: bfp.inserted_at,
        updated_at: bfp.updated_at
      })
      |> order_by([bfp, u, p], [desc: bfp.inserted_at])
      |> Repo.all()
    rescue
      e ->
        IO.inspect(e, label: "Error searching payments")
        []
    end
  end

  defp search_payments(_search_term, status_filter), do: get_payments_data(status_filter)

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-6xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Payments Management</h1>
            <div class="flex space-x-2">
              <button
                phx-click="refresh_payments"
                class="bg-gray-600 text-white px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors">
                <svg class="w-4 h-4 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
                </svg>
                Refresh
              </button>
              <button class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors">
                Export Report
              </button>
              <button class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors">
                Process Payment
              </button>
            </div>
          </div>

          <!-- Search and Filter Controls -->
          <div class="mb-6 flex flex-col sm:flex-row gap-4">
            <div class="flex-1">
              <form phx-submit="search_payments" class="flex">
                <input
                  type="text"
                  name="search"
                  value={@search_term}
                  placeholder="Search by customer name, email, or package..."
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-l-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
                <button type="submit" class="px-4 py-2 bg-gray-600 text-white rounded-r-lg hover:bg-gray-700 transition-colors">
                  Search
                </button>
              </form>
            </div>
            <div class="flex gap-2">
              <button
                phx-click="filter_by_status"
                phx-value-status="all"
                class={[
                  "px-4 py-2 rounded-lg transition-colors",
                  if(@filter_status == "all", do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300")
                ]}>
                All
              </button>
              <button
                phx-click="filter_by_status"
                phx-value-status="completed"
                class={[
                  "px-4 py-2 rounded-lg transition-colors",
                  if(@filter_status == "completed", do: "bg-green-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300")
                ]}>
                Completed
              </button>
              <button
                phx-click="filter_by_status"
                phx-value-status="in_progress"
                class={[
                  "px-4 py-2 rounded-lg transition-colors",
                  if(@filter_status == "in_progress", do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300")
                ]}>
                In Progress
              </button>
              <button
                phx-click="filter_by_status"
                phx-value-status="abandoned"
                class={[
                  "px-4 py-2 rounded-lg transition-colors",
                  if(@filter_status == "abandoned", do: "bg-red-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300")
                ]}>
                Abandoned
              </button>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Payment ID</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Customer</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Package</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Payment Method</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Progress</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Transaction ID</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Payment Date</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= if Enum.empty?(@payments) do %>
                  <tr>
                    <td colspan="10" class="px-6 py-8 text-center text-gray-500">
                      <div class="flex flex-col items-center">
                        <svg class="w-12 h-12 text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                        </svg>
                        <p class="text-lg font-medium">No payments found</p>
                        <p class="text-sm">Try adjusting your search or filter criteria</p>
                      </div>
                    </td>
                  </tr>
                <% else %>
                  <%= for payment <- @payments do %>
                    <tr class="hover:bg-gray-50">
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#<%= payment.id %></td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="text-sm text-gray-900"><%= payment.user_name %></div>
                        <div class="text-sm text-gray-500"><%= payment.user_email %></div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= payment.package_name %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900"><%= payment.amount %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <span class="capitalize"><%= String.replace(payment.payment_method, "_", " ") %></span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={[
                          "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                          case payment.status do
                            "completed" -> "bg-green-100 text-green-800"
                            "in_progress" -> "bg-blue-100 text-blue-800"
                            "abandoned" -> "bg-red-100 text-red-800"
                            _ -> "bg-gray-100 text-gray-800"
                          end
                        ]}>
                          <%= String.replace(payment.status, "_", " ") |> String.capitalize() %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <div class="flex items-center">
                          <span class="text-xs text-gray-500 mr-2"><%= payment.current_step %>/<%= payment.max_steps %></span>
                          <div class="w-16 bg-gray-200 rounded-full h-2">
                            <div class="bg-blue-600 h-2 rounded-full" style={"width: #{calculate_progress_percentage(payment.current_step, payment.max_steps)}%"}>
                            </div>
                          </div>
                        </div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= payment.transaction_id %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= payment.payment_date %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <button
                          phx-click="view_payment"
                          phx-value-id={payment.id}
                          class="text-teal-600 hover:text-teal-900 mr-3">
                          View
                        </button>
                        <button
                          phx-click="process_payment"
                          phx-value-id={payment.id}
                          class="text-blue-600 hover:text-blue-900 mr-3">
                          Process
                        </button>
                        <button
                          phx-click="refund_payment"
                          phx-value-id={payment.id}
                          class="text-red-600 hover:text-red-900">
                          Refund
                        </button>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>

          <!-- Summary Stats -->
          <div class="mt-6 grid grid-cols-1 md:grid-cols-4 gap-4">
            <div class="bg-blue-50 p-4 rounded-lg">
              <div class="text-sm font-medium text-blue-600">Total Payments</div>
              <div class="text-2xl font-bold text-blue-900"><%= length(@payments) %></div>
            </div>
            <div class="bg-green-50 p-4 rounded-lg">
              <div class="text-sm font-medium text-green-600">Completed</div>
              <div class="text-2xl font-bold text-green-900">
                <%= @payments |> Enum.filter(& &1.status == "completed") |> length() %>
              </div>
            </div>
            <div class="bg-blue-50 p-4 rounded-lg">
              <div class="text-sm font-medium text-blue-600">In Progress</div>
              <div class="text-2xl font-bold text-blue-900">
                <%= @payments |> Enum.filter(& &1.status == "in_progress") |> length() %>
              </div>
            </div>
            <div class="bg-red-50 p-4 rounded-lg">
              <div class="text-sm font-medium text-red-600">Abandoned</div>
              <div class="text-2xl font-bold text-red-900">
                <%= @payments |> Enum.filter(& &1.status == "abandoned") |> length() %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
