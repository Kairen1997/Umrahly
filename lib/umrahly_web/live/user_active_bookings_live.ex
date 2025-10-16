defmodule UmrahlyWeb.UserActiveBookingsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    # Get all active booking flows for the current user
    active_bookings = Bookings.get_booking_flow_progress_by_user_id(socket.assigns.current_user.id)

    # Enrich with latest booking to show payment-proof status
    enriched = Enum.map(active_bookings, fn progress ->
      latest_booking =
        Bookings.get_latest_booking_for_user_schedule(
          socket.assigns.current_user.id,
          progress.package_schedule_id
        )

      Map.put(progress, :_latest_booking, latest_booking)
    end)

    socket =
      socket
      |> assign(:active_bookings, enriched)
      |> assign(:page_title, "Active Bookings")
      |> assign(:booking_to_cancel, nil)
      |> assign(:show_cancel_modal, false)
      |> assign(:notifications, [])
      |> assign(:unread_notifications, 0)

    # Subscribe to admin notifications
    Phoenix.PubSub.subscribe(Umrahly.PubSub, "admin:notifications")
    Phoenix.PubSub.subscribe(Umrahly.PubSub, "user:notifications:#{socket.assigns.current_user.id}")

    {:ok, socket}
  end

  def handle_event("resume_booking", %{"id" => id}, socket) do
    # Find the booking flow progress
    case Enum.find(socket.assigns.active_bookings, &(&1.id == String.to_integer(id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Booking flow not found")}
      booking_flow ->
        # Prevent resuming if payment has been approved for full payment plan only
        if booking_flow._latest_booking &&
             booking_flow._latest_booking.payment_proof_status == "approved" &&
             booking_flow.payment_plan == "full_payment" do
          {:noreply, put_flash(socket, :info, "Payment approved. Please wait for your flight schedule.")}
        else
          # Redirect to the booking flow with the saved progress
          {:noreply, push_navigate(socket, to: ~p"/book/#{booking_flow.package_id}/#{booking_flow.package_schedule_id}?resume=true")}
        end
    end
  end

  def handle_event("upload_or_resubmit_proof", %{"progress_id" => id}, socket) do
    case Enum.find(socket.assigns.active_bookings, &(&1.id == String.to_integer(id))) do
      nil -> {:noreply, put_flash(socket, :error, "Booking flow not found")}
      booking_flow ->
        {:noreply, push_navigate(socket, to: ~p"/book/#{booking_flow.package_id}/#{booking_flow.package_schedule_id}?resume=true&jump_to=success")}
    end
  end

  def handle_event("view_proof", %{"progress_id" => id}, socket) do
    case Enum.find(socket.assigns.active_bookings, &(&1.id == String.to_integer(id))) do
      nil -> {:noreply, put_flash(socket, :error, "No proof uploaded yet")}
      booking_flow ->
        case booking_flow._latest_booking do
          nil -> {:noreply, put_flash(socket, :error, "No proof uploaded yet")}
          booking ->
            if booking.payment_proof_file do
              url = "/uploads/payment_proof/" <> booking.payment_proof_file
              {:noreply, push_event(socket, "js:open-url", %{url: url})}
            else
              {:noreply, put_flash(socket, :error, "No proof file found")}
            end
        end
    end
  end

  def handle_event("cancel_booking", %{"id" => id}, socket) do
    # Find the booking flow progress and mark it as cancelled
    case Enum.find(socket.assigns.active_bookings, &(&1.id == String.to_integer(id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Booking flow not found")}
      booking_flow ->
        # Call the Bookings module to cancel the booking flow progress
        case Bookings.update_booking_flow_progress(booking_flow, %{status: "abandoned", last_updated: DateTime.utc_now()}) do
          {:ok, _cancelled_booking} ->
            # Log the cancellation activity
            Umrahly.ActivityLogs.log_user_action(
              socket.assigns.current_user.id,
              "Booking Cancelled",
              "User cancelled booking for package: #{booking_flow.package.name}",
              %{
                booking_flow_id: booking_flow.id,
                package_id: booking_flow.package_id,
                package_name: booking_flow.package.name,
                package_schedule_id: booking_flow.package_schedule_id,
                cancellation_reason: "user_initiated"
              }
            )

            # Notify admin about the cancellation
            Phoenix.PubSub.broadcast(Umrahly.PubSub, "admin:notifications", {
              :booking_cancelled,
              %{
                user_id: socket.assigns.current_user.id,
                user_name: socket.assigns.current_user.full_name || socket.assigns.current_user.email,
                booking_flow_id: booking_flow.id,
                package_name: booking_flow.package.name,
                package_schedule_id: booking_flow.package_schedule_id,
                cancelled_at: DateTime.utc_now()
              }
            })

            # Remove the cancelled booking from the list
            updated_bookings = Enum.reject(socket.assigns.active_bookings, &(&1.id == String.to_integer(id)))

            socket =
              socket
              |> assign(:active_bookings, updated_bookings)
              |> put_flash(:info, "Booking has been cancelled successfully. Admin has been notified.")
              |> push_event("js:hide-modal", %{modal_id: "cancel-booking-modal"})

            {:noreply, socket}
          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to cancel booking. Please try again.")}
        end
    end
  end

  def handle_event("show_cancel_confirmation", %{"id" => id}, socket) do
    # Find the booking to cancel
    booking_to_cancel = Enum.find(socket.assigns.active_bookings, &(&1.id == String.to_integer(id)))

    socket =
      socket
      |> assign(:booking_to_cancel, booking_to_cancel)
      |> assign(:show_cancel_modal, true)

    {:noreply, socket}
  end

  def handle_event("confirm_cancel_booking", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.active_bookings, &(&1.id == String.to_integer(id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Booking flow not found")}
      booking_flow ->
        # Call the Bookings module to cancel the booking flow progress
        case Bookings.update_booking_flow_progress(booking_flow, %{status: "abandoned", last_updated: DateTime.utc_now()}) do
          {:ok, _cancelled_booking} ->
            # Remove the cancelled booking from the list
            updated_bookings = Enum.reject(socket.assigns.active_bookings, &(&1.id == String.to_integer(id)))

            socket =
              socket
              |> assign(:active_bookings, updated_bookings)
              |> put_flash(:info, "Booking has been cancelled successfully")

            {:noreply, socket}
          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to cancel booking. Please try again.")}
        end
    end
  end

  def handle_event("cancel_cancel_booking", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.active_bookings, &(&1.id == String.to_integer(id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Booking flow not found")}
      booking_flow ->
        socket =
          socket
          |> assign(:booking_to_cancel, booking_flow)
          |> assign(:show_cancel_modal, false)

        {:noreply, socket}
    end
  end

  def handle_event("hide_cancel_modal", _params, socket) do
    {:noreply, assign(socket, :show_cancel_modal, false)}
  end

  def handle_event("toggle_notifications", _params, socket) do
    # Toggle notification dropdown visibility
    {:noreply, push_event(socket, "js:toggle-notifications", %{})}
  end


  def handle_event("mark_all_read", _params, socket) do
    # Mark all notifications as read
    updated_notifications = Enum.map(socket.assigns.notifications, &Map.put(&1, :read, true))
    unread_count = 0

    socket =
      socket
      |> assign(:notifications, updated_notifications)
      |> assign(:unread_notifications, unread_count)

    {:noreply, socket}
  end

  def handle_info({:booking_cancelled, notification}, socket) do
    # Log the cancellation for admin
    Umrahly.ActivityLogs.log_user_action(
      socket.assigns.current_user.id,
      "Admin Notified: Booking Cancelled",
      "User #{notification.user_name} cancelled booking for #{notification.package_name}",
      %{
        cancelled_user_id: notification.user_id,
        cancelled_user_name: notification.user_name,
        booking_flow_id: notification.booking_flow_id,
        package_name: notification.package_name,
        cancelled_at: notification.cancelled_at
      }
    )

    # Add notification for user
    new_notification = %{
      id: System.unique_integer([:positive]),
      title: "Booking Cancelled",
      message: "Your booking for #{notification.package_name} has been cancelled",
      timestamp: DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.to_string(),
      read: false
    }

    updated_notifications = [new_notification | socket.assigns.notifications]
    unread_count = socket.assigns.unread_notifications + 1

    socket =
      socket
      |> assign(:notifications, updated_notifications)
      |> assign(:unread_notifications, unread_count)
      |> put_flash(:info, "Booking cancelled successfully")

    {:noreply, socket}
  end



  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title} flash={@flash}>
      <div class="max-w-6xl mx-auto space-y-6">
        <!-- Header -->
        <div class="bg-white/80 backdrop-blur rounded-xl shadow-sm ring-1 ring-gray-200 p-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-gray-900 tracking-tight">Active Bookings</h1>
              <p class="text-gray-600 mt-1">Resume your incomplete booking flows or start a new one</p>
            </div>
            <a
              href="/packages"
              class="inline-flex items-center gap-2 bg-blue-600 text-white px-5 py-2 rounded-lg hover:bg-blue-700 active:bg-blue-800 shadow-sm transition-colors font-medium"
            >
              Browse Packages
            </a>
          </div>
        </div>

        <%= if Enum.empty?(@active_bookings) do %>
          <!-- No Active Bookings -->
          <div class="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 p-10 text-center">
            <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-gray-900 mb-2">No Active Bookings</h3>
            <p class="text-gray-600 mb-6">You don't have any incomplete booking flows. Start booking a package to get started!</p>
            <a
              href="/packages"
              class="inline-block bg-blue-600 text-white px-5 py-2 rounded-lg hover:bg-blue-700 active:bg-blue-800 shadow-sm transition-colors font-medium"
            >
              Browse Packages
            </a>
          </div>
        <% else %>
          <!-- Active Bookings List -->
          <div class="space-y-6">
            <%= for booking <- @active_bookings do %>
              <div class="bg-white rounded-xl shadow-sm ring-1 ring-gray-200 overflow-hidden hover:shadow-md transition-shadow">
                <!-- Main Booking Header -->
                <div class="p-6 border-b border-gray-200">
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <div class="flex flex-wrap items-center gap-2 mb-3">
                        <h3 class="text-xl font-semibold text-gray-900 mr-2"><%= booking.package.name %></h3>
                        <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-blue-50 text-blue-700 ring-1 ring-blue-200">
                          Step <%= booking.current_step %> of <%= booking.max_steps %>
                        </span>
                        <span class={[
                          "inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold ring-1",
                          case booking.status do
                            "in_progress" -> "bg-yellow-50 text-yellow-800 ring-yellow-200"
                            "completed" -> "bg-green-50 text-green-800 ring-green-200"
                            "abandoned" -> "bg-red-50 text-red-800 ring-red-200"
                            _ -> "bg-gray-50 text-gray-800 ring-gray-200"
                          end
                        ]}>
                          <%= String.upcase(String.replace(booking.status, "_", " ")) %>
                        </span>
                        <%= if booking._latest_booking && booking._latest_booking.payment_proof_status do %>
                          <span class={[
                            "inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold ring-1",
                            case booking._latest_booking.payment_proof_status do
                              "approved" -> "bg-green-50 text-green-800 ring-green-200"
                              "submitted" -> "bg-amber-50 text-amber-800 ring-amber-200"
                              "rejected" -> "bg-red-50 text-red-800 ring-red-200"
                              _ -> "bg-gray-50 text-gray-800 ring-gray-200"
                            end
                          ]}>
                            PROOF: <%= String.upcase(booking._latest_booking.payment_proof_status) %>
                          </span>
                        <% end %>
                      </div>

                      <!-- Package and Schedule Details -->
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 text-sm text-gray-700 mb-4">
                        <div>
                          <span class="font-semibold text-gray-900">Travel Dates:</span>
                          <div class="mt-1 space-y-0.5">
                            <div>Departure: <%= Calendar.strftime(booking.package_schedule.departure_date, "%B %d, %Y") %></div>
                            <div>Return: <%= Calendar.strftime(booking.package_schedule.return_date, "%B %d, %Y") %></div>
                          </div>
                        </div>
                        <div>
                          <span class="font-semibold text-gray-900">Package Details:</span>
                          <div class="mt-1 space-y-0.5">
                            <div>Type: <%= String.upcase(String.replace(booking.package.accommodation_type || "standard", "_", " ")) %></div>
                            <div>Price: RM <%= booking.package.price %></div>
                          </div>
                        </div>
                      </div>

                      <!-- Payment Information -->
                      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 text-sm text-gray-700 mb-4">
                        <div>
                          <span class="font-semibold text-gray-900">Payment Method:</span>
                          <div class="mt-1">
                            <span class={[
                              "inline-flex items-center px-2.5 py-1 rounded-md text-xs font-semibold ring-1",
                              case booking.payment_method do
                                "credit_card" -> "bg-purple-50 text-purple-700 ring-purple-200"
                                "bank_transfer" -> "bg-blue-50 text-blue-700 ring-blue-200"
                                "online_banking" -> "bg-green-50 text-green-700 ring-green-200"
                                "cash" -> "bg-yellow-50 text-yellow-800 ring-yellow-200"
                                _ -> "bg-gray-50 text-gray-700 ring-gray-200"
                              end
                            ]}>
                              <%= String.upcase(String.replace(booking.payment_method || "Not selected", "_", " ")) %>
                            </span>
                          </div>
                        </div>
                        <div>
                          <span class="font-semibold text-gray-900">Payment Plan:</span>
                          <div class="mt-1">
                            <span class={[
                              "inline-flex items-center px-2.5 py-1 rounded-md text-xs font-semibold ring-1",
                              case booking.payment_plan do
                                "full_payment" -> "bg-green-50 text-green-700 ring-green-200"
                                "installment" -> "bg-blue-50 text-blue-700 ring-blue-200"
                                _ -> "bg-gray-50 text-gray-700 ring-gray-200"
                              end
                            ]}>
                              <%= String.upcase(String.replace(booking.payment_plan || "Not selected", "_", " ")) %>
                            </span>
                          </div>
                        </div>
                        <div>
                          <span class="font-semibold text-gray-900">Amounts:</span>
                          <div class="mt-1 space-y-0.5">
                            <% traveler_count = if booking.travelers_data && length(booking.travelers_data) > 0 do
                              length(booking.travelers_data)
                            else
                              if booking.is_booking_for_self, do: 1, else: 0
                            end %>
                            <% total_amount = if traveler_count > 0 do
                              booking.package.price * traveler_count
                            else
                              booking.package.price
                            end %>
                            <div>Total: RM <%= total_amount %></div>
                            <%= if booking.deposit_amount && traveler_count > 0 && Decimal.compare(booking.deposit_amount, Decimal.new(total_amount)) != :eq do %>
                              <div class="text-orange-600">Deposit: RM <%= booking.deposit_amount %></div>
                            <% end %>
                          </div>
                        </div>
                      </div>

                      <div class="text-xs text-gray-500">
                        Last updated: <%= UmrahlyWeb.Timezone.format_local(booking.last_updated, "%B %d, %Y at %I:%M %p") %>
                      </div>
                    </div>

                    <div class="flex flex-col space-y-2 ml-4 w-40">
                      <%= if booking._latest_booking && booking._latest_booking.payment_proof_status == "approved" && booking.payment_plan == "full_payment" do %>
                        <div class="bg-green-50 text-green-800 px-4 py-2 rounded-lg border border-green-200 text-sm text-center">
                          Payment approved. Please wait for your flight schedule.
                        </div>
                      <% else %>
                        <button
                          phx-click="resume_booking"
                          phx-value-id={booking.id}
                          class="inline-flex justify-center items-center bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 active:bg-blue-800 shadow-sm transition-colors font-medium text-sm"
                        >
                          Resume Booking
                        </button>
                      <% end %>
                      <%= if booking._latest_booking && booking._latest_booking.payment_proof_status in ["submitted", "approved", "rejected"] do %>
                        <%= if booking._latest_booking.payment_proof_status == "rejected" do %>
                          <button
                            phx-click="upload_or_resubmit_proof"
                            phx-value-progress_id={booking.id}
                            class="inline-flex justify-center items-center bg-orange-600 text-white px-4 py-2 rounded-lg hover:bg-orange-700 active:bg-orange-800 shadow-sm transition-colors font-medium text-sm"
                          >
                            Resubmit Proof
                          </button>
                          <%= if booking._latest_booking.payment_proof_file do %>
                            <a
                              href={"/uploads/payment_proof/" <> booking._latest_booking.payment_proof_file}
                              target="_blank"
                              class="inline-flex justify-center items-center bg-gray-100 text-gray-800 px-4 py-2 rounded-lg hover:bg-gray-200 active:bg-gray-300 shadow-sm transition-colors font-medium text-sm text-center"
                            >
                              View Proof
                            </a>
                          <% end %>
                        <% else %>
                          <%= if booking._latest_booking.payment_proof_file do %>
                            <a
                              href={"/uploads/payment_proof/" <> booking._latest_booking.payment_proof_file}
                              target="_blank"
                              class="inline-flex justify-center items-center bg-gray-100 text-gray-800 px-4 py-2 rounded-lg hover:bg-gray-200 active:bg-gray-300 shadow-sm transition-colors font-medium text-sm text-center"
                            >
                              View Proof
                            </a>
                          <% end %>
                        <% end %>
                      <% else %>
                        <button
                          phx-click="upload_or_resubmit_proof"
                          phx-value-progress_id={booking.id}
                          class="inline-flex justify-center items-center bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 active:bg-green-800 shadow-sm transition-colors font-medium text-sm"
                        >
                          Upload Proof
                        </button>
                      <% end %>
                      <button
                        phx-click="show_cancel_confirmation"
                        phx-value-id={booking.id}
                        class="inline-flex justify-center items-center bg-white text-red-600 px-4 py-2 rounded-lg ring-1 ring-red-300 hover:bg-red-50 active:bg-red-100 transition-colors font-medium text-sm"
                      >
                        Cancel Booking
                      </button>
                    </div>
                  </div>

                  <!-- Progress Bar -->
                  <div class="mt-4">
                    <div class="w-full bg-gray-200/80 rounded-full h-2">
                      <div class="bg-gradient-to-r from-blue-500 to-teal-500 h-2 rounded-full transition-all duration-300" style={"width: #{Float.round((booking.current_step / booking.max_steps) * 100, 1)}%"}>
                      </div>
                    </div>
                    <div class="flex justify-between text-[11px] text-gray-500 mt-1 font-medium">
                      <span>Package Details</span>
                      <span>Travelers</span>
                      <span>Payment</span>
                      <span>Review</span>
                      <span>Success</span>
                    </div>
                  </div>
                </div>

                <!-- Traveler Details Section -->
                <div id={"traveler-section-" <> to_string(booking.id)} class="p-6 bg-gray-50">
                  <div class="flex items-center justify-between mb-4">
                    <h4 class="text-lg font-medium text-gray-900 flex items-center">
                      <svg class="w-5 h-5 mr-2 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                      </svg>
                      Traveler Details (<%=
                        traveler_count = if booking.travelers_data && length(booking.travelers_data) > 0 do
                          length(booking.travelers_data)
                        else
                          if booking.is_booking_for_self, do: 1, else: 0
                        end
                        traveler_count %> person<%= if traveler_count > 1, do: "s", else: "" %>)
                    </h4>

                    <!-- Booking Type Indicator -->
                    <div class="flex items-center space-x-2">
                      <%= if booking.is_booking_for_self do %>
                        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-50 text-green-700 ring-1 ring-green-200">
                          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
                          </svg>
                          Booking for Self
                        </span>
                      <% else %>
                        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-50 text-blue-700 ring-1 ring-blue-200">
                          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                          </svg>
                          Booking for Others
                        </span>
                      <% end %>
                      <button
                        id={"toggle-travelers-" <> to_string(booking.id)}
                        data-toggle-id={"traveler-details-" <> to_string(booking.id)}
                        data-scroll-id={"traveler-list-" <> to_string(booking.id)}
                        data-scroll-offset="80"
                        data-show-text="View Travelers"
                        data-hide-text="Hide Travelers"
                        phx-hook="ToggleSection"
                        class="bg-white text-gray-800 px-3 py-1 rounded-lg ring-1 ring-gray-300 hover:bg-gray-50 transition-colors text-sm"
                      >
                        View Travelers
                      </button>
                    </div>
                  </div>

                 <!-- Toggleable traveler details wrapper -->
                 <div id={"traveler-details-" <> to_string(booking.id)} class="hidden">
                  <!-- Anchor to scroll into view just above the list -->
                  <div id={"traveler-list-" <> to_string(booking.id)}></div>

                  <%= if booking.travelers_data && length(booking.travelers_data) > 0 do %>
                    <div class="overflow-x-auto">
                      <table class="min-w-full bg-white border border-gray-200 rounded-lg shadow-sm">
                        <thead class="bg-gray-50">
                          <tr>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                              Traveler
                            </th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                              Full Name
                            </th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                              ID Number
                            </th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                              Phone
                            </th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                              Birth Date
                            </th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                              Address
                            </th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                              Emergency Contact
                            </th>
                          </tr>
                        </thead>
                        <tbody class="bg-white divide-y divide-gray-200">
                          <%= for {traveler, index} <- Enum.with_index(booking.travelers_data) do %>
                            <tr class="hover:bg-gray-50">
                              <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                <div class="flex items-center">
                                  <span>Traveler <%= index + 1 %></span>
                                  <%= if index == 0 && booking.is_booking_for_self do %>
                                    <span class="ml-2 inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                      Primary
                                    </span>
                                  <% end %>
                                </div>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= traveler["full_name"] || "Not provided" %>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= if traveler["identity_card_number"] && traveler["identity_card_number"] != "" do %>
                                  <%= traveler["identity_card_number"] %>
                                <% else %>
                                  <%= traveler["passport_number"] || "Not provided" %>
                                <% end %>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= traveler["phone"] || "Not provided" %>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= traveler["date_of_birth"] || "Not provided" %>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= if traveler["address"] && traveler["address"] != "" do %>
                                  <div class="max-w-xs">
                                    <div><%= traveler["address"] %></div>
                                    <%= if traveler["poskod"] && traveler["poskod"] != "" do %>
                                      <div class="text-gray-500"><%= traveler["poskod"] %></div>
                                    <% end %>
                                    <%= if traveler["city"] && traveler["city"] != "" do %>
                                      <div class="text-gray-500">
                                        <%= traveler["city"] %><%= if traveler["state"] && traveler["state"] != "", do: ", #{traveler["state"]}", else: "" %>
                                      </div>
                                    <% end %>
                                  </div>
                                <% else %>
                                  Not provided
                                <% end %>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= if traveler["emergency_contact_name"] && traveler["emergency_contact_name"] != "" do %>
                                  <div class="max-w-xs">
                                    <div><%= traveler["emergency_contact_name"] %></div>
                                    <%= if traveler["emergency_contact_phone"] && traveler["emergency_contact_phone"] != "" do %>
                                      <div class="text-gray-500"><%= traveler["emergency_contact_phone"] %></div>
                                    <% end %>
                                  </div>
                                <% else %>
                                  Not provided
                                <% end %>
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  <% else %>
                    <%= if booking.is_booking_for_self do %>
                      <!-- Show user's own information when booking for self but no travelers_data -->
                      <div class="overflow-x-auto">
                        <table class="min-w-full bg-white border border-gray-200 rounded-lg shadow-sm">
                          <thead class="bg-gray-50">
                            <tr>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                                Traveler
                              </th>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                                Full Name
                              </th>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                                ID Number
                              </th>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                                Phone
                              </th>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                                Birth Date
                              </th>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                                Address
                              </th>
                              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b border-gray-200">
                                Emergency Contact
                              </th>
                            </tr>
                          </thead>
                          <tbody class="bg-white divide-y divide-gray-200">
                            <tr class="hover:bg-gray-50">
                              <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                <div class="flex items-center">
                                  <span>Traveler 1</span>
                                  <span class="ml-2 inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                    Primary
                                  </span>
                                </div>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= @current_user.full_name || "Not provided" %>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= if @current_user.identity_card_number && @current_user.identity_card_number != "" do %>
                                  <%= @current_user.identity_card_number %>
                                <% else %>
                                  <%= @current_user.passport_number || "Not provided" %>
                                <% end %>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= @current_user.phone_number || "Not provided" %>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= if @current_user.birthdate do %>
                                  <%= Date.to_string(@current_user.birthdate) %>
                                <% else %>
                                  Not provided
                                <% end %>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= if @current_user.address && @current_user.address != "" do %>
                                  <div class="max-w-xs">
                                    <div><%= @current_user.address %></div>
                                    <%= if @current_user.poskod && @current_user.poskod != "" do %>
                                      <div class="text-gray-500"><%= @current_user.poskod %></div>
                                    <% end %>
                                    <%= if @current_user.city && @current_user.city != "" do %>
                                      <div class="text-gray-500">
                                        <%= @current_user.city %><%= if @current_user.state && @current_user.state != "", do: ", #{@current_user.state}", else: "" %>
                                      </div>
                                    <% end %>
                                  </div>
                                <% else %>
                                  Not provided
                                <% end %>
                              </td>
                              <td class="px-6 py-4 text-sm text-gray-900">
                                <%= if @current_user.emergency_contact_name && @current_user.emergency_contact_name != "" do %>
                                  <div class="max-w-xs">
                                    <div><%= @current_user.emergency_contact_name %></div>
                                    <%= if @current_user.emergency_contact_phone && @current_user.emergency_contact_phone != "" do %>
                                      <div class="text-gray-500"><%= @current_user.emergency_contact_phone %></div>
                                    <% end %>
                                  </div>
                                <% else %>
                                  Not provided
                                <% end %>
                              </td>
                            </tr>
                          </tbody>
                        </table>
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
                  <% end %>
                 </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </.sidebar>

    <!-- Cancel Booking Confirmation Modal -->
    <%= if @show_cancel_modal do %>
      <div id="cancel-booking-modal" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
          <div class="mt-3 text-center">
            <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-100">
              <svg class="h-6 w-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.268 18.5c-.77.833.192 2.5 1.732 2.5z"></path>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mt-2">Cancel Booking</h3>
            <div class="mt-2 px-7 py-3">
              <p class="text-sm text-gray-500">
                Are you sure you want to cancel this booking? This action cannot be undone and the admin will be notified.
              </p>
            </div>
            <div class="items-center px-4 py-3">
              <button
                id="confirm-cancel-booking"
                phx-click="confirm_cancel_booking"
                phx-value-id={@booking_to_cancel.id}
                class="bg-red-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 mr-2"
              >
                Yes, Cancel Booking
              </button>
              <button
                id="cancel-cancel-booking"
                phx-click="hide_cancel_modal"
                class="bg-gray-300 text-gray-800 px-4 py-2 rounded-md text-sm font-medium hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500"
              >
                Keep Booking
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
