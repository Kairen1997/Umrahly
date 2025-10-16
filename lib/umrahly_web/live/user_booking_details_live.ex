defmodule UmrahlyWeb.UserBookingDetailsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(%{"id" => id}, _session, socket) do
    case Bookings.get_booking_with_details(id) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/my-bookings")}

      booking ->
        # Ensure the booking belongs to the current user
        if booking.user_id == socket.assigns.current_user.id do
          socket =
            socket
            |> assign(:page_title, "Booking Details")
            |> assign(:booking, booking)

          {:ok, socket}
        else
          {:ok, push_navigate(socket, to: ~p"/my-bookings")}
        end
    end
  end

  defp format_amount(nil), do: "0.00"
  defp format_amount(%Decimal{} = amount) do
    :erlang.float_to_binary(Decimal.to_float(amount), [decimals: 2])
  end
  defp format_amount(amount) when is_number(amount), do: :erlang.float_to_binary(amount * 1.0, [decimals: 2])
  defp format_amount(amount) when is_binary(amount) do
    case Float.parse(amount) do
      {num, _} -> :erlang.float_to_binary(num, [decimals: 2])
      :error -> "0.00"
    end
  end
  defp format_amount(_), do: "0.00"

  defp calculate_remaining_amount(total_amount, paid_amount) do
    total = total_amount || Decimal.new(0)
    paid = paid_amount || Decimal.new(0)
    Decimal.sub(total, paid)
  end

  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div class="p-6">
        <div class="mb-6">
          <a href="/my-bookings" class="text-blue-600 hover:text-blue-800 text-sm font-medium">
            ← Back to My Bookings
          </a>
        </div>

        <div class="bg-white rounded-lg shadow-sm ring-1 ring-gray-200 overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200">
            <h1 class="text-2xl font-semibold text-gray-900">Booking Details</h1>
            <p class="mt-1 text-sm text-gray-500">Reference: #<%= @booking.booking_reference %></p>
          </div>

          <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <!-- Booking Information -->
              <div>
                <h3 class="text-lg font-medium text-gray-900 mb-4">Booking Information</h3>
                <dl class="space-y-3">
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Booking Reference</dt>
                    <dd class="text-sm text-gray-900">#<%= @booking.booking_reference %></dd>
                  </div>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Package</dt>
                    <dd class="text-sm text-gray-900"><%= @booking.package_name %></dd>
                  </div>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Status</dt>
                    <dd class="text-sm">
                      <span class={["inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                        if(String.downcase(@booking.status || "") == "confirmed", do: "bg-green-100 text-green-800", else: "bg-blue-100 text-blue-800")
                      ]}>
                        <%= String.upcase(@booking.status || "PENDING") %>
                      </span>
                    </dd>
                  </div>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Booking Date</dt>
                    <dd class="text-sm text-gray-900">
                      <%= if @booking.booking_date do %>
                        <%= UmrahlyWeb.Timezone.format_local(@booking.booking_date, "%B %d, %Y") %>
                      <% else %>
                        -
                      <% end %>
                    </dd>
                  </div>
                </dl>
              </div>

              <!-- Payment Information -->
              <div>
                <h3 class="text-lg font-medium text-gray-900 mb-4">Payment Information</h3>
                <dl class="space-y-3">
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Total Amount</dt>
                    <dd class="text-sm text-gray-900">RM <%= format_amount(@booking.total_amount) %></dd>
                  </div>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Paid Amount</dt>
                    <dd class="text-sm text-green-700">RM <%= format_amount(@booking.paid_amount || 0) %></dd>
                  </div>
                  <div>
                    <dt class="text-sm font-medium text-gray-500">Remaining Amount</dt>
                    <dd class="text-sm text-red-700">
                      RM <%= format_amount(calculate_remaining_amount(@booking.total_amount, @booking.paid_amount)) %>
                    </dd>
                  </div>
                </dl>
              </div>
            </div>

            <!-- Travelers Information -->
            <%= if @booking.travelers && length(@booking.travelers) > 0 do %>
              <div class="mt-8">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Travelers</h3>
                <div class="overflow-x-auto">
                  <table class="min-w-full divide-y divide-gray-200">
                    <thead class="bg-gray-50">
                      <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Passport</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Phone</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Relationship</th>
                      </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                      <%= for traveler <- @booking.travelers do %>
                        <tr>
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            <%= traveler["full_name"] || "-" %>
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700">
                            <%= traveler["passport_number"] || "-" %>
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700">
                            <%= traveler["phone"] || "-" %>
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700">
                            <%= traveler["relationship"] || "-" %>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            <% end %>

            <!-- Actions -->
            <div class="mt-8 flex justify-end space-x-3">
              <%= if Decimal.compare(calculate_remaining_amount(@booking.total_amount, @booking.paid_amount), Decimal.new(0)) == :gt do %>
                <a href="/payments" class="inline-flex items-center px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700">
                  Make Payment
                </a>
              <% end %>
              <a href="/my-bookings" class="inline-flex items-center px-4 py-2 bg-gray-600 text-white text-sm font-medium rounded-md hover:bg-gray-700">
                Back to Bookings
              </a>
            </div>
          </div>
        </div>
      </div>
    </.sidebar>
    """
  end
end
