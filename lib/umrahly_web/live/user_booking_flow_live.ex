defmodule UmrahlyWeb.UserBookingFlowLive do
  @moduledoc """
  LiveView for handling the user booking flow.

  ## Payment Gateway Integration

  This module includes placeholder implementations for payment gateway integration.
  To complete the integration, you need to:

  1. **Stripe Integration** (for credit card payments):
     - Install Stripe library: `mix deps.get stripe`
     - Set environment variables: STRIPE_PUBLISHABLE_KEY, STRIPE_SECRET_KEY
     - Replace `generate_stripe_payment_url/3` with actual Stripe Checkout Session creation

  2. **PayPal Integration** (for online banking/FPX):
     - Install PayPal library: `mix deps.get pay`
     - Set environment variables: PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET
     - Replace `generate_paypal_payment_url/3` with actual PayPal payment creation

  3. **E-Wallet Integration** (for Boost, Touch 'n Go):
     - Implement integration with respective e-wallet APIs
     - Update `generate_payment_gateway_url/2` to handle e-wallet payments

  4. **Bank Transfer & Cash**:
     - These are handled as offline payment methods
     - No immediate redirection required

  ## Environment Variables Required

  ```bash
  # Stripe
  export STRIPE_PUBLISHABLE_KEY=pk_test_...
  export STRIPE_SECRET_KEY=sk_test_...
  export STRIPE_WEBHOOK_SECRET=whsec_...

  # PayPal
  export PAYPAL_CLIENT_ID=client_id_...
  export PAYPAL_CLIENT_SECRET=client_secret_...
  export PAYPAL_MODE=sandbox  # or live

  # Generic Payment Gateway
  export PAYMENT_GATEWAY_URL=https://your-gateway.com
  export PAYMENT_MERCHANT_ID=your_merchant_id
  export PAYMENT_API_KEY=your_api_key
  ```
  """

  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings
  alias Umrahly.Bookings.Booking
  alias Umrahly.Packages

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}



  def mount(%{"package_id" => package_id, "schedule_id" => schedule_id}, _session, socket) do
    # Get package and schedule details
    user_id = socket.assigns.current_user.id
    package = Packages.get_package!(package_id)
    schedule = Packages.get_package_schedule!(schedule_id)

    # Helper function to check if price override should be shown
    has_price_override = schedule.price_override && Decimal.gt?(schedule.price_override, Decimal.new(0))

    #find or create booking flow progress
    progress = Bookings.get_or_create_booking_flow_progress(user_id, package_id, schedule_id)

    # Verify the schedule belongs to the package
    if schedule.package_id != String.to_integer(package_id) do
      {:noreply,
       socket
       |> put_flash(:error, "Invalid package schedule selected")
       |> push_navigate(to: ~p"/packages/#{package_id}")}
    else
      # Calculate total amount based on number of persons and schedule price
      base_price = package.price
      override_price = if schedule.price_override, do: Decimal.to_integer(schedule.price_override), else: 0
      schedule_price_per_person = base_price + override_price

      total_amount = Decimal.mult(Decimal.new(schedule_price_per_person), Decimal.new(1))

      # Create initial booking changeset
      changeset = Bookings.change_booking(%Booking{})

      # Initialize travelers based on number_of_persons and existing data
      travelers = cond do
        socket.assigns[:travelers] ->
          socket.assigns.travelers
        progress.travelers_data && length(progress.travelers_data) >= progress.number_of_persons ->
          # Use existing travelers data if it has enough entries
          progress.travelers_data
        progress.is_booking_for_self ->
          # Create travelers list based on number_of_persons
          Enum.map(1..progress.number_of_persons, fn index ->
            if index == 1 do
              # First traveler - pre-fill with user details if booking for self
              %{
                full_name: socket.assigns.current_user.full_name || "",
                identity_card_number: socket.assigns.current_user.identity_card_number || "",
                passport_number: "",
                phone: socket.assigns.current_user.phone_number || ""
              }
            else
              # Additional travelers - empty fields
              %{full_name: "", identity_card_number: "", passport_number: "", phone: ""}
            end
          end)
        true ->
          # Create empty travelers list based on number_of_persons
          Enum.map(1..progress.number_of_persons, fn _ ->
            %{full_name: "", identity_card_number: "", passport_number: "", phone: ""}
          end)
        end

      socket =
        socket
        |> assign(:package, package)
        |> assign(:schedule, schedule)
        |> assign(:has_price_override, has_price_override)
        |> assign(:price_per_person, schedule_price_per_person)
        |> assign(:total_amount, total_amount)
        |> assign(:payment_plan, "progress.payment_plan")
        |> assign(:deposit_amount, total_amount)
        |> assign(:number_of_persons, progress.number_of_persons)
        |> assign(:travelers, travelers)
        |> assign(:is_booking_for_self, progress.is_booking_for_self)
        |> assign(:payment_method, progress.payment_method)
        |> assign(:notes, progress.notes)
        |> assign(:changeset, changeset)
        |> assign(:current_page, "packages")
        |> assign(:page_title, "Book Package")
        |> assign(:current_step, progress.current_step)
        |> assign(:max_steps, progress.max_steps)
        |> assign(:requires_online_payment, false)
        |> assign(:payment_gateway_url, nil)
        |> assign(:payment_proof_file, nil)
        |> assign(:payment_proof_notes, "")
        |> assign(:show_payment_proof_form, false)
        |> assign(:saved_package_progress, nil)
        |> assign(:saved_travelers_progress, nil)
        |> assign(:saved_payment_progress, nil)
        |> assign(:current_step, progress.current_step)
        |> assign(:max_steps, progress.max_steps)
        |> assign(:booking_flow_progress, progress)
        |> allow_upload(:payment_proof, accept: ~w(.pdf .jpg .jpeg .png .doc .docx), max_entries: 1, max_file_size: 5_000_000)

      {:ok, socket}
    end
  end

  # All handle_event functions grouped together
  def handle_event("validate_booking", %{"booking" => booking_params}, socket) do
    # Update local assigns for real-time validation
    number_of_persons = String.to_integer(booking_params["number_of_persons"] || "1")
    payment_plan = booking_params["payment_plan"] || "full_payment"

    # Handle travelers data and sync with number of persons
    travelers = case booking_params["travelers"] do
      nil ->
        # If no travelers data in form, use existing travelers from socket
        socket.assigns.travelers
      travelers_params ->
        # If number of persons increased, add new travelers
        current_count = length(travelers_params)
        if number_of_persons > current_count do
          additional_travelers = Enum.map((current_count + 1)..number_of_persons, fn _ ->
            %{full_name: "", identity_card_number: "", passport_number: "", phone: ""}
          end)
          Enum.map(travelers_params, fn traveler ->
            %{
              full_name: traveler["full_name"] || "",
              identity_card_number: traveler["identity_card_number"] || "",
              passport_number: traveler["passport_number"] || "",
              phone: traveler["phone"] || ""
            }
          end) ++ additional_travelers
        else
          # If number of persons decreased, truncate the list
          Enum.take(Enum.map(travelers_params, fn traveler ->
            %{
              full_name: traveler["full_name"] || "",
              identity_card_number: traveler["identity_card_number"] || "",
              passport_number: traveler["passport_number"] || "",
              phone: traveler["phone"] || ""
            }
          end), number_of_persons)
        end
    end

    # Calculate amounts
    package_price = socket.assigns.package.price
    base_price = package_price
    override_price = if socket.assigns.schedule.price_override, do: Decimal.to_integer(socket.assigns.schedule.price_override), else: 0
    schedule_price_per_person = base_price + override_price

    total_amount = Decimal.mult(Decimal.new(schedule_price_per_person), Decimal.new(number_of_persons))

        deposit_amount = case payment_plan do
      "full_payment" -> total_amount
      "installment" ->
        deposit_input = booking_params["deposit_amount"] || "0"
        # Try to parse the deposit amount, default to 20% of total if parsing fails (same as package details)
        try do
          Decimal.new(deposit_input)
        rescue
          _ -> Decimal.mult(total_amount, Decimal.new("0.2"))
        end
    end

    # Create changeset for validation
    attrs = %{
      total_amount: total_amount,
      deposit_amount: deposit_amount,
      number_of_persons: number_of_persons,
      payment_method: booking_params["payment_method"],
      payment_plan: payment_plan,
      notes: booking_params["notes"] || "",
      user_id: socket.assigns.current_user.id,
      package_schedule_id: socket.assigns.schedule.id,
      status: "pending",
      booking_date: Date.utc_today()
    }

    changeset =
      %Booking{}
      |> Bookings.change_booking(attrs)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:total_amount, total_amount)
      |> assign(:deposit_amount, deposit_amount)
      |> assign(:number_of_persons, number_of_persons)
      |> assign(:travelers, travelers)
      |> assign(:payment_method, booking_params["payment_method"])
      |> assign(:payment_plan, payment_plan)
      |> assign(:notes, booking_params["notes"] || "")
      |> assign(:changeset, changeset)

    {:noreply, socket}
  end


  def handle_event("toggle_booking_for_self", _params, socket) do
    current_is_booking_for_self = socket.assigns.is_booking_for_self

    # Toggle the value
    new_is_booking_for_self = !current_is_booking_for_self

    # Update travelers based on the toggle
    travelers = if new_is_booking_for_self do
      # Booking for self - pre-fill with user details
      [%{
        full_name: socket.assigns.current_user.full_name || "",
        identity_card_number: socket.assigns.current_user.identity_card_number || "",
        passport_number: "",
        phone: socket.assigns.current_user.phone_number || ""
      }]
    else
      # Booking for someone else - empty fields
      [%{
        full_name: "",
        identity_card_number: "",
        passport_number: "",
        phone: ""
      }]
    end

    socket =
      socket
      |> assign(:is_booking_for_self, new_is_booking_for_self)
      |> assign(:travelers, travelers)

    {:noreply, socket}
  end

    def handle_event("update_number_of_persons", %{"action" => "increase"}, socket) do
    current_number = socket.assigns.number_of_persons
    new_number = min(current_number + 1, 10)

    # Preserve existing travelers data and add new ones
    existing_travelers = socket.assigns.travelers
    travelers = if new_number > current_number do
      # Add new travelers while preserving existing data
      additional_travelers = Enum.map((current_number + 1)..new_number, fn _index ->
        %{full_name: "", identity_card_number: "", passport_number: "", phone: ""}
      end)

      # Merge existing travelers with new ones
      new_travelers = existing_travelers ++ additional_travelers

      # Debug logging
      IO.puts("INCREASE: current_number=#{current_number}, new_number=#{new_number}")
      IO.puts("INCREASE: existing_travelers count=#{length(existing_travelers)}")
      IO.puts("INCREASE: new_travelers count=#{length(new_travelers)}")

      new_travelers
    else
      existing_travelers
    end

    # Calculate new amounts
    package_price = socket.assigns.package.price
    base_price = package_price
    override_price = if socket.assigns.schedule.price_override, do: Decimal.to_integer(socket.assigns.schedule.price_override), else: 0
    schedule_price_per_person = base_price + override_price

    total_amount = Decimal.mult(Decimal.new(schedule_price_per_person), Decimal.new(new_number))

    # Update deposit amount if payment plan is installment
    deposit_amount = if socket.assigns.payment_plan == "installment" do
      Decimal.mult(total_amount, Decimal.new("0.2"))
    else
      total_amount
    end

    socket =
      socket
      |> assign(:number_of_persons, new_number)
      |> assign(:travelers, travelers)
      |> assign(:total_amount, total_amount)
      |> assign(:deposit_amount, deposit_amount)

    {:noreply, socket}
  end

  def handle_event("update_number_of_persons", %{"action" => "decrease"}, socket) do
    current_number = socket.assigns.number_of_persons
    new_number = max(current_number - 1, 1)

    # Preserve existing travelers data when decreasing
    existing_travelers = socket.assigns.travelers
    travelers = if new_number < current_number do
      # Take only the first N travelers, preserving their data
      Enum.take(existing_travelers, new_number)
    else
      existing_travelers
    end

    # Calculate new amounts
    package_price = socket.assigns.package.price
    base_price = package_price
    override_price = if socket.assigns.schedule.price_override, do: Decimal.to_integer(socket.assigns.schedule.price_override), else: 0
    schedule_price_per_person = base_price + override_price

    total_amount = Decimal.mult(Decimal.new(schedule_price_per_person), Decimal.new(new_number))

    # Update deposit amount if payment plan is installment
    deposit_amount = if socket.assigns.payment_plan == "installment" do
      Decimal.mult(total_amount, Decimal.new("0.2"))
    else
      total_amount
    end

    socket =
      socket
      |> assign(:number_of_persons, new_number)
      |> assign(:travelers, travelers)
      |> assign(:total_amount, total_amount)
      |> assign(:deposit_amount, deposit_amount)

    {:noreply, socket}
  end

  def handle_event("update_payment_plan", %{"payment_plan" => payment_plan}, socket) do
    deposit_amount = case payment_plan do
      "full_payment" -> socket.assigns.total_amount
      "installment" ->
        # Default to 20% of total for installment (same as package details)
        Decimal.mult(socket.assigns.total_amount, Decimal.new("0.2"))
    end

    socket =
      socket
      |> assign(:payment_plan, payment_plan)
      |> assign(:deposit_amount, deposit_amount)

    {:noreply, socket}
  end

  def handle_event("update_payment_method", params, socket) do
    # Handle the case where payment_method might be in a nested structure
    payment_method = case params do
      %{"payment_method" => pm} -> pm
      %{"booking" => %{"payment_method" => pm}} -> pm
      _ -> socket.assigns.payment_method
    end

    # Update the payment method immediately for responsive UI
    socket = assign(socket, :payment_method, payment_method)

    # Add flash message to confirm the change
    socket = put_flash(socket, :info, "Payment method changed to #{String.replace(payment_method, "_", " ") |> String.capitalize()}")

    {:noreply, socket}
  end

  def handle_event("update_notes", %{"booking" => %{"notes" => notes}}, socket) do
    socket = assign(socket, :notes, notes)

    {:noreply, socket}
  end

  def handle_event("submit_payment_proof", %{"payment_proof_notes" => notes} = _params, socket) do
    handle_payment_proof_submission(notes, socket)
  end

  # Fallback handler for submit_payment_proof
  def handle_event("submit_payment_proof", params, socket) do
    # Check if we have a file but no notes
    if Map.has_key?(params, "payment_proof_notes") do
      # Handle the case where notes might be empty string
      notes = params["payment_proof_notes"] || ""
      handle_payment_proof_submission(notes, socket)
    else
      socket = put_flash(socket, :error, "Invalid form submission. Please try again.")
      {:noreply, socket}
    end
  end

  def handle_event("toggle_payment_proof_form", _params, socket) do
    show_form = !socket.assigns.show_payment_proof_form
    socket = assign(socket, :show_payment_proof_form, show_form)
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :payment_proof, ref)}
  end



  def handle_event("save_progress_async", %{"value" => %{"step" => _step_str}}, socket) do
    {:noreply, socket}
  end

  def handle_event("save_progress_async", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("refresh_progress", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("page_visible", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cross_tab_sync", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("sync_progress", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save_and_navigate", %{"url" => url}, socket) do
    {:noreply, push_navigate(socket, to: url)}
  end

  def handle_event("page_refresh", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("page_loaded", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_deposit_amount", %{"booking" => %{"deposit_amount" => deposit_amount_str}}, socket) do
    try do
      deposit_amount = Decimal.new(deposit_amount_str)
      socket = assign(socket, :deposit_amount, deposit_amount)

      {:noreply, socket}
    rescue
      _ ->
        {:noreply, socket}
    end
  end

    def handle_event("update_traveler", %{"index" => index_str, "field" => field, "value" => value}, socket) do
    index = String.to_integer(index_str)
    travelers = socket.assigns.travelers

    # Convert field to atom for consistency
    field_atom = String.to_atom(field)

    updated_travelers = List.update_at(travelers, index, fn traveler ->
      # Store only with atom keys for consistency
      Map.put(traveler, field_atom, value)
    end)

    socket = assign(socket, :travelers, updated_travelers)

    {:noreply, socket}
  end

      # Handle form submission for travelers step (kept for backward compatibility)
  def handle_event("validate_travelers", %{"booking" => booking_params}, socket) do
    # Extract travelers data from the form
    travelers_params = booking_params["travelers"] || []

    # Update travelers with form data
    updated_travelers =
      Enum.with_index(travelers_params)
      |> Enum.map(fn {traveler, idx} ->
        existing = Enum.at(socket.assigns.travelers, idx, %{})
        Map.merge(existing, %{
          full_name: traveler["full_name"] || existing[:full_name] || "",
          identity_card_number: traveler["identity_card_number"] || existing[:identity_card_number] || "",
          passport_number: traveler["passport_number"] || existing[:passport_number] || "",
          phone: traveler["phone"] || existing[:phone] || ""
        })
      end)

    # Validate that all required traveler information is filled
    all_travelers_complete =
      Enum.all?(updated_travelers, fn traveler ->
        traveler[:full_name] != "" and
        traveler[:identity_card_number] != "" and
        traveler[:phone] != ""
      end)

    # Update booking flow progress
    {_ok, _progress} =
      Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{travelers_data: updated_travelers, last_updated: DateTime.utc_now()})

    socket =
      socket
      |> assign(:travelers, updated_travelers)
      |> (fn s ->
        if all_travelers_complete do
          put_flash(s, :info, "Traveler information validated successfully!")
        else
          put_flash(s, :error, "Please complete all required traveler information before proceeding.")
        end
      end).()

    {:noreply, socket}
  end

  # Fallback handler for validate_travelers
  def handle_event("validate_travelers", _params, socket) do
    {:noreply, socket}
  end

  # Handle individual traveler field updates
  def handle_event("update_traveler_field", %{"value" => value} = params, socket) do
    index = String.to_integer(params["index"])
    field = params["field"]
    travelers = socket.assigns.travelers

    # Convert field to atom for consistency
    field_atom = String.to_atom(field)

    updated_travelers = List.update_at(travelers, index, fn traveler ->
      # Store only with atom keys for consistency
      Map.put(traveler, field_atom, value)
    end)

    socket = assign(socket, :travelers, updated_travelers)

    {:noreply, socket}
  end

  # Handle saving travelers data
  def handle_event("save_travelers", _params, socket) do
    # Use the current travelers data from socket assigns
    travelers = socket.assigns.travelers

    # Validate that all required traveler information is filled
    all_travelers_complete =
      Enum.all?(travelers, fn traveler ->
        traveler[:full_name] != "" and
        traveler[:identity_card_number] != "" and
        traveler[:phone] != ""
      end)

    if all_travelers_complete do
      # Update booking flow progress
      {_ok, _progress} =
        Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{travelers_data: travelers, last_updated: DateTime.utc_now()})

      socket =
        socket
        |> put_flash(:info, "Traveler information saved successfully!")

      {:noreply, socket}
    else
      socket = put_flash(socket, :error, "Please complete all required traveler information before saving.")
      {:noreply, socket}
    end
  end



  # Handle clearing individual traveler fields
  def handle_event("clear_traveler_field", %{"index" => index_str, "field" => field}, socket) do
    index = String.to_integer(index_str)
    travelers = socket.assigns.travelers

    # Convert field to atom for consistency
    field_atom = String.to_atom(field)

    updated_travelers = List.update_at(travelers, index, fn traveler ->
      Map.put(traveler, field_atom, "")
    end)

    socket = assign(socket, :travelers, updated_travelers)

    {:noreply, socket}
  end

  # Handle removing a traveler (when number of persons is decreased)
  def handle_event("remove_traveler", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    travelers = socket.assigns.travelers

    if length(travelers) > 1 do
      updated_travelers = List.delete_at(travelers, index)
      new_number_of_persons = length(updated_travelers)

      # Recalculate amounts
      package_price = socket.assigns.package.price
      base_price = package_price
      override_price = if socket.assigns.schedule.price_override, do: Decimal.to_integer(socket.assigns.schedule.price_override), else: 0
      schedule_price_per_person = base_price + override_price

      total_amount = Decimal.mult(Decimal.new(schedule_price_per_person), Decimal.new(new_number_of_persons))

      # Update deposit amount if payment plan is installment
      deposit_amount = if socket.assigns.payment_plan == "installment" do
        Decimal.mult(total_amount, Decimal.new("0.2"))
      else
        total_amount
      end

      socket =
        socket
        |> assign(:travelers, updated_travelers)
        |> assign(:number_of_persons, new_number_of_persons)
        |> assign(:total_amount, total_amount)
        |> assign(:deposit_amount, deposit_amount)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end



  def handle_event("go_to_next_step", _params, socket) do
    current_step = socket.assigns.current_step
    max_steps = socket.assigns.max_steps

    # If we're at the final step (step 5), don't allow any step changes
    if current_step == max_steps do
      {:noreply, socket}
    else
      # Validate step bounds - be more defensive
      cond do
        current_step < 1 ->
          socket = assign(socket, :current_step, 1)
          {:noreply, socket}
        current_step > max_steps ->
          socket = assign(socket, :current_step, max_steps)
          {:noreply, socket}
        current_step == 2 ->
          # Validate travelers before allowing progression to step 3
          travelers = socket.assigns.travelers
          all_travelers_complete = Enum.all?(travelers, fn traveler ->
            traveler[:full_name] != "" and
            traveler[:identity_card_number] != "" and
            traveler[:phone] != ""
          end)

          if all_travelers_complete do
            new_step = current_step + 1
            # Persist to DB
            {_ok, progress} = Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{current_step: new_step})

            socket = assign(socket, :current_step, new_step)
            socket = assign(socket, :booking_flow_progress, progress)
            {:noreply, socket}
          else
            socket = put_flash(socket, :error, "Please complete all required traveler information before proceeding.")
            {:noreply, socket}
          end
        current_step < max_steps ->
          new_step = current_step + 1

          # Persist to DB
          {_ok, progress} = Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{current_step: new_step})

          # Advance the step
          socket = assign(socket, :current_step, new_step)
          socket = assign(socket, :booking_flow_progress, progress)

          {:noreply, socket}
        true ->
          {:noreply, socket}
      end
    end
  end

  def handle_event("next_step", _params, socket) do
    current_step = socket.assigns.current_step
    max_steps = socket.assigns.max_steps

    if current_step >= max_steps do
      {:noreply, socket}
    else
      new_step = current_step + 1

      {_ok, updated_progress} =
        Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{current_step: new_step, last_updated: DateTime.utc_now()})

      socket = assign(socket, :current_step, new_step)
      socket = assign(socket, :booking_flow_progress, updated_progress)

      {:noreply, socket}
    end
  end

  def handle_event("prev_step", _params, socket) do

    current_step = socket.assigns.current_step
    prev_step = max(current_step - 1, 1)

    {_ok, updated_progress} = Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{current_step: prev_step})

    socket = assign(socket, :current_step, prev_step)
    socket = assign(socket, :booking_flow_progress, updated_progress)

    {:noreply, socket}
  end

  def handle_event("create_booking", _params, socket) do
    # Validate that all required traveler information is filled
    travelers = socket.assigns.travelers

        # Check if all travelers have required fields filled
    all_travelers_complete = Enum.all?(travelers, fn traveler ->
      traveler[:full_name] != "" and
      traveler[:identity_card_number] != "" and
      traveler[:phone] != ""
    end)

    # Check if payment method is selected
    cond do
      socket.assigns.payment_method == "" or is_nil(socket.assigns.payment_method) ->
        socket =
          socket
          |> put_flash(:error, "Please select a payment method before proceeding.")

        {:noreply, socket}

      !all_travelers_complete ->
        socket =
          socket
          |> put_flash(:error, "Please complete all required traveler information before proceeding.")

        {:noreply, socket}

      true ->
        attrs = %{
          total_amount: socket.assigns.total_amount,
          deposit_amount: socket.assigns.deposit_amount,
          amount: socket.assigns.total_amount, # Set amount to match total_amount
          number_of_persons: socket.assigns.number_of_persons,
          payment_method: socket.assigns.payment_method,
          payment_plan: socket.assigns.payment_plan,
          notes: socket.assigns.notes,
          user_id: socket.assigns.current_user.id,
          package_schedule_id: socket.assigns.schedule.id,
          status: "pending",
          booking_date: Date.utc_today()
        }

        try do
          case Bookings.create_booking(attrs) do
            {:ok, booking} ->
              # Check if payment method requires immediate payment gateway redirect
              payment_method = socket.assigns.payment_method
              requires_online_payment = payment_method in ["credit_card", "online_banking", "e_wallet"]

              socket = if requires_online_payment do
                # For online payment methods, redirect to payment gateway
                payment_url = generate_payment_gateway_url(booking, socket.assigns)

                # Set the payment gateway URL - the JavaScript hook will handle the redirect
                socket
                  |> put_flash(:info, "Booking created successfully! Redirecting to payment gateway...")
                  |> assign(:current_step, 5)
                  |> assign(:payment_gateway_url, payment_url)
                  |> assign(:requires_online_payment, true)
                  |> assign(:current_booking_id, booking.id)
              else
                # For offline payment methods, show success message
                socket
                  |> put_flash(:info, "Booking created successfully! Please complete your payment offline.")
                  |> assign(:current_step, 5)
                  |> assign(:requires_online_payment, false)
                  |> assign(:current_booking_id, booking.id)
              end

              # Return the socket with step 5
              {:noreply, socket}

            {:error, %Ecto.Changeset{} = changeset} ->
              socket =
                socket
                |> put_flash(:error, "Failed to create booking. Please check the form for errors.")
                |> assign(:changeset, changeset)

              {:noreply, socket}

            {:error, error} ->
              socket =
                socket
                |> put_flash(:error, "An unexpected error occurred while creating the booking: #{inspect(error)}")

              {:noreply, socket}
          end
        rescue
          error ->
            socket =
              socket
              |> put_flash(:error, "System error occurred: #{inspect(error)}")

            {:noreply, socket}
        end
    end
  end

  # Handle async messages
  def handle_info({:save_progress_async, _step}, socket) do
    {:noreply, socket}
  end



  # Helper function to handle payment proof submission
  defp handle_payment_proof_submission(notes, socket) do

      # Check if we have a current booking ID
      case socket.assigns[:current_booking_id] do
        nil ->
          socket = put_flash(socket, :error, "No booking found. Please create a booking first.")
          {:noreply, socket}

        booking_id ->
          # Get the booking from the database
          try do
            booking = Bookings.get_booking!(booking_id)

            # Check if payment proof has already been submitted
            if booking.payment_proof_status == "submitted" do
              socket = put_flash(socket, :error, "Payment proof has already been submitted for this booking.")
              {:noreply, socket}
            else
              # Check if there are uploaded files
              if Enum.empty?(socket.assigns.uploads.payment_proof.entries) do
                socket = put_flash(socket, :error, "Please select a file to upload.")
                {:noreply, socket}
              else
                # Consume the uploaded files
                uploaded_files = consume_uploaded_entries(socket, :payment_proof, fn entry, _socket ->
                  # Create a unique filename to avoid conflicts
                  timestamp = DateTime.utc_now() |> DateTime.to_unix()
                  extension = Path.extname(entry.client_name)
                  filename = "payment_proof_#{booking_id}_#{timestamp}#{extension}"

                  # Ensure upload directory exists and save the file
                  upload_path = ensure_upload_directory()
                  file_path = Path.join(upload_path, filename)

                  # Copy the uploaded file to the destination
                  case File.cp(entry.path, file_path) do
                    :ok ->
                      {:ok, filename}
                    {:error, reason} ->
                      {:error, "Failed to save file: #{inspect(reason)}"}
                  end
                end)

                # Filter out any failed uploads
                successful_uploads = Enum.filter(uploaded_files, fn
                  {:ok, _filename} -> true
                  {:error, _reason} -> false
                end)

                if Enum.empty?(successful_uploads) do
                  socket = put_flash(socket, :error, "Failed to process uploaded file.")
                  {:noreply, socket}
                else
                  # Get the first successful upload
                  {:ok, filename} = List.first(successful_uploads)

                  # Prepare payment proof attributes
                  attrs = %{
                    "payment_proof_file" => filename,
                    "payment_proof_notes" => notes || ""
                  }

                  case Bookings.submit_payment_proof(booking, attrs) do
                    {:ok, _updated_booking} ->
                      socket =
                        socket
                        |> put_flash(:info, "Payment proof submitted successfully! File: #{filename}. Admin will review and approve your payment.")
                        |> assign(:show_payment_proof_form, false)
                        |> assign(:payment_proof_notes, notes || "")
                        |> assign(:payment_proof_file, filename)

                      {:noreply, socket}

                    {:error, %Ecto.Changeset{} = _changeset} ->
                      socket = put_flash(socket, :error, "Failed to submit payment proof. Please check the form for errors.")
                      {:noreply, socket}

                    {:error, _error} ->
                      socket = put_flash(socket, :error, "An unexpected error occurred while submitting payment proof.")
                      {:noreply, socket}
                  end
                end
              end
            end
          rescue
            Ecto.QueryError ->
              socket = put_flash(socket, :error, "Invalid booking ID.")
              {:noreply, socket}
            Ecto.NoResultsError ->
              socket = put_flash(socket, :error, "Booking not found.")
              {:noreply, socket}
            _error ->
              socket = put_flash(socket, :error, "An unexpected error occurred while processing the request.")
              {:noreply, socket}
          end
      end
  end

  # Generate payment gateway URL (placeholder - replace with actual payment gateway integration)
  defp generate_payment_gateway_url(booking, assigns) do
    # Get payment gateway configuration
    config = Application.get_env(:umrahly, :payment_gateway)

    # Determine which payment gateway to use based on payment method
    payment_method = assigns.payment_method

    case payment_method do
      "credit_card" ->
        # Use Stripe for credit card payments
        generate_stripe_payment_url(booking, assigns, config[:stripe])

      "online_banking" ->
        # Use PayPal for online banking
        generate_paypal_payment_url(booking, assigns, config[:paypal])

      "e_wallet" ->
        # Use e-wallet payment gateway
        generate_ewallet_payment_url(booking, assigns, config[:ewallet])

      _ ->
        # Fallback to generic payment gateway
        generate_generic_payment_url(booking, assigns, config[:generic])
    end
  end

  # Generate Stripe payment URL
  defp generate_stripe_payment_url(booking, _assigns, _stripe_config) do
    # This is a placeholder - replace with actual Stripe integration
    # In a real implementation, you would:
    # 1. Create a Stripe Checkout Session
    # 2. Return the session URL

    # For demo purposes, we'll create a more realistic Stripe-like URL
    # In production, replace this with actual Stripe Checkout Session creation
    base_url = "https://checkout.stripe.com"

    # Create a demo session ID (in real implementation, this would come from Stripe API)
    # Safely handle the booking ID to prevent String.slice errors
    booking_id_str = case booking do
      %{id: id} when is_integer(id) -> Integer.to_string(id)
      %{id: id} when is_binary(id) -> id
      _ -> "demo"
    end

    # Take last 8 characters safely
    id_suffix = if String.length(booking_id_str) >= 8 do
      String.slice(booking_id_str, -8..-1)
    else
      String.pad_leading(booking_id_str, 8, "0")
    end

    session_id = "cs_test_#{id_suffix}_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"

    # Return a realistic Stripe checkout URL
    "#{base_url}/pay/#{session_id}"
  end

  # Generate PayPal payment URL
  defp generate_paypal_payment_url(booking, _assigns, paypal_config) do
    # This is a placeholder - replace with actual PayPal integration
    # In production, replace this with actual PayPal payment creation

    # For demo purposes, we'll create a realistic PayPal-like URL
    base_url = if paypal_config && paypal_config[:mode] == "live", do: "https://www.paypal.com", else: "https://www.sandbox.paypal.com"

    # Create a demo payment ID (in real implementation, this would come from PayPal API)
    # Safely handle the booking ID to prevent String.slice errors
    booking_id_str = case booking do
      %{id: id} when is_integer(id) -> Integer.to_string(id)
      %{id: id} when is_binary(id) -> id
      _ -> "demo"
    end

    # Take last 8 characters safely
    id_suffix = if String.length(booking_id_str) >= 8 do
      String.slice(booking_id_str, -8..-1)
    else
      String.pad_leading(booking_id_str, 8, "0")
    end

    payment_id = "PAY-#{id_suffix}-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :upper)}"

    # Return a realistic PayPal payment URL
    "#{base_url}/checkoutnow?token=#{payment_id}"
  end

    # Generate e-wallet payment URL
  defp generate_ewallet_payment_url(booking, _assigns, _ewallet_config) do
    # This is a placeholder - replace with actual e-wallet integration
    # In production, replace this with actual e-wallet payment creation

    # For demo purposes, we'll create a realistic e-wallet payment URL
    # This could be Boost, Touch 'n Go, or other Malaysian e-wallets
    base_url = "https://demo-ewallet-gateway.com"

    # Create a demo payment ID (in real implementation, this would come from the e-wallet API)
    # Safely handle the booking ID to prevent String.slice errors
    booking_id_str = case booking do
      %{id: id} when is_integer(id) -> Integer.to_string(id)
      %{id: id} when is_binary(id) -> id
      _ -> "demo"
    end

    # Take last 8 characters safely
    id_suffix = if String.length(booking_id_str) >= 8 do
      String.slice(booking_id_str, -8..-1)
    else
      String.pad_leading(booking_id_str, 8, "0")
    end

    payment_id = "EW-#{id_suffix}-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :upper)}"

    # Return a realistic e-wallet payment URL
    "#{base_url}/pay/#{payment_id}"
  end

  # Generate generic payment gateway URL
  defp generate_generic_payment_url(booking, _assigns, generic_config) do
    # This is a placeholder - replace with actual payment gateway integration

    # For demo purposes, we'll create a realistic payment gateway URL
    base_url = generic_config && generic_config[:base_url] || "https://demo-payment-gateway.com"

    # Create a demo transaction ID (in real implementation, this would come from the payment gateway API)
    # Safely handle the booking ID to prevent String.slice errors
    booking_id_str = case booking do
      %{id: id} when is_integer(id) -> Integer.to_string(id)
      %{id: id} when is_binary(id) -> id
      _ -> "demo"
    end

    # Take last 8 characters safely
    id_suffix = if String.length(booking_id_str) >= 8 do
      String.slice(booking_id_str, -8..-1)
    else
      String.pad_leading(booking_id_str, 8, "0")
    end

    transaction_id = "TXN-#{id_suffix}-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :upper)}"

    # Return a realistic payment gateway URL
    "#{base_url}/payment/#{transaction_id}"
  end

  # Helper function to convert upload errors to readable strings
  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(_), do: "Invalid file"

  # Helper function to ensure upload directory exists
  defp ensure_upload_directory do
    upload_path = Path.join(["priv", "static", "uploads", "payment_proof"])
    File.mkdir_p!(upload_path)
    upload_path
  end

  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div id="booking-flow-container" class="max-w-4xl mx-auto space-y-6"

           data-step={@current_step}
           data-package-id={@package.id}
           data-schedule-id={@schedule.id}>
        <!-- Progress Steps -->
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900 text-center flex-1">Book Your Package</h1>
            <div class="text-sm text-gray-500">
              Step <%= @current_step %> of <%= @max_steps %>
            </div>
          </div>

          <!-- Progress Restoration Message -->
          <!-- Removed progress restoration message since progress saving is disabled -->

          <!-- Progress Bar -->
          <div class="w-full bg-gray-200 rounded-full h-2 mb-6">
            <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{Float.round((@current_step / @max_steps) * 100, 1)}%"}>
            </div>
          </div>

          <!-- Step Indicators -->
          <div class="flex justify-between mb-8">
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @current_step >= 1, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                1
              </div>
              <span class="text-xs text-gray-600 mt-1">Package Details</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @current_step >= 2, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                2
              </div>
              <span class="text-xs text-gray-600 mt-1">Travelers</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @current_step >= 3, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                3
              </div>
              <span class="text-xs text-gray-600 mt-1">Payment</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @current_step >= 4, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                4
              </div>
              <span class="text-xs text-gray-600 mt-1">Review & Confirm</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @current_step >= 5, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                5
              </div>
              <span class="text-xs text-gray-600 mt-1">Success</span>
            </div>
          </div>
        </div>

        <!-- Step 1: Package Details -->
        <%= if @current_step == 1 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Package Details</h2>

            <!-- Progress Status for Step 1 -->
            <%= if @saved_package_progress || @saved_travelers_progress || @saved_payment_progress do %>
              <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm text-blue-700">
                      <strong>Progress Available!</strong> You have saved progress in later steps. You can continue to review and complete your booking.
                    </p>
                  </div>
                </div>
              </div>
            <% end %>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <!-- Package Information -->
              <div class="space-y-4">
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium text-gray-900 mb-2"><%= @package.name %></h3>
                  <p class="text-sm text-gray-600 mb-3"><%= @package.description %></p>

                  <div class="space-y-2 text-sm">
                    <div class="flex justify-between">
                      <span class="text-gray-600">Duration:</span>
                      <span class="font-medium"><%= @package.duration_days %> days, <%= @package.duration_nights %> nights</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Accommodation:</span>
                      <span class="font-medium"><%= @package.accommodation_type %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Transport:</span>
                      <span class="font-medium"><%= @package.transport_type %></span>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Schedule Information -->
              <div class="space-y-4">
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium text-gray-900 mb-2">Selected Schedule</h3>

                  <div class="space-y-2 text-sm">
                    <div class="flex justify-between">
                      <span class="text-gray-600">Departure:</span>
                      <span class="font-medium"><%= Calendar.strftime(@schedule.departure_date, "%B %d, %Y") %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Return:</span>
                      <span class="font-medium"><%= Calendar.strftime(@schedule.return_date, "%B %d, %Y") %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Base package price:</span>
                      <span class="font-medium">RM <%= @package.price %></span>
                    </div>
                    <%= if @has_price_override do %>
                      <div class="flex justify-between">
                        <span class="text-gray-600">Price override:</span>
                        <span class="font-medium">RM <%= @schedule.price_override %></span>
                      </div>
                    <% end %>
                    <div class="flex justify-between border-t pt-2">
                      <span class="text-gray-600 font-medium">Total price per person:</span>
                      <span class="font-bold text-green-600">RM <%= @price_per_person %></span>
                    </div>

                    <div class="flex justify-between">
                      <span class="text-gray-600">Available slots:</span>
                      <span class="font-medium"><%= @schedule.quota %></span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-6 flex justify-between">
              <a
                href={~p"/packages/#{@package.id}"}
                class="bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium"
              >
                Back
              </a>
              <button
                type="button"
                phx-click="go_to_next_step"
                class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
              >
                Continue
              </button>
            </div>
          </div>
        <% end %>

        <!-- Step 2: Travelers -->
        <%= if @current_step == 2 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Travelers</h2>
            <div class="space-y-6">
              <!-- Progress Status -->
              <%= if @saved_travelers_progress do %>
                <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                  <div class="flex items-center">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-green-700">
                        <strong>Progress Saved!</strong> Your travelers information has been saved. You can continue or go back to make changes.
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Number of Persons -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Number of Travelers
                </label>
                <div class="flex items-center space-x-2">
                  <div class="flex border border-gray-300 rounded-lg">
                    <button
                      type="button"
                      phx-click="update_number_of_persons"
                      phx-value-action="decrease"
                      disabled={@number_of_persons <= 1}
                      class="px-3 py-2 text-gray-600 hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      -
                    </button>
                    <span class="px-4 py-2 bg-gray-50 text-center min-w-[3rem]">
                      <%= @number_of_persons %>
                    </span>
                    <button
                      type="button"
                      phx-click="update_number_of_persons"
                      phx-value-action="increase"
                      disabled={@number_of_persons >= 10}
                      class="px-3 py-2 text-gray-600 hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      +
                    </button>
                  </div>
                </div>
                <!-- Debug info -->
                <div class="mt-2 text-xs text-gray-500">
                  Current travelers in list: <%= length(@travelers) %> |
                  Number of persons: <%= @number_of_persons %>
                </div>
              </div>

              <!-- Travelers Details -->
              <div class="bg-gray-50 rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Travelers Details</h3>

                <!-- Toggle for single traveler -->
                <%= if @number_of_persons == 1 do %>
                  <div class="mb-4">
                    <div class="flex items-center justify-between p-3 bg-white border border-gray-200 rounded-lg">
                      <div class="flex items-center">
                        <span class="text-sm font-medium text-gray-700 mr-3">Who is traveling?</span>
                      </div>
                      <div class="flex items-center space-x-3">
                        <button
                          type="button"
                          phx-click="toggle_booking_for_self"
                          class={"px-4 py-2 rounded-lg text-sm font-medium transition-colors #{if @is_booking_for_self, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-700"}"}
                        >
                          I am traveling
                        </button>
                        <button
                          type="button"
                          phx-click="toggle_booking_for_self"
                          class={"px-4 py-2 rounded-lg text-sm font-medium transition-colors #{if !@is_booking_for_self, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-700"}"}
                        >
                          Someone else is traveling
                        </button>
                      </div>
                    </div>
                  </div>
                <% end %>

                <%= if @number_of_persons > 1 do %>
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
                    <div class="flex">
                      <div class="flex-shrink-0">
                        <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                        </svg>
                      </div>
                      <div class="ml-3">
                        <p class="text-sm text-blue-700">
                          <strong>Important:</strong> When selecting more than 1 traveler, you must provide complete details for each person including full name, identity card number, and phone number. Passport number is optional.
                        </p>
                      </div>
                    </div>
                  </div>
                  <p class="text-sm text-gray-600 mb-4">Please provide details for all travelers.</p>
                <% else %>
                  <p class="text-sm text-gray-600 mb-4">
                    <%= if @is_booking_for_self do %>
                      Please provide your travel details. Your profile information has been pre-filled. Passport number is optional.
                    <% else %>
                      Please provide the traveler's details. Passport number is optional.
                    <% end %>
                  </p>
                <% end %>

                <div class="space-y-4">
                  <%= for {traveler, index} <- Enum.with_index(@travelers) do %>
                    <div class="border border-gray-200 rounded-lg p-4">
                      <div class="flex items-center justify-between mb-3">
                        <h4 class="font-medium text-gray-800">
                          <%= if(@number_of_persons == 1 and @is_booking_for_self, do: "Your Details", else: if(@number_of_persons == 1, do: "Traveler Details", else: if(index == 0, do: "Traveler #{index + 1} (Person In Charge)", else: "Traveler #{index + 1}"))) %>
                        </h4>
                        <%= if @number_of_persons > 1 do %>
                          <button
                            type="button"
                            phx-click="remove_traveler"
                            phx-value-index={index}
                            class="text-red-500 hover:text-red-700 text-sm font-medium"
                            title="Remove traveler"
                          >
                            Remove
                          </button>
                        <% end %>
                      </div>

                      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Full Name <span class="text-red-500">*</span>
                          </label>
                          <div class="relative">
                            <input
                              type="text"
                              value={traveler[:full_name] || ""}
                              phx-blur="update_traveler_field"
                              phx-value-index={index}
                              phx-value-field="full_name"
                              class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                              placeholder="Enter full name"
                            />
                            <%= if traveler[:full_name] && traveler[:full_name] != "" do %>
                              <button
                                type="button"
                                phx-click="clear_traveler_field"
                                phx-value-index={index}
                                phx-value-field="full_name"
                                class="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-red-500"
                                title="Clear field"
                              >
                                ×
                              </button>
                            <% end %>
                          </div>
                        </div>

                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Identity Card Number <span class="text-red-500">*</span>
                          </label>
                          <div class="relative">
                            <input
                              type="text"
                              value={traveler[:identity_card_number] || ""}
                              phx-blur="update_traveler_field"
                              phx-value-index={index}
                              phx-value-field="identity_card_number"
                              class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                              placeholder="Enter identity card number"
                            />
                            <%= if traveler[:identity_card_number] && traveler[:identity_card_number] != "" do %>
                              <button
                                type="button"
                                phx-click="clear_traveler_field"
                                phx-value-index={index}
                                phx-value-field="identity_card_number"
                                class="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-red-500"
                                title="Clear field"
                              >
                                ×
                              </button>
                            <% end %>
                          </div>
                        </div>

                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Passport Number
                          </label>
                          <div class="relative">
                            <input
                              type="text"
                              value={traveler[:passport_number] || ""}
                              phx-blur="update_traveler_field"
                              phx-value-index={index}
                              phx-value-field="passport_number"
                              class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                              placeholder="Enter passport number (optional)"
                            />
                            <%= if traveler[:passport_number] && traveler[:passport_number] != "" do %>
                              <button
                                type="button"
                                phx-click="clear_traveler_field"
                                phx-value-index={index}
                                phx-value-field="passport_number"
                                class="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-red-500"
                                title="Clear field"
                              >
                                ×
                              </button>
                            <% end %>
                          </div>
                        </div>

                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Phone Number <span class="text-red-500">*</span>
                          </label>
                          <div class="relative">
                            <input
                              type="text"
                              value={traveler[:phone] || ""}
                              phx-blur="update_traveler_field"
                              phx-value-index={index}
                              phx-value-field="phone"
                              class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                              placeholder="Enter phone number"
                            />
                            <%= if traveler[:phone] && traveler[:phone] != "" do %>
                              <button
                                type="button"
                                phx-click="clear_traveler_field"
                                phx-value-index={index}
                                phx-value-field="phone"
                                class="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-red-500"
                                title="Clear field"
                              >
                                ×
                              </button>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>

                                <!-- Save Button -->
                <div class="mt-6 flex justify-center">
                  <button
                    type="button"
                    phx-click="save_travelers"
                    class="bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium"
                  >
                    Save Traveler Information
                  </button>
                </div>
              </div>

              <!-- Summary -->
              <div class="bg-gray-50 rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Travelers Summary</h3>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Number of persons:</span>
                    <span><%= @number_of_persons %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Traveler details required:</span>
                    <span class="text-blue-600 font-medium">Yes</span>
                  </div>
                  <%= if @number_of_persons == 1 do %>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Booking type:</span>
                      <span class={if @is_booking_for_self, do: "text-blue-600 font-medium", else: "text-purple-600 font-medium"}>
                        <%= if @is_booking_for_self, do: "For yourself", else: "For someone else" %>
                      </span>
                    </div>
                  <% end %>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Details filled:</span>
                    <span class={if Enum.all?(@travelers, fn t -> t[:full_name] != "" and t[:identity_card_number] != "" and t[:phone] != "" end), do: "text-green-600 font-medium", else: "text-red-600 font-medium"}>
                      <%= if Enum.all?(@travelers, fn t -> t[:full_name] != "" and t[:identity_card_number] != "" and t[:phone] != "" end), do: "Complete", else: "Incomplete" %>
                    </span>
                  </div>
                </div>
              </div>

              <div class="flex justify-between">
                <button
                  type="button"
                  phx-click="prev_step"
                  class="bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium"
                >
                  Back
                </button>
                <div class="flex space-x-3">

                  <button
                    type="button"
                    phx-click="go_to_next_step"
                    class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                  >
                    Continue
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Step 3: Payment -->
        <%= if @current_step == 3 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Payment Details</h2>

            <form phx-submit="validate_booking" class="space-y-6" novalidate>
              <!-- Progress Status -->
              <%= if @saved_payment_progress do %>
                <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                  <div class="flex items-center">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-green-700">
                        <strong>Progress Saved!</strong> Your payment information has been saved. You can continue or go back to make changes.
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Payment Plan -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Payment Plan
                </label>
                <div class="space-y-2">
                  <label class="flex items-center">
                    <input
                      type="radio"
                      name="booking[payment_plan]"
                      value="full_payment"
                      checked={@payment_plan == "full_payment"}
                      phx-click="update_payment_plan"
                      phx-value-payment_plan="full_payment"
                      class="mr-2"
                    />
                    <span class="text-sm">Full Payment (RM <%= @total_amount %>)</span>
                  </label>
                  <label class="flex items-center">
                    <input
                      type="radio"
                      name="booking[payment_plan]"
                      value="installment"
                      checked={@payment_plan == "installment"}
                      phx-click="update_payment_plan"
                      phx-value-payment_plan="installment"
                      class="mr-2"
                    />
                    <span class="text-sm">Installment Plan</span>
                  </label>
                </div>
              </div>

              <!-- Deposit Amount (for installment) -->
              <%= if @payment_plan == "installment" do %>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Deposit Amount (Minimum: RM <%= Decimal.mult(@total_amount, Decimal.new("0.2")) %>)
                  </label>
                  <input
                    type="number"
                    name="booking[deposit_amount]"
                    value={@deposit_amount}
                    min={Decimal.mult(@total_amount, Decimal.new("0.2"))}
                    max={@total_amount}
                    step="0.01"
                    phx-change="update_deposit_amount"
                    class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="Enter deposit amount"
                  />
                </div>
              <% end %>

              <!-- Payment Method -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Payment Method
                </label>
                <select
                  name="booking[payment_method]"
                  phx-change="update_payment_method"
                  class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  value={@payment_method}
                  phx-debounce="100"
                >
                  <option value="">Select payment method</option>
                  <option value="credit_card">Credit Card</option>
                  <option value="online_banking">Online Banking (FPX)</option>
                  <option value="e_wallet">E-Wallet (Boost, Touch 'n Go)</option>
                  <option value="bank_transfer">Bank Transfer</option>
                  <option value="cash">Cash</option>
                </select>
              </div>

              <!-- Notes -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Special Requests or Notes
                </label>
                <textarea
                  name="booking[notes]"
                  rows="3"
                  phx-change="update_notes"
                  class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Any special requests or notes for the admin..."
                ><%= @notes %></textarea>
              </div>

              <!-- Summary -->
              <div class="bg-gray-50 rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Payment Summary</h3>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Number of persons:</span>
                    <span><%= @number_of_persons %></span>
                  </div>
                  <div class="flex justify-between border-t pt-2">
                    <span class="text-gray-600 font-medium">Total amount:</span>
                    <span class="font-bold text-green-600">RM <%= @total_amount %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Deposit amount:</span>
                    <span class="font-medium">RM <%= @deposit_amount %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Payment plan:</span>
                    <span class="capitalize"><%= String.replace(@payment_plan, "_", " ") %></span>
                  </div>
                </div>
              </div>

              <div class="flex justify-between">
                <button
                  type="button"
                  phx-click="prev_step"
                  class="bg-gray-700 text-white px-6 py-2 rounded-lg hover:bg-gray-800 transition-colors font-medium"
                >
                  Back
                </button>
                <button
                  type="button"
                  phx-click="go_to_next_step"
                  class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                >
                  Continue
                </button>
              </div>
            </form>
          </div>
        <% end %>

        <!-- Step 4: Review & Confirm -->
        <%= if @current_step == 4 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Review & Confirm Booking</h2>

            <div class="space-y-6">

              <!-- Progress Status for Step 4 -->
              <%= if @saved_package_progress || @saved_travelers_progress || @saved_payment_progress do %>
                <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                  <div class="flex items-center">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-green-700">
                        <strong>Progress Saved!</strong> Your booking information has been saved. You can now review and confirm your booking.
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Package Summary -->
              <div class="border rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Package Details</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                  <div>
                    <span class="text-gray-600">Package:</span>
                    <span class="font-medium ml-2"><%= @package.name %></span>
                  </div>
                  <div>
                    <span class="text-gray-600">Schedule:</span>
                    <span class="font-medium ml-2">
                      <%= Calendar.strftime(@schedule.departure_date, "%B %d, %Y") %> -
                      <%= Calendar.strftime(@schedule.return_date, "%B %d, %Y") %>
                    </span>
                  </div>
                  <div>
                    <span class="text-gray-600">Travelers:</span>
                    <span class="font-medium ml-2"><%= @number_of_persons %></span>
                  </div>
                  <div>
                    <span class="text-gray-600">Payment Method:</span>
                    <span class="font-medium ml-2 capitalize"><%= String.replace(@payment_method, "_", " ") %></span>
                  </div>
                </div>
              </div>

              <!-- Travelers Details -->
              <div class="border rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Travelers Details</h3>
                <div class="space-y-3">
                  <%= for {traveler, index} <- Enum.with_index(@travelers) do %>
                    <div class="bg-gray-50 rounded-lg p-3">
                      <h4 class="font-medium text-gray-800 mb-2">
                        <%= if(@number_of_persons == 1 and @is_booking_for_self, do: "Your Details", else: if(@number_of_persons == 1, do: "Traveler Details", else: if(index == 0, do: "Traveler #{index + 1} (Person In Charge)", else: "Traveler #{index + 1}"))) %>
                      </h4>
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                        <div>
                          <span class="text-gray-600">Full Name:</span>
                          <span class="font-medium ml-2"><%= traveler[:full_name] || "" %></span>
                        </div>
                        <div>
                          <span class="text-gray-600">Identity Card:</span>
                          <span class="font-medium ml-2"><%= traveler[:identity_card_number] || "" %></span>
                        </div>
                        <div>
                          <span class="text-gray-600">Passport Number:</span>
                          <span class="font-medium ml-2"><%= traveler[:passport_number] || "" %></span>
                        </div>
                        <div>
                          <span class="text-gray-600">Phone:</span>
                          <span class="font-medium ml-2"><%= traveler[:phone] || "" %></span>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Payment Summary -->
              <div class="border rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Payment Summary</h3>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Number of persons:</span>
                    <span><%= @number_of_persons %></span>
                  </div>
                  <div class="flex justify-between border-t pt-2">
                    <span class="text-gray-900 font-medium">Total amount:</span>
                    <span class="text-gray-900 font-bold text-green-600">RM <%= @total_amount %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Deposit amount:</span>
                    <span class="font-medium">RM <%= @deposit_amount %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Payment plan:</span>
                    <span class="capitalize"><%= String.replace(@payment_plan, "_", " ") %></span>
                  </div>
                </div>
              </div>

              <!-- Notes -->
              <%= if @notes != "" do %>
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium text-gray-900 mb-2">Special Requests</h3>
                  <p class="text-sm text-gray-600"><%= @notes %></p>
                </div>
              <% end %>

              <!-- Terms and Conditions -->
              <div class="border rounded-lg p-4">
                <div class="flex items-start">
                  <input
                    type="checkbox"
                    id="terms"
                    class="mt-1 mr-3"
                    required
                    phx-hook="TermsValidation"
                  />
                  <label for="terms" class="text-sm text-gray-600">
                    I agree to the terms and conditions and understand that this booking is subject to confirmation by Umrahly.
                  </label>
                </div>
              </div>

              <div class="flex justify-between">
                <button
                  type="button"
                  phx-click="prev_step"
                  class="bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium"
                >
                  Back
                </button>
                <button
                  type="button"
                  phx-click="create_booking"
                  class="bg-green-600 text-white px-8 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium opacity-50 cursor-not-allowed"
                  id="confirm-booking-btn"
                  disabled
                >
                  Confirm & Proceed to Payment
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Step 5: Success -->
        <%= if @current_step == 5 do %>
          <%= if @requires_online_payment do %>
            <!-- Online Payment Success -->
            <div
              id="payment-gateway-container"
              class="bg-white rounded-lg shadow p-6 text-center"
              phx-hook="PaymentGatewayRedirect"
              data-requires-online-payment={@requires_online_payment}
              data-payment-gateway-url={@payment_gateway_url}>
              <div class="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                </svg>
              </div>

              <h2 class="text-2xl font-bold text-gray-900 mb-2">Booking Confirmed!</h2>
              <p class="text-gray-600 mb-6">
                Your booking has been created successfully. You are being redirected to the payment gateway to complete your payment.
              </p>

              <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm text-blue-700">
                      <strong>Payment Gateway:</strong> <%= String.replace(@payment_method, "_", " ") |> String.capitalize() %>
                    </p>
                    <p class="text-sm text-blue-700 mt-1">
                      Complete your payment securely on the external payment gateway.
                    </p>
                  </div>
                </div>
              </div>
                <div class="space-y-3">
                <button
                  type="button"
                  onclick={"window.open('#{@payment_gateway_url}', '_blank')"}
                  class="inline-block bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                >
                  Go to Payment Gateway Now
                </button>
                <button
                  type="button"
                  onclick={"window.location.href='#{@payment_gateway_url}'"}
                  class="inline-block bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium ml-3"
                >
                  Redirect to Payment Gateway
                </button>
                <a
                  href={~p"/dashboard"}
                  class="inline-block bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium ml-3"
                >
                  Go to Dashboard
                </a>
              </div>
            </div>
          <% else %>
            <!-- Offline Payment Success -->
            <div class="bg-white rounded-lg shadow p-6 text-center">
              <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                </svg>
              </div>

              <h2 class="text-2xl font-bold text-gray-900 mb-2">Booking Confirmed!</h2>
              <p class="text-gray-600 mb-6">
                Your booking has been created successfully. Please complete your payment using the selected payment method.
              </p>

              <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm text-yellow-700">
                      <strong>Payment Method:</strong> <%= String.replace(@payment_method, "_", " ") |> String.capitalize() %>
                    </p>
                    <p class="text-sm text-yellow-700 mt-1">
                      Please contact our team to arrange payment completion.
                    </p>
                  </div>
                </div>
              </div>

              <!-- Payment Proof Submission Section -->
              <%= if !@payment_proof_file do %>
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
                  <div class="flex items-center justify-between mb-3">
                    <h3 class="text-lg font-medium text-blue-900">Submit Payment Proof</h3>
                    <button
                      type="button"
                      phx-click="toggle_payment_proof_form"
                      class="text-blue-600 hover:text-blue-800 text-sm font-medium"
                    >
                      <%= if @show_payment_proof_form, do: "Hide Form", else: "Show Form" %>
                    </button>
                  </div>

                  <p class="text-sm text-blue-700 mb-3">
                    After completing your payment, please upload proof of payment (receipt, bank transfer slip, etc.) for admin approval.
                  </p>

                  <%= if @show_payment_proof_form do %>
                    <form phx-submit="submit_payment_proof" method="post" class="space-y-4 text-left" enctype="multipart/form-data" id="payment-proof-form">
                      <div>
                        <label class="block text-sm font-medium text-blue-900 mb-2">
                          Payment Proof File <span class="text-red-500">*</span>
                        </label>
                        <div class="w-full border border-blue-300 rounded-lg px-3 py-2 focus-within:ring-2 focus-within:ring-blue-500">
                          <.live_file_input upload={@uploads.payment_proof} class="w-full border-0 focus:outline-none" />
                        </div>
                        <p class="text-xs text-blue-600 mt-1">
                          Accepted formats: PDF, JPG, PNG, DOC, DOCX (Max 5MB)
                        </p>

                        <!-- Show selected file info -->
                        <%= for entry <- @uploads.payment_proof.entries do %>
                          <div class="mt-2 p-2 bg-blue-50 border border-blue-200 rounded">
                            <div class="flex items-center justify-between">
                              <span class="text-sm text-blue-700"><%= entry.client_name %></span>
                              <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-red-500 hover:text-red-700">
                                Remove
                              </button>
                            </div>
                            <%= for err <- upload_errors(@uploads.payment_proof, entry) do %>
                              <div class="text-red-500 text-xs mt-1"><%= error_to_string(err) %></div>
                            <% end %>
                          </div>
                        <% end %>
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-blue-900 mb-2">
                          Additional Notes
                        </label>
                        <textarea
                          rows="3"
                          name="payment_proof_notes"
                          placeholder="Any additional information about your payment..."
                          class="w-full border border-blue-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        ><%= @payment_proof_notes %></textarea>
                      </div>
                      <button
                        type="submit"
                        class="w-full bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                      >
                        Submit Payment Proof
                      </button>
                    </form>
                  <% end %>
                </div>
              <% end %>

              <!-- Display Submitted Payment Proof -->
              <%= if @payment_proof_file do %>
                <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
                  <div class="flex items-center mb-3">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <h3 class="text-lg font-medium text-green-900">Payment Proof Submitted</h3>
                      <p class="text-sm text-green-700">Your payment proof has been submitted and is pending admin review.</p>
                    </div>
                  </div>

                  <div class="bg-white border border-green-200 rounded-lg p-3">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center">
                        <svg class="h-4 w-4 text-green-500 mr-2" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clip-rule="evenodd" />
                        </svg>
                        <span class="text-sm font-medium text-green-900"><%= @payment_proof_file %></span>
                      </div>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                        Pending Review
                      </span>
                    </div>
                    <%= if @payment_proof_notes && @payment_proof_notes != "" do %>
                      <div class="mt-2 text-sm text-green-700">
                        <strong>Notes:</strong> <%= @payment_proof_notes %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <div class="space-y-3">
                <a
                  href={~p"/packages"}
                  class="inline-block bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                >
                  Browse More Packages
                </a>
                <a
                  href={~p"/dashboard"}
                  class="inline-block bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium ml-3"
                >
                  Go to Dashboard
                </a>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </.sidebar>
    """
  end
end
