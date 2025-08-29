defmodule UmrahlyWeb.UserActiveBookingsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    # Get all active booking flows for the current user
    active_bookings = Bookings.get_booking_flow_progress_by_user_id(socket.assigns.current_user.id)

    socket =
      socket
      |> assign(:active_bookings, active_bookings)
      |> assign(:page_title, "Active Bookings")

    {:ok, socket}
  end

  def handle_event("resume_booking", %{"id" => id}, socket) do
    # Find the booking flow progress
    case Enum.find(socket.assigns.active_bookings, &(&1.id == String.to_integer(id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Booking flow not found")}
      booking_flow ->
        # Redirect to the booking flow with the saved progress
        {:noreply, push_navigate(socket, to: ~p"/book/#{booking_flow.package_id}/#{booking_flow.package_schedule_id}?resume=true")}
    end
  end

  def handle_event("abandon_booking", %{"id" => id}, socket) do
    # Find the booking flow progress and mark it as abandoned
    case Enum.find(socket.assigns.active_bookings, &(&1.id == String.to_integer(id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Booking flow not found")}
      _booking_flow ->
        # In a real implementation, you would call Bookings.abandon_booking_flow_progress/1
        # For now, we'll just remove it from the list
        updated_bookings = Enum.reject(socket.assigns.active_bookings, &(&1.id == String.to_integer(id)))

        socket =
          socket
          |> assign(:active_bookings, updated_bookings)
          |> put_flash(:info, "Booking flow abandoned")

        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div class="max-w-6xl mx-auto space-y-6">
        <!-- Header -->
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">Active Bookings</h1>
              <p class="text-gray-600 mt-1">Resume your incomplete booking flows or start a new one</p>
            </div>
            <a
              href="/packages"
              class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
            >
              Browse Packages
            </a>
          </div>
        </div>

        <%= if Enum.empty?(@active_bookings) do %>
          <!-- No Active Bookings -->
          <div class="bg-white rounded-lg shadow p-8 text-center">
            <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No Active Bookings</h3>
            <p class="text-gray-600 mb-6">You don't have any incomplete booking flows. Start booking a package to get started!</p>
            <a
              href="/packages"
              class="inline-block bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
            >
              Browse Packages
            </a>
          </div>
        <% else %>
          <!-- Active Bookings List -->
          <div class="space-y-6">
            <%= for booking <- @active_bookings do %>
              <div class="bg-white rounded-lg shadow overflow-hidden">
                <!-- Main Booking Header -->
                <div class="p-6 border-b border-gray-200">
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <div class="flex items-center space-x-3 mb-3">
                        <h3 class="text-xl font-semibold text-gray-900"><%= booking.package.name %></h3>
                        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
                          Step <%= booking.current_step %> of <%= booking.max_steps %>
                        </span>
                        <span class={[
                          "inline-flex items-center px-3 py-1 rounded-full text-sm font-medium",
                          case booking.status do
                            "in_progress" -> "bg-yellow-100 text-yellow-800"
                            "completed" -> "bg-green-100 text-green-800"
                            "abandoned" -> "bg-red-100 text-red-800"
                            _ -> "bg-gray-100 text-gray-800"
                          end
                        ]}>
                          <%= String.upcase(String.replace(booking.status, "_", " ")) %>
                        </span>
                      </div>

                      <!-- Package and Schedule Details -->
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-gray-600 mb-4">
                        <div>
                          <span class="font-medium text-gray-900">Travel Dates:</span>
                          <div class="mt-1">
                            <div>Departure: <%= Calendar.strftime(booking.package_schedule.departure_date, "%B %d, %Y") %></div>
                            <div>Return: <%= Calendar.strftime(booking.package_schedule.return_date, "%B %d, %Y") %></div>
                          </div>
                        </div>
                        <div>
                          <span class="font-medium text-gray-900">Package Details:</span>
                          <div class="mt-1">
                            <div>Type: <%= String.upcase(String.replace(booking.package.accommodation_type || "standard", "_", " ")) %></div>
                            <div>Price: RM <%= booking.package.price %></div>
                            <%= if booking.package_schedule.price_override && Decimal.gt?(booking.package_schedule.price_override, Decimal.new(0)) do %>
                              <div class="text-orange-600">Override: +RM <%= booking.package_schedule.price_override %></div>
                            <% end %>
                          </div>
                        </div>
                      </div>

                      <!-- Payment Information -->
                      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm text-gray-600 mb-4">
                        <div>
                          <span class="font-medium text-gray-900">Payment Method:</span>
                          <div class="mt-1">
                            <span class={[
                              "inline-flex items-center px-2 py-1 rounded text-xs font-medium",
                              case booking.payment_method do
                                "credit_card" -> "bg-purple-100 text-purple-800"
                                "bank_transfer" -> "bg-blue-100 text-blue-800"
                                "online_banking" -> "bg-green-100 text-green-800"
                                "cash" -> "bg-yellow-100 text-yellow-800"
                                "e_wallet" -> "bg-orange-100 text-orange-800"
                                _ -> "bg-gray-100 text-gray-800"
                              end
                            ]}>
                              <%= String.upcase(String.replace(booking.payment_method || "Not selected", "_", " ")) %>
                            </span>
                          </div>
                        </div>
                        <div>
                          <span class="font-medium text-gray-900">Payment Plan:</span>
                          <div class="mt-1">
                            <span class={[
                              "inline-flex items-center px-2 py-1 rounded text-xs font-medium",
                              case booking.payment_plan do
                                "full_payment" -> "bg-green-100 text-green-800"
                                "installment" -> "bg-blue-100 text-blue-800"
                                _ -> "bg-gray-100 text-gray-800"
                              end
                            ]}>
                              <%= String.upcase(String.replace(booking.payment_plan || "Not selected", "_", " ")) %>
                            </span>
                          </div>
                        </div>
                        <div>
                          <span class="font-medium text-gray-900">Amounts:</span>
                          <div class="mt-1">
                            <%= if booking.total_amount do %>
                              <div>Total: RM <%= booking.total_amount %></div>
                              <%= if booking.deposit_amount && Decimal.compare(booking.deposit_amount, booking.total_amount) != :eq do %>
                                <div class="text-orange-600">Deposit: RM <%= booking.deposit_amount %></div>
                              <% end %>
                            <% else %>
                              <div class="text-gray-500">Not calculated yet</div>
                            <% end %>
                          </div>
                        </div>
                      </div>

                      <div class="text-xs text-gray-500">
                        Last updated: <%= Calendar.strftime(booking.last_updated, "%B %d, %Y at %I:%M %p") %>
                      </div>
                    </div>

                    <div class="flex flex-col space-y-2 ml-4">
                      <button
                        phx-click="resume_booking"
                        phx-value-id={booking.id}
                        class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium text-sm"
                      >
                        Resume Booking
                      </button>
                      <button
                        phx-click="abandon_booking"
                        phx-value-id={booking.id}
                        class="bg-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium text-sm"
                      >
                        Abandon
                      </button>
                    </div>
                  </div>

                  <!-- Progress Bar -->
                  <div class="mt-4">
                    <div class="w-full bg-gray-200 rounded-full h-2">
                      <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{Float.round((booking.current_step / booking.max_steps) * 100, 1)}%"}>
                      </div>
                    </div>
                    <div class="flex justify-between text-xs text-gray-500 mt-1">
                      <span>Package Details</span>
                      <span>Travelers</span>
                      <span>Payment</span>
                      <span>Review</span>
                      <span>Success</span>
                    </div>
                  </div>
                </div>

                <!-- Traveler Details Section -->
                <div class="p-6 bg-gray-50">
                  <h4 class="text-lg font-medium text-gray-900 mb-4 flex items-center">
                    <svg class="w-5 h-5 mr-2 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                    </svg>
                    Traveler Details (<%= booking.number_of_persons %> person<%= if booking.number_of_persons > 1, do: "s", else: "" %>)
                  </h4>

                  <%= if booking.travelers_data && length(booking.travelers_data) > 0 do %>
                    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                      <%= for {traveler, index} <- Enum.with_index(booking.travelers_data) do %>
                        <div class="bg-white rounded-lg border border-gray-200 p-4">
                          <div class="flex items-center justify-between mb-3">
                            <h5 class="font-medium text-gray-900">
                              Traveler <%= index + 1 %>
                              <%= if index == 0 && booking.is_booking_for_self do %>
                                <span class="text-xs text-blue-600 bg-blue-50 px-2 py-1 rounded ml-2">Primary</span>
                              <% end %>
                            </h5>
                          </div>

                          <div class="space-y-2 text-sm">
                            <div>
                              <span class="font-medium text-gray-700">Name:</span>
                              <div class="text-gray-900"><%= traveler["full_name"] || "Not provided" %></div>
                            </div>
                            <div>
                              <span class="font-medium text-gray-700">ID:</span>
                              <div class="text-gray-900">
                                <%= if traveler["identity_card_number"] && traveler["identity_card_number"] != "" do %>
                                  <%= traveler["identity_card_number"] %>
                                <% else %>
                                  <%= traveler["passport_number"] || "Not provided" %>
                                <% end %>
                              </div>
                            </div>
                            <div>
                              <span class="font-medium text-gray-700">Phone:</span>
                              <div class="text-gray-900"><%= traveler["phone"] || "Not provided" %></div>
                            </div>
                            <%= if traveler["date_of_birth"] && traveler["date_of_birth"] != "" do %>
                              <div>
                                <span class="font-medium text-gray-700">Birth Date:</span>
                                <div class="text-gray-900"><%= traveler["date_of_birth"] %></div>
                              </div>
                            <% end %>
                            <%= if traveler["address"] && traveler["address"] != "" do %>
                              <div>
                                <span class="font-medium text-gray-700">Address:</span>
                                <div class="text-gray-900">
                                  <%= traveler["address"] %>
                                  <%= if traveler["poskod"] && traveler["poskod"] != "" do %>
                                    <br><%= traveler["poskod"] %>
                                  <% end %>
                                  <%= if traveler["city"] && traveler["city"] != "" do %>
                                    <br><%= traveler["city"] %><%= if traveler["state"] && traveler["state"] != "", do: ", #{traveler["state"]}", else: "" %>
                                  <% end %>
                                </div>
                              </div>
                            <% end %>
                            <%= if traveler["emergency_contact_name"] && traveler["emergency_contact_name"] != "" do %>
                              <div>
                                <span class="font-medium text-gray-700">Emergency Contact:</span>
                                <div class="text-gray-900">
                                  <%= traveler["emergency_contact_name"] %>
                                  <%= if traveler["emergency_contact_phone"] && traveler["emergency_contact_phone"] != "" do %>
                                    <br><%= traveler["emergency_contact_phone"] %>
                                  <% end %>
                                </div>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% else %>
                    <div class="text-center py-8">
                      <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
                        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
                        </svg>
                      </div>
                      <h5 class="text-lg font-medium text-gray-900 mb-2">No Traveler Information Yet</h5>
                      <p class="text-gray-600">Traveler details will be collected in the next step of your booking process.</p>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </.sidebar>
    """
  end
end
