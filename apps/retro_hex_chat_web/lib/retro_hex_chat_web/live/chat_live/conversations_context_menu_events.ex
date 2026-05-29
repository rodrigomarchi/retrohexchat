defmodule RetroHexChatWeb.ChatLive.ConversationsContextMenuEvents do
  @moduledoc """
  Handle conversations sidebar channel context menu events.

  Covers: channel_right_click, close_conversations_context_menu,
  ctx_conversations_mark_read, ctx_conversations_mute, ctx_conversations_copy_name,
  ctx_conversations_leave, ctx_conversations_settings.

  Attached as an `attach_hook(:conversations_context_menu_events, :handle_event, ...)` in ChatLive.mount/3.
  Returns `{:halt, socket}` when the event is handled, `{:cont, socket}` otherwise.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [part_channel: 2]

  alias RetroHexChat.Chat.UnreadTracker
  alias RetroHexChatWeb.ChatLive.ChannelCentralEvents

  # ── Context menu ─────────────────────────────────────────

  def handle_event("channel_right_click", %{"channel" => channel} = params, socket) do
    x = params["x"] || 0
    y = params["y"] || 0

    {:halt,
     assign(socket,
       conversations_context_menu: %{visible: true, x: x, y: y, channel: channel}
     )}
  end

  def handle_event("close_conversations_context_menu", _params, socket) do
    {:halt,
     assign(socket, conversations_context_menu: %{visible: false, x: 0, y: 0, channel: nil})}
  end

  # ── Extended conversations context menu actions ────────────────

  def handle_event("ctx_conversations_mark_read", %{"channel" => channel}, socket) do
    unread_counts = UnreadTracker.reset(socket.assigns.unread_counts, channel)
    highlight = MapSet.delete(socket.assigns.highlight_channels, channel)
    flash = MapSet.delete(socket.assigns.flash_channels, channel)

    {:halt,
     socket
     |> close_conversations_menu()
     |> assign(unread_counts: unread_counts, highlight_channels: highlight, flash_channels: flash)}
  end

  def handle_event("ctx_conversations_mute", %{"channel" => channel}, socket) do
    muted = toggle_muted(socket.assigns.muted_channels, channel)

    {:halt,
     socket
     |> close_conversations_menu()
     |> assign(muted_channels: muted)}
  end

  def handle_event("ctx_conversations_copy_name", %{"channel" => channel}, socket) do
    {:halt,
     socket
     |> close_conversations_menu()
     |> push_event("clipboard_copy", %{text: channel})}
  end

  def handle_event("ctx_conversations_leave", %{"channel" => channel}, socket) do
    {:halt,
     socket
     |> close_conversations_menu()
     |> part_channel(channel)}
  end

  def handle_event("ctx_conversations_settings", %{"channel" => channel}, socket) do
    socket = close_conversations_menu(socket)

    ChannelCentralEvents.handle_event(
      "open_channel_central",
      %{"cc_channel" => channel},
      socket
    )
  end

  # ── Catch-all: pass unhandled events to next hook ────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private helpers ──────────────────────────────────────

  defp close_conversations_menu(socket) do
    assign(socket, conversations_context_menu: %{visible: false, x: 0, y: 0, channel: nil})
  end

  defp toggle_muted(muted_set, channel) do
    if MapSet.member?(muted_set, channel) do
      MapSet.delete(muted_set, channel)
    else
      MapSet.put(muted_set, channel)
    end
  end
end
