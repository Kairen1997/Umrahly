defmodule UmrahlyWeb.AdminPaymentRefundLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.AdminLayout
  import Ecto.Query, warn: false
  alias Umrahly.Repo
  alias Umrahly.Bookings.Booking
  alias Umrahly.Bookings.BookingFlowProgress

  def mount(%{"id" => id, "source" => source} = _params, _session, socket) do
    payment_details = load_payment_details(id, source)

    socket =
      socket
      |> assign(:payment_details, payment_details)
      |> assign(:current_page, "payments")
      |> assign(:has_profile, true)
      |> assign(:is_admin, true)
      |> assign(:profile, socket.assigns.current_user)
      |> assign(:source, source)
      |> assign(:refund_amount, nil)
      |> assign(:refund_reason, "")

    {:ok, socket}
  rescue
    _e ->
      {:ok, socket |> put_flash(:error, "Payment not found") |> redirect(to: "/admin/payments")}
  end

  def handle_event("submit_refund", %{"amount" => amount, "reason" => reason}, socket) do
    # NOTE: Implement actual refund logic here (gateway + DB transaction)
    _amount = amount
    _reason = reason

    {:noreply,
     socket
     |> put_flash(:info, "Refund submitted")
     |> push_navigate(to: "/admin/payments/#{socket.assigns.payment_details.id}/#{socket.assigns.source}")}
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

  def render(assigns) do
    ~H"""
    <.admin_layout current_page={@current_page} has_profile={@has_profile} current_user={@current_user} profile={@profile} is_admin={@is_admin}>
      <div class="max-w-3xl mx-auto">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <div class="flex items-center">
              <.link navigate={"/admin/payments/#{@payment_details.id}/#{@source}"} class="text-gray-500 hover:text-gray-700 mr-4">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
                </svg>
              </.link>
              <h1 class="text-2xl font-bold text-gray-900">Refund Payment</h1>
            </div>
            <span class="inline-flex px-3 py-1 text-sm font-semibold rounded-full bg-red-100 text-red-800">Refund</span>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="space-y-6">
              <div class="bg-gray-50 p-4 rounded-lg">
                <h3 class="text-lg font-semibold mb-4">Payment Summary</h3>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between"><span class="text-gray-500">Payment ID</span><span class="font-medium">#<%= @payment_details.id %></span></div>
                  <div class="flex justify-between"><span class="text-gray-500">Type</span><span class="font-medium capitalize"><%= @payment_details.source %></span></div>
                  <div class="flex justify-between"><span class="text-gray-500">Status</span><span class="font-medium capitalize"><%= String.replace(@payment_details.status, "_", " ") %></span></div>
                  <div class="flex justify-between"><span class="text-gray-500">Total Amount</span><span class="font-medium"><%= format_amount(@payment_details.total_amount) %></span></div>
                  <div class="flex justify-between"><span class="text-gray-500">Paid To Date</span><span class="font-medium"><%= format_amount(@payment_details.deposit_amount) %></span></div>
                </div>
              </div>

              <div class="bg-gray-50 p-4 rounded-lg">
                <h3 class="text-lg font-semibold mb-4">Customer</h3>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between"><span class="text-gray-500">Name</span><span class="font-medium"><%= @payment_details.user && @payment_details.user.full_name %></span></div>
                  <div class="flex justify-between"><span class="text-gray-500">Email</span><span class="font-medium"><%= @payment_details.user && @payment_details.user.email %></span></div>
                </div>
              </div>
            </div>

            <div class="space-y-6">
              <div class="bg-gray-50 p-4 rounded-lg">
                <h3 class="text-lg font-semibold mb-4">Refund Form</h3>
                <.simple_form for={:refund} phx-submit="submit_refund">
                  <div class="space-y-4">
                    <div>
                      <label class="block text-sm text-gray-600 mb-1">Amount</label>
                      <input name="amount" type="number" step="0.01" min="0" required class="w-full border rounded px-3 py-2" />
                    </div>
                    <div>
                      <label class="block text-sm text-gray-600 mb-1">Reason</label>
                      <textarea name="reason" rows="3" class="w-full border rounded px-3 py-2" placeholder="Optional"></textarea>
                    </div>
                  </div>
                  <:actions>
                    <div class="flex justify-end gap-3">
                      <.link navigate={"/admin/payments/#{@payment_details.id}/#{@source}"} class="px-4 py-2 rounded bg-gray-200 text-gray-700 hover:bg-gray-300">Cancel</.link>
                      <button type="submit" class="px-4 py-2 rounded bg-red-600 text-white hover:bg-red-700">Submit Refund</button>
                    </div>
                  </:actions>
                </.simple_form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.admin_layout>
    """
  end
end
