defmodule UmrahlyWeb.AdminPaymentProofsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Bookings
  alias Umrahly.Repo

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    # Ensure user is admin
    if socket.assigns.current_user.is_admin do
      # Get all bookings with submitted payment proofs
      pending_proofs = Bookings.get_bookings_flow_progress_pending_payment_proof_approval()

      socket =
        socket
        |> assign(:page_title, "Payment Proof Management")
        |> assign(:current_page, :admin_payment_proofs)
        |> assign(:pending_proofs, pending_proofs)
        |> assign(:selected_booking, nil)
        |> assign(:admin_notes, "")

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  def handle_event("select_booking", %{"id" => booking_id}, socket) do
    try do
      # Get booking with preloaded associations
      booking =
        Umrahly.Bookings.Booking
        |> Repo.get!(booking_id)
        |> Repo.preload([:user, package_schedule: :package])

      socket = assign(socket, :selected_booking, booking)
      {:noreply, socket}
    rescue
      Ecto.NoResultsError ->
        socket = put_flash(socket, :error, "Booking not found.")
        {:noreply, socket}
      error ->
        socket = put_flash(socket, :error, "Error loading booking: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  def handle_event("update_admin_notes", %{"admin_notes" => notes}, socket) do
    socket = assign(socket, :admin_notes, notes)
    {:noreply, socket}
  end

  def handle_event("approve_payment", %{"id" => booking_id}, socket) do
    try do
      booking =
        Umrahly.Bookings.Booking
        |> Repo.get!(booking_id)
        |> Repo.preload([:user, package_schedule: :package])

      case Bookings.update_payment_proof_status(booking, "approved", socket.assigns.admin_notes) do
        {:ok, updated_booking} ->
          # Update the booking status to confirmed
          {:ok, _final_booking} = Bookings.update_booking(updated_booking, %{"status" => "confirmed"})

          # Refresh the pending proofs list
          pending_proofs = Bookings.get_bookings_flow_progress_pending_payment_proof_approval()

          socket =
            socket
            |> put_flash(:info, "Payment proof approved and booking confirmed successfully!")
            |> assign(:pending_proofs, pending_proofs)
            |> assign(:selected_booking, nil)
            |> assign(:admin_notes, "")

          {:noreply, socket}

        {:error, _changeset} ->
          socket = put_flash(socket, :error, "Failed to approve payment proof.")
          {:noreply, socket}
      end
    rescue
      Ecto.NoResultsError ->
        socket = put_flash(socket, :error, "Booking not found.")
        {:noreply, socket}
      error ->
        socket = put_flash(socket, :error, "Error processing approval: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  def handle_event("reject_payment", %{"id" => booking_id}, socket) do
    try do
      booking =
        Umrahly.Bookings.Booking
        |> Repo.get!(booking_id)
        |> Repo.preload([:user, package_schedule: :package])

      case Bookings.update_payment_proof_status(booking, "rejected", socket.assigns.admin_notes) do
        {:ok, _updated_booking} ->
          # Refresh the pending proofs list
          pending_proofs = Bookings.get_bookings_flow_progress_pending_payment_proof_approval()

          socket =
            socket
            |> put_flash(:info, "Payment proof rejected successfully!")
            |> assign(:pending_proofs, pending_proofs)
            |> assign(:selected_booking, nil)
            |> assign(:admin_notes, "")

          {:noreply, socket}

        {:error, _changeset} ->
          socket = put_flash(socket, :error, "Failed to reject payment proof.")
          {:noreply, socket}
      end
    rescue
      Ecto.NoResultsError ->
        socket = put_flash(socket, :error, "Booking not found.")
        {:noreply, socket}
      error ->
        socket = put_flash(socket, :error, "Error processing rejection: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  # Helper function to get file extension
  defp get_file_extension(filename) do
    filename
    |> Path.extname()
    |> String.downcase()
  end

  # Helper function to check if file is an image
  defp is_image_file?(filename) do
    extension = get_file_extension(filename)
    Enum.member?([".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"], extension)
  end

  # Helper function to get file type icon
  defp get_file_type_icon(filename) do
    extension = get_file_extension(filename)

    case extension do
      ext when ext in [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"] ->
        "image"
      ".pdf" ->
        "pdf"
      ".doc" ->
        "document"
      ".docx" ->
        "document"
      ".xls" ->
        "spreadsheet"
      ".xlsx" ->
        "spreadsheet"
      _ ->
        "file"
    end
  end

  # Helper function to generate file URL
  defp get_file_url(filename) do
    "/uploads/payment_proof/#{filename}"
  end

  def render(assigns) do
    ~H"""
    <.admin_layout page_title={@page_title} current_page={@current_page}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Payment Proof Management</h1>
          <p class="mt-2 text-gray-600">
            Review and approve payment proof submissions from users
          </p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Pending Proofs List -->
          <div class="lg:col-span-2">
            <div class="bg-white shadow rounded-lg">
              <div class="px-6 py-4 border-b border-gray-200">
                <h2 class="text-lg font-medium text-gray-900">
                  Pending Payment Proofs (<%= length(@pending_proofs) %>)
                </h2>
              </div>

              <div class="divide-y divide-gray-200">
                <%= if Enum.empty?(@pending_proofs) do %>
                  <div class="px-6 py-8 text-center">
                    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <h3 class="mt-2 text-sm font-medium text-gray-900">No pending proofs</h3>
                    <p class="mt-1 text-sm text-gray-500">
                      All payment proofs have been reviewed.
                    </p>
                  </div>
                <% else %>
                  <%= for proof <- @pending_proofs do %>
                    <div class="px-6 py-4 hover:bg-gray-50 cursor-pointer transition-colors"
                         phx-click="select_booking"
                         phx-value-id={proof.id}>
                      <div class="flex items-center justify-between">
                        <div class="flex-1">
                          <div class="flex items-center space-x-3">
                            <div class="flex-shrink-0">
                              <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                                <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                                </svg>
                              </div>
                            </div>
                            <div class="flex-1 min-w-0">
                              <p class="text-sm font-medium text-gray-900 truncate">
                                <%= proof.user.full_name %>
                              </p>
                              <p class="text-sm text-gray-500 truncate">
                                <%= proof.package_schedule.package.name %> - RM <%= proof.total_amount %>
                              </p>
                              <p class="text-xs text-gray-400">
                                Submitted: <%= Calendar.strftime(proof.payment_proof_submitted_at, "%B %d, %Y at %I:%M %p") %>
                              </p>
                            </div>
                          </div>
                        </div>
                        <div class="flex-shrink-0">
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                            Pending Review
                          </span>
                        </div>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Proof Details and Actions -->
          <div class="lg:col-span-1">
            <%= if @selected_booking do %>
              <div class="bg-white shadow rounded-lg sticky top-8">
                <div class="px-6 py-4 border-b border-gray-200">
                  <h3 class="text-lg font-medium text-gray-900">Payment Proof Details</h3>
                </div>

                <div class="px-6 py-4 space-y-4">
                  <!-- User Information -->
                  <div>
                    <h4 class="text-sm font-medium text-gray-900 mb-2">User Information</h4>
                    <div class="text-sm text-gray-600 space-y-1">
                      <p><strong>Name:</strong> <%= @selected_booking.user.full_name %></p>
                      <p><strong>Email:</strong> <%= @selected_booking.user.email %></p>
                      <p><strong>Phone:</strong> <%= @selected_booking.user.phone_number %></p>
                    </div>
                  </div>

                  <!-- Booking Information -->
                  <div>
                    <h4 class="text-sm font-medium text-gray-900 mb-2">Booking Information</h4>
                    <div class="text-sm text-gray-600 space-y-1">
                      <p><strong>Package:</strong> <%= @selected_booking.package_schedule.package.name %></p>
                      <p><strong>Amount:</strong> RM <%= @selected_booking.total_amount %></p>
                      <p><strong>Payment Method:</strong> <%= String.replace(@selected_booking.payment_method, "_", " ") |> String.capitalize() %></p>
                      <p><strong>Booking Date:</strong> <%= Calendar.strftime(@selected_booking.booking_date, "%B %d, %Y") %></p>
                    </div>
                  </div>

                  <!-- Payment Proof -->
                  <div>
                    <h4 class="text-sm font-medium text-gray-900 mb-2">Payment Proof</h4>
                    <div class="text-sm text-gray-600 space-y-3">
                      <%= if @selected_booking.payment_proof_file do %>
                        <div class="border border-gray-200 rounded-lg p-3">
                          <div class="flex items-center justify-between mb-2">
                            <div class="flex items-center space-x-2">
                              <!-- File Type Icon -->
                              <%= cond do %>
                                <% is_image_file?(@selected_booking.payment_proof_file) -> %>
                                  <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                  </svg>
                                <% get_file_type_icon(@selected_booking.payment_proof_file) == "pdf" -> %>
                                  <svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
                                  </svg>
                                <% true -> %>
                                  <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                                  </svg>
                              <% end %>
                              <span class="font-medium"><%= @selected_booking.payment_proof_file %></span>
                            </div>
                            <a href={get_file_url(@selected_booking.payment_proof_file)}
                               target="_blank"
                               class="text-blue-600 hover:text-blue-800 underline text-sm flex items-center space-x-1">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                              </svg>
                              <span>Download</span>
                            </a>
                          </div>

                          <!-- Image Preview -->
                          <%= if is_image_file?(@selected_booking.payment_proof_file) do %>
                            <div class="mt-2">
                              <img src={get_file_url(@selected_booking.payment_proof_file)}
                                   alt="Payment proof"
                                   class="max-w-full h-auto max-h-64 rounded border border-gray-200"
                                   onerror="this.style.display='none'" />
                            </div>
                          <% end %>
                        </div>
                      <% else %>
                        <div class="text-gray-500 text-sm italic">
                          No payment proof file uploaded
                        </div>
                      <% end %>

                      <%= if @selected_booking.payment_proof_notes && @selected_booking.payment_proof_notes != "" do %>
                        <div>
                          <p class="font-medium text-gray-900 mb-1">User Notes:</p>
                          <div class="bg-gray-50 p-3 rounded border border-gray-200">
                            <p class="text-xs text-gray-700 whitespace-pre-wrap"><%= @selected_booking.payment_proof_notes %></p>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <!-- Admin Notes -->
                  <div>
                    <label class="block text-sm font-medium text-gray-900 mb-2">
                      Admin Notes
                    </label>
                    <textarea
                      name="admin_notes"
                      rows="3"
                      placeholder="Add notes about your decision..."
                      phx-change="update_admin_notes"
                      value={@admin_notes}
                      class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    ></textarea>
                  </div>

                  <!-- Action Buttons -->
                  <div class="space-y-2">
                    <button
                      type="button"
                      phx-click="approve_payment"
                      phx-value-id={@selected_booking.id}
                      class="w-full bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium flex items-center justify-center space-x-2"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                      </svg>
                      <span>Approve Payment</span>
                    </button>

                    <button
                      type="button"
                      phx-click="reject_payment"
                      phx-value-id={@selected_booking.id}
                      class="w-full bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors font-medium flex items-center justify-center space-x-2"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                      <span>Reject Payment</span>
                    </button>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="bg-white shadow rounded-lg p-6 text-center">
                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-gray-900">Select a payment proof</h3>
                <p class="mt-1 text-sm text-gray-500">
                  Click on a pending proof to review and take action.
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
