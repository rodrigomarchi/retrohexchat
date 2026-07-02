defmodule RetroHexChatWeb.ChatLive.AddressBookEvents do
  @moduledoc """
  Routes the Address Book open triggers to its server-managed desktop window.

  All Address Book state, events and the `ContactList`/`NickColors`/`IgnoreList`/
  `NotifyOps` mutation logic live in
  `RetroHexChatWeb.ChatLive.Components.AddressBookDialog`, mounted inside the
  window; closing the window unmounts the island.

  Attached as `attach_hook(:address_book_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  alias RetroHexChatWeb.ChatLive.Components.AddressBookDialog
  alias RetroHexChatWeb.ChatLive.Windows

  def handle_event("toggle_address_book", _params, socket) do
    {:halt, Windows.open(socket, "address-book")}
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  Opens/focuses the Address Book window on a specific tab. The window mounts
  first (managed), then the tab directive reaches the island — `open_window`
  before `send_update`, so the island exists in the patch.
  """
  @spec open(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket, tab \\ "contacts") do
    socket = Windows.open(socket, "address-book")
    send_update(AddressBookDialog, id: AddressBookDialog.id(), open: tab)
    socket
  end

  @doc "Opens/focuses the Address Book window (keyboard shortcut)."
  @spec toggle(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def toggle(socket), do: open(socket)
end
