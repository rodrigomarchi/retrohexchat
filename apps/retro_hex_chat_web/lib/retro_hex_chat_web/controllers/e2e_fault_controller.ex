defmodule RetroHexChatWeb.E2EFaultController do
  use RetroHexChatWeb, :controller

  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.PeerSupervisor
  alias RetroHexChat.GroupCall.Registry

  @peer_down_wait_ms 2_000
  @peer_down_poll_ms 25

  @spec terminate_group_call_peer(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def terminate_group_call_peer(conn, params) do
    if Application.get_env(:retro_hex_chat, :e2e_fault_injection?, false) do
      do_terminate_group_call_peer(conn, params)
    else
      not_found(conn)
    end
  end

  defp do_terminate_group_call_peer(conn, %{"token" => token, "participant_id" => participant_id}) do
    with {:ok, parsed_participant_id} <- parse_id(participant_id),
         {:ok, room} <- GroupCall.get_room(token),
         {:ok, _pid} <- Registry.lookup_peer({:peer, room.id, parsed_participant_id}) do
      PeerSupervisor.terminate_peer(room.id, parsed_participant_id)

      case wait_until_peer_down(token, room.id, parsed_participant_id) do
        :ok ->
          json(conn, %{status: "terminated"})

        :timeout ->
          conn
          |> put_status(:conflict)
          |> json(%{status: "pending"})
      end
    else
      _ -> not_found(conn)
    end
  end

  defp do_terminate_group_call_peer(conn, _params), do: not_found(conn)

  defp parse_id(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_id(value) do
    case Integer.parse(to_string(value)) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> :error
    end
  end

  defp wait_until_peer_down(token, room_id, participant_id) do
    deadline = System.monotonic_time(:millisecond) + @peer_down_wait_ms
    do_wait_until_peer_down(token, room_id, participant_id, deadline)
  end

  defp do_wait_until_peer_down(token, room_id, participant_id, deadline) do
    cond do
      peer_down?(room_id, participant_id) and participant_disconnected?(token, participant_id) ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        :timeout

      true ->
        Process.sleep(@peer_down_poll_ms)
        do_wait_until_peer_down(token, room_id, participant_id, deadline)
    end
  end

  defp peer_down?(room_id, participant_id) do
    Registry.lookup_peer({:peer, room_id, participant_id}) == {:error, :not_found}
  end

  defp participant_disconnected?(token, participant_id) do
    case GroupCall.get_summary(token) do
      {:ok, %{participants: participants}} ->
        Enum.any?(participants, fn participant ->
          participant[:id] == participant_id and participant[:status] == "disconnected"
        end)

      _ ->
        false
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{status: "not_found"})
  end
end
