defmodule RetroHexChatWeb.ChatLive.TreebarContextMenuEvents do
  @moduledoc """
  Handle treebar channel context menu events.

  Covers: channel_right_click, close_treebar_context_menu,
  ctx_treebar_mark_read, ctx_treebar_mute, ctx_treebar_copy_name,
  ctx_treebar_leave, ctx_treebar_settings.

  Attached as an `attach_hook(:treebar_context_menu_events, :handle_event, ...)` in ChatLive.mount/3.
  Returns `{:halt, socket}` when the event is handled, `{:cont, socket}` otherwise.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [part_channel: 2]

  alias RetroHexChat.Chat.{UnreadTracker, UserPreferences}
  alias RetroHexChatWeb.ChatLive.Helpers.Persistence

  # ── Context menu ─────────────────────────────────────────

  def handle_event("channel_right_click", %{"channel" => channel} = params, socket) do
    x = params["x"] || 0
    y = params["y"] || 0

    {:halt,
     assign(socket,
       treebar_context_menu: %{visible: true, x: x, y: y, channel: channel}
     )}
  end

  def handle_event("close_treebar_context_menu", _params, socket) do
    {:halt, assign(socket, treebar_context_menu: %{visible: false, x: 0, y: 0, channel: nil})}
  end

  # ── Extended treebar context menu actions ────────────────

  def handle_event("ctx_treebar_mark_read", %{"channel" => channel}, socket) do
    unread_counts = UnreadTracker.reset(socket.assigns.unread_counts, channel)
    highlight = MapSet.delete(socket.assigns.highlight_channels, channel)
    flash = MapSet.delete(socket.assigns.flash_channels, channel)

    {:halt,
     socket
     |> close_treebar_menu()
     |> assign(unread_counts: unread_counts, highlight_channels: highlight, flash_channels: flash)}
  end

  def handle_event("ctx_treebar_mute", %{"channel" => channel}, socket) do
    session = socket.assigns.session
    updated_prefs = UserPreferences.toggle_mute_channel(session.user_preferences, channel)
    updated_session = %{session | user_preferences: updated_prefs}
    muted = toggle_muted(socket.assigns.muted_channels, channel)

    {:halt,
     socket
     |> close_treebar_menu()
     |> assign(session: updated_session, muted_channels: muted)
     |> Persistence.maybe_persist_user_preferences(updated_session)}
  end

  def handle_event("ctx_treebar_copy_name", %{"channel" => channel}, socket) do
    {:halt,
     socket
     |> close_treebar_menu()
     |> push_event("clipboard_copy", %{text: channel})}
  end

  def handle_event("ctx_treebar_leave", %{"channel" => channel}, socket) do
    {:halt,
     socket
     |> close_treebar_menu()
     |> part_channel(channel)}
  end

  def handle_event("ctx_treebar_settings", %{"channel" => _channel}, socket) do
    # Channel settings dialog — placeholder, close menu for now
    {:halt, close_treebar_menu(socket)}
  end

  # ── Catch-all: pass unhandled events to next hook ────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private helpers ──────────────────────────────────────

  defp close_treebar_menu(socket) do
    assign(socket, treebar_context_menu: %{visible: false, x: 0, y: 0, channel: nil})
  end

  defp toggle_muted(muted_set, channel) do
    if MapSet.member?(muted_set, channel) do
      MapSet.delete(muted_set, channel)
    else
      MapSet.put(muted_set, channel)
    end
  end
end
