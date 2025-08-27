defmodule UmrahlyWeb.UserPaymentsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings
  alias Decimal
  alias Calendar
  alias Float
  alias Umrahly.Accounts

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

  defp load_data(socket) do
    user = socket.assigns.current_user

    # Load user's bookings with payment information
    bookings = Bookings.list_user_bookings_with_payments(user.id)

    # Load payment history
    payment_history = load_payment_history(user.id)

    # Load receipts
    receipts = load_receipts(user.id)

    socket
    |> assign(:bookings, bookings)
    |> assign(:payment_history, payment_history)
    |> assign(:receipts, receipts)
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
      {:ok, decimal} -> decimal
      :error -> Decimal.new(0)
      _ -> Decimal.new(0)
    end
  end
  defp ensure_decimal(_), do: Decimal.new(0)

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
                  <div class="space-y-6">
                    <%= for booking <- @bookings do %>
                      <div class="border border-gray-200 rounded-lg p-6">
                        <div class="flex items-center justify-between mb-4">
                          <div>
                            <h3 class="text-lg font-medium text-gray-900">Booking #<%= booking.booking_reference %></h3>
                            <p class="text-sm text-gray-500">Package: <%= booking.package_name %></p>
                          </div>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            <%= String.upcase(booking.status) %>
                          </span>
                        </div>

                        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                          <div>
                            <div class="text-sm font-medium text-gray-500">Total Amount</div>
                            <div class="mt-1 text-lg font-semibold text-gray-900">RM <%= format_amount(booking.total_amount) %></div>
                          </div>
                          <div>
                            <div class="text-sm font-medium text-gray-500">Paid Amount</div>
                            <div class="mt-1 text-lg font-semibold text-green-600">RM <%= format_amount(booking.paid_amount || 0) %></div>
                          </div>
                          <div>
                            <div class="text-sm font-medium text-gray-500">Remaining</div>
                            <div class="mt-1 text-lg font-semibold text-red-600">RM <%= format_amount(calculate_remaining_amount(booking.total_amount, booking.paid_amount)) %></div>
                          </div>
                        </div>

                        <%= if (booking.total_amount || 0) > (booking.paid_amount || 0) do %>
                          <div class="border-t border-gray-200 pt-4">
                            <h4 class="text-sm font-medium text-gray-900 mb-3">Make a Payment</h4>
                            <form phx-submit="make-payment" class="flex gap-3">
                              <input type="hidden" name="booking_id" value={booking.id} />
                              <input
                                type="number"
                                name="amount"
                                step="0.01"
                                min="0.01"
                                max={calculate_remaining_amount(booking.total_amount, booking.paid_amount)}
                                placeholder="Enter amount"
                                class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                                required
                              />
                              <button
                                type="submit"
                                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                              >
                                Pay Now
                              </button>
                            </form>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
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
                              <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{if payment.status == "completed", do: "bg-green-100 text-green-800", else: "bg-yellow-100 text-yellow-800"}"}>
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
                    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{if @selected_payment.status == "completed", do: "bg-green-100 text-green-800", else: "bg-yellow-100 text-yellow-800"}"}>
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
    </div>
    """
  end
end
