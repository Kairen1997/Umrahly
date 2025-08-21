# Auto-Dismissing Flash Messages

This application now features an enhanced flash message system that automatically dismisses messages after a configurable time period.

## Features

- **Auto-dismiss**: Messages automatically disappear after 5 seconds (configurable)
- **Progress bar**: Visual countdown showing time remaining
- **Hover pause**: Hovering over a message pauses the auto-dismiss timer
- **Click to dismiss**: Click anywhere on the message to dismiss it immediately
- **Close button**: Dedicated close button for easy dismissal
- **Mobile support**: Swipe right to dismiss on touch devices
- **Message stacking**: Multiple messages stack vertically with staggered animations
- **Message limit**: Maximum of 3 messages shown at once (configurable)

## Message Types

The system supports four message types:

- **Info** (`:info`): Blue styling for informational messages
- **Success** (`:success`): Green styling for success confirmations
- **Warning** (`:warning`): Amber styling for warning messages
- **Error** (`:error`): Red styling for error messages

## Usage

### In Controllers

```elixir
def some_action(conn, _params) do
  conn
  |> put_flash(:info, "This is an information message")
  |> put_flash(:success, "Operation completed successfully!")
  |> put_flash(:warning, "Please check your input")
  |> put_flash(:error, "Something went wrong")
  |> render(:some_template)
end
```

### In LiveViews

```elixir
def handle_event("save", _params, socket) do
  case save_operation() do
    {:ok, _result} ->
      {:noreply, put_flash(socket, :success, "Saved successfully!")}
    
    {:error, _changeset} ->
      {:noreply, put_flash(socket, :error, "Failed to save")}
  end
end
```

## Configuration

You can customize the flash message behavior by modifying `assets/js/flash_config.js`:

```javascript
window.FlashConfig = {
  // Auto-dismiss delay in milliseconds
  autoDismissDelay: 5000,
  
  // Whether to show progress bar
  showProgressBar: true,
  
  // Animation duration in milliseconds
  animationDuration: 300,
  
  // Maximum number of flash messages to show at once
  maxMessages: 3
};
```

## Testing

Visit `/test-flash` to see all message types in action and test the auto-dismiss functionality.

## Technical Details

- **JavaScript Hook**: `AutoDismissFlash` handles all client-side functionality
- **CSS Classes**: Uses Tailwind CSS with custom animations
- **LiveView Integration**: Automatically included in all LiveViews via `FlashHandler`
- **Responsive Design**: Adapts to mobile and desktop screen sizes
- **Accessibility**: Proper ARIA labels and keyboard navigation support

## Browser Support

- Modern browsers with ES6+ support
- Touch devices for swipe gestures
- Graceful degradation for older browsers 