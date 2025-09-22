defmodule Umrahly.ToyyibPay do
  @moduledoc """
  ToyyibPay payment gateway integration service.

  This module handles all interactions with the ToyyibPay API including:
  - Creating bills for payments
  - Getting bill payment links
  - Verifying payment status
  - Handling callbacks
  """

  require Logger
  alias Umrahly.Bookings

  @doc """
  Creates a bill in ToyyibPay for the given booking.

  ## Parameters
  - `booking`: The booking struct
  - `assigns`: LiveView assigns containing user and payment information

  ## Returns
  - `{:ok, %{bill_code: string, payment_url: string}}` on success
  - `{:error, reason}` on failure
  """
  def create_bill(booking, assigns) do
    config = get_config()

    bill_params = %{
      "userSecretKey" => config.user_secret_key,
      "categoryCode" => config.category_code,
      "billName" => generate_bill_name(booking, assigns),
      "billDescription" => generate_bill_description(booking, assigns),
      "billPriceSetting" => 0, # Fixed price
      "billPayorInfo" => 1, # Required payor info
      "billAmount" => convert_amount_to_cents(assigns.deposit_amount),
      "billReturnUrl" => config.redirect_uri,
      "billCallbackUrl" => config.callback_uri,
      "billExternalReferenceNo" => "UMR-#{booking.id}",
      "billTo" => assigns.current_user.full_name || "Customer",
      "billEmail" => assigns.current_user.email,
      "billPhone" => assigns.current_user.phone_number || "",
      "billSplitPayment" => 0, # No split payment
      "billSplitPaymentArgs" => "",
      "billPaymentChannel" => 0, # All payment channels
      "billDisplayMerchant" => 1, # Show merchant info
      "billContentEmail" => generate_email_content(booking, assigns),
      "billChargeToCustomer" => 2 # Customer pays fees
    }

    case make_api_request("createBill", bill_params) do
      {:ok, response} ->
        case parse_create_bill_response(response) do
          {:ok, bill_code} ->
            payment_url = generate_payment_url(bill_code)
            {:ok, %{bill_code: bill_code, payment_url: payment_url}}
          {:error, reason} ->
            {:error, reason}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the payment status of a bill.

  ## Parameters
  - `bill_code`: The ToyyibPay bill code

  ## Returns
  - `{:ok, %{status: string, amount: float, transaction_id: string}}` on success
  - `{:error, reason}` on failure
  """
  def get_bill_transactions(bill_code) do
    _config = get_config()

    params = %{
      "billCode" => bill_code,
      "billpaymentStatus" => "" # Get all statuses
    }

    case make_api_request("getBillTransactions", params) do
      {:ok, response} ->
        parse_bill_transactions_response(response)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Verifies a payment callback from ToyyibPay.

  ## Parameters
  - `callback_params`: The callback parameters from ToyyibPay

  ## Returns
  - `{:ok, %{bill_code: string, status: string, amount: float, transaction_id: string}}` on success
  - `{:error, reason}` on failure
  """
  def verify_callback(callback_params) do
    required_fields = ["billcode", "status_id", "transaction_id", "order_id"]

    if Enum.all?(required_fields, &Map.has_key?(callback_params, &1)) do
      bill_code = callback_params["billcode"]
      status = callback_params["status_id"]
      transaction_id = callback_params["transaction_id"]
      order_id = callback_params["order_id"]

      # Verify the payment status with ToyyibPay API
      case get_bill_transactions(bill_code) do
        {:ok, %{status: api_status, amount: amount}} ->
          if api_status == status do
            {:ok, %{
              bill_code: bill_code,
              status: status,
              amount: amount,
              transaction_id: transaction_id,
              order_id: order_id
            }}
          else
            {:error, "Status mismatch between callback and API"}
          end
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Missing required callback parameters"}
    end
  end

  @doc """
  Updates booking payment status after successful payment.

  ## Parameters
  - `booking_id`: The booking ID
  - `payment_data`: Payment data from ToyyibPay

  ## Returns
  - `{:ok, booking}` on success
  - `{:error, reason}` on failure
  """
  def update_booking_payment(booking_id, payment_data) do
    try do
      booking = Bookings.get_booking!(booking_id)
      update_attrs = %{
        payment_status: "paid",
        payment_method: "toyyibpay",
        payment_reference: payment_data.transaction_id,
        payment_completed_at: DateTime.utc_now()
      }

      Bookings.update_booking(booking, update_attrs)
    rescue
      Ecto.NoResultsError ->
        {:error, "Booking not found"}
    end
  end

  # Private functions

  defp get_config do
    config = Application.get_env(:umrahly, :payment_gateway)[:toyyibpay]

    %{
      user_secret_key: config[:user_secret_key],
      category_code: config[:category_code],
      redirect_uri: config[:redirect_uri],
      callback_uri: config[:callback_uri],
      sandbox: config[:sandbox],
      api_url: config[:api_url]
    }
  end

  defp make_api_request(endpoint, params) do
    config = get_config()
    url = "#{config.api_url}/#{endpoint}"

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Accept", "application/json"}
    ]

    body = URI.encode_query(params)

    case Finch.build(:post, url, headers, body) |> Finch.request(Umrahly.Finch) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, "Invalid JSON response"}
        end
      {:ok, %Finch.Response{status: status_code, body: body}} ->
        Logger.error("ToyyibPay API error: #{status_code} - #{body}")
        {:error, "API request failed with status #{status_code}"}
      {:error, %Mint.TransportError{reason: reason}} ->
        Logger.error("ToyyibPay HTTP error: #{inspect(reason)}")
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp parse_create_bill_response(response) do
    case response do
      %{"BillCode" => bill_code} when is_binary(bill_code) ->
        {:ok, bill_code}
      %{"error" => error_message} ->
        {:error, "ToyyibPay error: #{error_message}"}
      _ ->
        {:error, "Unexpected response format from ToyyibPay"}
    end
  end

  defp parse_bill_transactions_response(response) do
    case response do
      %{"BillPayment" => [payment | _]} ->
        status = case payment["billpaymentStatus"] do
          "1" -> "paid"
          "2" -> "failed"
          "3" -> "pending"
          _ -> "unknown"
        end

        amount = case Float.parse(payment["billpaymentAmount"]) do
          {amount, _} -> amount / 100 # Convert from cents
          :error -> 0.0
        end

        {:ok, %{
          status: status,
          amount: amount,
          transaction_id: payment["billpaymentInvoiceNo"] || payment["billpaymentTransactionId"]
        }}
      %{"error" => error_message} ->
        {:error, "ToyyibPay error: #{error_message}"}
      _ ->
        {:error, "No payment data found"}
    end
  end

  defp generate_bill_name(_booking, assigns) do
    package_name = assigns.package.name
    "Umrah Package - #{package_name}"
  end

  defp generate_bill_description(_booking, assigns) do
    package_name = assigns.package.name
    schedule_date = assigns.schedule.departure_date
    number_of_persons = assigns.number_of_persons

    "Payment for Umrah package: #{package_name}. Departure: #{schedule_date}. Travelers: #{number_of_persons} person(s)."
  end

  defp generate_email_content(_booking, assigns) do
    """
    Thank you for your Umrah booking with us!

    Your booking details:
    - Package: #{assigns.package.name}
    - Departure Date: #{assigns.schedule.departure_date}
    - Number of Travelers: #{assigns.number_of_persons}
    - Total Amount: RM #{assigns.deposit_amount}

    We will contact you soon with further details about your journey.

    Best regards,
    Umrahly Team
    """
  end

  defp convert_amount_to_cents(amount) do
    case amount do
      %Decimal{} = decimal_amount ->
        decimal_amount
        |> Decimal.mult(100)
        |> Decimal.to_integer()
      amount when is_number(amount) ->
        round(amount * 100)
      amount when is_binary(amount) ->
        case Float.parse(amount) do
          {float_amount, _} -> round(float_amount * 100)
          :error -> 0
        end
      _ -> 0
    end
  end

  defp generate_payment_url(bill_code) do
    config = get_config()
    base_url = if config.sandbox, do: "https://dev.toyyibpay.com", else: "https://toyyibpay.com"
    "#{base_url}/#{bill_code}"
  end
end
