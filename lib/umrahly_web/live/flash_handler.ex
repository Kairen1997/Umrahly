defmodule UmrahlyWeb.FlashHandler do
  @moduledoc """
  Handles flash message events across all LiveViews.
  """

  defmacro __using__(_) do
    quote do
      # Handle flash message clearing
      def handle_event("lv:clear-flash", %{"key" => key}, socket) do
        # Clear the specific flash message
        socket = clear_flash(socket, String.to_existing_atom(key))
        {:noreply, socket}
      end

      def handle_event("lv:clear-flash", _params, socket) do
        # Clear all flash messages if no specific key provided
        socket = clear_flash(socket)
        {:noreply, socket}
      end
    end
  end
end
