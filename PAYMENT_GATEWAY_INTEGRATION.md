# Payment Gateway Integration Guide

This document explains how the payment gateway integration works in the Umrahly booking system.

## Overview

When a user chooses an online payment method during the booking process, they are automatically redirected to an external payment gateway to complete their payment securely.

## Supported Payment Methods

### Online Payment Methods (Require Gateway Redirect)
1. **Credit Card** → Stripe Checkout
2. **Online Banking (FPX)** → PayPal
3. **E-Wallet** → Boost, Touch 'n Go, etc.

### Offline Payment Methods (No Redirect)
1. **Bank Transfer** → Manual payment proof upload
2. **Cash** → Manual payment proof upload

## How It Works

### 1. User Selection
- User selects an online payment method in step 3 of the booking flow
- System determines which payment gateway to use based on the selection

### 2. Booking Creation
- User completes the booking form and clicks "Confirm & Proceed to Payment"
- System creates the booking in the database
- System generates a payment gateway URL based on the selected payment method

### 3. Immediate Redirect
- User is immediately redirected to the external payment gateway
- The redirect happens using `push_navigate(socket, to: payment_url, external: true)`
- A JavaScript hook (`PaymentGatewayRedirect`) provides additional fallback functionality

### 4. Payment Completion
- User completes payment on the external gateway
- User returns to the dashboard after successful payment

## Implementation Details

### LiveView Changes

The main changes are in `lib/umrahly_web/live/user_booking_flow_live.ex`:

```elixir
# In the create_booking function
socket = if requires_online_payment do
  payment_url = generate_payment_gateway_url(booking, socket.assigns)
  
  socket
    |> put_flash(:info, "Booking created successfully! Redirecting to payment gateway...")
    |> assign(:step, 5)
    |> assign(:payment_gateway_url, payment_url)
    |> assign(:requires_online_payment, true)
    |> assign(:current_booking_id, booking.id)
    |> push_navigate(to: payment_url, external: true)  # Immediate redirect
else
  # Handle offline payment methods
end
```

### Payment Gateway URL Generation

The system generates different URLs based on the payment method:

```elixir
defp generate_payment_gateway_url(booking, assigns) do
  config = Application.get_env(:umrahly, :payment_gateway)
  payment_method = assigns.payment_method

  case payment_method do
    "credit_card" -> generate_stripe_payment_url(booking, assigns, config[:stripe])
    "online_banking" -> generate_paypal_payment_url(booking, assigns, config[:paypal])
    "e_wallet" -> generate_ewallet_payment_url(booking, assigns, config[:ewallet])
    _ -> generate_generic_payment_url(booking, assigns, config[:generic])
  end
end
```

### JavaScript Hook

A JavaScript hook (`PaymentGatewayRedirect`) provides additional functionality:

```javascript
const PaymentGatewayRedirect = {
  mounted() {
    const requiresOnlinePayment = this.el.dataset.requiresOnlinePayment === "true";
    const paymentGatewayUrl = this.el.dataset.paymentGatewayUrl;
    
    if (requiresOnlinePayment && paymentGatewayUrl) {
      setTimeout(() => {
        window.open(paymentGatewayUrl, '_blank');
        window.location.href = '/dashboard';
      }, 1500);
    }
  }
};
```

## Configuration

Payment gateway configuration is in `config/config.exs`:

```elixir
config :umrahly, :payment_gateway,
  stripe: [
    publishable_key: System.get_env("STRIPE_PUBLISHABLE_KEY") || "pk_test_example",
    secret_key: System.get_env("STRIPE_SECRET_KEY") || "sk_test_example",
    webhook_secret: System.get_env("STRIPE_WEBHOOK_SECRET") || "whsec_example",
    mode: System.get_env("STRIPE_MODE") || "test"
  ],
  paypal: [
    client_id: System.get_env("PAYPAL_CLIENT_ID") || "client_id_example",
    client_secret: System.get_env("PAYPAL_CLIENT_SECRET") || "client_secret_example",
    mode: System.get_env("PAYPAL_MODE") || "sandbox"
  ],
  ewallet: [
    boost_api_key: System.get_env("BOOST_API_KEY") || "boost_api_key_example",
    touchngo_api_key: System.get_env("TOUCHNGO_API_KEY") || "touchngo_api_key_example",
    mode: System.get_env("EWALLET_MODE") || "test"
  ],
  generic: [
    base_url: System.get_env("PAYMENT_GATEWAY_URL") || "https://payment-gateway.example.com",
    merchant_id: System.get_env("PAYMENT_MERCHANT_ID") || "merchant_example",
    api_key: System.get_env("PAYMENT_API_KEY") || "api_key_example"
  ]
```

