defmodule RetroHexChat.VirtualSpace.DirectMessageSpaceTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChat.VirtualSpace.Registry

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    on_exit(fn -> Application.delete_env(:retro_hex_chat, :virtual_space_step_ms) end)
    :ok
  end

  defp unique_participants do
    suffix = System.unique_integer([:positive])
    ["dm_alice_#{suffix}", "dm_bob_#{suffix}"]
  end

  defp start_private_space(participants, nickname \\ nil) do
    [left, right] = participants
    nickname = nickname || left
    space_id = DirectMessageSpace.space_id(left, right)

    on_exit(fn ->
      case Registry.lookup({:direct_message_space, space_id}) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        {:error, :not_found} -> :ok
      end
    end)

    {:ok, joined} =
      VirtualSpace.join_direct_message_space(
        space_id,
        %{user_id: nil, nickname: nickname},
        participants
      )

    %{space_id: space_id, joined: joined}
  end

  defp participant_key(nickname), do: "nick:#{String.downcase(nickname)}"

  defp track_online(nickname) do
    assert {:ok, _ref} = Tracker.track_user("presence:global", nickname)
    Process.sleep(50)
  end

  test "snapshot contains only online DM participants on the indoor room map" do
    [local, peer] = participants = unique_participants()
    ctx = start_private_space(participants, local)

    assert ctx.joined.map.id == "direct_message_room"
    assert ctx.joined.map.width == 72
    assert ctx.joined.map.height == 30
    assert ctx.joined.participant.key == participant_key(local)

    snapshot_participants = ctx.joined.snapshot.participants
    assert Map.keys(snapshot_participants) == [participant_key(local)]
    refute Map.has_key?(snapshot_participants, participant_key(peer))
  end

  test "globally online peer appears and the room plaque names both users" do
    [local, peer] = participants = unique_participants()
    track_online(peer)

    ctx = start_private_space(participants, local)
    snapshot_participants = ctx.joined.snapshot.participants

    assert Map.keys(snapshot_participants) |> Enum.sort() ==
             [participant_key(local), participant_key(peer)] |> Enum.sort()

    expected_label = "#{local} + #{peer}"

    assert %{text: ^expected_label} =
             Enum.find(ctx.joined.map.labels, &(&1.id == "dm_nameplate"))
  end

  test "global disconnect removes a DM peer even before presence untracks" do
    [local, peer] = participants = unique_participants()
    track_online(peer)

    ctx = start_private_space(participants, local)
    peer_key = participant_key(peer)

    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      "presence:global",
      {:user_disconnected, %{nickname: peer}}
    )

    wait_until(fn ->
      {:ok, snapshot} = VirtualSpace.direct_message_snapshot(ctx.space_id)
      not Map.has_key?(snapshot.participants, peer_key)
    end)
  end

  test "a third user cannot join an existing private room" do
    participants = unique_participants()
    ctx = start_private_space(participants)

    assert {:error, :not_in_direct_message} =
             VirtualSpace.join_direct_message_space(
               ctx.space_id,
               %{user_id: nil, nickname: "charlie"},
               participants
             )
  end

  test "private room movement uses the same delta protocol" do
    ctx = start_private_space(unique_participants())
    key = ctx.joined.participant.key
    %{x: x0, y: y0} = ctx.joined.participant

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "space:#{ctx.space_id}")

    assert :ok = VirtualSpace.input_direct_message(ctx.space_id, key, %{seq: 1, dx: 1, dy: 0})

    assert_receive %{
      event: "space_delta",
      payload: %{seq_ack: %{^key => 1}, updates: %{^key => moved}}
    }

    assert moved.x == x0 + 1
    assert moved.y == y0
    assert moved.dir == "right"
  end

  defp wait_until(fun, retries \\ 50) do
    cond do
      fun.() ->
        :ok

      retries == 0 ->
        flunk("condition never became true")

      true ->
        Process.sleep(10)
        wait_until(fun, retries - 1)
    end
  end
end
