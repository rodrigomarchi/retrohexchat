defmodule RetroHexChat.Jobs.RuntimeStaleCleanupWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Arcade.Queries, as: ArcadeQueries
  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.GroupCall.Queries, as: GroupCallQueries
  alias RetroHexChat.GroupCall.Schema.Room
  alias RetroHexChat.Jobs.RuntimeStaleCleanupWorker
  alias RetroHexChat.Lobby.Queries, as: LobbyQueries
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChat.RuntimeStaleCleanup
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  test "worker expires stale lobby, arcade and group call records and emits telemetry" do
    now = DateTime.utc_now()
    old = DateTime.add(now, -600, :second)
    fresh = DateTime.add(now, -60, :second)

    {creator, peer} = registered_pair("RuntimeStale")
    lobby = insert_lobby_session!(creator.id, peer.id, "connected")
    fresh_lobby = insert_lobby_session!(creator.id, peer.id, "pending")
    arcade = insert_arcade_session!(creator.id, "playing")
    fresh_arcade = insert_arcade_session!(peer.id, "lobby")
    room = insert_group_call_room!(creator, "active")
    fresh_room = insert_group_call_room!(peer, "open")

    touch!(LobbySession, lobby.id, old)
    touch!(LobbySession, fresh_lobby.id, fresh)
    touch!(SoloSession, arcade.id, old)
    touch!(SoloSession, fresh_arcade.id, fresh)
    touch!(Room, room.id, old)
    touch!(Room, fresh_room.id, fresh)

    attach_telemetry([:retro_hex_chat, :runtime, :stale_cleanup, :stop])

    assert {:ok, summary} =
             RuntimeStaleCleanupWorker.perform(%Oban.Job{
               args: %{"limit" => 10, "stale_after_seconds" => 300}
             })

    assert summary.lobby == %{candidates: 1, expired: 1, skipped: 0}
    assert summary.arcade == %{candidates: 1, expired: 1, skipped: 0}
    assert summary.group_call == %{candidates: 1, expired: 1, skipped: 0}

    assert Repo.get!(LobbySession, lobby.id).status == "expired"
    assert Repo.get!(LobbySession, fresh_lobby.id).status == "pending"
    assert Repo.get!(SoloSession, arcade.id).status == "expired"
    assert Repo.get!(SoloSession, fresh_arcade.id).status == "lobby"
    assert Repo.get!(Room, room.id).status == "expired"
    assert Repo.get!(Room, fresh_room.id).status == "open"

    assert_receive {:telemetry_event, [:retro_hex_chat, :runtime, :stale_cleanup, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "runtime"
    assert metadata.operation == "stale_cleanup"
    assert metadata.result == "ok"
    assert metadata.lobby_expired == 1
    assert metadata.arcade_expired == 1
    assert metadata.group_call_expired == 1
  end

  test "stale expiration skips records updated after candidate selection" do
    now = DateTime.utc_now()
    old = DateTime.add(now, -600, :second)
    fresh = DateTime.add(now, -60, :second)

    {creator, peer} = registered_pair("RuntimeRace")
    lobby = insert_lobby_session!(creator.id, peer.id, "pending")

    touch!(LobbySession, lobby.id, old)

    [candidate] = LobbyQueries.list_stale_sessions(DateTime.add(now, -300, :second), limit: 10)

    touch!(LobbySession, lobby.id, fresh)

    assert {:ok, :skipped} =
             LobbyQueries.expire_stale_session(candidate, DateTime.add(now, -300, :second))

    assert Repo.get!(LobbySession, lobby.id).status == "pending"
  end

  test "counts stale records with the same cutoff used by cleanup" do
    now = DateTime.utc_now()
    old = DateTime.add(now, -600, :second)

    {creator, peer} = registered_pair("RuntimeCount")
    lobby = insert_lobby_session!(creator.id, peer.id, "pending")
    arcade = insert_arcade_session!(creator.id, "playing")
    room = insert_group_call_room!(creator, "active")

    touch!(LobbySession, lobby.id, old)
    touch!(SoloSession, arcade.id, old)
    touch!(Room, room.id, old)

    counts = RuntimeStaleCleanup.counts(cutoff: DateTime.add(now, -300, :second))

    assert counts.lobby == 1
    assert counts.arcade == 1
    assert counts.group_call == 1
    assert counts.total == 3
  end

  defp registered_pair(prefix) do
    suffix = System.unique_integer([:positive]) |> rem(10_000)
    base = String.slice(prefix, 0, 8)
    creator = registered_nick!("#{base}A#{suffix}")
    peer = registered_nick!("#{base}B#{suffix}")

    {creator, peer}
  end

  defp registered_nick!(nickname) do
    {:ok, nick} = ServiceQueries.insert_registered_nick(nickname, "secret123")
    nick
  end

  defp insert_lobby_session!(creator_id, peer_id, status) do
    {:ok, session} =
      LobbyQueries.insert_session(%{
        token: "lobby-#{System.unique_integer([:positive])}",
        creator_id: creator_id,
        peer_id: peer_id,
        status: status
      })

    session
  end

  defp insert_arcade_session!(creator_id, status) do
    {:ok, session} =
      ArcadeQueries.insert_session(%{
        token: "arcade-#{System.unique_integer([:positive])}",
        creator_id: creator_id,
        status: status
      })

    session
  end

  defp insert_group_call_room!(creator, status) do
    {:ok, room} =
      GroupCallQueries.insert_room(%{
        token: "room-#{System.unique_integer([:positive])}",
        channel_name: "#runtime-#{System.unique_integer([:positive])}",
        creator_id: creator.id,
        creator_nick: creator.nickname,
        status: status
      })

    room
  end

  defp touch!(schema, id, timestamp) do
    from(record in schema, where: record.id == ^id)
    |> Repo.update_all(set: [updated_at: timestamp])
  end

  defp attach_telemetry(event) do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [event],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end
end
