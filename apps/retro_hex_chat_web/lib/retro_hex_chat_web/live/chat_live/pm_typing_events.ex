defmodule RetroHexChatWeb.ChatLive.PmTypingEvents do
  @moduledoc """
  Handle events for PM typing indicators, tab focus, and mute state sync.

  Covers: pm_typing, pm_stop_typing, tab_focused, mute_state_sync.

  Attached as `attach_hook(:pm_typing_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]
  import RetroHexChatWeb.ChatLive.Helpers, only: [pm_topic: 2]

  def handle_event("pm_typing", _params, socket) do
    session = socket.assigns.session

    if session.active_pm do
      topic = "pm:#{pm_topic(session.nickname, session.active_pm)}"

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        topic,
        %{event: "typing", payload: %{nickname: session.nickname}}
      )
    end

    {:halt, socket}
  end

  def handle_event("pm_stop_typing", _params, socket) do
    session = socket.assigns.session

    if session.active_pm do
      topic = "pm:#{pm_topic(session.nickname, session.active_pm)}"

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        topic,
        %{event: "stop_typing", payload: %{nickname: session.nickname}}
      )
    end

    {:halt, socket}
  end

  def handle_event("tab_focused", _params, socket) do
    {:halt, push_event(socket, "title_flash_stop", %{})}
  end

  def handle_event("mute_state_sync", %{"muted" => muted}, socket) do
    {:halt, assign(socket, muted: muted)}
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
