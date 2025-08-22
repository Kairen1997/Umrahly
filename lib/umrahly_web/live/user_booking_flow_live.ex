defmodule UmrahlyWeb.UserBookingFlowLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings
  alias Umrahly.Bookings.Booking
  alias Umrahly.Packages
  alias Umrahly.Accounts

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(%{"package_id" => package_id, "schedule_id" => schedule_id}, _session, socket) do
    # Get package and schedule details
    package = Packages.get_package!(package_id)
    schedule = Packages.get_package_schedule!(schedule_id)

    # Verify the schedule belongs to the package
    if schedule.package_id != String.to_integer(package_id) do
      {:noreply,
       socket
       |> put_flash(:error, "Invalid package schedule selected")
       |> push_navigate(to: ~p"/packages/#{package_id}")}
    else
      # Calculate total amount based on number of persons
      total_amount = Decimal.mult(Decimal.new(package.price), Decimal.new(1))

      # Create initial booking changeset
      changeset = Bookings.change_booking(%Booking{})

      socket =
        socket
        |> assign(:package, package)
        |> assign(:schedule, schedule)
        |> assign(:total_amount, total_amount)
        |> assign(:deposit_amount, total_amount)
        |> assign(:number_of_persons, 1)
        |> assign(:payment_method, "bank_transfer")
        |> assign(:payment_plan, "full_payment")
        |> assign(:notes, "")
        |> assign(:changeset, changeset)
        |> assign(:current_page, "packages")
        |> assign(:page_title, "Book Package")
        |> assign(:step, 1)
        |> assign(:max_steps, 3)

      {:ok, socket}
    end
  end

  def handle_event("validate_booking", %{"booking" => booking_params}, socket) do
    # Update local assigns for real-time validation
    number_of_persons = String.to_integer(booking_params["number_of_persons"] || "1")
    payment_plan = booking_params["payment_plan"] || "full_payment"

    # Calculate amounts
    package_price = socket.assigns.package.price
    total_amount = Decimal.mult(Decimal.new(package_price), Decimal.new(number_of_persons))

    deposit_amount = case payment_plan do
      "full_payment" -> total_amount
      "installment" ->
        deposit_input = booking_params["deposit_amount"] || "0"
        case Decimal.parse(deposit_input) do
          {:ok, amount} -> amount
          :error -> Decimal.mult(total_amount, Decimal.new("0.1"))
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
      |> assign(:payment_method, booking_params["payment_method"])
      |> assign(:payment_plan, payment_plan)
      |> assign(:notes, booking_params["notes"] || "")
      |> assign(:changeset, changeset)

    {:noreply, socket}
  end

  def handle_event("next_step", _params, socket) do
    current_step = socket.assigns.step

    if current_step < socket.assigns.max_steps do
      {:noreply, assign(socket, :step, current_step + 1)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("prev_step", _params, socket) do
    current_step = socket.assigns.step

    if current_step > 1 do
      {:noreply, assign(socket, :step, current_step - 1)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("create_booking", _params, socket) do
    # Create final booking attributes
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
      booking_date: Date.utc_today()
    }

    case Bookings.create_booking(attrs) do
      {:ok, booking} ->
        socket =
          socket
          |> put_flash(:info, "Booking created successfully! You will be redirected to payment.")
          |> assign(:step, 4) # Show success step

        # In a real application, you would redirect to a payment gateway here
        # For now, we'll just show the success message

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to create booking. Please check the form for errors.")
          |> assign(:changeset, changeset)

        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div class="max-w-4xl mx-auto space-y-6">
        <!-- Progress Steps -->
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Book Your Package</h1>
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
              <span class="text-xs text-gray-600 mt-1">Travelers & Payment</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @step >= 3, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                3
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
                      <span class="text-gray-600">Price per person:</span>
                      <span class="font-medium">RM <%= @package.price %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Available slots:</span>
                      <span class="font-medium"><%= @schedule.quota %></span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-6 flex justify-end">
              <button
                phx-click="next_step"
                class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
              >
                Continue
              </button>
            </div>
          </div>
        <% end %>

        <!-- Step 2: Travelers & Payment -->
        <%= if @step == 2 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Travelers & Payment Details</h2>

            <form phx-change="validate_booking" phx-submit="validate_booking" class="space-y-6">
              <!-- Number of Persons -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Number of Travelers
                </label>
                <select
                  name="booking[number_of_persons]"
                  class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  value={@number_of_persons}
                >
                  <%= for i <- 1..10 do %>
                    <option value={i} selected={@number_of_persons == i}>
                      <%= i %> <%= if i == 1, do: "Person", else: "Persons" %>
                    </option>
                  <% end %>
                </select>
              </div>

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
                    Deposit Amount (Minimum: RM <%= Decimal.mult(@total_amount, Decimal.new("0.1")) %>)
                  </label>
                  <input
                    type="number"
                    name="booking[deposit_amount]"
                    value={@deposit_amount}
                    min={Decimal.mult(@total_amount, Decimal.new("0.1"))}
                    max={@total_amount}
                    step="0.01"
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
                  class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  value={@payment_method}
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
                  class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Any special requests or notes for the admin..."
                ><%= @notes %></textarea>
              </div>

              <!-- Summary -->
              <div class="bg-gray-50 rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Booking Summary</h3>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Price per person:</span>
                    <span>RM <%= @package.price %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Number of persons:</span>
                    <span><%= @number_of_persons %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Total amount:</span>
                    <span class="font-medium">RM <%= @total_amount %></span>
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

        <!-- Step 3: Review & Confirm -->
        <%= if @step == 3 do %>
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

              <!-- Payment Summary -->
              <div class="border rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Payment Summary</h3>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Price per person:</span>
                    <span>RM <%= @package.price %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Number of persons:</span>
                    <span><%= @number_of_persons %></span>
                  </div>
                  <div class="flex justify-between border-t pt-2">
                    <span class="text-gray-900 font-medium">Total amount:</span>
                    <span class="text-gray-900 font-medium">RM <%= @total_amount %></span>
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

        <!-- Step 4: Success -->
        <%= if @step == 4 do %>
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
