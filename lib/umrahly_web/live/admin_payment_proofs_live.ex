defmodule UmrahlyWeb.AdminPaymentProofsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  alias Umrahly.Bookings
  alias Umrahly.Repo
  alias Phoenix.LiveView.JS
  import Ecto.Query
  alias Umrahly.Notifications

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(_params, _session, socket) do
    # Ensure user is admin
    if socket.assigns.current_user.is_admin do
      # Defaults
      page_size = 10
      page = 1
      status_filter = "submitted" # Pending review by default
      search_query = ""

      proofs = fetch_payment_proofs(search_query, status_filter)

      socket =
        socket
        |> assign(:page_title, "Payment Proof Management")
        |> assign(:current_page, :admin_payment_proofs)
        |> assign(:pending_proofs, proofs)
        |> assign(:selected_booking, nil)
        |> assign(:admin_notes, "")
        |> assign(:page_size, page_size)
        |> assign(:page, page)
        |> assign(:status_filter, status_filter)
        |> assign(:search_query, search_query)
        |> assign(:show_reject_modal, false)
        |> assign(:reject_booking_id, nil)
        |> assign_pagination()

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Admin privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  # Load data based on action/params for index/show pages
  def handle_params(%{"id" => booking_id}, _uri, %{assigns: %{live_action: :show}} = socket) do
    booking =
      Umrahly.Bookings.Booking
      |> Repo.get!(booking_id)
      |> Repo.preload([:user, package_schedule: :package])

    {:noreply,
     socket
     |> assign(:selected_booking, booking)
     |> assign(:page_title, "Payment Proof Details")}
  rescue
    Ecto.NoResultsError ->
      {:noreply, socket |> put_flash(:error, "Booking not found.") |> push_navigate(to: ~p"/admin/payment-proofs")}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
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

  # Search submit
  def handle_event("search_payment_proofs", %{"search" => term}, socket) do
    status = socket.assigns.status_filter
    proofs = fetch_payment_proofs(term, status)

    {:noreply,
      socket
      |> assign(:search_query, term)
      |> assign(:pending_proofs, proofs)
      |> assign(:page, 1)
      |> assign_pagination()}
  end

  # Status filter click
  def handle_event("filter_payment_proofs_status", %{"status" => status}, socket) do
    term = socket.assigns.search_query
    proofs = fetch_payment_proofs(term, status)

    {:noreply,
      socket
      |> assign(:status_filter, status)
      |> assign(:pending_proofs, proofs)
      |> assign(:page, 1)
      |> assign_pagination()}
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

          # Notify user about approval (shows up in bell)
          _ = notify_payment_decision(updated_booking, :approved)

          # Refresh with current filters
          proofs = fetch_payment_proofs(socket.assigns.search_query, socket.assigns.status_filter)

          socket =
            socket
            |> put_flash(:info, "Payment proof approved and booking confirmed successfully!")
            |> assign(:pending_proofs, proofs)
            |> assign(:selected_booking, nil)
            |> assign(:admin_notes, "")
            |> assign_pagination()

          {:noreply, push_navigate(socket, to: ~p"/admin/payment-proofs")}

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
          # Notify user about rejection (shows up in bell)
          _ = notify_payment_decision(booking, :rejected)

          # Refresh with current filters
          proofs = fetch_payment_proofs(socket.assigns.search_query, socket.assigns.status_filter)

          socket =
            socket
            |> put_flash(:info, "Payment proof rejected successfully!")
            |> assign(:pending_proofs, proofs)
            |> assign(:selected_booking, nil)
            |> assign(:admin_notes, "")
            |> assign_pagination()

          {:noreply, push_navigate(socket, to: ~p"/admin/payment-proofs")}

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

  # Open reject confirmation modal
  def handle_event("open_reject_modal", %{"id" => booking_id}, socket) do
    {:noreply,
      socket
      |> assign(:reject_booking_id, booking_id)
      |> assign(:show_reject_modal, true)}
  end

  # Close reject confirmation modal
  def handle_event("close_reject_modal", _params, socket) do
    {:noreply,
      socket
      |> assign(:show_reject_modal, false)
      |> assign(:reject_booking_id, nil)}
  end

  # Confirm reject action from modal
  def handle_event("confirm_reject_payment", _params, socket) do
    booking_id = socket.assigns.reject_booking_id

    if is_nil(booking_id) do
      {:noreply, assign(socket, :show_reject_modal, false)}
    else
      try do
        booking =
          Umrahly.Bookings.Booking
          |> Repo.get!(booking_id)
          |> Repo.preload([:user, package_schedule: :package])

        case Bookings.update_payment_proof_status(booking, "rejected", socket.assigns.admin_notes) do
          {:ok, _updated_booking} ->
            # Notify user about rejection (shows up in bell)
            _ = notify_payment_decision(booking, :rejected)

            proofs = fetch_payment_proofs(socket.assigns.search_query, socket.assigns.status_filter)

            socket =
              socket
              |> put_flash(:info, "Payment proof rejected successfully!")
              |> assign(:pending_proofs, proofs)
              |> assign(:selected_booking, nil)
              |> assign(:admin_notes, "")
              |> assign(:show_reject_modal, false)
              |> assign(:reject_booking_id, nil)
              |> assign_pagination()

            {:noreply, push_navigate(socket, to: ~p"/admin/payment-proofs")}

          {:error, _changeset} ->
            socket =
              socket
              |> put_flash(:error, "Failed to reject payment proof.")
              |> assign(:show_reject_modal, false)

            {:noreply, socket}
        end
      rescue
        Ecto.NoResultsError ->
          socket =
            socket
            |> put_flash(:error, "Booking not found.")
            |> assign(:show_reject_modal, false)
            |> assign(:reject_booking_id, nil)

          {:noreply, socket}
        error ->
          socket =
            socket
            |> put_flash(:error, "Error processing rejection: #{inspect(error)}")
            |> assign(:show_reject_modal, false)

          {:noreply, socket}
      end
    end
  end

  def handle_event("paginate", %{"action" => action}, socket) do
    page = socket.assigns.page
    total_pages = socket.assigns.total_pages

    new_page = case action do
      "first" -> 1
      "prev" -> max(page - 1, 1)
      "next" -> min(page + 1, total_pages)
      "last" -> max(total_pages, 1)
      _ -> page
    end

    {:noreply,
      socket
      |> assign(:page, new_page)
      |> assign_pagination()}
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

  # --- Data fetch with filters and search ---
  defp fetch_payment_proofs(search_term, status_filter) do
    status_clause =
      case status_filter do
        "all" -> ["submitted", "approved", "rejected"]
        s when is_binary(s) -> [s]
        _ -> ["submitted"]
      end

    base = Umrahly.Bookings.Booking
      |> join(:inner, [b], u in Umrahly.Accounts.User, on: b.user_id == u.id)
      |> join(:inner, [b, u], ps in Umrahly.Packages.PackageSchedule, on: b.package_schedule_id == ps.id)
      |> join(:inner, [b, u, ps], p in Umrahly.Packages.Package, on: ps.package_id == p.id)
      |> where([b, _u, _ps, _p], b.payment_proof_status in ^status_clause)
      |> preload([b, u, ps, p], user: u, package_schedule: {ps, package: p})

    base =
      case String.trim(to_string(search_term)) do
        "" -> base
        term ->
          pattern = "%#{term}%"
          base
          |> where([_b, u, _ps, p], ilike(u.full_name, ^pattern) or ilike(p.name, ^pattern))
      end

    base
    |> order_by([b], desc: b.payment_proof_submitted_at)
    |> Repo.all()
  end

  # --- Notifications helper ---
  defp notify_payment_decision(booking, type) when type in [:approved, :rejected] do
    virtual_payment = %{
      id: booking.id,
      amount: booking.total_amount,
      booking_reference: "BK#{booking.id}"
    }

    Notifications.create_payment_notification(booking.user_id, virtual_payment, type)
  end

  # --- Pagination helpers ---
  defp assign_pagination(socket, proofs \\ nil) do
    proofs = proofs || socket.assigns.pending_proofs
    page_size = socket.assigns.page_size
    total_count = length(proofs)
    total_pages = calc_total_pages(total_count, page_size)
    page = socket.assigns.page |> min(total_pages) |> max(1)
    visible_proofs = paginate_list(proofs, page, page_size)

    socket
    |> assign(:pending_proofs, proofs)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
    |> assign(:page, page)
    |> assign(:visible_proofs, visible_proofs)
  end

  defp calc_total_pages(0, _page_size), do: 1
  defp calc_total_pages(total_count, page_size) when page_size > 0 do
    div(total_count + page_size - 1, page_size)
  end

  defp paginate_list(list, page, page_size) do
    start_index = (page - 1) * page_size
    Enum.slice(list, start_index, page_size)
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

        <%= if @live_action == :show do %>
          <!-- Details page -->
          <div class="max-w-3xl">
            <div class="mb-4">
              <.link
                navigate={~p"/admin/payment-proofs"}
                class="text-gray-600 hover:text-gray-800 flex items-center space-x-2 text-sm font-medium"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                </svg>
                <span>Back to list</span>
              </.link>
            </div>
            <div class="bg-white shadow rounded-lg">
              <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-medium text-gray-900">Payment Proof Details</h3>
              </div>
              <div class="px-6 py-4">
                <%= render_details(assigns) %>

                <!-- Reject Confirmation Modal -->
                <.modal id="reject-payment-modal" show={@show_reject_modal} on_cancel={JS.push("close_reject_modal")}>
                  <div class="sm:flex sm:items-start">
                    <div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-red-100 sm:mx-0 sm:h-10 sm:w-10">
                      <svg class="h-6 w-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.268 18.5c-.77.833.192 2.5 1.732 2.5z" />
                      </svg>
                    </div>
                    <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left">
                      <h3 class="text-base font-semibold leading-6 text-gray-900">Reject Payment Proof</h3>
                      <div class="mt-2">
                        <p class="text-sm text-gray-500">Are you sure you want to reject this payment proof? This action cannot be undone.</p>
                      </div>
                    </div>
                  </div>
                  <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                    <button phx-click="confirm_reject_payment" type="button" class="inline-flex w-full justify-center rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-700 sm:ml-3 sm:w-auto">Yes, Reject</button>
                    <button phx-click={JS.exec("data-cancel", to: "#reject-payment-modal")} type="button" class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:mt-0 sm:w-auto">Cancel</button>
                  </div>
                </.modal>
              </div>
            </div>
          </div>
        <% else %>
          <!-- List page only -->
          <div class="bg-white shadow rounded-lg">
            <div class="px-6 py-4 border-b border-gray-200">
              <h2 class="text-lg font-medium text-gray-900">
                Payment Proofs (<%= @total_count %>)
              </h2>
            </div>

            <!-- Search and Filters -->
            <div class="px-6 pt-4">
              <div class="mb-6 flex flex-col sm:flex-row gap-4">
                <div class="flex-1">
                  <form phx-submit="search_payment_proofs" class="flex">
                    <input
                      type="text"
                      name="search"
                      value={@search_query}
                      placeholder="Search by user or package..."
                      class="flex-1 px-3 py-2 border border-gray-300 rounded-l-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                    <button type="submit" class="px-4 py-2 bg-gray-600 text-white rounded-r-lg hover:bg-gray-700 transition-colors">
                      Search
                    </button>
                  </form>
                </div>
                <div class="flex gap-2">
                  <button
                    phx-click="filter_payment_proofs_status"
                    phx-value-status="all"
                    class={[
                      "px-4 py-2 rounded-lg transition-colors",
                      if(@status_filter == "all", do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300")
                    ]}>
                    All
                  </button>
                  <button
                    phx-click="filter_payment_proofs_status"
                    phx-value-status="submitted"
                    class={[
                      "px-4 py-2 rounded-lg transition-colors",
                      if(@status_filter == "submitted", do: "bg-yellow-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300")
                    ]}>
                    Pending
                  </button>
                  <button
                    phx-click="filter_payment_proofs_status"
                    phx-value-status="approved"
                    class={[
                      "px-4 py-2 rounded-lg transition-colors",
                      if(@status_filter == "approved", do: "bg-green-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300")
                    ]}>
                    Approved
                  </button>
                  <button
                    phx-click="filter_payment_proofs_status"
                    phx-value-status="rejected"
                    class={[
                      "px-4 py-2 rounded-lg transition-colors",
                      if(@status_filter == "rejected", do: "bg-red-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300")
                    ]}>
                    Rejected
                  </button>
                </div>
              </div>
            </div>

            <!-- Table view for payment proofs -->
            <div class="px-6 pb-4">
              <%= if Enum.empty?(@pending_proofs) do %>
                <div class="py-12 text-center">
                  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No results</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    Try adjusting your search or filter criteria.
                  </p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="min-w-full text-left text-sm">
                    <thead class="bg-gray-50 text-gray-700">
                      <tr>
                        <th class="py-2 px-3 font-medium">User</th>
                        <th class="py-2 px-3 font-medium">Package</th>
                        <th class="py-2 px-3 font-medium">Amount</th>
                        <th class="py-2 px-3 font-medium">Submitted</th>
                        <th class="py-2 px-3 font-medium">Status</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200">
                      <%= for proof <- @visible_proofs do %>
                        <tr phx-click={JS.navigate(~p"/admin/payment-proofs/#{proof.id}")} class="hover:bg-teal-50 cursor-pointer">
                          <td class="py-3 px-3 text-gray-900 font-medium truncate max-w-[12rem]">
                            <%= proof.user.full_name %>
                          </td>
                          <td class="py-3 px-3 text-gray-600 truncate max-w-[20rem]">
                            <%= proof.package_schedule.package.name %>
                          </td>
                          <td class="py-3 px-3 text-gray-600">
                            RM <%= proof.total_amount %>
                          </td>
                          <td class="py-3 px-3 text-gray-500 whitespace-nowrap">
                            <%= UmrahlyWeb.Timezone.format_local(proof.payment_proof_submitted_at, "%B %d, %Y at %I:%M %p") %>
                          </td>
                          <td class="py-3 px-3">
                            <%= case proof.payment_proof_status do %>
                              <% "submitted" -> %>
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">Pending Review</span>
                              <% "approved" -> %>
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">Approved</span>
                              <% "rejected" -> %>
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">Rejected</span>
                              <% _ -> %>
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">Unknown</span>
                            <% end %>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>

                <!-- Pagination Controls -->
                <div class="mt-4 flex items-center justify-between">
                  <div class="text-sm text-gray-600">
                    <%= if @total_count > 0 do %>
                      <%= start_idx = ((@page - 1) * @page_size) + 1 %>
                      <%= end_idx = min(@total_count, @page * @page_size) %>
                      Showing <%= start_idx %>–<%= end_idx %> of <%= @total_count %>
                    <% else %>
                      Showing 0–0 of 0
                    <% end %>
                  </div>
                  <div class="flex gap-2">
                    <button phx-click="paginate" phx-value-action="first" class={[
                      "px-3 py-1 rounded border",
                      if(@page == 1, do: "bg-gray-100 text-gray-400 cursor-not-allowed", else: "bg-white text-gray-700 hover:bg-gray-50")
                    ]} disabled={@page == 1}>&laquo; First</button>
                    <button phx-click="paginate" phx-value-action="prev" class={[
                      "px-3 py-1 rounded border",
                      if(@page == 1, do: "bg-gray-100 text-gray-400 cursor-not-allowed", else: "bg-white text-gray-700 hover:bg-gray-50")
                    ]} disabled={@page == 1}>&lsaquo; Prev</button>
                    <span class="px-3 py-1 text-sm text-gray-600">Page <%= @page %> of <%= @total_pages %></span>
                    <button phx-click="paginate" phx-value-action="next" class={[
                      "px-3 py-1 rounded border",
                      if(@page >= @total_pages, do: "bg-gray-100 text-gray-400 cursor-not-allowed", else: "bg-white text-gray-700 hover:bg-gray-50")
                    ]} disabled={@page >= @total_pages}>Next &rsaquo;</button>
                    <button phx-click="paginate" phx-value-action="last" class={[
                      "px-3 py-1 rounded border",
                      if(@page >= @total_pages, do: "bg-gray-100 text-gray-400 cursor-not-allowed", else: "bg-white text-gray-700 hover:bg-gray-50")
                    ]} disabled={@page >= @total_pages}>Last &raquo;</button>
                  </div>
                </div>

              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </.admin_layout>
    """
  end

  # Shared details section renderer to avoid duplication across index/show
  defp render_details(assigns) do
    ~H"""
    <!-- Details Table -->
    <div class="space-y-4">
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Details</h4>
        <div class="overflow-hidden rounded-lg border border-gray-200">
          <table class="w-full text-sm">
            <thead>
              <tr class="bg-gray-50">
                <th class="px-4 py-3 text-gray-600 font-medium">Name</th>
                <th class="px-4 py-3 text-gray-600 font-medium">Email</th>
                <th class="px-4 py-3 text-gray-600 font-medium">Phone</th>
                <th class="px-4 py-3 text-gray-600 font-medium">Package</th>
                <th class="px-4 py-3 text-gray-600 font-medium">Amount</th>
                <th class="px-4 py-3 text-gray-600 font-medium">Payment Method</th>
                <th class="px-4 py-3 text-gray-600 font-medium">Booking Date</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="px-4 py-3 text-gray-900 font-medium"><%= @selected_booking.user.full_name %></td>
                <td class="px-4 py-3 text-gray-700"><%= @selected_booking.user.email %></td>
                <td class="px-4 py-3 text-gray-700"><%= @selected_booking.user.phone_number %></td>
                <td class="px-4 py-3 text-gray-700"><%= @selected_booking.package_schedule.package.name %></td>
                <td class="px-4 py-3 text-gray-900 font-medium">RM <%= @selected_booking.total_amount %></td>
                <td class="px-4 py-3 text-gray-700"><%= String.replace(@selected_booking.payment_method, "_", " ") |> String.capitalize() %></td>
                <td class="px-4 py-3 text-gray-700"><%= UmrahlyWeb.Timezone.format_local(@selected_booking.booking_date, "%B %d, %Y") %></td>
              </tr>
            </tbody>
          </table>
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
                <div class="flex items-center gap-4">
                  <a href={get_file_url(@selected_booking.payment_proof_file)}
                     target="_blank"
                     class="text-gray-600 hover:text-gray-800 flex items-center space-x-2 text-sm font-medium">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0zM2.458 12C3.732 7.943 7.523 5 12 5c4.477 0 8.268 2.943 9.542 7-1.274 4.057-5.065 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                    <span>View</span>
                                     </a>
                   <a href={get_file_url(@selected_booking.payment_proof_file)}
                      download={@selected_booking.payment_proof_file}
                      class="text-gray-600 hover:text-gray-800 flex items-center space-x-2 text-sm font-medium">
                     <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                     </svg>
                     <span>Download</span>
                   </a>
                </div>
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
          phx-click={JS.push("open_reject_modal", value: %{id: @selected_booking.id}) |> show_modal("reject-payment-modal")}
          class="w-full bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors font-medium flex items-center justify-center space-x-2"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
          <span>Reject Payment</span>
        </button>
      </div>
    </div>
    """
  end
end
