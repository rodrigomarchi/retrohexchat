defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.Ctcp do
  @moduledoc """
  PubSub handlers for CTCP requests, replies, and timeouts.
  """

  import Phoenix.Component, only: [assign: 2]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_event: 2, maybe_send_ctcp_reply: 7]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.CtcpSettings

  def handle_info(
        {:ctcp_request, %{type: type, sender: sender, request_id: req_id, sent_at: sent_at}},
        socket
      ) do
    session = socket.assigns.session
    settings = Session.get_ctcp_settings(session)
    type_upper = type |> Atom.to_string() |> String.upcase()

    socket = system_event(socket, "* CTCP #{type_upper} request from #{sender}")

    socket = maybe_send_ctcp_reply(socket, session, settings, type, sender, req_id, sent_at)
    {:halt, socket}
  end

  def handle_info(
        {:ctcp_reply,
         %{type: type, replier: replier, request_id: req_id, value: value, sent_at: sent_at}},
        socket
      ) do
    pending = socket.assigns.ctcp_pending

    case Map.pop(pending, req_id) do
      {nil, _} ->
        {:halt, socket}

      {%{timer_ref: timer_ref}, remaining} ->
        Process.cancel_timer(timer_ref)
        type_upper = type |> Atom.to_string() |> String.upcase()

        display_value =
          case type do
            :ping ->
              latency = System.monotonic_time(:millisecond) - sent_at
              "#{latency}ms"

            _ ->
              value
          end

        {:halt,
         socket
         |> assign(ctcp_pending: remaining)
         |> system_event("* CTCP #{type_upper} reply from #{replier}: #{display_value}")}
    end
  end

  def handle_info({:ctcp_timeout, request_id}, socket) do
    pending = socket.assigns.ctcp_pending

    case Map.pop(pending, request_id) do
      {nil, _} ->
        {:halt, socket}

      {%{target: target}, remaining} ->
        {:halt,
         socket
         |> assign(ctcp_pending: remaining)
         |> system_event("* No CTCP reply from #{target} (timed out)")}
    end
  end

  # Test helpers for CTCP
  def handle_info({:_test_add_ctcp_pending, request_id, data}, socket) do
    pending = Map.put(socket.assigns.ctcp_pending, request_id, data)
    {:halt, assign(socket, ctcp_pending: pending)}
  end

  def handle_info({:_test_set_ctcp_enabled, enabled}, socket) do
    session = socket.assigns.session
    settings = CtcpSettings.set_enabled(session.ctcp_settings, enabled)
    new_session = Session.set_ctcp_settings(session, settings)
    {:halt, assign(socket, session: new_session)}
  end

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_, socket), do: {:cont, socket}
end
