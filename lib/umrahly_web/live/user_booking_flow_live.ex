defmodule UmrahlyWeb.UserBookingFlowLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings
  alias Umrahly.Bookings.Booking
  alias Umrahly.Packages

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}



  def mount(%{"package_id" => package_id, "schedule_id" => schedule_id}, _session, socket) do
    # Get package and schedule details
    package = Packages.get_package!(package_id)
    schedule = Packages.get_package_schedule!(schedule_id)

    # Always check for existing progress to resume the booking flow
    progress = case Bookings.get_or_create_booking_flow_progress(
      socket.assigns.current_user.id,
      package.id,
      schedule.id
    ) do
      {:ok, progress} ->
        progress
      {:error, error} ->
        nil
      other ->
        nil
    end

        # Helper function to check if price override should be shown
    has_price_override = schedule.price_override && Decimal.gt?(schedule.price_override, Decimal.new(0))

    # Calculate price per person
    base_price = package.price
    override_price = if has_price_override, do: Decimal.to_integer(schedule.price_override), else: 0
    price_per_person = base_price + override_price

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

      # Progress is already retrieved above

      # Create initial booking changeset
      changeset = Bookings.change_booking(%Booking{})

      # Initialize travelers with current user details for single traveler
      travelers = if progress && progress.travelers_data && length(progress.travelers_data) > 0 do
        # Use saved travelers data
        progress.travelers_data
      else
        [%{
          full_name: socket.assigns.current_user.full_name || "",
          identity_card_number: socket.assigns.current_user.identity_card_number || "",
          passport_number: "", # Passport might not be in user profile
          phone: socket.assigns.current_user.phone_number || ""
        }]
      end

      socket =
        socket
        |> assign(:package, package)
        |> assign(:schedule, schedule)
        |> assign(:has_price_override, has_price_override)
        |> assign(:price_per_person, price_per_person)
        |> assign(:total_amount, progress && progress.total_amount || total_amount)
        |> assign(:payment_plan, progress && progress.payment_plan || "full_payment")
        |> assign(:deposit_amount, progress && progress.deposit_amount || if((progress && progress.payment_plan) == "installment", do: Decimal.mult(total_amount, Decimal.new("0.2")), else: total_amount))
        |> assign(:number_of_persons, progress && progress.number_of_persons || 1)
        |> assign(:travelers, travelers)
        |> assign(:is_booking_for_self, progress && progress.is_booking_for_self || true)
        |> assign(:payment_method, progress && progress.payment_method || "bank_transfer")
        |> assign(:notes, progress && progress.notes || "")
        |> assign(:changeset, changeset)
        |> assign(:current_page, "packages")
        |> assign(:page_title, "Book Package")
        |> assign(:step, if(progress && progress.current_step && progress.current_step > 0, do: progress.current_step, else: 1))
        |> assign(:max_steps, 4)

      {:ok, socket}
    end
  end

  def handle_event("validate_booking", %{"booking" => booking_params}, socket) do
    IO.puts("DEBUG: validate_booking called with params: #{inspect(booking_params)}")
    IO.puts("DEBUG: Current step before validation: #{socket.assigns.step}")

    # Update local assigns for real-time validation
    number_of_persons = String.to_integer(booking_params["number_of_persons"] || "1")
    payment_plan = booking_params["payment_plan"] || "full_payment"

    # Handle travelers data and sync with number of persons
    travelers = case booking_params["travelers"] do
      nil ->
        # Initialize travelers based on number of persons
        Enum.map(1..number_of_persons, fn _ ->
          %{full_name: "", identity_card_number: "", passport_number: "", phone: ""}
        end)
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
      |> assign(:step, socket.assigns.step) # Preserve the current step

    # Save progress after validation
    save_booking_progress(socket, socket.assigns.step)

    IO.puts("DEBUG: validate_booking completed. Final step: #{socket.assigns.step}")

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

    # Initialize travelers based on new number of persons
    travelers = Enum.map(1..new_number, fn index ->
      if index == 1 and socket.assigns.is_booking_for_self do
        # First traveler - pre-fill with user details if booking for self
        %{
          full_name: socket.assigns.current_user.full_name || "",
          identity_card_number: socket.assigns.current_user.identity_card_number || "",
          passport_number: "",
          phone: socket.assigns.current_user.phone_number || ""
        }
      else
        # Additional travelers or booking for someone else - empty fields
        %{full_name: "", identity_card_number: "", passport_number: "", phone: ""}
      end
    end)

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

    # Save progress after updating number of persons
    save_booking_progress(socket, socket.assigns.step)

    {:noreply, socket}
  end

  def handle_event("update_number_of_persons", %{"action" => "decrease"}, socket) do
    current_number = socket.assigns.number_of_persons
    new_number = max(current_number - 1, 1)

    # Initialize travelers based on new number of persons
    travelers = Enum.map(1..new_number, fn index ->
      if index == 1 and socket.assigns.is_booking_for_self do
        # First traveler - pre-fill with user details if booking for self
        %{
          full_name: socket.assigns.current_user.full_name || "",
          identity_card_number: socket.assigns.current_user.identity_card_number || "",
          passport_number: "",
          phone: socket.assigns.current_user.phone_number || ""
        }
      else
        # Additional travelers or booking for someone else - empty fields
        %{full_name: "", identity_card_number: "", passport_number: "", phone: ""}
      end
    end)

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

    # Save progress after updating number of persons
    save_booking_progress(socket, socket.assigns.step)

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

    # Save progress after updating payment plan
    save_booking_progress(socket, socket.assigns.step)

    {:noreply, socket}
  end

  def handle_event("update_payment_method", params, socket) do
    # Handle the case where payment_method might be in a nested structure
    payment_method = case params do
      %{"payment_method" => pm} -> pm
      %{"booking" => %{"payment_method" => pm}} -> pm
      _ -> socket.assigns.payment_method
    end

    # Store the current step before any operations
    current_step = socket.assigns.step

    # Update the payment method immediately for responsive UI
    socket = assign(socket, :payment_method, payment_method)

    # Send immediate response to prevent timeout
    send(self(), {:save_progress_async, current_step})

    # Add flash message to confirm the change
    socket = put_flash(socket, :info, "Payment method changed to #{String.replace(payment_method, "_", " ") |> String.capitalize()}")

    {:noreply, socket}
  end

  def handle_event("update_notes", %{"booking" => %{"notes" => notes}}, socket) do
    socket = assign(socket, :notes, notes)

    # Save progress after updating notes
    save_booking_progress(socket, socket.assigns.step)

    {:noreply, socket}
  end

  def handle_info({:save_progress_async, step}, socket) do
    case save_booking_progress(socket, step) do
      :ok -> :ok
      :error -> :error
    end
    {:noreply, socket}
  end

  def handle_event("update_deposit_amount", %{"booking" => %{"deposit_amount" => deposit_amount_str}}, socket) do
    try do
      deposit_amount = Decimal.new(deposit_amount_str)
      socket = assign(socket, :deposit_amount, deposit_amount)

      # Save progress after updating deposit amount
      save_booking_progress(socket, socket.assigns.step)

      {:noreply, socket}
    rescue
      _ ->
        {:noreply, socket}
    end
  end

    def handle_event("update_traveler", %{"index" => index_str, "field" => field, "value" => value}, socket) do
    index = String.to_integer(index_str)
    travelers = socket.assigns.travelers

    updated_travelers = List.update_at(travelers, index, fn traveler ->
      Map.put(traveler, String.to_atom(field), value)
    end)

    socket = assign(socket, :travelers, updated_travelers)

    # Don't auto-save on every keystroke to prevent interference
    # Progress will be saved when user clicks Save Progress or navigates

    {:noreply, socket}
  end

  def handle_event("save_travelers_progress", _params, socket) do
    # Save the current progress
    case save_booking_progress(socket, socket.assigns.step) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Travelers details saved successfully!")

        {:noreply, socket}
      _ ->
        socket =
          socket
          |> put_flash(:error, "Failed to save progress. Please try again.")

        {:noreply, socket}
    end
  end

  def handle_event("validate_booking", _params, socket) do
    # This is just a placeholder to prevent form submission
    # The actual validation happens in real-time via individual field updates
    {:noreply, socket}
  end

    def handle_event("go_to_next_step", _params, socket) do
    current_step = socket.assigns.step
    max_steps = socket.assigns.max_steps

    # Debug logging
    IO.puts("DEBUG: go_to_next_step called. Current step: #{current_step}, Max steps: #{max_steps}")

    # Validate step bounds - be more defensive
    cond do
      current_step < 1 ->
        IO.puts("DEBUG: Step too low (#{current_step}), resetting to step 1")
        {:noreply, assign(socket, :step, 1)}
      current_step > max_steps ->
        IO.puts("DEBUG: Step too high (#{current_step}), resetting to step #{max_steps}")
        {:noreply, assign(socket, :step, max_steps)}
      current_step < max_steps ->
        new_step = current_step + 1
        IO.puts("DEBUG: Advancing from step #{current_step} to step #{new_step}")

        # Advance the step
        socket = assign(socket, :step, new_step)

        # Save progress
        _ = save_booking_progress(socket, new_step)

        {:noreply, socket}
      true ->
        IO.puts("DEBUG: Already at max step")
        {:noreply, socket}
    end
  end

  def handle_event("next_step", params, socket) do
    handle_event("go_to_next_step", params, socket)
  end

  def handle_event("prev_step", _params, socket) do
    current_step = socket.assigns.step

    if current_step > 1 do
      new_step = current_step - 1
      _ = save_booking_progress(socket, new_step)
      {:noreply, assign(socket, :step, new_step)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("create_booking", _params, socket) do
    attrs = %{
      total_amount: socket.assigns.total_amount,
      deposit_amount: socket.assigns.deposit_amount,
      number_of_persons: socket.assigns.number_of_persons,
      payment_method: socket.assigns.payment_method,
      payment_plan: socket.assigns.payment_plan,
      notes: socket.assigns.notes,
      user_id: socket.assigns.current_user.id,
      package_schedule_id: socket.assigns.schedule.id,
      status: "pending",
      booking_date: Date.utc_today(),
      travelers: socket.assigns.travelers
    }

    case Bookings.create_booking(attrs) do
      {:ok, _booking} ->
        complete_booking_flow_progress(socket)

        socket =
          socket
          |> put_flash(:info, "Booking created successfully! You will be redirected to payment.")
          |> assign(:step, 5)

        {:noreply, socket}



      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to create booking. Please check the form for errors.")
          |> assign(:changeset, changeset)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end


    defp save_booking_progress(socket, step) do
    # Ensure we don't save a step that's less than 1
    step_to_save = if step < 1, do: 1, else: step

    # Add timeout protection
    try do
      # Use Task.async to prevent blocking
      task = Task.async(fn ->
        try do
          case Bookings.get_or_create_booking_flow_progress(
            socket.assigns.current_user.id,
            socket.assigns.package.id,
            socket.assigns.schedule.id
          ) do
            {:ok, progress} ->
              attrs = %{
                current_step: step_to_save,
                number_of_persons: socket.assigns.number_of_persons,
                is_booking_for_self: socket.assigns.is_booking_for_self,
                payment_method: socket.assigns.payment_method,
                payment_plan: socket.assigns.payment_plan,
                notes: socket.assigns.notes,
                travelers_data: socket.assigns.travelers,
                total_amount: socket.assigns.total_amount,
                deposit_amount: socket.assigns.deposit_amount
              }

              case Bookings.update_booking_flow_progress(progress, attrs) do
                {:ok, _updated_progress} -> :ok
                {:error, _changeset} -> :error
              end
            {:error, _changeset} -> :error
            _ -> :error
          end
        rescue
          _ -> :error
        end
      end)

      # Wait for the task with a timeout
      case Task.await(task, 5000) do
        :ok -> :ok
        :error -> :error
        _ -> :error
      end
    rescue
      _ -> :error
    end
  end

  defp complete_booking_flow_progress(socket) do
    case Bookings.get_or_create_booking_flow_progress(
      socket.assigns.current_user.id,
      socket.assigns.package.id,
      socket.assigns.schedule.id
    ) do
      {:ok, progress} ->
        Bookings.complete_booking_flow_progress(progress)
      _ ->
        :error
    end
  end



  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div class="max-w-4xl mx-auto space-y-6">
        <!-- Progress Steps -->
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900 text-center flex-1">Book Your Package</h1>
            <div class="text-sm text-gray-500">
              Step <%= @step %> of <%= @max_steps %>
            </div>
          </div>

          <!-- Progress Bar -->
          <div class="w-full bg-gray-200 rounded-full h-2 mb-6">
            <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{Float.round((@step / @max_steps) * 100, 1)}%"}>
            </div>
          </div>

          <!-- Step Indicators -->
          <div class="flex justify-between mb-8">
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @step >= 1, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                1
              </div>
              <span class="text-xs text-gray-600 mt-1">Package Details</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @step >= 2, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                2
              </div>
              <span class="text-xs text-gray-600 mt-1">Travelers</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @step >= 3, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                3
              </div>
              <span class="text-xs text-gray-600 mt-1">Payment</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @step >= 4, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                4
              </div>
              <span class="text-xs text-gray-600 mt-1">Review & Confirm</span>
            </div>
          </div>
        </div>

        <!-- Step 1: Package Details -->
        <%= if @step == 1 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Package Details</h2>

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
        <%= if @step == 2 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Travelers</h2>

            <div class="space-y-6">
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
                <div class="text-xs text-gray-500 mt-1">
                  Current: <%= @number_of_persons %> travelers, Step: <%= @step %>
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
                      <h4 class="font-medium text-gray-800 mb-3">
                        <%= if(@number_of_persons == 1 and @is_booking_for_self, do: "Your Details", else: if(@number_of_persons == 1, do: "Traveler Details", else: "Traveler #{index + 1}")) %>
                      </h4>
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Full Name <span class="text-red-500">*</span>
                          </label>
                          <input
                            type="text"
                            name={"booking[travelers][#{index}][full_name]"}
                            value={traveler.full_name}
                            phx-change="update_traveler"
                            phx-value-index={index}
                            phx-value-field="full_name"
                            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                            placeholder="Enter full name"
                            required
                          />
                        </div>
                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Identity Card Number <span class="text-red-500">*</span>
                          </label>
                          <input
                            type="text"
                            name={"booking[travelers][#{index}][identity_card_number]"}
                            value={traveler.identity_card_number}
                            phx-change="update_traveler"
                            phx-value-index={index}
                            phx-value-field="identity_card_number"
                            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                            placeholder="Enter identity card number"
                            required
                          />
                        </div>
                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Passport Number
                          </label>
                          <input
                            type="text"
                            name={"booking[travelers][#{index}][passport_number]"}
                            value={traveler.passport_number}
                            phx-change="update_traveler"
                            phx-value-index={index}
                            phx-value-field="passport_number"
                            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                            placeholder="Enter passport number (optional)"
                          />
                        </div>
                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Phone Number <span class="text-red-500">*</span>
                          </label>
                          <input
                            type="text"
                            name={"booking[travelers][#{index}][phone]"}
                            value={traveler.phone}
                            phx-change="update_traveler"
                            phx-value-index={index}
                            phx-value-field="phone"
                            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                            placeholder="Enter phone number"
                            required
                          />
                        </div>
                      </div>
                    </div>
                  <% end %>
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
                    <span class={if Enum.all?(@travelers, fn t -> t.full_name != "" and t.identity_card_number != "" and t.phone != "" end), do: "text-green-600 font-medium", else: "text-red-600 font-medium"}>
                      <%= if Enum.all?(@travelers, fn t -> t.full_name != "" and t.identity_card_number != "" and t.phone != "" end), do: "Complete", else: "Incomplete" %>
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
                    phx-click="save_travelers_progress"
                    class="bg-gray-500 text-white px-4 py-2 rounded-lg hover:bg-gray-600 transition-colors font-medium"
                  >
                    Save Progress
                  </button>
                  <button
                    type="button"
                    phx-click="next_step"
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
        <%= if @step == 3 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Payment Details</h2>

            <form phx-submit="validate_booking" phx-submit-ignore class="space-y-6" onsubmit="return false;" novalidate>
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
                  <option value="credit_card">Credit Card</option>
                  <option value="bank_transfer">Bank Transfer</option>
                  <option value="online_banking">Online Banking</option>
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
                  class="bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium"
                >
                  Back
                </button>
                <button
                  type="button"
                  phx-click="next_step"
                  class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                >
                  Continue
                </button>
              </div>
            </form>
          </div>
        <% end %>

        <!-- Step 4: Review & Confirm -->
        <%= if @step == 4 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Review & Confirm Booking</h2>

            <div class="space-y-6">
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
                        <%= if(@number_of_persons == 1 and @is_booking_for_self, do: "Your Details", else: if(@number_of_persons == 1, do: "Traveler Details", else: "Traveler #{index + 1}")) %>
                      </h4>
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                        <div>
                          <span class="text-gray-600">Full Name:</span>
                          <span class="font-medium ml-2"><%= traveler.full_name %></span>
                        </div>
                        <div>
                          <span class="text-gray-600">Identity Card:</span>
                          <span class="font-medium ml-2"><%= traveler.identity_card_number %></span>
                        </div>
                        <div>
                          <span class="text-gray-600">Passport Number:</span>
                          <span class="font-medium ml-2"><%= traveler.passport_number %></span>
                        </div>
                        <div>
                          <span class="text-gray-600">Phone:</span>
                          <span class="font-medium ml-2"><%= traveler.phone %></span>
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
                  phx-click="create_booking"
                  class="bg-green-600 text-white px-8 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium"
                >
                  Confirm & Proceed to Payment
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Step 5: Success -->
        <%= if @step == 5 do %>
          <div class="bg-white rounded-lg shadow p-6 text-center">
            <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
              </svg>
            </div>

            <h2 class="text-2xl font-bold text-gray-900 mb-2">Booking Confirmed!</h2>
            <p class="text-gray-600 mb-6">
              Your booking has been created successfully. You will be redirected to the payment gateway to complete your payment.
            </p>

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
      </div>
    </.sidebar>
    """
  end
end
