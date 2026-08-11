defmodule RetroHexChatWeb.ChatLive.PmTypingEvents do
  @moduledoc """
  Handle events for PM typing indicators, tab focus, and legacy mute sync.

  Covers: pm_typing, pm_stop_typing, tab_focused, mute_state_sync.

  Attached as `attach_hook(:pm_typing_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [push_event: 3]

  alias RetroHexChat.Topics

  def handle_event("pm_typing", _params, socket) do
    {:halt, tell_peer(socket, "typing")}
  end

  def handle_event("pm_stop_typing", _params, socket) do
    {:halt, tell_peer(socket, "stop_typing")}
  end

  def handle_event("tab_focused", _params, socket) do
    {:halt, push_event(socket, "title_flash_stop", %{})}
  end

  def handle_event("mute_state_sync", _params, socket), do: {:halt, socket}

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # Addressed to the other person rather than to a topic both are on: the only
  # reader of this is the one being typed at, and the writer was throwing its
  # own echo away.
  defp tell_peer(socket, event) do
    session = socket.assigns.session

    if session.active_pm do
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        Topics.inbox(session.active_pm),
        %{event: event, payload: %{nickname: session.nickname}}
      )
    end

    socket
  end
end
