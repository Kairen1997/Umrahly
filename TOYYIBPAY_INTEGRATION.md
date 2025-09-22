# ToyyibPay Integration Guide

This document explains how to set up and use ToyyibPay for online payments in the Umrahly booking system.

## Overview

ToyyibPay is a Malaysian payment gateway that supports FPX (Online Banking) and Credit Card payments. This integration allows users to pay for their Umrah bookings securely through ToyyibPay's platform.

## Setup Instructions

### 1. ToyyibPay Account Setup

1. Register for a ToyyibPay account at [https://toyyibpay.com](https://toyyibpay.com)
2. Complete the merchant verification process
3. Create a category for your Umrah bookings
4. Get your User Secret Key and Category Code from the dashboard

### 2. Environment Variables

Add the following environment variables to your `.env` file or system environment:

```bash
# ToyyibPay Configuration
TOYYIBPAY_USER_SECRET_KEY=your_user_secret_key_here
TOYYIBPAY_CATEGORY_CODE=your_category_code_here
TOYYIBPAY_REDIRECT_URI=https://yourdomain.com/payment/toyyibpay/return
TOYYIBPAY_CALLBACK_URI=https://yourdomain.com/payment/toyyibpay/callback
TOYYIBPAY_SANDBOX=true
TOYYIBPAY_API_URL=https://dev.toyyibpay.com/index.php/api
```

### 3. Production Configuration

For production, update the following variables:

```bash
TOYYIBPAY_SANDBOX=false
TOYYIBPAY_API_URL=https://toyyibpay.com/index.php/api
```

## How It Works

### 1. Payment Flow

1. User selects "ToyyibPay (FPX & Credit Card)" as payment method
2. User completes booking form and clicks "Confirm & Proceed to Payment"
3. System creates a bill in ToyyibPay with booking details
4. User is redirected to ToyyibPay payment page
5. User completes payment on ToyyibPay platform
6. ToyyibPay sends callback to your system
7. User is redirected back to your application

### 2. Bill Creation

When a user chooses ToyyibPay, the system:
- Creates a bill in ToyyibPay with booking details
- Sets the bill amount to the deposit amount
- Includes customer information (name, email, phone)
- Sets up callback and return URLs

### 3. Payment Verification

After payment completion:
- ToyyibPay sends a callback to your system
- System verifies the payment with ToyyibPay API
- Booking status is updated to "paid"
- User receives confirmation

## API Integration

### ToyyibPay Service Module

The `Umrahly.ToyyibPay` module handles all ToyyibPay API interactions:

```elixir
# Create a bill
{:ok, %{bill_code: bill_code, payment_url: payment_url}} = 
  Umrahly.ToyyibPay.create_bill(booking, assigns)

# Get payment status
{:ok, %{status: status, amount: amount}} = 
  Umrahly.ToyyibPay.get_bill_transactions(bill_code)

# Verify callback
{:ok, payment_data} = 
  Umrahly.ToyyibPay.verify_callback(callback_params)
```

### Payment Controller

The `UmrahlyWeb.PaymentController` handles:
- ToyyibPay callbacks (`/payment/toyyibpay/callback`)
- Payment return redirects (`/payment/toyyibpay/return`)

## Testing

### Sandbox Mode

1. Set `TOYYIBPAY_SANDBOX=true`
2. Use ToyyibPay sandbox credentials
3. Test payments using bank simulators

### Test Payment Flow

1. Create a test booking
2. Select ToyyibPay as payment method
3. Complete the booking form
4. You'll be redirected to ToyyibPay sandbox
5. Use test payment details to complete payment
6. Verify callback and return handling

## Security Considerations

1. **HTTPS Only**: All payment URLs must use HTTPS
2. **Environment Variables**: Never hardcode API keys
3. **Callback Verification**: Always verify callbacks with ToyyibPay API
4. **Input Validation**: Validate all user inputs
5. **Error Handling**: Implement proper error handling and logging

## Troubleshooting

### Common Issues

1. **Bill Creation Fails**
   - Check User Secret Key and Category Code
   - Verify API URL is correct
   - Check network connectivity

2. **Callback Not Received**
   - Verify callback URL is accessible
   - Check firewall settings
   - Ensure HTTPS is properly configured

3. **Payment Status Not Updated**
   - Check callback verification logic
   - Verify database update operations
   - Check error logs

### Debug Information

Enable debug logging by setting log level to `:debug` in your configuration:

```elixir
config :logger, level: :debug
```

## Support

For ToyyibPay specific issues:
- ToyyibPay Support: [https://toyyibpay.com](https://toyyibpay.com)
- API Documentation: [https://toyyibpay.com/apireference](https://toyyibpay.com/apireference)

For integration issues:
- Check application logs
- Verify environment variables
- Test with sandbox mode first

## Migration from Other Payment Methods

If you're migrating from other payment methods:

1. Update payment method options in UI
2. Update payment processing logic
3. Test thoroughly in sandbox mode
4. Update user documentation
5. Deploy to production with monitoring

## Best Practices

1. **Always test in sandbox first**
2. **Implement proper error handling**
3. **Log all payment transactions**
4. **Monitor payment success rates**
5. **Keep API credentials secure**
6. **Regular security updates** 