defmodule RetroHexChatWeb.ChatLive.AddressBookEvents do
  @moduledoc """
  Routes the Address Book open/close triggers to the stateful island.

  All Address Book state, events and the `ContactList`/`NickColors`/`IgnoreList`/
  `NotifyOps` mutation logic live in
  `RetroHexChatWeb.ChatLive.Components.AddressBookDialog`. This hook only opens the
  dialog (toolbar/menu/keyboard) and reflects the main dialog's Close/OK/Cancel and
  its own Escape/click-away back into the island via `send_update`.

  Attached as `attach_hook(:address_book_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  alias RetroHexChatWeb.ChatLive.Components.AddressBookDialog

  def handle_event("toggle_address_book", _params, socket) do
    send_update(AddressBookDialog, id: AddressBookDialog.id(), toggle: true)
    {:halt, socket}
  end

  def handle_event("close_address_book", _params, socket) do
    send_update(AddressBookDialog, id: AddressBookDialog.id(), close: true)
    {:halt, socket}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc "Opens the Address Book island, optionally on a specific tab."
  @spec open(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket, tab \\ "contacts") do
    send_update(AddressBookDialog, id: AddressBookDialog.id(), open: tab)
    socket
  end

  @doc "Toggles the Address Book island open/closed (keyboard shortcut)."
  @spec toggle(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def toggle(socket) do
    send_update(AddressBookDialog, id: AddressBookDialog.id(), toggle: true)
    socket
  end
end
