defmodule RetroHexChatWeb.P2PLive.SessionStatus do
  @moduledoc """
  Where a P2P session stands, as this page holds it in the `p2p_session`
  assign: reconnecting or failed and why, the telemetry each recovery step
  emits, and the sentences the page says about it.
  """

  import Phoenix.Component, only: [assign: 2, update: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Calls.Events, as: CallEvents
  alias RetroHexChat.Lobby
  alias RetroHexChatWeb.App.P2PStats
  alias RetroHexChatWeb.Live.Surface

  @doc "Replaces the `p2p_session` assign."
  @spec put_p2p(Socket.t(), map() | nil) :: Socket.t()
  def put_p2p(socket, p2p), do: assign(socket, p2p_session: p2p)

  @doc "Marks the session reconnecting (attempt, reason, trigger), clears its stats and reports the transition."
  @spec mark_p2p_reconnecting(Socket.t(), integer() | nil, String.t(), map()) :: Socket.t()
  def mark_p2p_reconnecting(socket, attempt, reason, metadata) do
    emit_p2p_recovery_transition(socket.assigns[:p2p_session], :reconnecting, reason, %{
      attempt: attempt,
      manual_retry: false,
      trigger: metadata[:trigger]
    })

    update(socket, :p2p_session, fn
      nil ->
        nil

      p2p ->
        %{
          p2p
          | recovery: %{
              state: :reconnecting,
              attempt: attempt,
              reason: reason,
              trigger: metadata[:trigger],
              manual_retry: false
            },
            stats: P2PStats.empty()
        }
    end)
  end

  @doc "Marks the session failed for `reason`, offering a manual retry, and reports it."
  @spec mark_p2p_failed(Socket.t(), String.t()) :: Socket.t()
  def mark_p2p_failed(socket, reason) do
    p2p = socket.assigns[:p2p_session]

    emit_p2p_recovery_transition(p2p, :failed, reason, %{
      manual_retry: true,
      phase: "connection"
    })

    CallEvents.emit_client_error(:p2p, reason, %{phase: "connection"})

    update(socket, :p2p_session, fn
      nil ->
        nil

      p2p ->
        %{
          p2p
          | recovery: %{
              state: :failed,
              attempt: nil,
              reason: reason,
              trigger: "connection",
              manual_retry: true
            },
            stats: P2PStats.empty()
        }
    end)
  end

  @doc "Whether the session already failed for this same reason."
  @spec p2p_failed?(map() | nil, String.t()) :: boolean()
  def p2p_failed?(%{recovery: %{state: :failed, reason: reason}}, reason), do: true

  def p2p_failed?(_p2p, _reason), do: false

  @doc "The recovery state of a session that has not had to recover."
  @spec empty_p2p_recovery() :: map()
  def empty_p2p_recovery do
    %{state: :idle, attempt: nil, reason: nil, trigger: nil, manual_retry: false}
  end

  @doc "Says a P2P notice on this page's status bar."
  @spec p2p_system_event(Socket.t(), term()) :: Socket.t()
  def p2p_system_event(socket, message) do
    Surface.system(socket, p2p_notice_text(message))
  end

  @doc "The sentence for a P2P notice: itself when already a sentence, else what the reason means."
  @spec p2p_notice_text(term()) :: String.t()
  def p2p_notice_text(message) when is_binary(message), do: message

  def p2p_notice_text(:not_found) do
    dgettext("chat", "This P2P invite is no longer active.")
  end

  def p2p_notice_text(:already_joined) do
    dgettext("chat", "This P2P session is already active in another window.")
  end

  def p2p_notice_text(reason) when is_atom(reason) do
    reason = reason |> Atom.to_string() |> String.replace("_", " ")
    dgettext("chat", "P2P action failed: %{reason}", reason: reason)
  end

  def p2p_notice_text(reason) do
    dgettext("chat", "P2P action failed: %{reason}", reason: inspect(reason))
  end

  @doc "The other side's nickname in the session, as `user_id` sees it; nil for a session that is gone."
  @spec peer_nick_for(String.t(), integer()) :: String.t() | nil
  def peer_nick_for(token, user_id) do
    case Lobby.session_summary(token) do
      {:ok, summary} ->
        case Lobby.get_session(token) do
          {:ok, %{creator_id: ^user_id}} -> summary.peer
          _ -> summary.created_by
        end

      _ ->
        nil
    end
  end

  @doc "The sentence for a session that ended, by why it ended."
  @spec ended_message(String.t() | nil, String.t()) :: String.t()
  def ended_message(peer_nick, reason) do
    reason_message(reason, peer_nick || dgettext("chat", "the other user"))
  end

  defp reason_message("declined", peer),
    do: dgettext("chat", "%{peer} declined the P2P invite.", peer: peer)

  defp reason_message("invite_cancelled", _peer),
    do: dgettext("chat", "The P2P invite was cancelled.")

  defp reason_message("peer_left", peer),
    do: dgettext("chat", "%{peer} left the P2P session.", peer: peer)

  defp reason_message("connecting_timeout", peer),
    do: dgettext("chat", "Could not connect to %{peer}.", peer: peer)

  defp reason_message(reason, _peer)
       when reason in ["expired", "pending_timeout", "lobby_inactivity"],
       do: dgettext("chat", "The P2P session expired.")

  defp reason_message(_user_closed_or_other, peer),
    do: dgettext("chat", "P2P session with %{peer} ended.", peer: peer)

  @doc "Reports a recovery that ended connected, when the session was reconnecting or failed."
  @spec emit_p2p_connected(map() | nil) :: :ok
  def emit_p2p_connected(p2p) do
    case p2p_recovery_state(p2p) do
      state when state in [:reconnecting, :failed] ->
        emit_p2p_recovery_transition(p2p, :connected, p2p_recovery_reason(p2p), %{
          manual_retry: false,
          trigger: "connected"
        })

      _state ->
        :ok
    end
  end

  @doc "Reports a recovery transition with the session's role; nothing without a session."
  @spec emit_p2p_recovery_transition(map() | nil, atom(), String.t(), map()) :: :ok
  def emit_p2p_recovery_transition(nil, _state, _reason, _metadata), do: :ok

  def emit_p2p_recovery_transition(p2p, state, reason, metadata) when is_map(p2p) do
    CallEvents.emit_recovery_transition(
      :p2p,
      state,
      reason,
      Map.put(metadata, :role, Map.get(p2p, :role))
    )
  end

  defp p2p_recovery_state(%{recovery: %{state: state}}), do: state

  defp p2p_recovery_state(_p2p), do: nil

  defp p2p_recovery_reason(%{recovery: %{reason: reason}}) when not is_nil(reason), do: reason

  defp p2p_recovery_reason(_p2p), do: "connected"
end
