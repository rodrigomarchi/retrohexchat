defmodule RetroHexChatWeb.P2PChannel do
  @moduledoc """
  The signaling wire of a 1:1 P2P session, `p2p:<session_token>`.

  SDP and ICE used to travel on the LiveView's own socket: the browser pushed to
  `ChatLive`, `ChatLive` broadcast on `"lobby:<token>"`, and the peer's
  `ChatLive` pushed it down again. That made the conversation between two peers
  a property of the page hosting it — a page reload took the wire with it, and
  the same wire could not be shared by a second host.

  What moved here is exactly the traffic that goes **between the two peers**:
  offers, answers, candidates, the answerer's request to renegotiate, and the
  replay that fills the gap after a reconnect. What did not move is everything
  the host does *about* signaling — starting it, restarting it, and the session
  lifecycle — because those carry state the host owns (the transport policy, the
  reattach handshake) and because keeping them still is what let this change
  promise that nothing the user sees is different.

  The domain topic did not change either. This channel publishes on
  `"lobby:<token>"` and subscribes to it, so the LiveView that also listens
  there keeps reacting to the same events it always did.

  Validation and rate limiting are the shared ones — `Calls.SignalValidation`
  and `P2P.SignalingRateLimit`. A second validator is how one path silently
  gets a wider attack surface than the other.
  """

  use Phoenix.Channel, log_join: :debug

  alias RetroHexChat.Calls.Events, as: CallEvents
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.JoinToken
  alias RetroHexChat.Lobby.Policy
  alias RetroHexChat.P2P
  alias RetroHexChat.P2P.SignalingRateLimit

  @pubsub RetroHexChat.PubSub

  @impl true
  def join("p2p:" <> session_token, params, socket) do
    with {:ok, data} <- verify_join_token(params, session_token),
         {:ok, session} <- Lobby.get_session(session_token),
         :ok <- Policy.can_join?(data.user_id, session) do
      Phoenix.PubSub.subscribe(@pubsub, topic(session_token))

      socket =
        socket
        |> assign(:session_token, session_token)
        |> assign(:user_id, data.user_id)
        |> assign(:nickname, data.nickname)

      # Joining is itself the statement "I am listening and I may have missed
      # something", so the catch-up rides the join reply rather than costing a
      # round trip of its own. The client can still ask again on its own
      # schedule, which is what it does when it notices a gap.
      {:ok, %{version: 1, replay: replay_payload(session_token, data.user_id, "channel_join")},
       socket}
    else
      {:error, reason} ->
        code = join_error(reason)
        CallEvents.emit_client_error(:p2p, code, %{phase: "channel_join"})
        {:error, %{reason: code}}
    end
  end

  @impl true
  def handle_in("lobby_signal", params, socket) do
    with :ok <- check_signal_rate(socket),
         {:ok, validated} <- P2P.validate_signal(params) do
      payload = Map.put(validated, :from, socket.assigns.user_id)
      record_and_broadcast(socket, "lobby_signal", payload)
      {:reply, :ok, socket}
    else
      {:error, reason} -> reject(socket, reason, "signal")
    end
  end

  # The answerer asks the initiator to re-offer after adding local media tracks.
  # Only the initiator ever emits offers, so this is how the other side gets
  # one — and it is why two simultaneous Retry clicks are idempotent.
  def handle_in("lobby_renegotiate", params, socket) do
    case check_signal_rate(socket) do
      :ok ->
        payload = renegotiate_payload(params, socket.assigns.user_id)
        record_and_broadcast(socket, "lobby_renegotiate", payload)
        {:reply, :ok, socket}

      {:error, reason} ->
        reject(socket, reason, "renegotiate")
    end
  end

  def handle_in("lobby_signal_replay_request", params, socket) do
    reason = short_string(params, "reason", 80)

    push(socket, "lobby_signal_replay", %{
      events: replay_events(socket.assigns.session_token, socket.assigns.user_id, params),
      reason: reason,
      request_epoch: integer_param(params, "epoch"),
      attempt: integer_param(params, "attempt")
    })

    {:reply, :ok, socket}
  end

  def handle_in(_event, _payload, socket), do: {:noreply, socket}

  @impl true
  # The session topic carries far more than signaling — status changes, feature
  # events, presence. Only the two that are traffic between the peers are named
  # here; everything else belongs to the host that draws it, and is left for it.
  def handle_info(%{event: "lobby_signal", payload: %{from: from} = payload}, socket) do
    unless from == socket.assigns.user_id, do: push(socket, "lobby_signal", payload)
    {:noreply, socket}
  end

  def handle_info(%{event: "lobby_renegotiate", payload: %{from: from} = payload}, socket) do
    unless from == socket.assigns.user_id do
      push(socket, "lobby_renegotiate", %{
        kinds: payload[:kinds] || [],
        recover: payload[:recover] || false,
        epoch: payload[:epoch],
        reason: payload[:reason],
        attempt: payload[:attempt],
        connection_reset: payload[:connection_reset] || false
      })
    end

    {:noreply, socket}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp record_and_broadcast(socket, event, payload) do
    token = socket.assigns.session_token
    _ = Lobby.record_signaling_event(token, socket.assigns.user_id, event, payload)

    Phoenix.PubSub.broadcast(@pubsub, topic(token), %{
      event: event,
      payload: payload,
      token: token
    })
  end

  # A refusal is pushed rather than only replied so the client's recovery path
  # sees it the same way it always did: `lobby_signal_rejected` is what tells it
  # to back off instead of retrying into the same wall.
  defp reject(socket, reason, phase) do
    code = signal_error_code(reason)
    CallEvents.emit_client_error(:p2p, code, %{phase: phase})

    payload = %{code: code, phase: phase, retry_after_ms: retry_after_ms(reason)}
    push(socket, "lobby_signal_rejected", payload)
    {:reply, {:error, payload}, socket}
  end

  defp replay_payload(session_token, user_id, reason) do
    %{
      events: replay_events(session_token, user_id, %{"reason" => reason}),
      reason: reason,
      request_epoch: nil,
      attempt: nil
    }
  end

  defp replay_events(session_token, user_id, params) do
    reason = short_string(params, "reason", 80)
    attempt = integer_param(params, "attempt")
    metadata = %{reason: reason, attempt: attempt}

    case Lobby.signaling_replay(session_token, user_id) do
      {:ok, []} ->
        CallEvents.emit_signaling_replay(:p2p, :empty, Map.put(metadata, :event_count, 0))
        []

      {:ok, events} ->
        CallEvents.emit_signaling_replay(
          :p2p,
          :served,
          Map.put(metadata, :event_count, length(events))
        )

        events

      _unavailable ->
        CallEvents.emit_signaling_replay(:p2p, :failed, metadata)
        []
    end
  end

  defp renegotiate_payload(params, user_id) do
    %{
      from: user_id,
      kinds: safe_track_kinds(Map.get(params, "kinds", [])),
      recover: boolean_param(params, "recover"),
      epoch: integer_param(params, "epoch"),
      reason: short_string(params, "reason", 80),
      attempt: integer_param(params, "attempt"),
      connection_reset: boolean_param(params, "connection_reset")
    }
  end

  defp check_signal_rate(socket) do
    SignalingRateLimit.configured_module().check_signal_rate(
      socket.assigns.session_token,
      socket.assigns.user_id
    )
  end

  defp verify_join_token(%{"join_token" => join_token}, session_token) do
    case JoinToken.verify(join_token) do
      {:ok, %{session_token: ^session_token} = data} -> {:ok, data}
      {:ok, _other_session} -> {:error, :invalid_token}
      {:error, reason} -> {:error, reason}
    end
  end

  defp verify_join_token(_params, _session_token), do: {:error, :invalid_token}

  defp topic(session_token), do: "lobby:#{session_token}"

  defp safe_track_kinds(kinds) when is_list(kinds) do
    kinds
    |> Enum.filter(&(&1 in ["audio", "video"]))
    |> Enum.uniq()
  end

  defp safe_track_kinds(_kinds), do: []

  # A channel payload arrives string-keyed, and a browser spells a boolean four
  # different ways depending on how it got into the JSON.
  defp boolean_param(params, key) do
    Map.get(params, key) in [true, "true", "on", "1", 1]
  end

  defp integer_param(params, key) do
    case Map.get(params, key) do
      value when is_integer(value) -> value
      value when is_binary(value) -> parse_integer(value)
      _absent -> nil
    end
  end

  defp parse_integer(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp short_string(params, key, max) do
    case Map.get(params, key) do
      value when is_binary(value) -> String.slice(value, 0, max)
      _absent -> nil
    end
  end

  # The four the token and the lookup can produce, and the policy's own
  # sentence — which the browser is told nothing about beyond "no", because the
  # reason belongs in the conversation the host owns, not on the wire.
  defp join_error(:not_found), do: "not_found"
  defp join_error(:invalid), do: "invalid_token"
  defp join_error(:expired), do: "invalid_token"
  defp join_error(:invalid_token), do: "invalid_token"
  defp join_error(reason) when is_binary(reason), do: "not_allowed"

  defp signal_error_code(:invalid_signal), do: "invalid_signal"
  defp signal_error_code(:rate_limited), do: "rate_limited"
  defp signal_error_code({:rate_limited, _retry_after}), do: "rate_limited"
  defp signal_error_code(_reason), do: "signal_rejected"

  defp retry_after_ms({:rate_limited, retry_after}) when is_integer(retry_after),
    do: max(retry_after, 0)

  defp retry_after_ms(_reason), do: 0
end