## Environment Variables

Set these environment variables for production:

```bash
# Stripe
export STRIPE_PUBLISHABLE_KEY=pk_live_...
export STRIPE_SECRET_KEY=sk_live_...
export STRIPE_WEBHOOK_SECRET=whsec_...
export STRIPE_MODE=live

# PayPal
export PAYPAL_CLIENT_ID=client_id_...
export PAYPAL_CLIENT_SECRET=client_secret_...
export PAYPAL_MODE=live

# E-Wallet
export BOOST_API_KEY=boost_api_key_...
export TOUCHNGO_API_KEY=touchngo_api_key_...
export EWALLET_MODE=live

# Generic Payment Gateway
export PAYMENT_GATEWAY_URL=https://your-gateway.com
export PAYMENT_MERCHANT_ID=your_merchant_id
export PAYMENT_API_KEY=your_api_key
```

## Testing

### Demo URLs

The system generates realistic demo URLs for testing:

- **Stripe**: `https://checkout.stripe.com/pay/cs_test_12345678_abcdef1234567890`
- **PayPal**: `https://www.sandbox.paypal.com/checkoutnow?token=PAY-12345678-ABCD`
- **E-Wallet**: `https://demo-ewallet-gateway.com/pay/EW-12345678-ABCD`
- **Generic**: `https://demo-payment-gateway.com/payment/TXN-12345678-ABCD`

### Test Page

Use `test_payment_gateway.html` to test the payment gateway URLs.

## Production Integration

To complete the integration for production:

### 1. Stripe
- Install Stripe library: `mix deps.get stripe`
- Replace `generate_stripe_payment_url/3` with actual Stripe Checkout Session creation
- Handle webhooks for payment confirmation

### 2. PayPal
- Install PayPal library: `mix deps.get pay`
- Replace `generate_paypal_payment_url/3` with actual PayPal payment creation
- Handle IPN (Instant Payment Notification) for payment confirmation

### 3. E-Wallet
- Implement integration with respective e-wallet APIs
- Replace `generate_ewallet_payment_url/3` with actual e-wallet payment creation

### 4. Generic Gateway
- Implement integration with your payment gateway's API
- Replace `generate_generic_payment_url/3` with actual payment creation

## Security Considerations

1. **HTTPS Only**: All payment gateway URLs must use HTTPS
2. **Environment Variables**: Never hardcode API keys in the source code
3. **Webhook Verification**: Verify webhooks using secret keys
4. **Input Validation**: Validate all user inputs before processing
5. **CSRF Protection**: Ensure CSRF tokens are properly handled

## Troubleshooting

### Common Issues

1. **Redirect Not Working**
   - Check if the payment gateway URL is valid
   - Verify the JavaScript hook is properly loaded
   - Check browser console for errors

2. **Payment Gateway Errors**
   - Verify API keys and configuration
   - Check payment gateway logs
   - Ensure proper error handling

3. **Booking Creation Fails**
   - Check database constraints
   - Verify user authentication
   - Check form validation

### Debug Information

The system includes debug information in step 5:
- Payment method selected
- Payment gateway URL generated
- Online payment requirement status
- Booking ID created

## Future Enhancements

1. **Payment Status Tracking**: Real-time payment status updates
2. **Multiple Currency Support**: Support for different currencies
3. **Recurring Payments**: Subscription-based payment plans
4. **Payment Analytics**: Payment success/failure analytics
5. **Mobile Payment**: Integration with mobile payment solutions

## Support

For questions or issues with the payment gateway integration:

1. Check the debug information in the booking flow
2. Review the browser console for JavaScript errors
3. Check the server logs for Elixir errors
4. Verify payment gateway configuration
5. Test with the provided test page 