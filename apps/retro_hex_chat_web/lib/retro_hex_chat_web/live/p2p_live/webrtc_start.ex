defmodule RetroHexChatWeb.P2PLive.WebRTCStart do
  @moduledoc """
  Starting and restarting the session's WebRTC connection from this page:
  the ICE servers and the role-specific start event, pushed exactly once per
  signalling round, said again when the lazily loaded hook says it is
  listening, and a restart turned into a rebuild for a page that has no
  connection yet.
  """

  import Phoenix.LiveView, only: [push_event: 3]

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.P2P
  alias RetroHexChatWeb.App.P2PStats
  alias RetroHexChatWeb.P2PLive.{Console, SessionStatus}

  # ICE config + the role-specific start event, exactly once per
  # (re)signaling round.
  @doc "Pushes the ICE servers and the role's start event, moving the session to `next_state`; once per signalling round. `connection_reset: true` starts it as a rebuild."
  @spec start(Socket.t(), map(), atom(), keyword()) :: Socket.t()
  def start(socket, p2p, next_state \\ :connecting, opts \\ [])

  def start(socket, %{webrtc_started: true} = _p2p, _next_state, _opts), do: socket

  def start(socket, p2p, next_state, opts) do
    connection_reset = Keyword.get(opts, :connection_reset, p2p.webrtc_connection_reset)

    payload = Map.put(payload(p2p), :connection_reset, connection_reset)

    socket
    |> SessionStatus.put_p2p(%{
      p2p
      | state: next_state,
        webrtc_started: true,
        webrtc_connection_reset: connection_reset
    })
    |> push_event(start_webrtc_event(p2p), payload)
  end

  defp start_webrtc_event(%{role: :creator}), do: "lobby_start_offer"

  defp start_webrtc_event(%{role: :peer}), do: "lobby_start_answer"

  # The readiness protocol's second half (`AGENT-GUIDE` §15). The WebRTC hook is
  # lazy, so a page that resumes into a running session pushes its start while
  # the implementation is still being imported — at nobody. The hook says when
  # it is listening, and the start is said again then; `handleStartOffer` and
  # `handleStartAnswer` both return early once they hold a connection, so a page
  # that did hear the first one does nothing with the second.
  #
  # Without this the loss is silent and permanent: the surface has recorded the
  # start, so it never pushes it again, and the restart that follows arrives at
  # a connection with no role and no ICE servers to rebuild from.
  @doc "Says the start again once the lazily loaded hook is listening; nothing before the start was said."
  @spec resend_start(Socket.t(), map()) :: Socket.t()
  def resend_start(socket, %{webrtc_started: true} = p2p) do
    payload = Map.put(payload(p2p), :connection_reset, p2p.webrtc_connection_reset)

    push_event(socket, start_webrtc_event(p2p), payload)
  end

  def resend_start(socket, _p2p), do: socket

  @doc "The server asked for a restart: the session is marked reconnecting, shows the call, and restarts its connection, or starts one as a rebuild if it had none."
  @spec restart_from_signaling(Socket.t(), map(), String.t() | nil) :: Socket.t()
  def restart_from_signaling(socket, p2p, reason) do
    reason = reason || "signaling_restart"

    SessionStatus.emit_p2p_recovery_transition(p2p, :reconnecting, reason, %{
      manual_retry: false,
      trigger: "server"
    })

    p2p = %{
      p2p
      | recovery: %{
          state: :reconnecting,
          attempt: nil,
          reason: reason,
          trigger: "server",
          manual_retry: false
        },
        stats: P2PStats.empty()
    }

    socket =
      socket
      |> SessionStatus.put_p2p(p2p)
      |> Console.open("call")

    if p2p.webrtc_started do
      push_event(socket, "lobby_restart", Map.put(payload(p2p), :reason, reason))
    else
      # A page that has no connection yet but is being told to restart is a page
      # that opened into a session already running — a second tab that took the
      # seat, or a reload mid-call. It has to start as a *rebuild*, because the
      # peer kept its own signalling epoch and would read a fresh page's first
      # offer as stale for the rest of the session.
      start(socket, p2p, :connecting, connection_reset: true)
    end
  end

  @doc "What a start or restart carries: the ICE servers, the role, and whether to relay through TURN only."
  @spec payload(map()) :: map()
  def payload(p2p) do
    %{
      ice_servers: P2P.ice_servers(to_string(p2p.user_id)),
      role: to_string(p2p.role),
      turn_only: p2p.turn_only && p2p.turn_configured
    }
  end
end
