defmodule UmrahlyWeb.AdminPaymentsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  import Ecto.Query, warn: false
  alias Umrahly.Repo
  alias Umrahly.Bookings.BookingFlowProgress
  alias Umrahly.Bookings.Booking
  alias Umrahly.Accounts.User
  alias Umrahly.Packages.Package

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Umrahly.PubSub, "admin:payments")
    end

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
      |> assign(:page_size, 10)
      |> assign(:page, 1)

    {:ok, socket |> assign_pagination(payments)}
  end

  def handle_event("refresh_payments", _params, socket) do
    payments = get_payments_data(socket.assigns.filter_status)
    {:noreply, socket |> assign(:page, 1) |> assign_pagination(payments)}
  end

  def handle_event("filter_by_status", %{"status" => status}, socket) do
    payments = get_payments_data(status)
    {:noreply, socket |> assign(:filter_status, status) |> assign(:page, 1) |> assign_pagination(payments)}
  end

  def handle_event("search_payments", %{"search" => search_term}, socket) do
    payments = search_payments(search_term, socket.assigns.filter_status)
    {:noreply, socket |> assign(:search_term, search_term) |> assign(:page, 1) |> assign_pagination(payments)}
  end

  def handle_event("paginate", %{"action" => action}, socket) do
    total_pages = socket.assigns.total_pages
    current = socket.assigns.page
    new_page =
      case action do
        "first" -> 1
        "prev" -> max(1, current - 1)
        "next" -> min(total_pages, current + 1)
        "last" -> total_pages
        _ -> current
      end

    {:noreply, socket |> assign(:page, new_page) |> assign_pagination()}
  end

  def handle_event("view_payment", %{"id" => id, "source" => source}, socket) do
    {:noreply, push_navigate(socket, to: "/admin/payments/#{id}/#{source}")}
  end

  def handle_event("process_payment", %{"id" => id, "source" => source}, socket) do
    result =
      case source do
        "booking" ->
          with %Booking{} = booking <- Repo.get(Booking, id),
               {:ok, _} <- booking |> Ecto.Changeset.change(%{status: "confirmed"}) |> Repo.update() do
            :ok
          else
            _ -> :error
          end
        "progress" ->
          with %BookingFlowProgress{} = bfp <- Repo.get(BookingFlowProgress, id),
               {:ok, _} <- bfp |> Ecto.Changeset.change(%{status: "completed"}) |> Repo.update() do
            :ok
          else
            _ -> :error
          end
        _ -> :error
      end

    payments = get_payments_data(socket.assigns.filter_status)
    socket = socket |> assign(:page, 1) |> assign_pagination(payments)

    case result do
      :ok -> {:noreply, socket |> put_flash(:info, "Payment processed")}
      :error -> {:noreply, socket |> put_flash(:error, "Failed to process payment")}
    end
  end


  def handle_event("go_to_payment_proofs", _params, socket) do
    {:noreply, push_navigate(socket, to: "/admin/payment-proofs")}
  end

  def handle_info({:payments_changed}, socket) do
    payments = get_payments_data(socket.assigns.filter_status)
    {:noreply, socket |> assign(:search_term, "") |> assign(:page, 1) |> assign_pagination(payments)}
  end



  # --- Data loading (bookings + in-progress flows) ---
  defp get_payments_data(status_filter \\ "all") do
    try do
      # Always fetch all, then filter after computing derived status
      bookings = get_payments_from_bookings("all")
      progresses = get_payments_from_progress("all")

      combined =
        (bookings ++ progresses)
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
        |> Enum.flat_map(&expand_traveler_data/1)
        |> Enum.map(&format_payment_data/1)

      case status_filter do
        "all" -> combined
        other -> Enum.filter(combined, fn p -> p.status == other end)
      end
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
      deposit_amount: b.deposit_amount,
      payment_method: b.payment_method,
      payment_plan: b.payment_plan,
      status: b.status,
      number_of_persons: b.number_of_persons,
      is_booking_for_self: b.is_booking_for_self,
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
      deposit_amount: bfp.deposit_amount,
      payment_method: bfp.payment_method,
      payment_plan: bfp.payment_plan,
      status: bfp.status,
      number_of_persons: bfp.number_of_persons,
      is_booking_for_self: bfp.is_booking_for_self,
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

      bookings_results =
        bookings_query
        |> select([b, u, ps, p], %{
          id: b.id,
          source: "booking",
          user_name: u.full_name,
          user_email: u.email,
          package_name: p.name,
          total_amount: b.total_amount,
          deposit_amount: b.deposit_amount,
          payment_method: b.payment_method,
          payment_plan: b.payment_plan,
          status: b.status,
          number_of_persons: b.number_of_persons,
          is_booking_for_self: b.is_booking_for_self,
          current_step: 4,
          max_steps: 4,
          inserted_at: b.inserted_at,
          updated_at: b.updated_at,
          travelers_data: nil
        })
        |> Repo.all()

      progress_results =
        get_payments_from_progress_for_search(search_pattern, "all")

      combined =
        (bookings_results ++ progress_results)
        |> Enum.flat_map(&expand_traveler_data/1)
        |> Enum.map(&format_payment_data/1)

      filtered =
        case status_filter do
          "all" -> combined
          other -> Enum.filter(combined, fn p -> p.status == other end)
        end

      # Final text filter safeguard
      filtered
      |> Enum.filter(fn payment ->
        search_lc = String.downcase(search_term)
        String.contains?(String.downcase(payment.user_name || ""), search_lc) or
        String.contains?(String.downcase(payment.user_email || ""), search_lc) or
        String.contains?(String.downcase(payment.package_name || ""), search_lc) or
        String.contains?(String.downcase(payment.traveler_name || ""), search_lc) or
        String.contains?(String.downcase(payment.traveler_identity || ""), search_lc)
      end)
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
      deposit_amount: bfp.deposit_amount,
      payment_method: bfp.payment_method,
      payment_plan: bfp.payment_plan,
      status: bfp.status,
      number_of_persons: bfp.number_of_persons,
      is_booking_for_self: bfp.is_booking_for_self,
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
        [Map.merge(booking, %{
          traveler_name: booking.user_name || "Unknown",
          traveler_identity: "No ID",
          traveler_phone: "No phone",
          traveler_address: "No address",
          traveler_city: "No city",
          traveler_state: "No state",
          traveler_citizenship: "No citizenship"
        })]
      travelers when is_list(travelers) ->
        case length(travelers) do
          n when n > 1 ->
            # For more than one traveler, display only the user (do not list travelers individually)
            [Map.merge(booking, %{
              traveler_name: booking.user_name || "Unknown",
              traveler_identity: "No ID",
              traveler_phone: "No phone",
              traveler_address: "No address",
              traveler_city: "No city",
              traveler_state: "No state",
              traveler_citizenship: "No citizenship"
            })]
          _ ->
            Enum.map(travelers, fn traveler ->
              Map.merge(booking, %{
                traveler_name: traveler["full_name"] || "Unknown Traveler",
                traveler_identity: traveler["identity_card_number"] || traveler["passport_number"] || "No ID",
                traveler_phone: traveler["phone"] || "No phone",
                traveler_address: traveler["address"] || "No address",
                traveler_city: traveler["city"] || "No city",
                traveler_state: traveler["state"] || "No state",
                traveler_citizenship: traveler["citizenship"] || traveler["nationality"] || "No citizenship"
              })
            end)
        end
      _ ->
        # Fallback for unexpected data types
        [Map.merge(booking, %{
          traveler_name: booking.user_name || "Unknown",
          traveler_identity: "No ID",
          traveler_phone: "No phone",
          traveler_address: "No address",
          traveler_city: "No city",
          traveler_state: "No state",
          traveler_citizenship: "No citizenship"
        })]
    end
  end

  defp format_payment_data(payment) do
    paid_decimal = payment[:deposit_amount] || Decimal.new("0")
    total_decimal = payment.total_amount || Decimal.new("0")

    total_minus_paid = Decimal.sub(total_decimal, paid_decimal)
    unpaid_decimal =
      if Decimal.compare(total_minus_paid, Decimal.new("0")) == :lt do
        Decimal.new("0")
      else
        total_minus_paid
      end

    amount_display =
      case payment.payment_plan do
        "installment" ->
          "#{format_amount(paid_decimal)}/#{format_amount(unpaid_decimal)}"
        _ ->
          format_amount(total_decimal)
      end

    # Derive status: installments remain in_progress until fully paid
    computed_status =
      case payment.payment_plan do
        "installment" ->
          if Decimal.compare(unpaid_decimal, Decimal.new("0")) == :gt do
            "in_progress"
          else
            normalize_status(payment.status)
          end
        _ -> normalize_status(payment.status)
      end

    %{
      id: payment.id,
      source: payment[:source],
      user_name: payment.user_name || "Unknown",
      user_email: payment.user_email || "No email",
      package_name: payment.package_name || "Unknown Package",
      amount: amount_display,
      raw_amount: payment.total_amount,
      payment_method: payment.payment_method || "Not specified",
      payment_plan: payment.payment_plan || "Not specified",
      status: computed_status,
      is_booking_for_self: payment.is_booking_for_self,
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
      traveler_citizenship: payment.traveler_citizenship || "No citizenship",
      # Payment breakdown
      paid_amount: paid_decimal,
      unpaid_amount: unpaid_decimal
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

  # --- Pagination helpers ---
  defp assign_pagination(socket, payments \\ nil) do
    payments = payments || socket.assigns.payments
    page_size = socket.assigns.page_size
    total_count = length(payments)
    total_pages = calc_total_pages(total_count, page_size)
    # Ensure current page is within bounds
    page = socket.assigns.page |> min(total_pages) |> max(1)
    visible_payments = paginate_list(payments, page, page_size)

    socket
    |> assign(:payments, payments)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
    |> assign(:page, page)
    |> assign(:visible_payments, visible_payments)
  end

  defp calc_total_pages(0, _page_size), do: 1
  defp calc_total_pages(total_count, page_size) when page_size > 0 do
    div(total_count + page_size - 1, page_size)
  end

  defp paginate_list(list, page, page_size) do
    start_index = (page - 1) * page_size
    Enum.slice(list, start_index, page_size)
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-full mx-auto">
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
              <button phx-click="go_to_payment_proofs" class="bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors">
                Process Payment
              </button>
            </div>
          </div>

          <!-- Summary Stats -->
          <div class="mb-6 grid grid-cols-1 md:grid-cols-5 gap-4">
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

          <!-- Scroll indicator (shows after 10th row) -->
          <%= if length(@visible_payments) > 10 do %>
            <div class="mb-2 flex items-center justify-center text-sm text-gray-500 bg-blue-50 py-2 rounded">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16l-4-4m0 0l4-4m-4 4h18"></path>
              </svg>
              Scroll horizontally to view all columns
              <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"></path>
              </svg>
            </div>
          <% end %>

          <div class="overflow-x-auto border border-gray-200 rounded-lg">
            <table class="min-w-full divide-y divide-gray-200 text-sm">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[100px]">Payment ID</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[200px]">Booked By</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[150px]">Package</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[120px]">Booking Type</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[80px]">No. of Persons</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[100px]">Amount</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[120px]">Payment Method</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[100px]">Payment Type</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[100px]">Status</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[120px]">Transaction ID</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[120px]">Payment Date</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-[100px]">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= if Enum.empty?(@payments) do %>
                  <tr>
                    <td colspan="12" class="px-4 py-8 text-center text-gray-500">
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
                  <%= for payment <- @visible_payments do %>
                    <tr class="hover:bg-teal-50 transition-colors">
                      <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">#<%= payment.id %></td>
                      <td class="px-4 py-3 whitespace-nowrap">
                        <div class="text-sm text-gray-900"><%= payment.user_name %></div>
                        <div class="text-xs text-gray-500"><%= payment.user_email %></div>
                      </td>
                      <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900"><%= payment.package_name %></td>
                      <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                        <%= if payment.is_booking_for_self do %>
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
                            </svg>
                            Myself
                          </span>
                        <% else %>
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                            </svg>
                            Else
                          </span>
                        <% end %>
                      </td>
                      <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900 text-center">
                        <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                          </svg>
                          <%= payment.number_of_persons %>
                        </span>
                      </td>
                      <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">
                        <%= if payment.payment_plan == "installment" do %>
                          <span class="text-green-700 font-semibold"><%= format_amount(payment.paid_amount) %></span>
                          /
                          <span class="text-red-700 font-semibold"><%= format_amount(payment.unpaid_amount) %></span>
                        <% else %>
                          <%= payment.amount %>
                        <% end %>
                      </td>
                      <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                        <span class="capitalize"><%= String.replace(payment.payment_method, "_", " ") %></span>
                      </td>
                      <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                        <%= if payment.payment_plan == "installment" do %>
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-orange-100 text-orange-800">
                            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"></path>
                            </svg>
                            Installment
                          </span>
                        <% else %>
                          <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                            </svg>
                            Full Payment
                          </span>
                        <% end %>
                      </td>
                      <td class="px-4 py-3 whitespace-nowrap">
                        <span class={[
                          "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                          case payment.status do
                            "completed" -> "bg-green-100 text-green-800"
                            "in_progress" -> "bg-blue-100 text-blue-800"
                            "canceled" -> "bg-red-100 text-red-800"
                            _ -> "bg-gray-100 text-gray-800"
                          end
                        ]}>
                          <%= String.replace(payment.status, "_", " ") |> String.capitalize() %>
                        </span>
                      </td>
                      <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900"><%= payment.transaction_id %></td>
                      <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900"><%= payment.payment_date %></td>
                      <td class="px-4 py-3 whitespace-nowrap text-sm font-medium">
                        <div class="flex items-center gap-2 flex-nowrap">
                          <button
                            phx-click="view_payment"
                            phx-value-id={payment.id}
                            phx-value-source={payment.source}
                            class="text-teal-600 hover:text-teal-900 px-2 py-1 border rounded">
                            View
                          </button>
                        </div>
                      </td>
                     </tr>
                   <% end %>
                 <% end %>
               </tbody>
             </table>
           </div>

          <!-- Pagination Controls -->
          <div class="mt-4 flex items-center justify-between">
            <div class="text-sm text-gray-600">
              <%= if @total_count > 0 do %>
                <%= start_idx = ((@page - 1) * @page_size) + 1 %>
                <%= end_idx = min(@total_count, @page * @page_size) %>
                Showing <%= start_idx %>–<%= end_idx %> of <%= @total_count %>
              <% else %>
                Showing 0–0 of 0
              <% end %>
            </div>
            <div class="flex gap-2">
              <button phx-click="paginate" phx-value-action="first" class={[
                "px-3 py-1 rounded border",
                if(@page == 1, do: "bg-gray-100 text-gray-400 cursor-not-allowed", else: "bg-white text-gray-700 hover:bg-gray-50")
              ]} disabled={@page == 1}>&laquo; First</button>
              <button phx-click="paginate" phx-value-action="prev" class={[
                "px-3 py-1 rounded border",
                if(@page == 1, do: "bg-gray-100 text-gray-400 cursor-not-allowed", else: "bg-white text-gray-700 hover:bg-gray-50")
              ]} disabled={@page == 1}>&lsaquo; Prev</button>
              <span class="px-3 py-1 text-sm text-gray-600">Page <%= @page %> of <%= @total_pages %></span>
              <button phx-click="paginate" phx-value-action="next" class={[
                "px-3 py-1 rounded border",
                if(@page >= @total_pages, do: "bg-gray-100 text-gray-400 cursor-not-allowed", else: "bg-white text-gray-700 hover:bg-gray-50")
              ]} disabled={@page >= @total_pages}>Next &rsaquo;</button>
              <button phx-click="paginate" phx-value-action="last" class={[
                "px-3 py-1 rounded border",
                if(@page >= @total_pages, do: "bg-gray-100 text-gray-400 cursor-not-allowed", else: "bg-white text-gray-700 hover:bg-gray-50")
              ]} disabled={@page >= @total_pages}>Last &raquo;</button>
            </div>
          </div>


        </div>
      </div>
    </.admin_layout>
    """
  end
end
