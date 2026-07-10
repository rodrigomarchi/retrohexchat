defmodule RetroHexChatWeb.GroupCallChannel do
  @moduledoc """
  Dedicated signaling channel for embedded SFU group calls.

  The browser joins `group_call:<room_token>` with a signed join token, then
  sends SDP answers and ICE candidates directly to the server-side PeerServer
  owned by the room runtime.
  """

  use Phoenix.Channel

  require Logger

  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.JoinToken
  alias RetroHexChat.GroupCall.RateLimiter

  @impl true
  def join("group_call:" <> room_token, params, socket) do
    with {:ok, data} <- verify_join_token(params, room_token),
         {:ok, room} <- GroupCall.get_room(room_token),
         true <- data.channel_name == room.channel_name do
      socket =
        socket
        |> assign(:room_token, room_token)
        |> assign(:channel_name, room.channel_name)
        |> assign(:user_id, data.user_id)
        |> assign(:nickname, data.nickname)

      {:ok, %{version: 1, room: room_payload(room)}, socket}
    else
      false ->
        {:error, %{reason: "invalid_token"}}

      {:error, reason} ->
        {:error, %{reason: join_error(reason, room_token)}}
    end
  end

  @impl true
  def handle_in("group_call_join", payload, socket) do
    actor = %{user_id: socket.assigns.user_id, nickname: socket.assigns.nickname}
    client_info = Map.get(payload, "client_info", %{})
    media_constraints = Map.get(payload, "media_constraints", %{})

    result =
      with :ok <- RateLimiter.check_join_rate(socket.assigns.user_id) do
        GroupCall.join_call(
          socket.assigns.room_token,
          actor,
          self(),
          client_info,
          media_constraints
        )
      end

    case result do
      {:ok, join_payload} ->
        socket = assign(socket, :participant_id, join_payload.participant.id)
        push(socket, "group_call_joined", join_payload)
        {:reply, {:ok, %{participant_id: join_payload.participant.id}}, socket}

      {:error, reason} ->
        payload = %{code: "join_failed", message: error_message(reason)}
        push(socket, "group_call_error", payload)
        {:reply, {:error, payload}, socket}
    end
  end

  def handle_in("group_call_answer", %{"sdp" => sdp}, socket) when is_binary(sdp) do
    with {:ok, participant_id} <- fetch_participant_id(socket),
         :ok <- check_signal_rate(socket),
         :ok <- GroupCall.answer(socket.assigns.room_token, participant_id, sdp) do
      {:reply, :ok, socket}
    else
      {:error, reason} ->
        payload = %{code: "answer_failed", message: error_message(reason)}
        push(socket, "group_call_error", payload)
        {:reply, {:error, payload}, socket}
    end
  end

  def handle_in("group_call_ice_candidate", %{"candidate" => candidate}, socket)
      when is_map(candidate) do
    with {:ok, participant_id} <- fetch_participant_id(socket),
         :ok <- check_signal_rate(socket),
         :ok <- GroupCall.add_ice_candidate(socket.assigns.room_token, participant_id, candidate) do
      {:reply, :ok, socket}
    else
      {:error, reason} ->
        payload = %{code: "ice_failed", message: error_message(reason)}
        push(socket, "group_call_error", payload)
        {:reply, {:error, payload}, socket}
    end
  end

  def handle_in("group_call_media_state", media_state, socket) when is_map(media_state) do
    with {:ok, participant_id} <- fetch_participant_id(socket),
         :ok <- check_signal_rate(socket),
         :ok <- GroupCall.set_media_state(socket.assigns.room_token, participant_id, media_state) do
      {:reply, :ok, socket}
    else
      {:error, reason} ->
        payload = %{code: "media_state_failed", message: error_message(reason)}
        push(socket, "group_call_error", payload)
        {:reply, {:error, payload}, socket}
    end
  end

  def handle_in("group_call_leave", _payload, socket) do
    if participant_id = socket.assigns[:participant_id] do
      :ok = GroupCall.leave_call(socket.assigns.room_token, participant_id, "left")
    end

    {:reply, :ok, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_cast({:group_call_push, event, payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns do
      %{room_token: room_token, participant_id: participant_id} ->
        GroupCall.leave_call(room_token, participant_id, "channel_closed")

      _ ->
        :ok
    end

    :ok
  end

  defp verify_join_token(%{"join_token" => join_token}, room_token) do
    case JoinToken.verify(join_token) do
      {:ok, %{room_token: ^room_token} = data} -> {:ok, data}
      {:ok, _other_room} -> {:error, :invalid_token}
      {:error, reason} -> {:error, reason}
    end
  end

  defp verify_join_token(_params, _room_token), do: {:error, :invalid_token}

  defp fetch_participant_id(socket) do
    case socket.assigns[:participant_id] do
      participant_id when is_integer(participant_id) -> {:ok, participant_id}
      _missing -> {:error, :not_joined}
    end
  end

  defp check_signal_rate(socket) do
    RateLimiter.check_signal_rate(socket.assigns.room_token, socket.assigns.user_id)
  end

  defp room_payload(room) do
    %{
      id: room.id,
      token: room.token,
      channel_name: room.channel_name,
      status: room.status,
      max_participants: room.max_participants
    }
  end

  defp join_error(:not_found, _room_token), do: "not_found"
  defp join_error(:invalid, _room_token), do: "invalid_token"
  defp join_error(:expired, _room_token), do: "invalid_token"
  defp join_error(:invalid_token, _room_token), do: "invalid_token"

  defp join_error(other, room_token) do
    Logger.info("Group call channel join denied",
      room_token: room_token,
      reason: inspect(other)
    )

    "access_denied"
  end

  defp error_message(%Ecto.Changeset{}), do: "Invalid group call state"
  defp error_message(:not_joined), do: "Join the group call before signaling"
  defp error_message(:not_found), do: "Group call not found"
  defp error_message({:rate_limited, seconds}), do: "Rate limited. Try again in #{seconds}s"
  defp error_message(reason) when is_binary(reason), do: reason
  defp error_message(reason), do: inspect(reason)
end
