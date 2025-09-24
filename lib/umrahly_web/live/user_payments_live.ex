defmodule UmrahlyWeb.UserPaymentsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings
  alias Umrahly.Repo
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
      |> assign(:payment_history_all, [])
      |> assign(:payment_history_items, [])
      |> assign(:payment_history_page, 1)
      |> assign(:payment_history_per_page, 10)
      |> assign(:payment_history_total_pages, 1)
      |> assign(:installments_all, [])
      |> assign(:installments_items, [])
      |> assign(:installments_page, 1)
      |> assign(:installments_per_page, 10)
      |> assign(:installments_total_pages, 1)
      |> assign(:receipts_all, [])
      |> assign(:receipts_items, [])
      |> assign(:receipts_page, 1)
      |> assign(:receipts_per_page, 9)
      |> assign(:receipts_total_pages, 1)
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

  # --- Installments Pagination Events ---
  def handle_event("inst-first", _params, socket) do
    socket = socket |> assign(:installments_page, 1) |> paginate_installments()
    {:noreply, socket}
  end

  def handle_event("inst-prev", _params, socket) do
    page = max(1, socket.assigns.installments_page - 1)
    socket = socket |> assign(:installments_page, page) |> paginate_installments()
    {:noreply, socket}
  end

  def handle_event("inst-next", _params, socket) do
    page = min(socket.assigns.installments_total_pages, socket.assigns.installments_page + 1)
    socket = socket |> assign(:installments_page, page) |> paginate_installments()
    {:noreply, socket}
  end

  def handle_event("inst-last", _params, socket) do
    last = socket.assigns.installments_total_pages
    socket = socket |> assign(:installments_page, last) |> paginate_installments()
    {:noreply, socket}
  end

  # --- Tab Switching ---
  def handle_event("switch-tab", %{"tab" => tab}, socket) do
    socket = assign(socket, :current_tab, tab)
    {:noreply, socket}
  end

  def handle_event("ph-prev", _params, socket) do
    page = max(1, socket.assigns.payment_history_page - 1)
    socket = socket |> assign(:payment_history_page, page) |> paginate_payment_history()
    {:noreply, socket}
  end

  def handle_event("ph-next", _params, socket) do
    page = min(socket.assigns.payment_history_total_pages, socket.assigns.payment_history_page + 1)
    socket = socket |> assign(:payment_history_page, page) |> paginate_payment_history()
    {:noreply, socket}
  end

  def handle_event("ph-first", _params, socket) do
    socket = socket |> assign(:payment_history_page, 1) |> paginate_payment_history()
    {:noreply, socket}
  end

  def handle_event("ph-last", _params, socket) do
    last = socket.assigns.payment_history_total_pages
    socket = socket |> assign(:payment_history_page, last) |> paginate_payment_history()
    {:noreply, socket}
  end

  def handle_event("ph-go", %{"page" => page_str}, socket) do
    page =
      case Integer.parse(page_str) do
        {p, _} -> p
        :error -> socket.assigns.payment_history_page
      end

    page =
      page
      |> max(1)
      |> min(socket.assigns.payment_history_total_pages)

    socket = socket |> assign(:payment_history_page, page) |> paginate_payment_history()
    {:noreply, socket}
  end

  def handle_event("view-payment-details", %{"payment_id" => payment_id}, socket) do
    # Try to find in the full list first, fall back to current page items
    payment =
      find_payment_by_id(payment_id, socket.assigns.payment_history_all) ||
        find_payment_by_id(payment_id, socket.assigns.payment_history_items)

    if payment do
      socket =
        socket
        |> assign(:selected_payment, payment)
        |> assign(:show_payment_modal, true)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Payment not found")}
    end
  end

  def handle_event("close-payment-modal", _params, socket) do
    socket =
      socket
      |> assign(:selected_payment, nil)
      |> assign(:show_payment_modal, false)

    {:noreply, socket}
  end

  def handle_event("view-booking", %{"booking_id" => booking_id}, socket) do


    # Find the booking in the @bookings list
    booking = Enum.find(socket.assigns.bookings, fn b ->
      to_string(b.id) == to_string(booking_id)
    end)

    if booking do
      installments = calculate_installment_breakdown_dynamic(booking.total_amount, booking.paid_amount || 0, booking.departure_date)
      socket =
        socket
        |> assign(:selected_booking, booking)
        |> assign(:show_booking_modal, false)
        |> assign(:show_booking_plan, true)
        |> assign(:installments_all, installments)
        |> assign(:installments_page, 1)
        |> assign(:installments_total_pages, calculate_total_pages(installments, socket.assigns.installments_per_page))
        |> paginate_installments()

      {:noreply, socket}
    else
      # Enhanced error message with debugging info
      socket = put_flash(socket, :error, "Booking not found. ID: #{booking_id}, Available IDs: #{Enum.map(socket.assigns.bookings, & &1.id) |> inspect}")
      {:noreply, socket}
    end
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
    {:ok, file_path, filename} = download_receipt(receipt_id, socket.assigns.current_user)
    socket = push_event(socket, "receipt_download_ready", %{
      file_path: file_path,
      filename: filename
    })
    {:noreply, socket}
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
          socket,
          socket.assigns.current_user
        ) do
          {:ok, %{redirect_to: payment_url}} ->
            # For online payments, redirect to payment gateway
            socket =
              socket
              |> put_flash(:info, "Redirecting to payment gateway...")
              |> assign(:show_installment_payment_modal, false)
              |> assign(:selected_installment, nil)
              |> assign(:selected_payment_method, "")

            {:noreply, redirect(socket, external: payment_url)}

          {:ok, _payment} ->
            # For offline payments, show success message
            socket =
              socket
              |> put_flash(:info, "Installment payment submitted successfully! We will verify your payment and update your account.")
              |> assign(:show_installment_payment_modal, false)
              |> assign(:selected_installment, nil)
              |> assign(:selected_payment_method, "")
              |> load_data()

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

  # --- Receipts Pagination Events ---
  def handle_event("rcp-first", _params, socket) do
    socket = socket |> assign(:receipts_page, 1) |> paginate_receipts()
    {:noreply, socket}
  end

  def handle_event("rcp-prev", _params, socket) do
    page = max(1, socket.assigns.receipts_page - 1)
    socket = socket |> assign(:receipts_page, page) |> paginate_receipts()
    {:noreply, socket}
  end

  def handle_event("rcp-next", _params, socket) do
    page = min(socket.assigns.receipts_total_pages, socket.assigns.receipts_page + 1)
    socket = socket |> assign(:receipts_page, page) |> paginate_receipts()
    {:noreply, socket}
  end

  def handle_event("rcp-last", _params, socket) do
    last = socket.assigns.receipts_total_pages
    socket = socket |> assign(:receipts_page, last) |> paginate_receipts()
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
    |> assign(:payment_history_all, payment_history)
    |> assign(:receipts_all, receipts)
    |> assign(:receipts_total_pages, calculate_total_pages(receipts, socket.assigns.receipts_per_page))
    |> assign(:receipts_page, 1)
    |> assign(:payment_history_total_pages, calculate_total_pages(payment_history, socket.assigns.payment_history_per_page))
    |> assign(:payment_history_page, 1)
    |> paginate_payment_history()
    |> paginate_receipts()
  end

  defp build_installment_bookings(user_id) do
    Bookings.get_booking_flow_progress_by_user_id(user_id)
    |> Enum.filter(fn progress -> progress.payment_plan == "installment" end)
    |> Enum.map(fn progress ->
      latest_booking =
        Bookings.get_latest_booking_for_user_schedule(user_id, progress.package_schedule_id)

      schedule = safe_get_schedule(progress.package_schedule_id)

      # Always use the latest booking ID, or create a consistent identifier
      booking_id = if latest_booking, do: latest_booking.id, else: progress.id

      %{
        id: booking_id,  # This will always be the same type
        booking_id: latest_booking && latest_booking.id,  # Keep original booking ID separate
        progress_id: progress.id,  # Keep original progress ID separate
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

  defp load_payment_history(user_id) do
    # Use existing booking data as payment history entries until a dedicated payments table exists
    Bookings.list_user_bookings_with_payments(user_id)
    |> Enum.map(fn booking ->
      paid_amount = booking.paid_amount || Decimal.new(0)

      # Determine status for display
      status =
        case booking.status do
          s when s in ["confirmed", "completed"] -> "completed"
          _ -> "pending"
        end

      # Compose a pseudo transaction id for traceability
      transaction_id = "BOOKING-" <> to_string(booking.id)

      # Fees are not tracked yet; default to 0 and net = amount
      fees = Decimal.new(0)

      %{
        id: to_string(booking.id),
        date: booking.booking_date || Date.utc_today(),
        amount: paid_amount,
        status: status,
        method: booking.payment_method || "unknown",
        booking_reference: booking.booking_reference,
        transaction_id: transaction_id,
        description: booking.package_name,
        fees: fees,
        net_amount: Decimal.sub(paid_amount, fees)
      }
    end)
    |> Enum.sort_by(& &1.date, {:desc, Date})
  end

  # --- Payment History Pagination Helpers ---
  defp calculate_total_pages(list, per_page) when is_list(list) and is_integer(per_page) and per_page > 0 do
    total = length(list)
    case total do
      0 -> 1
      _ -> div(total + per_page - 1, per_page)
    end
  end

  defp paginate_payment_history(socket) do
    list = socket.assigns.payment_history_all
    per_page = socket.assigns.payment_history_per_page
    total_pages = calculate_total_pages(list, per_page)
    page = socket.assigns.payment_history_page |> max(1) |> min(total_pages)

    start_index = (page - 1) * per_page
    items = list |> Enum.drop(start_index) |> Enum.take(per_page)

    socket
    |> assign(:payment_history_total_pages, total_pages)
    |> assign(:payment_history_page, page)
    |> assign(:payment_history_items, items)
  end

  defp find_payment_by_id(payment_id, payment_history) do
    Enum.find(payment_history, fn payment -> payment.id == payment_id end)
  end

  defp load_receipts(user_id) do
    # Build receipts list from actual bookings with payment info
    Bookings.list_user_bookings_with_payments(user_id)
    |> Enum.map(fn booking ->
      %{
        id: to_string(booking.id),
        date: booking.booking_date || Date.utc_today(),
        amount: booking.paid_amount || Decimal.new(0),
        booking_reference: booking.booking_reference,
        file_path: "/receipts/#{booking.id}/download"
      }
    end)
    |> Enum.sort_by(& &1.date, {:desc, Date})
  end

  defp process_payment(_booking_id, _amount, _user) do
    # This would integrate with actual payment gateway
    # For now, simulating success
    {:ok, %{id: "payment_#{:rand.uniform(1000)}", status: "completed"}}
  end

  defp download_receipt(receipt_id, _user) do
    # Build real download path and a friendly filename; controller enforces access and streams file
    path = "/receipts/#{receipt_id}/download"
    filename = "receipt_#{Date.utc_today()}.txt"
    {:ok, path, filename}
  end

  defp process_installment_payment(booking_id, installment_number, amount, payment_method, socket, user) do
    booking = Bookings.get_booking!(booking_id)
    |> Repo.preload([:package_schedule, package_schedule: :package])

    # Check if this is an online payment method that requires gateway redirect
    requires_online_payment = payment_method in ["toyyibpay"]

    if requires_online_payment do
      # For online payments, generate payment gateway URL
      payment_url = generate_installment_payment_url(booking, installment_number, amount, payment_method, socket.assigns.current_user)

      # Log the payment attempt
      Umrahly.ActivityLogs.log_user_action(
        user.id,
        "Installment Payment Initiated",
        "Payment #{installment_number} for booking #{booking_id}",
        %{
          booking_id: booking_id,
          installment_number: installment_number,
          amount: amount,
          payment_method: payment_method,
          payment_url: payment_url
        }
      )

      {:ok, %{redirect_to: payment_url}}
    else
      # For offline payments, handle file uploads and create a pending payment record
      file_paths = save_uploaded_files(socket, booking_id, installment_number)

      # Persist proof and update payment progress on the booking record
      booking = Bookings.get_booking!(booking_id)

      current_paid = ensure_decimal(booking.deposit_amount)
      incoming_amount = ensure_decimal(amount)
      new_paid = Decimal.add(current_paid, incoming_amount) |> Decimal.round(2)

      update_attrs = %{
        deposit_amount: new_paid,
        payment_method: payment_method,
        payment_proof_file: List.first(file_paths),
        payment_proof_status: "submitted",
        payment_proof_submitted_at: DateTime.utc_now()
      }

      {:ok, _updated_booking} = Bookings.update_booking_payment_with_proof(booking, update_attrs)

      # Create a payment record with pending status (for future use / audit trail)
      payment_attrs = %{
        booking_id: booking_id,
        installment_number: installment_number,
        amount: Decimal.new(amount),
        payment_method: payment_method,
        status: "pending_verification",
        payment_proof_files: file_paths,
        submitted_at: DateTime.utc_now()
      }

      # For now, log the activity and notify
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

  defp save_uploaded_files(socket, booking_id, installment_number) do
    # Consume entries and copy to static uploads dir; return list of relative URLs
    consume_uploaded_entries(socket, :payment_proof, fn %{path: path, client_name: client_name}, _entry ->
      upload_dir = Path.join([
        "priv/static/uploads/payment_proof",
        to_string(booking_id),
        "installment_#{installment_number}"
      ])

      File.mkdir_p!(upload_dir)

      timestamp = DateTime.utc_now() |> DateTime.to_unix()
      filename = "#{timestamp}_#{client_name}"
      file_path = Path.join(upload_dir, filename)

      File.cp!(path, file_path)

      rel = "/uploads/payment_proof/#{booking_id}/installment_#{installment_number}/#{filename}"
      {:ok, rel}
    end)
    |> Enum.map(fn
      {:ok, rel} -> rel
      other -> other
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


  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:too_many_files), do: "Too many files (max 5)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"

  defp generate_installment_payment_url(booking, installment_number, amount, payment_method, user) do
    config = Application.get_env(:umrahly, :payment_gateway)

     # Get package and schedule information
     package = booking.package_schedule.package
     schedule = booking.package_schedule

    # Create installment payment context similar to booking context
    installment_assigns = %{
      payment_method: payment_method,
      deposit_amount: amount,
      current_user: user,
      booking: booking,
      installment_number: installment_number,
      package: package,
      schedule: schedule,
      number_of_persons: booking.number_of_persons
    }

    case payment_method do
      "toyyibpay" ->
        generate_toyyibpay_installment_payment_url(booking, installment_assigns, config[:toyyibpay])
      _ ->
        generate_generic_installment_payment_url(booking, installment_assigns, config[:generic])
    end
  end

  defp generate_toyyibpay_installment_payment_url(booking, assigns, _toyyibpay_config) do
    case Umrahly.ToyyibPay.create_bill(booking, assigns) do
      {:ok, %{payment_url: payment_url}} ->
        payment_url
      {:error, reason} ->
        # Log error and fallback to demo URL
        require Logger
        Logger.error("ToyyibPay installment payment bill creation failed: #{inspect(reason)}")
        "https://dev.toyyibpay.com"
    end
  end

  defp generate_generic_installment_payment_url(booking, assigns, _generic_config) do
    base_url = "https://demo-generic-gateway.com"

    booking_id_str = case booking do
      %{id: id} when is_integer(id) -> Integer.to_string(id)
      %{id: id} when is_binary(id) -> id
      _ -> "demo"
    end

    id_suffix = if String.length(booking_id_str) >= 8 do
      String.slice(booking_id_str, -8..-1)
    else
      String.pad_leading(booking_id_str, 8, "0")
    end

    installment_suffix = String.pad_leading(Integer.to_string(assigns.installment_number), 2, "0")
    payment_id = "INST-#{id_suffix}-#{installment_suffix}-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :upper)}"

    "#{base_url}/pay/#{payment_id}"
  end


  defp paginate_installments(socket) do
    list = socket.assigns.installments_all
    per_page = socket.assigns.installments_per_page
    total_pages = calculate_total_pages(list, per_page)
    page = socket.assigns.installments_page |> max(1) |> min(total_pages)

    start_index = (page - 1) * per_page
    items = list |> Enum.drop(start_index) |> Enum.take(per_page)

    socket
    |> assign(:installments_total_pages, total_pages)
    |> assign(:installments_page, page)
    |> assign(:installments_items, items)
  end

  defp paginate_receipts(socket) do
    list = socket.assigns.receipts_all
    per_page = socket.assigns.receipts_per_page
    total_pages = calculate_total_pages(list, per_page)
    page = socket.assigns.receipts_page |> max(1) |> min(total_pages)

    start_index = (page - 1) * per_page
    items = list |> Enum.drop(start_index) |> Enum.take(per_page)

    socket
    |> assign(:receipts_total_pages, total_pages)
    |> assign(:receipts_page, page)
    |> assign(:receipts_items, items)
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
              class={"px-3 py-2 rounded-md text-sm font-medium #{if @current_tab == "installment", do: "bg-blue-100 text-blue-700", else: "text-gray-600 hover:bg-gray-50 hover:text-gray-900"}"}
            >
              Installment Payment
            </button>
            <button
              phx-click="switch-tab"
              phx-value-tab="history"
              class={"px-3 py-2 rounded-md text-sm font-medium #{if @current_tab == "history", do: "bg-blue-100 text-blue-700", else: "text-gray-600 hover:bg-gray-50 hover:text-gray-900"}"}
            >
              Payment History
            </button>
            <button
              phx-click="switch-tab"
              phx-value-tab="receipts"
              class={"px-3 py-2 rounded-md text-sm font-medium #{if @current_tab == "receipts", do: "bg-blue-100 text-blue-700", else: "text-gray-600 hover:bg-gray-50 hover:text-gray-900"}"}
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
                            <%= for installment <- @installments_items do %>
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
                                      phx-value-booking_id={@selected_booking.booking_id || @selected_booking.id}
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
                        <div class="flex items-center justify-between px-4 py-3 bg-white border-t border-gray-200">
                          <div class="text-sm text-gray-700">
                            Page <span class="font-medium"><%= @installments_page %></span> of <span class="font-medium"><%= @installments_total_pages %></span>
                          </div>
                          <div class="space-x-2">
                            <button
                              phx-click="inst-first"
                              class={"px-3 py-1.5 border text-sm rounded-md " <> if(@installments_page == 1, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                              disabled={@installments_page == 1}
                            >
                              First
                            </button>
                            <button
                              phx-click="inst-prev"
                              class={"px-3 py-1.5 border text-sm rounded-md " <> if(@installments_page == 1, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                              disabled={@installments_page == 1}
                            >
                              Prev
                            </button>
                            <button
                              phx-click="inst-next"
                              class={"px-3 py-1.5 border text-sm rounded-md " <> if(@installments_page == @installments_total_pages, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                              disabled={@installments_page == @installments_total_pages}
                            >
                              Next
                            </button>
                            <button
                              phx-click="inst-last"
                              class={"px-3 py-1.5 border text-sm rounded-md " <> if(@installments_page == @installments_total_pages, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                              disabled={@installments_page == @installments_total_pages}
                            >
                              Last
                            </button>
                          </div>
                        </div>
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
                                  <%= UmrahlyWeb.Timezone.format_local(booking.booking_date, "%b %d, %Y") %>
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

                <%= if Enum.empty?(@payment_history_all) do %>
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
                        <%= for payment <- @payment_history_items do %>
                          <tr>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              <%= UmrahlyWeb.Timezone.format_local(payment.date, "%B %d, %Y") %>
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
                    <div class="flex items-center justify-between px-4 py-3 bg-white border-t border-gray-200">
                      <div class="text-sm text-gray-700">
                        Page <span class="font-medium"><%= @payment_history_page %></span> of <span class="font-medium"><%= @payment_history_total_pages %></span>
                      </div>
                      <div class="space-x-2">
                        <button
                          phx-click="ph-first"
                          class={"px-3 py-1.5 border text-sm rounded-md " <> if(@payment_history_page == 1, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                          disabled={@payment_history_page == 1}
                        >
                          First
                        </button>
                        <button
                          phx-click="ph-prev"
                          class={"px-3 py-1.5 border text-sm rounded-md " <> if(@payment_history_page == 1, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                          disabled={@payment_history_page == 1}
                        >
                          Prev
                        </button>
                        <button
                          phx-click="ph-next"
                          class={"px-3 py-1.5 border text-sm rounded-md " <> if(@payment_history_page == @payment_history_total_pages, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                          disabled={@payment_history_page == @payment_history_total_pages}
                        >
                          Next
                        </button>
                        <button
                          phx-click="ph-last"
                          class={"px-3 py-1.5 border text-sm rounded-md " <> if(@payment_history_page == @payment_history_total_pages, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                          disabled={@payment_history_page == @payment_history_total_pages}
                        >
                          Last
                        </button>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>

            <% "receipts" -> %>
              <!-- Receipts Tab -->
              <div class="p-6">
                <h2 class="text-xl font-semibold text-gray-900 mb-6">Receipts</h2>

                <%= if Enum.empty?(@receipts_items) do %>
                  <div class="text-center py-12">
                    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                    <h3 class="mt-2 text-sm font-medium text-gray-900">No receipts available</h3>
                    <p class="mt-1 text-sm text-gray-500">Receipts will appear here after you make payments.</p>
                  </div>
                <% else %>
                  <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
                    <table class="min-w-full divide-y divide-gray-300">
                      <thead class="bg-gray-50">
                        <tr>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Amount (RM)</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Reference</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                        </tr>
                      </thead>
                      <tbody class="bg-white divide-y divide-gray-200">
                        <%= for receipt <- @receipts_items do %>
                          <tr>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              <%= UmrahlyWeb.Timezone.format_local(receipt.date, "%B %d, %Y") %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                              <%= format_amount(receipt.amount) %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              <%= receipt.booking_reference %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm">
                              <a
                                href={~p"/receipts/#{receipt.id}/view"}
                                target="_blank"
                                class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                              >
                                <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553 2.276A1 1 0 0120 13.191V18a2 2 0 01-2 2H6a2 2 0 01-2-2v-4.809a1 1 0 01.447-.915L9 10m6 0V6a3 3 0 10-6 0v4"/>
                                </svg>
                                View
                              </a>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                  <div class="flex items-center justify-between px-4 py-3 bg-white border-t border-gray-200 mt-4 rounded-md">
                    <div class="text-sm text-gray-700">
                      Page <span class="font-medium"><%= @receipts_page %></span> of <span class="font-medium"><%= @receipts_total_pages %></span>
                    </div>
                    <div class="space-x-2">
                      <button
                        phx-click="rcp-first"
                        class={"px-3 py-1.5 border text-sm rounded-md " <> if(@receipts_page == 1, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                        disabled={@receipts_page == 1}
                      >
                        First
                      </button>
                      <button
                        phx-click="rcp-prev"
                        class={"px-3 py-1.5 border text-sm rounded-md " <> if(@receipts_page == 1, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                        disabled={@receipts_page == 1}
                      >
                        Prev
                      </button>
                      <button
                        phx-click="rcp-next"
                        class={"px-3 py-1.5 border text-sm rounded-md " <> if(@receipts_page == @receipts_total_pages, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                        disabled={@receipts_page == @receipts_total_pages}
                      >
                        Next
                      </button>
                      <button
                        phx-click="rcp-last"
                        class={"px-3 py-1.5 border text-sm rounded-md " <> if(@receipts_page == @receipts_total_pages, do: "text-gray-400 border-gray-200 cursor-not-allowed", else: "text-gray-700 border-gray-300 hover:bg-gray-50")}
                        disabled={@receipts_page == @receipts_total_pages}
                      >
                        Last
                      </button>
                    </div>
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
                    <span class="text-sm text-gray-900"><%= UmrahlyWeb.Timezone.format_local(@selected_payment.date, "%B %d, %Y") %></span>
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
                          <%= for installment <- @installments_items do %>
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
                                <%= UmrahlyWeb.Timezone.format_local(installment.due_date, "%B %d, %Y") %>
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
                        <%= UmrahlyWeb.Timezone.format_local(@selected_booking.booking_date, "%B %d, %Y") %>
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

              <form phx-change="update_payment_method">
                <div class="mb-6">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Select Payment Method
                  </label>
                  <select
                    name="payment_method"
                    class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    value={@selected_payment_method}
                  >
                    <option value="">Choose payment method</option>
                    <option value="toyyibpay">ToyyibPay (FPX & Credit Card)</option>
                    <option value="bank_transfer">Bank Transfer</option>
                    <option value="cash">Cash</option>
                  </select>
                </div>
              </form>

              <!-- File Upload Section (only for offline payment methods) -->
              <%= if @selected_payment_method in ["bank_transfer", "cash"] do %>
                <div class="mb-6">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Upload Transaction Proof
                  </label>
                  <form phx-change="validate">
                    <div class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md phx-drop-target">
                      <div class="space-y-1 text-center">
                        <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                          <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                        </svg>
                        <div class="flex flex-col items-center gap-2 text-sm text-gray-600">
                          <.live_file_input upload={@uploads.payment_proof} id="payment_proof" class="px-3 py-2 border rounded cursor-pointer text-blue-600 hover:text-blue-700" />
                          <p class="text-xs text-gray-500">or drag and drop</p>
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
                  </form>
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
end
