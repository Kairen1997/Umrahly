defmodule UmrahlyWeb.AdminPaymentDetailsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  import Ecto.Query, warn: false
  alias Umrahly.Repo
  alias Umrahly.Bookings.BookingFlowProgress
  alias Umrahly.Bookings.Booking

  def mount(%{"id" => id, "source" => source}, _session, socket) do
    payment_details = load_payment_details(id, source)

    socket =
      socket
      |> assign(:payment_details, payment_details)
      |> assign(:current_page, "payments")
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns.current_user)

    {:ok, socket}
  rescue
    _e ->
      {:ok, socket |> put_flash(:error, "Payment not found") |> redirect(to: "/admin/payments")}
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

    case result do
      :ok ->
        # Reload payment details
        payment_details = load_payment_details(id, source)
        {:noreply, socket |> assign(:payment_details, payment_details) |> put_flash(:info, "Payment processed successfully")}
      :error ->
        {:noreply, socket |> put_flash(:error, "Failed to process payment")}
    end
  end

  defp load_payment_details(id, source) do
    case source do
      "booking" ->
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
    UmrahlyWeb.Timezone.format_local(datetime, "%Y-%m-%d %H:%M")
  end

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-4xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <!-- Header -->
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center">
              <.link navigate="/admin/payments" class="text-gray-500 hover:text-gray-700 mr-4">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
                </svg>
              </.link>
              <h1 class="text-2xl font-bold text-gray-900">Payment Details</h1>
            </div>
            <div class="flex items-center gap-3">
              <span class={[
                "inline-flex px-3 py-1 text-sm font-semibold rounded-full",
                case @payment_details.status do
                  "completed" -> "bg-green-100 text-green-800"
                  "confirmed" -> "bg-green-100 text-green-800"
                  "pending" -> "bg-blue-100 text-blue-800"
                  "in_progress" -> "bg-blue-100 text-blue-800"
                  "cancelled" -> "bg-red-100 text-red-800"
                  "abandoned" -> "bg-red-100 text-red-800"
                  _ -> "bg-gray-100 text-gray-800"
                end
              ]}>
                <%= String.replace(@payment_details.status, "_", " ") |> String.capitalize() %>
              </span>
            </div>
          </div>

          <!-- Payment Information -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Left Column -->
            <div class="space-y-6">
              <!-- Basic Information -->
              <div class="bg-gray-50 p-4 rounded-lg">
                <h3 class="text-lg font-semibold mb-4">Basic Information</h3>
                <div class="space-y-3">
                  <div>
                    <div class="text-sm text-gray-500">Payment ID</div>
                    <div class="font-medium">#<%= @payment_details.id %></div>
                  </div>
                  <div>
                    <div class="text-sm text-gray-500">Type</div>
                    <div class="font-medium capitalize"><%= @payment_details.source %></div>
                  </div>
                  <div>
                    <div class="text-sm text-gray-500">Date</div>
                    <div class="font-medium"><%= format_date(@payment_details.inserted_at) %></div>
                  </div>
                </div>
              </div>

              <!-- Customer Information -->
              <div class="bg-gray-50 p-4 rounded-lg">
                <h3 class="text-lg font-semibold mb-4">Customer Information</h3>
                <div class="space-y-3">
                  <div>
                    <div class="text-sm text-gray-500">Name</div>
                    <div class="font-medium"><%= @payment_details.user && @payment_details.user.full_name %></div>
                  </div>
                  <div>
                    <div class="text-sm text-gray-500">Email</div>
                    <div class="font-medium"><%= @payment_details.user && @payment_details.user.email %></div>
                  </div>
                  <div>
                    <div class="text-sm text-gray-500">Number of Persons</div>
                    <div class="font-medium"><%= @payment_details.number_of_persons %></div>
                  </div>
                </div>
              </div>

              <!-- Package Information -->
              <div class="bg-gray-50 p-4 rounded-lg">
                <h3 class="text-lg font-semibold mb-4">Package Information</h3>
                <div class="space-y-3">
                  <div>
                    <div class="text-sm text-gray-500">Package Name</div>
                    <div class="font-medium"><%= @payment_details.package && @payment_details.package.name %></div>
                  </div>
                  <%= if @payment_details.package_schedule do %>
                    <div>
                      <div class="text-sm text-gray-500">Schedule</div>
                      <div class="font-medium">
                        <%= if @payment_details.package_schedule.departure_date do %>
                          Departure: <%= UmrahlyWeb.Timezone.format_local(@payment_details.package_schedule.departure_date, "%Y-%m-%d") %>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Right Column -->
            <div class="space-y-6">
              <!-- Payment Details -->
              <div class="bg-gray-50 p-4 rounded-lg">
                <h3 class="text-lg font-semibold mb-4">Payment Details</h3>
                <div class="space-y-3">
                  <div>
                    <div class="text-sm text-gray-500">Payment Method</div>
                    <div class="font-medium capitalize"><%= String.replace(@payment_details.payment_method || "", "_", " ") %></div>
                  </div>
                  <div>
                    <div class="text-sm text-gray-500">Payment Plan</div>
                    <div class="font-medium capitalize"><%= String.replace(@payment_details.payment_plan || "", "_", " ") %></div>
                  </div>
                  <div>
                    <div class="text-sm text-gray-500">Total Amount</div>
                    <div class="font-medium text-lg text-green-600"><%= format_amount(@payment_details.total_amount) %></div>
                  </div>
                  <%= if @payment_details.deposit_amount do %>
                    <div>
                      <div class="text-sm text-gray-500">Deposit Amount</div>
                      <div class="font-medium"><%= format_amount(@payment_details.deposit_amount) %></div>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Progress (for booking flow progress) -->
              <%= if @payment_details.source == "progress" and @payment_details.current_step do %>
                <div class="bg-gray-50 p-4 rounded-lg">
                  <h3 class="text-lg font-semibold mb-4">Progress</h3>
                  <div class="space-y-3">
                    <div>
                      <div class="text-sm text-gray-500">Current Step</div>
                      <div class="font-medium"><%= @payment_details.current_step %> of <%= @payment_details.max_steps %></div>
                    </div>
                    <div class="w-full bg-gray-200 rounded-full h-3">
                      <div class="bg-blue-600 h-3 rounded-full" style={"width: #{min(100, max(0, round(@payment_details.current_step / @payment_details.max_steps * 100)))}%"}>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Payment Proof (for bookings) -->
              <%= if @payment_details.source == "booking" do %>
                <div class="bg-gray-50 p-4 rounded-lg">
                  <h3 class="text-lg font-semibold mb-4">Payment Proof</h3>
                  <div class="space-y-3">
                    <div>
                      <div class="text-sm text-gray-500">Status</div>
                      <div class="font-medium capitalize"><%= @payment_details.payment_proof_status || "Not uploaded" %></div>
                    </div>
                    <%= if @payment_details.payment_proof_file do %>
                      <div>
                        <div class="text-sm text-gray-500 mb-1">File</div>
                        <a class="text-blue-600 hover:underline inline-flex items-center" href={"/uploads/payment_proof/#{@payment_details.payment_proof_file}"} target="_blank">
                          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
                          </svg>
                          View Proof
                        </a>
                      </div>
                    <% else %>
                      <div class="text-gray-500 text-sm">No file uploaded</div>
                    <% end %>
                    <%= if @payment_details.payment_proof_notes do %>
                      <div>
                        <div class="text-sm text-gray-500">Notes</div>
                        <div class="text-sm bg-white p-2 rounded border"><%= @payment_details.payment_proof_notes %></div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Travelers Information (for progress) -->
          <%= if @payment_details.source == "progress" and is_list(@payment_details.travelers_data) and length(@payment_details.travelers_data) > 0 do %>
            <div class="mt-6 bg-gray-50 p-4 rounded-lg">
              <h3 class="text-lg font-semibold mb-4">Travelers Information</h3>
              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gray-100">
                    <tr>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">#</th>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Full Name</th>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Identity Card</th>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Passport</th>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Phone</th>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Address</th>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">City</th>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">State</th>
                      <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Citizenship</th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    <%= for {traveler, index} <- Enum.with_index(@payment_details.travelers_data, 1) do %>
                      <tr class="hover:bg-gray-50">
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900"><%= index %></td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">
                          <%= traveler["full_name"] || traveler[:full_name] || "Unknown" %>
                        </td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                          <%= traveler["identity_card_number"] || traveler[:identity_card_number] || "-" %>
                        </td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                          <%= traveler["passport_number"] || traveler[:passport_number] || "-" %>
                        </td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                          <%= if traveler["phone"] || traveler[:phone] do %>
                            <span class="inline-flex items-center">
                              <svg class="w-4 h-4 mr-1 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"></path>
                              </svg>
                              <%= traveler["phone"] || traveler[:phone] %>
                            </span>
                          <% else %>
                            <span class="text-gray-400">-</span>
                          <% end %>
                        </td>
                        <td class="px-4 py-3 text-sm text-gray-900">
                          <%= traveler["address"] || traveler[:address] || "-" %>
                        </td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                          <%= traveler["city"] || traveler[:city] || "-" %>
                        </td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                          <%= traveler["state"] || traveler[:state] || "-" %>
                        </td>
                        <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                          <%= traveler["citizenship"] || traveler[:citizenship] || traveler["nationality"] || traveler[:nationality] || "-" %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          <% end %>

         <.link
          navigate={"/admin/payments/#{@payment_details.id}/#{@payment_details.source}/refund"}
          class="px-3 py-1 rounded bg-red-600 text-white text-sm hover:bg-red-700 transition-colors">
          Refund
        </.link>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
