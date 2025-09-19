defmodule UmrahlyWeb.UserPaymentsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings
  alias Decimal
  alias Calendar
  alias Float
  alias Umrahly.Packages
  #alias Umrahly.Accounts

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to payment updates
      Phoenix.PubSub.subscribe(Umrahly.PubSub, "payments:#{socket.assigns.current_user.id}")
    end

    socket =
      socket
      |> assign(:current_tab, "installment")
      |> assign(:current_user, socket.assigns.current_user)
      |> assign(:bookings, [])
      |> assign(:payment_history, [])
      |> assign(:receipts, [])
      |> assign(:selected_payment, nil)
      |> assign(:show_payment_modal, false)
      |> assign(:selected_booking, nil)
      |> assign(:show_booking_modal, false)
      |> assign(:show_booking_plan, false)
      |> assign(:show_installment_payment_modal, false)
      |> assign(:selected_installment, nil)
      |> assign(:selected_payment_method, "")
      |> assign(:uploaded_files, [])
      |> assign(:upload_errors, [])
      |> allow_upload(:payment_proof,
        accept: ~w(.jpg .jpeg .png .pdf .doc .docx),
        max_entries: 5,
        max_file_size: 10_000_000  # 10MB
      )
      |> load_data()

    {:ok, socket}
  end

  def handle_params(%{"tab" => tab}, _url, socket) do
    socket = assign(socket, :current_tab, tab)
    {:noreply, socket}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("switch-tab", %{"tab" => tab}, socket) do
    socket = assign(socket, :current_tab, tab)
    {:noreply, socket}
  end

  def handle_event("view-payment-details", %{"payment_id" => payment_id}, socket) do
    payment = find_payment_by_id(payment_id, socket.assigns.payment_history)
    socket =
      socket
      |> assign(:selected_payment, payment)
      |> assign(:show_payment_modal, true)

    {:noreply, socket}
  end

  def handle_event("close-payment-modal", _params, socket) do
    socket =
      socket
      |> assign(:selected_payment, nil)
      |> assign(:show_payment_modal, false)

    {:noreply, socket}
  end

  def handle_event("view-booking", %{"booking_id" => booking_id}, socket) do
    booking = Enum.find(socket.assigns.bookings, fn b -> to_string(b.id) == to_string(booking_id) end)

    socket =
      socket
      |> assign(:selected_booking, booking)
      |> assign(:show_booking_modal, false)
      |> assign(:show_booking_plan, true)

    {:noreply, socket}
  end

  def handle_event("close-booking-modal", _params, socket) do
    socket =
      socket
      |> assign(:selected_booking, nil)
      |> assign(:show_booking_modal, false)

    {:noreply, socket}
  end

  def handle_event("close-booking-plan", _params, socket) do
    socket =
      socket
      |> assign(:show_booking_plan, false)
      |> assign(:selected_booking, nil)

    {:noreply, socket}
  end

  def handle_event("make-payment", %{"booking_id" => booking_id, "amount" => amount}, socket) do
    # Handle payment processing
    case process_payment(booking_id, amount, socket.assigns.current_user) do
      {:ok, _payment} ->
        socket =
          socket
          |> put_flash(:info, "Payment processed successfully!")
          |> load_data()

        {:noreply, socket}
    end
  end

  def handle_event("download-receipt", %{"receipt_id" => receipt_id}, socket) do
    # Handle receipt download
    case download_receipt(receipt_id, socket.assigns.current_user) do
      {:ok, file_path, filename} ->
        # Send file download response to the client
        socket = push_event(socket, "receipt_download_ready", %{
          file_path: file_path,
          filename: filename
        })
        {:noreply, socket}
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to download receipt: #{reason}")
        {:noreply, socket}
    end
  end

  def handle_event("pay-installment", %{"booking_id" => booking_id, "installment_number" => installment_number, "amount" => amount}, socket) do
    # Show payment method selection modal
    installment = %{
      booking_id: booking_id,
      installment_number: installment_number,
      amount: amount
    }

    socket =
      socket
      |> assign(:selected_installment, installment)
      |> assign(:show_installment_payment_modal, true)
      |> assign(:selected_payment_method, "")

    {:noreply, socket}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :payment_proof, ref)}
  end

  def handle_event("update_payment_method", %{"payment_method" => payment_method}, socket) do
    socket =
      socket
      |> assign(:selected_payment_method, payment_method)
      |> assign(:uploaded_files, [])  # Clear uploaded files when payment method changes
      |> assign(:upload_errors, [])   # Clear upload errors

    {:noreply, socket}
  end

  def handle_event("confirm-installment-payment", _params, socket) do
    if socket.assigns.selected_payment_method == "" do
      socket = put_flash(socket, :error, "Please select a payment method")
      {:noreply, socket}
    else
      # Check if offline payment method requires file upload
      requires_file_upload = socket.assigns.selected_payment_method in ["bank_transfer", "cash"]

      if requires_file_upload and Enum.empty?(socket.assigns.uploads.payment_proof.entries) do
        socket = put_flash(socket, :error, "Please upload your transaction proof")
        {:noreply, socket}
      else
        installment = socket.assigns.selected_installment

        case process_installment_payment(
          installment.booking_id,
          installment.installment_number,
          installment.amount,
          socket.assigns.selected_payment_method,
          socket.assigns.uploads.payment_proof.entries,
          socket.assigns.current_user
        ) do
          {:ok, _payment} ->
            socket =
              socket
              |> put_flash(:info, "Installment payment submitted successfully! We will verify your payment and update your account.")
              |> assign(:show_installment_payment_modal, false)
              |> assign(:selected_installment, nil)
              |> assign(:selected_payment_method, "")
              |> load_data()

            {:noreply, socket}
          {:error, reason} ->
            socket = put_flash(socket, :error, "Failed to process payment: #{reason}")
            {:noreply, socket}
        end
      end
    end
  end

  def handle_event("close-installment-payment-modal", _params, socket) do
    socket =
      socket
      |> assign(:show_installment_payment_modal, false)
      |> assign(:selected_installment, nil)
      |> assign(:selected_payment_method, "")
      |> assign(:uploaded_files, [])
      |> assign(:upload_errors, [])

    {:noreply, socket}
  end

  defp load_data(socket) do
    user = socket.assigns.current_user

    # Build installment-facing bookings from active booking flows enriched with latest booking
    bookings = build_installment_bookings(user.id)

    # Load payment history
    payment_history = load_payment_history(user.id)

    # Load receipts
    receipts = load_receipts(user.id)

    socket
    |> assign(:bookings, bookings)
    |> assign(:payment_history, payment_history)
    |> assign(:receipts, receipts)
  end

  defp build_installment_bookings(user_id) do
    Bookings.get_booking_flow_progress_by_user_id(user_id)
    |> Enum.filter(fn progress -> progress.payment_plan == "installment" end)
    |> Enum.map(fn progress ->
      latest_booking =
        Bookings.get_latest_booking_for_user_schedule(user_id, progress.package_schedule_id)

      schedule = safe_get_schedule(progress.package_schedule_id)

      %{
        id: (latest_booking && latest_booking.id) || progress.id,
        booking_reference:
          if latest_booking do
            "BK" <> Integer.to_string(latest_booking.id)
          else
            "BFP" <> Integer.to_string(progress.id)
          end,
        package_name: progress.package && progress.package.name,
        status: (latest_booking && latest_booking.status) || progress.status,
        total_amount: (latest_booking && latest_booking.total_amount) || progress.total_amount,
        paid_amount: (latest_booking && latest_booking.deposit_amount) || progress.deposit_amount,
        payment_method: (latest_booking && latest_booking.payment_method) || progress.payment_method,
        payment_plan: "installment",
        booking_date: latest_booking && latest_booking.booking_date,
        package_schedule_id: (latest_booking && latest_booking.package_schedule_id) || progress.package_schedule_id,
        departure_date: schedule && schedule.departure_date
      }
    end)
  end

  defp safe_get_schedule(nil), do: nil
  defp safe_get_schedule(schedule_id) do
    try do
      Packages.get_package_schedule!(schedule_id)
    rescue
      _ -> nil
    end
  end

  defp load_payment_history(_user_id) do
    # This would typically query a payments table
    # For now, returning mock data with more detailed information
    [
      %{
        id: "1",
        date: ~D[2024-01-15],
        amount: 1500.00,
        status: "completed",
        method: "credit_card",
        booking_reference: "BK001",
        transaction_id: "TXN_001_20240115",
        card_last4: "1234",
        card_brand: "Visa",
        description: "Umrah Package - Standard Plan",
        fees: 15.00,
        net_amount: 1485.00
      },
      %{
        id: "2",
        date: ~D[2024-01-10],
        amount: 750.00,
        status: "completed",
        method: "bank_transfer",
        booking_reference: "BK002",
        transaction_id: "TXN_002_20240110",
        bank_name: "Maybank",
        account_last4: "5678",
        description: "Umrah Package - Economy Plan",
        fees: 5.00,
        net_amount: 745.00
      }
    ]
  end

  defp find_payment_by_id(payment_id, payment_history) do
    Enum.find(payment_history, fn payment -> payment.id == payment_id end)
  end

  defp load_receipts(_user_id) do
    # This would typically query a receipts table
    # For now, returning mock data
    [
      %{
        id: "1",
        date: ~D[2024-01-15],
        amount: 1500.00,
        booking_reference: "BK001",
        file_path: "/receipts/receipt_1.pdf"
      },
      %{
        id: "2",
        date: ~D[2024-01-10],
        amount: 750.00,
        booking_reference: "BK002",
        file_path: "/receipts/receipt_2.pdf"
      }
    ]
  end

  defp process_payment(_booking_id, _amount, _user) do
    # This would integrate with actual payment gateway
    # For now, simulating success
    {:ok, %{id: "payment_#{:rand.uniform(1000)}", status: "completed"}}
  end

  defp download_receipt(receipt_id, _user) do
    # This would handle actual file download
    # For now, simulating success with proper file information
    case receipt_id do
      "1" ->
        {:ok, "/receipts/#{receipt_id}/download", "receipt_BK001_#{Date.utc_today()}.txt"}
      "2" ->
        {:ok, "/receipts/#{receipt_id}/download", "receipt_BK002_#{Date.utc_today()}.txt"}
      _ ->
        {:error, "Invalid receipt ID"}
    end
  end

  defp process_installment_payment(booking_id, installment_number, amount, payment_method, upload_entries, user) do
    booking = Bookings.get_booking!(booking_id)

    # Check if this is an online payment method that requires gateway redirect
    requires_online_payment = payment_method in ["credit_card", "online_banking", "e_wallet"]

    if requires_online_payment do
      # For online payments, we would redirect to payment gateway
      # This is a placeholder - you'd implement actual gateway integration
      {:ok, :redirect_to_gateway}
    else
      # For offline payments, we need to handle file uploads and create a pending payment record
      # Save uploaded files
      file_paths = save_uploaded_files(upload_entries, booking_id, installment_number)

      # Create a payment record with pending status
      payment_attrs = %{
        booking_id: booking_id,
        installment_number: installment_number,
        amount: Decimal.new(amount),
        payment_method: payment_method,
        status: "pending_verification",
        payment_proof_files: file_paths,
        submitted_at: DateTime.utc_now()
      }

      # For now, we'll just log the activity and notify
      # In a real implementation, you'd save this to a payments table
      Umrahly.ActivityLogs.log_user_action(
        user.id,
        "Installment Payment Submitted",
        "Payment #{installment_number} for booking #{booking_id}",
        %{
          booking_id: booking_id,
          installment_number: installment_number,
          amount: amount,
          payment_method: payment_method,
          file_count: length(file_paths)
        }
      )

      # Notify admin about pending payment verification
      Phoenix.PubSub.broadcast(Umrahly.PubSub, "admin:payments", {
        :payment_submitted_for_verification,
        %{
          booking_id: booking_id,
          installment_number: installment_number,
          amount: amount,
          payment_method: payment_method,
          user_id: user.id,
          file_paths: file_paths
        }
      })

      {:ok, payment_attrs}
    end
  end

  defp save_uploaded_files(upload_entries, booking_id, installment_number) do
    # Save uploaded files to the filesystem
    Enum.map(upload_entries, fn entry ->
      # Create directory structure: priv/static/uploads/payment_proof/booking_id/installment_number/
      upload_dir = Path.join([
        "priv/static/uploads/payment_proof",
        to_string(booking_id),
        "installment_#{installment_number}"
      ])

      File.mkdir_p!(upload_dir)

      # Generate unique filename
      timestamp = DateTime.utc_now() |> DateTime.to_unix()
      extension = Path.extname(entry.client_name)
      filename = "#{timestamp}_#{entry.client_name}"
      file_path = Path.join(upload_dir, filename)

      # Copy file to upload directory
      File.cp!(entry.path, file_path)

      # Return relative path for database storage
      "/uploads/payment_proof/#{booking_id}/installment_#{installment_number}/#{filename}"
    end)
  end

  defp format_amount(amount) when is_nil(amount), do: "0.00"
  defp format_amount(%Decimal{} = amount) do
    Decimal.to_string(amount)
  end
  defp format_amount(amount) when is_number(amount) do
    :erlang.float_to_binary(amount, decimals: 2)
  end
  defp format_amount(amount) when is_binary(amount) do
    # Try to parse as number, fallback to original string
    case Float.parse(amount) do
      {float, _} -> :erlang.float_to_binary(float, decimals: 2)
      :error -> amount
    end
  end
  defp format_amount(_amount), do: "0.00"

  defp calculate_remaining_amount(total_amount, paid_amount) do
    total = ensure_decimal(total_amount)
    paid = ensure_decimal(paid_amount)
    Decimal.sub(total, paid)
  end

  defp ensure_decimal(nil), do: Decimal.new(0)
  defp ensure_decimal(%Decimal{} = value), do: value
  defp ensure_decimal(value) when is_number(value), do: Decimal.new(value)
  defp ensure_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      {decimal, _rest} -> decimal
      :error -> Decimal.new(0)
    end
  end
  defp ensure_decimal(_), do: Decimal.new(0)
  defp months_to_pay_until_departure(nil), do: 3
  defp months_to_pay_until_departure(%Date{} = departure_date) do
    today = Date.utc_today()
    months_until_departure = Date.diff(departure_date, today) |> div(30)
    max(1, months_until_departure - 1)
  end

  defp calculate_installment_breakdown_dynamic(total_amount, deposit_amount, departure_date) do
    total = ensure_decimal(total_amount)
    deposit = ensure_decimal(deposit_amount)
    remaining = Decimal.sub(total, deposit)

    months = months_to_pay_until_departure(departure_date)
    today = Date.utc_today()

    # Base monthly amount rounded up to ensure we finish before departure
    base =
      remaining
      |> Decimal.div(Decimal.new(months))
      |> Decimal.round(2)

    # We'll make first (months - 1) equal, and adjust the last to match exactly
    installments = Enum.map(1..months, fn idx ->
      # Calculate due date for each month
      due_date = Date.add(today, idx * 30)
      is_last_payment = idx == months

      amount = if idx < months do
        base
      else
        paid_so_far = Decimal.mult(base, Decimal.new(months - 1)) |> Decimal.round(2)
        Decimal.sub(remaining, paid_so_far) |> Decimal.round(2)
      end

      # Determine status based on due date
      status = cond do
        Date.compare(due_date, today) == :gt -> "Upcoming"
        Date.compare(due_date, today) == :eq -> "Due Today"
        true -> "Overdue"
      end

      type = if is_last_payment, do: "Final Installment", else: "Installment"

      %{
        n: idx,
        amount: amount,
        due_date: due_date,
        type: type,
        status: status,
        is_last: is_last_payment
      }
    end)

    # Find the first upcoming payment (next payment in the schedule)
    first_upcoming = Enum.find(installments, fn installment ->
      installment.status == "Upcoming"
    end)

    # Mark the first upcoming payment as payable
    Enum.map(installments, fn installment ->
      can_pay = installment.status in ["Due Today", "Overdue"] or
                (installment.status == "Upcoming" and installment == first_upcoming)

      Map.put(installment, :can_pay, can_pay)
    end)
  end

  def render(assigns) do
    ~H"""
    <.sidebar page_title="Payments">
      <%= render_payments_content(assigns) %>
    </.sidebar>
    """
  end

  defp render_payments_content(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Page Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Payments</h1>
          <p class="mt-2 text-gray-600">Manage your payments, view history, and download receipts</p>
        </div>

        <!-- Tab Navigation -->
        <div class="border-b border-gray-200 mb-8">
          <nav class="-mb-px flex space-x-8">
            <button
              phx-click="switch-tab"
              phx-value-tab="installment"
              class={"py-2 px-1 border-b-2 font-medium text-sm #{if @current_tab == "installment", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Installment Payment
            </button>
            <button
              phx-click="switch-tab"
              phx-value-tab="history"
              class={"py-2 px-1 border-b-2 font-medium text-sm #{if @current_tab == "history", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Payment History
            </button>
            <button
              phx-click="switch-tab"
              phx-value-tab="receipts"
              class={"py-2 px-1 border-b-2 font-medium text-sm #{if @current_tab == "receipts", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Receipts
            </button>
          </nav>
        </div>

        <!-- Tab Content -->
        <div class="bg-white rounded-lg shadow">
          <%= case @current_tab do %>
            <% "installment" -> %>
              <!-- Installment Payment Tab -->
              <div class="p-6">
                <h2 class="text-xl font-semibold text-gray-900 mb-6">Installment Payment Plans</h2>

                <%= if @show_booking_plan and @selected_booking do %>
                  <% remaining_for_plan = calculate_remaining_amount(@selected_booking.total_amount, @selected_booking.paid_amount) %>
                  <div class="mb-6">
                    <button
                      phx-click="close-booking-plan"
                      class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                    >
                      ← Back to bookings
                    </button>
                  </div>

                  <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
                    <div class="lg:col-span-1">
                      <div class="border border-gray-200 rounded-lg p-4">
                        <div class="flex justify-between items-center mb-2">
                          <span class="text-sm text-gray-500">Reference</span>
                          <span class="text-sm font-mono text-gray-900">#<%= @selected_booking.booking_reference %></span>
                        </div>
                        <div class="flex justify-between items-center mb-2">
                          <span class="text-sm text-gray-500">Package</span>
                          <span class="text-sm text-gray-900"><%= @selected_booking.package_name %></span>
                        </div>
                        <div class="flex justify-between items-center mb-2">
                          <span class="text-sm text-gray-500">Total</span>
                          <span class="text-sm font-medium text-gray-900">RM <%= format_amount(@selected_booking.total_amount) %></span>
                        </div>
                        <div class="flex justify-between items-center mb-2">
                          <span class="text-sm text-gray-500">Paid (Deposit)</span>
                          <span class="text-sm text-green-700">RM <%= format_amount(@selected_booking.paid_amount || 0) %></span>
                        </div>
                        <div class="flex justify-between items-center">
                          <span class="text-sm text-gray-500">Remaining</span>
                          <span class="text-sm text-red-700">RM <%= format_amount(remaining_for_plan) %></span>
                        </div>
                        <div class="mt-3 text-xs text-gray-500">
                          <span>Departure: <%= if @selected_booking.departure_date, do: Calendar.strftime(@selected_booking.departure_date, "%B %d, %Y"), else: "-" %></span>
                        </div>
                      </div>
                    </div>

                    <div class="lg:col-span-2">
                      <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 rounded-lg">
                        <table class="min-w-full divide-y divide-gray-200">
                          <thead class="bg-gray-50">
                            <tr>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Payment #</th>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Due Date</th>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount (RM)</th>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Action</th>
                            </tr>
                          </thead>
                          <tbody class="bg-white divide-y divide-gray-200">
                            <%= for installment <- calculate_installment_breakdown_dynamic(@selected_booking.total_amount, @selected_booking.paid_amount || 0, @selected_booking.departure_date) do %>
                              <tr class={if installment.is_last, do: "bg-yellow-50", else: ""}>
                                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                  <%= installment.n %>
                                  <%= if installment.is_last do %>
                                    <span class="ml-1 text-xs text-yellow-600">(Final)</span>
                                  <% end %>
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap">
                                  <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800">
                                    <%= installment.type %>
                                  </span>
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                                  <%= Calendar.strftime(installment.due_date, "%B %d, %Y") %>
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm font-semibold text-gray-900">
                                  <%= format_amount(installment.amount) %>
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap">
                                  <span class={[
                                    "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                                    case installment.status do
                                      "Upcoming" -> "bg-gray-100 text-gray-800"
                                      "Due Today" -> "bg-yellow-100 text-yellow-800"
                                      "Overdue" -> "bg-red-100 text-red-800"
                                      _ -> "bg-gray-100 text-gray-800"
                                    end
                                  ]}>
                                    <%= installment.status %>
                                  </span>
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                  <%= if installment.can_pay do %>
                                    <button
                                      phx-click="pay-installment"
                                      phx-value-booking_id={@selected_booking.id}
                                      phx-value-installment_number={installment.n}
                                      phx-value-amount={Decimal.to_string(installment.amount)}
                                      class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                                    >
                                      <%= if installment.status in ["Due Today", "Overdue"], do: "Pay Now", else: "Pay Early" %>
                                    </button>
                                  <% else %>
                                    <span class="text-gray-400 text-xs">Not available yet</span>
                                  <% end %>
                                </td>
                              </tr>
                            <% end %>
                          </tbody>
                        </table>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <%= if Enum.empty?(@bookings) do %>
                    <div class="text-center py-12">
                      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                      </svg>
                      <h3 class="mt-2 text-sm font-medium text-gray-900">No active bookings</h3>
                      <p class="mt-1 text-sm text-gray-500">You don't have any bookings that require installment payments.</p>
                      <div class="mt-6">
                        <a href="/packages" class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700">
                          Browse Packages
                        </a>
                      </div>
                    </div>
                  <% else %>
                    <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
                      <table class="min-w-full divide-y divide-gray-300">
                        <thead class="bg-gray-50">
                          <tr>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Reference</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Package</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Total (RM)</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Paid (RM)</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Remaining (RM)</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Booking Date</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Action</th>
                          </tr>
                        </thead>
                        <tbody class="bg-white divide-y divide-gray-200">
                          <%= for booking <- @bookings do %>
                            <% remaining_decimal = calculate_remaining_amount(booking.total_amount, booking.paid_amount) %>
                            <tr>
                              <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">#<%= booking.booking_reference %></td>
                              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700"><%= booking.package_name %></td>
                              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"> <%= format_amount(booking.total_amount) %> </td>
                              <td class="px-6 py-4 whitespace-nowrap text-sm text-green-700"> <%= format_amount(booking.paid_amount || 0) %> </td>
                              <td class="px-6 py-4 whitespace-nowrap text-sm text-red-700"> <%= format_amount(remaining_decimal) %> </td>
                              <td class="px-6 py-4 whitespace-nowrap">
                                <span class={["inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium", if(booking.status == "completed", do: "bg-green-100 text-green-800", else: "bg-blue-100 text-blue-800")]}>
                                  <%= String.upcase(booking.status) %>
                                </span>
                              </td>
                              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                <%= if booking.booking_date do %>
                                  <%= Calendar.strftime(booking.booking_date, "%b %d, %Y") %>
                                <% else %>
                                  -
                                <% end %>
                              </td>
                              <td class="px-6 py-4 whitespace-nowrap text-sm">
                                <button
                                  phx-click="view-booking"
                                  phx-value-booking_id={booking.id}
                                  class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                                >
                                  View
                                </button>
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% end %>
                <% end %>
              </div>

            <% "history" -> %>
              <!-- Payment History Tab -->
              <div class="p-6">
                <h2 class="text-xl font-semibold text-gray-900 mb-6">Payment History</h2>

                <%= if Enum.empty?(@payment_history) do %>
                  <div class="text-center py-12">
                    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"/>
                    </svg>
                    <h3 class="mt-2 text-sm font-medium text-gray-900">No payment history</h3>
                    <p class="mt-1 text-sm text-gray-500">You haven't made any payments yet.</p>
                  </div>
                <% else %>
                  <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
                    <table class="min-w-full divide-y divide-gray-300">
                      <thead class="bg-gray-50">
                        <tr>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Method</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Reference</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                        </tr>
                      </thead>
                      <tbody class="bg-white divide-y divide-gray-200">
                        <%= for payment <- @payment_history do %>
                          <tr>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              <%= Calendar.strftime(payment.date, "%B %d, %Y") %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                              RM <%= format_amount(payment.amount) %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              <%= String.replace(payment.method, "_", " ") |> String.upcase() %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                              <span class={["inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium", if(payment.status == "completed", do: "bg-green-100 text-green-800", else: "bg-yellow-100 text-yellow-800")]}>
                                <%= String.upcase(payment.status) %>
                              </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              <%= payment.booking_reference %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              <button
                                phx-click="view-payment-details"
                                phx-value-payment_id={payment.id}
                                class="text-blue-600 hover:text-blue-900 font-medium"
                              >
                                View Details
                              </button>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                <% end %>
              </div>

            <% "receipts" -> %>
              <!-- Receipts Tab -->
              <div class="p-6">
                <h2 class="text-xl font-semibold text-gray-900 mb-6">Receipts</h2>

                <%= if Enum.empty?(@receipts) do %>
                  <div class="text-center py-12">
                    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                    <h3 class="mt-2 text-sm font-medium text-gray-900">No receipts available</h3>
                    <p class="mt-1 text-sm text-gray-500">Receipts will appear here after you make payments.</p>
                  </div>
                <% else %>
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                    <%= for receipt <- @receipts do %>
                      <div class="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-lg transition-shadow duration-200">
                        <div class="flex items-center justify-between mb-4">
                          <div class="flex-shrink-0">
                            <svg class="h-8 w-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                            </svg>
                          </div>
                          <div class="text-right">
                            <p class="text-sm font-medium text-gray-900">RM <%= format_amount(receipt.amount) %></p>
                            <p class="text-xs text-gray-500"><%= receipt.booking_reference %></p>
                          </div>
                        </div>

                        <div class="mb-4">
                          <p class="text-sm text-gray-600">
                            <span class="font-medium">Date:</span> <%= Calendar.strftime(receipt.date, "%B %d, %Y") %>
                          </p>
                        </div>

                        <button
                          id={"receipt-download-#{receipt.id}"}
                          phx-click="download-receipt"
                          phx-value-receipt_id={receipt.id}
                          phx-hook="DownloadReceipt"
                          data-receipt-id={receipt.id}
                          class="w-full inline-flex justify-center items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                        >
                          <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                          </svg>
                          Download Receipt
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
          <% end %>
        </div>
      </div>

      <!-- Payment Details Modal -->
      <%= if @show_payment_modal and @selected_payment do %>
        <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" id="payment-modal">
          <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div class="mt-3">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-medium text-gray-900">Payment Details</h3>
                <button
                  phx-click="close-payment-modal"
                  class="text-gray-400 hover:text-gray-600"
                >
                  <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>

              <div class="space-y-4">
                <div class="border-b border-gray-200 pb-3">
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Transaction ID:</span>
                    <span class="text-sm text-gray-900 font-mono"><%= @selected_payment.transaction_id %></span>
                  </div>
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Date:</span>
                    <span class="text-sm text-gray-900"><%= Calendar.strftime(@selected_payment.date, "%B %d, %Y") %></span>
                  </div>
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Status:</span>
                    <span class={["inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium", if(@selected_payment.status == "completed", do: "bg-green-100 text-green-800", else: "bg-yellow-100 text-yellow-800")]}>
                      <%= String.upcase(@selected_payment.status) %>
                    </span>
                  </div>
                </div>

                <div class="border-b border-gray-200 pb-3">
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Amount:</span>
                    <span class="text-lg font-semibold text-gray-900">RM <%= format_amount(@selected_payment.amount) %></span>
                  </div>
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Fees:</span>
                    <span class="text-sm text-gray-900">RM <%= format_amount(@selected_payment.fees) %></span>
                  </div>
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Net Amount:</span>
                    <span class="text-sm font-medium text-gray-900">RM <%= format_amount(@selected_payment.net_amount) %></span>
                  </div>
                </div>

                <div class="border-b border-gray-200 pb-3">
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Payment Method:</span>
                    <span class="text-sm text-gray-900"><%= String.replace(@selected_payment.method, "_", " ") |> String.upcase() %></span>
                  </div>

                  <%= if @selected_payment.method == "credit_card" do %>
                    <div class="flex justify-between items-center mb-2">
                      <span class="text-sm font-medium text-gray-500">Card:</span>
                      <span class="text-sm text-gray-900"><%= @selected_payment.card_brand %> •••• <%= @selected_payment.card_last4 %></span>
                    </div>
                  <% end %>

                  <%= if @selected_payment.method == "bank_transfer" do %>
                    <div class="flex justify-between items-center mb-2">
                      <span class="text-sm font-medium text-gray-500">Bank:</span>
                      <span class="text-sm text-gray-900"><%= @selected_payment.bank_name %></span>
                    </div>
                    <div class="flex justify-between items-center mb-2">
                      <span class="text-sm font-medium text-gray-500">Account:</span>
                      <span class="text-sm text-gray-900">•••• <%= @selected_payment.account_last4 %></span>
                    </div>
                  <% end %>
                </div>

                <div class="border-b border-gray-200 pb-3">
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Booking Reference:</span>
                    <span class="text-sm text-gray-900 font-mono"><%= @selected_payment.booking_reference %></span>
                  </div>
                  <div class="flex justify-between items-start mb-2">
                    <span class="text-sm font-medium text-gray-500">Description:</span>
                    <span class="text-sm text-gray-900 text-right"><%= @selected_payment.description %></span>
                  </div>
                </div>
              </div>

              <div class="mt-6 flex justify-end">
                <button
                  phx-click="close-payment-modal"
                  class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Booking Details Modal -->
      <%= if @show_booking_modal and @selected_booking do %>
        <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" id="booking-modal">
          <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div class="mt-3">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-medium text-gray-900">Booking Details</h3>
                <button
                  phx-click="close-booking-modal"
                  class="text-gray-400 hover:text-gray-600"
                >
                  <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>

              <div class="space-y-4">
                <div class="border-b border-gray-200 pb-3">
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Reference:</span>
                    <span class="text-sm text-gray-900 font-mono">#<%= @selected_booking.booking_reference %></span>
                  </div>
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Package:</span>
                    <span class="text-sm text-gray-900"><%= @selected_booking.package_name %></span>
                  </div>
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Status:</span>
                    <span class={["inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium", if(@selected_booking.status == "completed", do: "bg-green-100 text-green-800", else: "bg-blue-100 text-blue-800")]}>
                      <%= String.upcase(@selected_booking.status) %>
                    </span>
                  </div>
                </div>

                <div class="border-b border-gray-200 pb-3">
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Total:</span>
                    <span class="text-sm font-medium text-gray-900">RM <%= format_amount(@selected_booking.total_amount) %></span>
                  </div>
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Paid:</span>
                    <span class="text-sm text-green-700">RM <%= format_amount(@selected_booking.paid_amount || 0) %></span>
                  </div>
                  <% remaining_for_modal = calculate_remaining_amount(@selected_booking.total_amount, @selected_booking.paid_amount) %>
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Remaining:</span>
                    <span class="text-sm text-red-700">RM <%= format_amount(remaining_for_modal) %></span>
                  </div>
                </div>

                <%= if Decimal.compare(remaining_for_modal, 0) == :gt do %>
                  <div class="border-b border-gray-200 pb-3">
                    <h4 class="text-sm font-medium text-gray-900 mb-2">Unpaid Monthly Breakdown (dynamic)</h4>
                    <div class="overflow-hidden ring-1 ring-black ring-opacity-5 rounded-md">
                      <table class="min-w-full divide-y divide-gray-200">
                        <thead class="bg-gray-50">
                          <tr>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Payment #</th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Due Date</th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount (RM)</th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Action</th>
                          </tr>
                        </thead>
                        <tbody class="bg-white divide-y divide-gray-200">
                          <%= for installment <- calculate_installment_breakdown_dynamic(@selected_booking.total_amount, @selected_booking.paid_amount || 0, @selected_booking.departure_date) do %>
                            <tr class={if installment.is_last, do: "bg-yellow-50", else: ""}>
                              <td class="px-4 py-2 text-sm font-medium text-gray-900">
                                <%= installment.n %>
                                <%= if installment.is_last do %>
                                  <span class="ml-1 text-xs text-yellow-600">(Final)</span>
                                <% end %>
                              </td>
                              <td class="px-4 py-2">
                                <span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800">
                                  <%= installment.type %>
                                </span>
                              </td>
                              <td class="px-4 py-2 text-sm text-gray-900">
                                <%= Calendar.strftime(installment.due_date, "%B %d, %Y") %>
                              </td>
                              <td class="px-4 py-2 text-sm font-semibold text-gray-900">
                                <%= format_amount(installment.amount) %>
                              </td>
                              <td class="px-4 py-2">
                                <span class={[
                                  "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                                  case installment.status do
                                    "Upcoming" -> "bg-gray-100 text-gray-800"
                                    "Due Today" -> "bg-yellow-100 text-yellow-800"
                                    "Overdue" -> "bg-red-100 text-red-800"
                                    _ -> "bg-gray-100 text-gray-800"
                                  end
                                ]}>
                                  <%= installment.status %>
                                </span>
                              </td>
                              <td class="px-4 py-2 text-sm font-medium">
                                <%= if installment.can_pay do %>
                                  <button
                                    phx-click="pay-installment"
                                    phx-value-booking_id={@selected_booking.id}
                                    phx-value-installment_number={installment.n}
                                    phx-value-amount={Decimal.to_string(installment.amount)}
                                    class="inline-flex items-center px-2 py-1 border border-transparent text-xs font-medium rounded text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
                                  >
                                    <%= if installment.status in ["Due Today", "Overdue"], do: "Pay", else: "Pay Early" %>
                                  </button>
                                <% else %>
                                  <span class="text-gray-400 text-xs">Not available</span>
                                <% end %>
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </div>
                <% end %>

                <div class="border-b border-gray-200 pb-3">
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Booking Date:</span>
                    <span class="text-sm text-gray-900">
                      <%= if @selected_booking.booking_date do %>
                        <%= Calendar.strftime(@selected_booking.booking_date, "%B %d, %Y") %>
                      <% else %>
                        -
                      <% end %>
                    </span>
                  </div>
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-sm font-medium text-gray-500">Payment Plan:</span>
                    <span class="text-sm text-gray-900"><%= String.capitalize(@selected_booking.payment_plan) %></span>
                  </div>
                </div>
              </div>

              <div class="mt-6 flex justify-end">
                <button
                  phx-click="close-booking-modal"
                  class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Installment Payment Method Selection Modal -->
      <%= if @show_installment_payment_modal and @selected_installment do %>
        <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" id="installment-payment-modal">
          <div class="relative top-10 mx-auto p-5 border w-full max-w-md shadow-lg rounded-md bg-white">
            <div class="mt-3">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-medium text-gray-900">Payment Method</h3>
                <button
                  phx-click="close-installment-payment-modal"
                  class="text-gray-400 hover:text-gray-600"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                  </svg>
                </button>
              </div>

              <div class="mb-4 p-3 bg-gray-50 rounded-lg">
                <div class="text-sm text-gray-600">
                  <div class="flex justify-between">
                    <span>Payment #<%= @selected_installment.installment_number %></span>
                    <span class="font-semibold">RM <%= @selected_installment.amount %></span>
                  </div>
                </div>
              </div>

              <div class="mb-6">
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Select Payment Method
                </label>
                <select
                  phx-change="update_payment_method"
                  class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  value={@selected_payment_method}
                >
                  <option value="">Choose payment method</option>
                  <option value="credit_card">Credit Card</option>
                  <option value="online_banking">Online Banking (FPX)</option>
                  <option value="e_wallet">E-Wallet (Boost, Touch 'n Go)</option>
                  <option value="bank_transfer">Bank Transfer</option>
                  <option value="cash">Cash</option>
                </select>
              </div>

              <!-- File Upload Section (only for offline payment methods) -->
              <%= if @selected_payment_method in ["bank_transfer", "cash"] do %>
                <div class="mb-6">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Upload Transaction Proof
                  </label>
                  <div class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md">
                    <div class="space-y-1 text-center">
                      <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                        <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                      </svg>
                      <div class="flex text-sm text-gray-600">
                        <label for="payment_proof" class="relative cursor-pointer bg-white rounded-md font-medium text-blue-600 hover:text-blue-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-blue-500">
                          <span>Upload files</span>
                          <.live_file_input upload={@uploads.payment_proof} class="sr-only" />
                        </label>
                        <p class="pl-1">or drag and drop</p>
                      </div>
                      <p class="text-xs text-gray-500">PNG, JPG, PDF, DOC up to 10MB each</p>
                    </div>
                  </div>

                  <!-- Show uploaded files -->
                  <%= for entry <- @uploads.payment_proof.entries do %>
                    <div class="mt-3">
                      <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                        <div class="flex items-center">
                          <svg class="w-4 h-4 text-gray-400 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                          </svg>
                          <span class="text-sm text-gray-700"><%= entry.client_name %></span>
                          <span class="ml-2 text-xs text-gray-500">(<%= entry.client_size %> bytes)</span>
                        </div>
                        <button
                          phx-click="cancel-upload"
                          phx-value-ref={entry.ref}
                          class="text-red-500 hover:text-red-700"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                          </svg>
                        </button>
                      </div>
                    </div>
                  <% end %>

                  <!-- Show upload errors -->
                  <%= for {_ref, error} <- @uploads.payment_proof.errors do %>
                    <div class="mt-2 text-sm text-red-600">
                      <%= error_to_string(error) %>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <div class="flex justify-end space-x-3">
                <button
                  phx-click="close-installment-payment-modal"
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500"
                >
                  Cancel
                </button>
                <button
                  phx-click="confirm-installment-payment"
                  disabled={@selected_payment_method == "" or (@selected_payment_method in ["bank_transfer", "cash"] and Enum.empty?(@uploads.payment_proof.entries))}
                  class="px-4 py-2 text-sm font-medium text-white bg-green-600 border border-transparent rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:bg-gray-300 disabled:cursor-not-allowed"
                >
                  <%= if @selected_payment_method in ["bank_transfer", "cash"], do: "Submit Payment", else: "Proceed to Payment" %>
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:too_many_files), do: "Too many files (max 5)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end
