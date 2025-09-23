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
      |> assign(:show_payment_modal, false)
      |> assign(:selected_payment, nil)

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

  def handle_event("view_payment", %{"id" => id, "source" => source}, socket) do
    details =
      case source do
        "booking" ->
          alias Umrahly.Bookings.Booking
          Booking
          |> Repo.get!(id)
          |> Repo.preload([:user, package_schedule: :package])
          |> booking_to_details()
        "progress" ->
          BookingFlowProgress
          |> Repo.get!(id)
          |> Repo.preload([:user, :package, :package_schedule])
          |> progress_to_details()
        _ ->
          nil
      end

    {:noreply, socket |> assign(:selected_payment, details) |> assign(:show_payment_modal, true)}
  rescue
    _e ->
      {:noreply, socket |> put_flash(:error, "Failed to load payment details")}
  end

  def handle_event("close_payment_modal", _params, socket) do
    {:noreply, socket |> assign(:show_payment_modal, false) |> assign(:selected_payment, nil)}
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

  # --- Data loading (bookings + in-progress flows) ---
  defp get_payments_data(status_filter \\ "all") do
    try do
      bookings = get_payments_from_bookings(status_filter)
      progresses = get_payments_from_progress(status_filter)

      (bookings ++ progresses)
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
      |> Enum.flat_map(&expand_traveler_data/1)
      |> Enum.map(&format_payment_data/1)
    rescue e ->
      require Logger
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      []
    end
  end

  defp get_payments_from_bookings(status_filter) do
    # Pull real, confirmed booking/payment data
    alias Umrahly.Bookings.Booking
    alias Umrahly.Packages.PackageSchedule

    base_query =
      Booking
      |> join(:inner, [b], u in User, on: b.user_id == u.id)
      |> join(:inner, [b, u], ps in PackageSchedule, on: b.package_schedule_id == ps.id)
      |> join(:inner, [b, u, ps], p in Package, on: ps.package_id == p.id)

    filtered_query =
      case status_filter do
        "all" -> base_query |> where([b, u, ps, p], b.status != "cancelled")
        # Map UI statuses to booking statuses where sensible
        "completed" -> base_query |> where([b, u, ps, p], b.status == "completed" or b.status == "confirmed")
        "in_progress" -> base_query |> where([b, u, ps, p], b.status == "pending")
        "canceled" -> base_query |> where([b, u, ps, p], b.status == "cancelled")
        _ -> base_query
      end

    filtered_query
    |> select([b, u, ps, p], %{
      id: b.id,
      source: "booking",
      user_name: u.full_name,
      user_email: u.email,
      package_name: p.name,
      total_amount: b.total_amount,
      payment_method: b.payment_method,
      payment_plan: b.payment_plan,
      status: b.status,
      number_of_persons: b.number_of_persons,
      current_step: 4,
      max_steps: 4,
      inserted_at: b.inserted_at,
      updated_at: b.updated_at,
      travelers_data: nil
    })
    |> Repo.all()
  end

  defp get_payments_from_progress(status_filter) do
    base_query =
      BookingFlowProgress
      |> join(:inner, [bfp], u in User, on: bfp.user_id == u.id)
      |> join(:inner, [bfp, u], p in Package, on: bfp.package_id == p.id)

    filtered_query =
      case status_filter do
        "all" -> base_query
        "completed" -> base_query |> where([bfp, u, p], bfp.status == "completed")
        "in_progress" -> base_query |> where([bfp, u, p], bfp.status == "in_progress")
        "canceled" -> base_query |> where([bfp, u, p], bfp.status == "abandoned")
        _ -> base_query
      end

    filtered_query
    |> select([bfp, u, p], %{
      id: bfp.id,
      source: "progress",
      user_name: u.full_name,
      user_email: u.email,
      package_name: p.name,
      total_amount: bfp.total_amount,
      payment_method: bfp.payment_method,
      payment_plan: bfp.payment_plan,
      status: bfp.status,
      number_of_persons: bfp.number_of_persons,
      current_step: bfp.current_step,
      max_steps: bfp.max_steps,
      inserted_at: bfp.inserted_at,
      updated_at: bfp.updated_at,
      travelers_data: bfp.travelers_data
    })
    |> order_by([bfp, u, p], [desc: bfp.inserted_at])
    |> Repo.all()
  end

  defp search_payments(search_term, status_filter) when byte_size(search_term) > 0 do
    try do
      search_pattern = "%#{search_term}%"

      # Search confirmed/real bookings
      alias Umrahly.Bookings.Booking
      alias Umrahly.Packages.PackageSchedule

      bookings_query =
        Booking
        |> join(:inner, [b], u in User, on: b.user_id == u.id)
        |> join(:inner, [b, u], ps in PackageSchedule, on: b.package_schedule_id == ps.id)
        |> join(:inner, [b, u, ps], p in Package, on: ps.package_id == p.id)
        |> where([b, u, ps, p],
          ilike(u.full_name, ^search_pattern) or
          ilike(u.email, ^search_pattern) or
          ilike(p.name, ^search_pattern)
        )

      bookings_query =
        case status_filter do
          "all" -> bookings_query |> where([b, u, ps, p], b.status != "cancelled")
          "completed" -> bookings_query |> where([b, u, ps, p], b.status in ["completed", "confirmed"])
          "in_progress" -> bookings_query |> where([b, u, ps, p], b.status == "pending")
          "abandoned" -> bookings_query |> where([b, u, ps, p], b.status == "cancelled")
          "canceled" -> bookings_query |> where([b, u, ps, p], b.status == "cancelled")
          _ -> bookings_query
        end

      bookings_results =
        bookings_query
        |> select([b, u, ps, p], %{
          id: b.id,
          source: "booking",
          user_name: u.full_name,
          user_email: u.email,
          package_name: p.name,
          total_amount: b.total_amount,
          payment_method: b.payment_method,
          payment_plan: b.payment_plan,
          status: b.status,
          number_of_persons: b.number_of_persons,
          current_step: 4,
          max_steps: 4,
          inserted_at: b.inserted_at,
          updated_at: b.updated_at,
          travelers_data: nil
        })
        |> Repo.all()

      progress_results =
        get_payments_from_progress_for_search(search_pattern, status_filter)

      (bookings_results ++ progress_results)
      |> Enum.flat_map(&expand_traveler_data/1)
      |> Enum.filter(fn payment ->
        search_lc = String.downcase(search_term)

        String.contains?(String.downcase(payment.user_name || ""), search_lc) or
        String.contains?(String.downcase(payment.user_email || ""), search_lc) or
        String.contains?(String.downcase(payment.package_name || ""), search_lc) or
        String.contains?(String.downcase(payment.traveler_name || ""), search_lc) or
        String.contains?(String.downcase(payment.traveler_identity || ""), search_lc)
      end)
      |> Enum.map(&format_payment_data/1)
    rescue e ->
      require Logger
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      []
    end
  end

  defp search_payments(_search_term, status_filter), do: get_payments_data(status_filter)

  defp get_payments_from_progress_for_search(search_pattern, status_filter) do
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
        "canceled" -> base_query |> where([bfp, u, p], bfp.status == "abandoned")
        _ -> base_query
      end

    filtered_query
    |> select([bfp, u, p], %{
      id: bfp.id,
      source: "progress",
      user_name: u.full_name,
      user_email: u.email,
      package_name: p.name,
      total_amount: bfp.total_amount,
      payment_method: bfp.payment_method,
      payment_plan: bfp.payment_plan,
      status: bfp.status,
      number_of_persons: bfp.number_of_persons,
      current_step: bfp.current_step,
      max_steps: bfp.max_steps,
      inserted_at: bfp.inserted_at,
      updated_at: bfp.updated_at,
      travelers_data: bfp.travelers_data
    })
    |> Repo.all()
  end

  # Expand traveler data to show individual travelers
  defp expand_traveler_data(booking) do
    case booking.travelers_data do
      nil ->
        # If no travelers data, create a single entry with user info
        [%{booking |
          traveler_name: booking.user_name || "Unknown",
          traveler_identity: "No ID",
          traveler_phone: "No phone",
          traveler_address: "No address",
          traveler_city: "No city",
          traveler_state: "No state",
          traveler_citizenship: "No citizenship"
        }]
      travelers when is_list(travelers) ->
        Enum.map(travelers, fn traveler ->
          %{booking |
            traveler_name: traveler["full_name"] || "Unknown Traveler",
            traveler_identity: traveler["identity_card_number"] || traveler["passport_number"] || "No ID",
            traveler_phone: traveler["phone"] || "No phone",
            traveler_address: traveler["address"] || "No address",
            traveler_city: traveler["city"] || "No city",
            traveler_state: traveler["state"] || "No state",
            traveler_citizenship: traveler["citizenship"] || traveler["nationality"] || "No citizenship"
          }
        end)
      _ ->
        # Fallback for unexpected data types
        [%{booking |
          traveler_name: booking.user_name || "Unknown",
          traveler_identity: "No ID",
          traveler_phone: "No phone",
          traveler_address: "No address",
          traveler_city: "No city",
          traveler_state: "No state",
          traveler_citizenship: "No citizenship"
        }]
    end
  end

  defp format_payment_data(payment) do
    %{
      id: payment.id,
      source: payment[:source],
      user_name: payment.user_name || "Unknown",
      user_email: payment.user_email || "No email",
      package_name: payment.package_name || "Unknown Package",
      amount: format_amount(payment.total_amount),
      raw_amount: payment.total_amount,
      payment_method: payment.payment_method || "Not specified",
      payment_plan: payment.payment_plan || "Not specified",
      status: normalize_status(payment.status),
      transaction_id: "TXN-#{String.pad_leading("#{payment.id}", 6, "0")}",
      payment_date: format_date(payment.inserted_at),
      booking_reference: "BK-#{String.pad_leading("#{payment.id}", 6, "0")}",
      number_of_persons: payment.number_of_persons || 1,
      current_step: payment.current_step || 1,
      max_steps: payment.max_steps || 4,
      inserted_at: payment.inserted_at,
      updated_at: payment.updated_at,
      # Traveler information
      traveler_name: payment.traveler_name || payment.user_name || "Unknown",
      traveler_identity: payment.traveler_identity || "No ID",
      traveler_phone: payment.traveler_phone || "No phone",
      traveler_address: payment.traveler_address || "No address",
      traveler_city: payment.traveler_city || "No city",
      traveler_state: payment.traveler_state || "No state",
      traveler_citizenship: payment.traveler_citizenship || "No citizenship"
    }
  end

  defp normalize_status(nil), do: "unknown"
  defp normalize_status("confirmed"), do: "completed"
  defp normalize_status("pending"), do: "in_progress"
  defp normalize_status("cancelled"), do: "canceled"
  defp normalize_status("abandoned"), do: "canceled"
  defp normalize_status(status), do: status

  defp format_amount(nil), do: "RM 0"
  defp format_amount(%Decimal{} = amount) do
    "RM #{Decimal.round(amount, 0)}"
  end
  defp format_amount(amount) when is_number(amount) do
    "RM #{amount}"
  end
  defp format_amount(amount), do: "RM #{amount}"

  defp format_date(nil), do: "Unknown"
  defp format_date(datetime) do
    UmrahlyWeb.Timezone.format_local(datetime, "%Y-%m-%d")
  end

  defp booking_to_details(booking) do
    %{
      id: booking.id,
      source: "booking",
      user: booking.user,
      package: booking.package_schedule && booking.package_schedule.package,
      package_schedule: booking.package_schedule,
      status: booking.status,
      total_amount: booking.total_amount,
      deposit_amount: booking.deposit_amount,
      payment_plan: booking.payment_plan,
      payment_method: booking.payment_method,
      number_of_persons: booking.number_of_persons,
      booking_date: booking.booking_date,
      payment_proof_file: booking.payment_proof_file,
      payment_proof_status: booking.payment_proof_status,
      payment_proof_notes: booking.payment_proof_notes,
      inserted_at: booking.inserted_at
    }
  end

  defp progress_to_details(bfp) do
    %{
      id: bfp.id,
      source: "progress",
      user: bfp.user,
      package: bfp.package,
      package_schedule: bfp.package_schedule,
      status: bfp.status,
      total_amount: bfp.total_amount,
      deposit_amount: bfp.deposit_amount,
      payment_plan: bfp.payment_plan,
      payment_method: bfp.payment_method,
      number_of_persons: bfp.number_of_persons,
      travelers_data: bfp.travelers_data,
      current_step: bfp.current_step,
      max_steps: bfp.max_steps,
      inserted_at: bfp.inserted_at
    }
  end

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
                  placeholder="Search by traveler name, user name, email, or package..."
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
                phx-value-status="canceled"
                class={[
                  "px-4 py-2 rounded-lg transition-colors",
                  if(@filter_status == "canceled", do: "bg-red-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300")
                ]}>
                Canceled
              </button>
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Payment ID</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Traveler</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Booked By</th>
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
                    <td colspan="11" class="px-6 py-8 text-center text-gray-500">
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
                        <div class="text-sm text-gray-900 font-medium"><%= payment.traveler_name %></div>
                        <div class="text-sm text-gray-500">
                          <%= if payment.traveler_identity != "No ID" do %>
                            ID: <%= payment.traveler_identity %>
                          <% end %>
                        </div>
                        <div class="text-xs text-gray-400">
                          <%= if payment.traveler_phone != "No phone" do %>
                            📞 <%= payment.traveler_phone %>
                          <% end %>
                        </div>
                      </td>
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
                            # removed abandoned
                            "canceled" -> "bg-red-100 text-red-800"
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
                          phx-value-source={payment.source}
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
          <div class="mt-6 grid grid-cols-1 md:grid-cols-5 gap-4">
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
              <div class="text-sm font-medium text-red-600">Canceled</div>
              <div class="text-2xl font-bold text-red-900">
                <%= @payments |> Enum.filter(& &1.status == "canceled") |> length() %>
              </div>
            </div>
          </div>
        </div>

        <%= if @show_payment_modal and @selected_payment do %>
          <div class="fixed inset-0 z-50 flex items-center justify-center">
            <div class="absolute inset-0 bg-black opacity-30" phx-click="close_payment_modal"></div>
            <div class="relative bg-white rounded-lg shadow-lg w-full max-w-2xl mx-4 p-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-xl font-semibold">Payment Details</h2>
                <button class="text-gray-500 hover:text-gray-700" phx-click="close_payment_modal">✕</button>
              </div>

              <div class="space-y-3 text-sm">
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <div class="text-gray-500">Type</div>
                    <div class="font-medium capitalize"><%= @selected_payment.source %></div>
                  </div>
                  <div>
                    <div class="text-gray-500">Status</div>
                    <div class="font-medium capitalize"><%= @selected_payment.status %></div>
                  </div>
                  <div>
                    <div class="text-gray-500">User</div>
                    <div class="font-medium"><%= @selected_payment.user && @selected_payment.user.full_name %> (<%= @selected_payment.user && @selected_payment.user.email %>)</div>
                  </div>
                  <div>
                    <div class="text-gray-500">Package</div>
                    <div class="font-medium"><%= @selected_payment.package && @selected_payment.package.name %></div>
                  </div>
                  <div>
                    <div class="text-gray-500">Payment Method</div>
                    <div class="font-medium capitalize"><%= @selected_payment.payment_method %></div>
                  </div>
                  <div>
                    <div class="text-gray-500">Payment Plan</div>
                    <div class="font-medium capitalize"><%= @selected_payment.payment_plan %></div>
                  </div>
                  <div>
                    <div class="text-gray-500">Total Amount</div>
                    <div class="font-medium"><%= format_amount(@selected_payment.total_amount) %></div>
                  </div>
                  <div>
                    <div class="text-gray-500">Deposit</div>
                    <div class="font-medium"><%= format_amount(@selected_payment[:deposit_amount]) %></div>
                  </div>
                </div>

                <%= if @selected_payment.source == "progress" and is_list(@selected_payment[:travelers_data]) do %>
                  <div class="mt-4">
                    <div class="text-gray-700 font-semibold mb-2">Travelers</div>
                    <div class="space-y-2">
                      <%= for t <- @selected_payment[:travelers_data] do %>
                        <div class="border rounded p-2">
                          <div class="font-medium"><%= t["full_name"] || t[:full_name] %></div>
                          <div class="text-gray-600 text-xs">ID: <%= t["identity_card_number"] || t[:identity_card_number] || t["passport_number"] || t[:passport_number] || "N/A" %></div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <%= if @selected_payment.source == "booking" do %>
                  <div class="mt-4">
                    <div class="text-gray-700 font-semibold mb-2">Payment Proof</div>
                    <div class="text-sm">
                      <div>Status: <span class="capitalize font-medium"><%= @selected_payment.payment_proof_status %></span></div>
                      <%= if @selected_payment.payment_proof_file do %>
                        <div class="mt-1">
                          <a class="text-blue-600 hover:underline" href={"/uploads/payment_proof/#{@selected_payment.payment_proof_file}"} target="_blank">View Proof</a>
                        </div>
                      <% else %>
                        <div class="text-gray-500">No file uploaded</div>
                      <% end %>
                      <%= if @selected_payment.payment_proof_notes do %>
                        <div class="mt-1 text-gray-700">Notes: <%= @selected_payment.payment_proof_notes %></div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>

              <div class="mt-6 flex justify-end gap-2">
                <button class="px-4 py-2 rounded bg-gray-200 text-gray-700" phx-click="close_payment_modal">Close</button>
                <button class="px-4 py-2 rounded bg-blue-600 text-white">Process</button>
                <button class="px-4 py-2 rounded bg-red-600 text-white">Refund</button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </.admin_layout>
    """
  end
end
