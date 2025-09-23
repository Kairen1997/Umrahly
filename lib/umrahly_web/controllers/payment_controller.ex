defmodule UmrahlyWeb.PaymentController do
  use UmrahlyWeb, :controller

  require Logger
  alias Umrahly.ToyyibPay

  @doc """
  Handles ToyyibPay payment callbacks.
  """
  def toyyibpay_callback(conn, params) do
    Logger.info("ToyyibPay callback received: #{inspect(params)}")

    case ToyyibPay.verify_callback(params) do
      {:ok, payment_data} ->
        case process_payment_callback(payment_data) do
          {:ok, _booking} ->
            # Return success response to ToyyibPay
            conn
            |> put_status(200)
            |> text("OK")
          {:error, reason} ->
            Logger.error("Payment processing failed: #{inspect(reason)}")
            conn
            |> put_status(500)
            |> text("Payment processing failed")
        end
      {:error, reason} ->
        Logger.error("ToyyibPay callback verification failed: #{inspect(reason)}")
        conn
        |> put_status(400)
        |> text("Invalid callback")
    end
  end

  @doc """
  Handles payment return redirects from ToyyibPay.
  """
  def toyyibpay_return(conn, params) do
    Logger.info("ToyyibPay return received: #{inspect(params)}")

    bill_code = params["billcode"]
    status = params["status_id"]

    case {bill_code, status} do
      {bill_code, "1"} when not is_nil(bill_code) ->
        # Payment successful
        conn
        |> put_flash(:info, "Payment completed successfully!")
        |> redirect(to: ~p"/dashboard")
      {bill_code, "2"} when not is_nil(bill_code) ->
        # Payment failed
        conn
        |> put_flash(:error, "Payment was not completed. Please try again.")
        |> redirect(to: ~p"/dashboard")
      {bill_code, "3"} when not is_nil(bill_code) ->
        # Payment pending
        conn
        |> put_flash(:info, "Payment is being processed. We will notify you once it's completed.")
        |> redirect(to: ~p"/dashboard")
      _ ->
        # Invalid parameters
        conn
        |> put_flash(:error, "Invalid payment response. Please contact support.")
        |> redirect(to: ~p"/dashboard")
    end
  end

  # Private functions

  defp process_payment_callback(payment_data) do
    # Extract booking ID from the external reference number
    booking_id = extract_booking_id_from_reference(payment_data.order_id)

    if booking_id do
      case ToyyibPay.update_booking_payment(booking_id, payment_data) do
        {:ok, booking} ->
          # Log the successful payment
          Umrahly.ActivityLogs.log_user_action(
            booking.user_id,
            "Payment Completed",
            "ToyyibPay Payment",
            %{
              booking_id: booking.id,
              transaction_id: payment_data.transaction_id,
              amount: payment_data.amount
            }
          )
          {:ok, booking}
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Could not extract booking ID from reference"}
    end
  end

  defp extract_booking_id_from_reference(reference) do
    case reference do
      "UMR-" <> booking_id_str ->
        case Integer.parse(booking_id_str) do
          {booking_id, _} -> booking_id
          :error -> nil
        end
      _ -> nil
    end
  end
end
