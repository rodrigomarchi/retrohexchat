defmodule RetroHexChat.VirtualSpace.SessionServerTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.VirtualSpace.{Queries, Registry, SessionServer, Supervisor}

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_pending_timeout, 100)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :virtual_space_pending_timeout)
    end)
  end

  defp insert_space(attrs) do
    creator = insert(:registered_nick)

    base = %{
      token: "space-#{System.unique_integer([:positive])}",
      channel_name: "#retro",
      creator_id: creator.id,
      creator_nick: creator.nickname,
      title: "HQ",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }

    {:ok, session} = Queries.insert_session(Map.merge(base, attrs))
    {session, creator}
  end

  defp start_space(attrs \\ %{}) do
    {session, creator} = insert_space(attrs)
    {:ok, pid} = Supervisor.start_child(session.token)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal)
    end)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "space:#{session.token}")
    {session, creator}
  end

  defp participant(nick) do
    %{user_id: nick.id, nickname: nick.nickname}
  end

  describe "join/2" do
    test "first join transitions pending -> active and records activated_at" do
      {session, creator} = start_space()

      assert {:ok, joined} = SessionServer.join(session.token, participant(creator))
      assert joined.participant.key == "registered:#{creator.id}"

      db_session = Queries.get_session_by_token(session.token)
      assert db_session.status == "active"
      assert db_session.activated_at

      assert_received %{event: "space_participant_joined", payload: %{nickname: nickname}}
      assert nickname == creator.nickname
    end

    test "joins get distinct free spawn tiles" do
      {session, creator} = start_space()
      other = insert(:registered_nick)

      {:ok, first} = SessionServer.join(session.token, participant(creator))
      {:ok, second} = SessionServer.join(session.token, participant(other))

      assert {first.participant.x, first.participant.y} !=
               {second.participant.x, second.participant.y}
    end

    test "rejects a join beyond capacity" do
      {session, creator} = start_space(%{max_participants: 1})
      other = insert(:registered_nick)

      {:ok, _} = SessionServer.join(session.token, participant(creator))

      assert {:error, :space_full} = SessionServer.join(session.token, participant(other))
    end

    test "rejoin of the same participant_key takes over and keeps the position" do
      {session, creator} = start_space(%{max_participants: 1})

      {:ok, first} = SessionServer.join(session.token, participant(creator))
      :ok = SessionServer.leave(session.token, "registered:#{creator.id}")

      {:ok, state} = SessionServer.get_state(session.token)
      refute state.participants["registered:#{creator.id}"].online?

      {:ok, again} = SessionServer.join(session.token, participant(creator))
      assert again.participant.x == first.participant.x
      assert again.participant.y == first.participant.y
      assert again.participant.online?
    end
  end

  describe "leave/2" do
    test "marks the participant offline but keeps the position" do
      {session, creator} = start_space()
      {:ok, joined} = SessionServer.join(session.token, participant(creator))

      :ok = SessionServer.leave(session.token, joined.participant.key)

      {:ok, state} = SessionServer.get_state(session.token)
      entry = state.participants[joined.participant.key]
      refute entry.online?
      assert entry.x == joined.participant.x
      assert entry.y == joined.participant.y

      assert_received %{event: "space_participant_left", payload: %{key: key}}
      assert key == joined.participant.key
    end
  end

  describe "expiry" do
    test "a pending session with no joins expires on the pending timeout" do
      {session, _creator} = start_space()

      assert_receive %{event: "space_closed", payload: %{reason: "pending_timeout"}}, 500
      assert Queries.get_session_by_token(session.token).status == "expired"
    end

    test "an active session expires at expires_at and broadcasts the end" do
      {session, creator} =
        start_space(%{expires_at: DateTime.add(DateTime.utc_now(), 200, :millisecond)})

      {:ok, _} = SessionServer.join(session.token, participant(creator))

      assert_receive %{event: "space_closed", payload: %{reason: "expired"}}, 1000
      assert Queries.get_session_by_token(session.token).status == "expired"
    end
  end

  describe "close/3" do
    test "closes the session and stops the process" do
      {session, creator} = start_space()
      {:ok, _} = SessionServer.join(session.token, participant(creator))

      assert :ok = SessionServer.close(session.token, "creator_closed")

      assert_receive %{event: "space_closed", payload: %{reason: "creator_closed"}}
      assert Queries.get_session_by_token(session.token).status == "closed"
      assert {:error, :not_found} = Registry.lookup(session.token)
    end
  end

  describe "session_summary/1" do
    test "reflects the live process count and status" do
      {session, creator} = start_space()
      other = insert(:registered_nick)

      {:ok, _} = SessionServer.join(session.token, participant(creator))
      {:ok, _} = SessionServer.join(session.token, participant(other))

      assert {:ok, summary} = SessionServer.session_summary(session.token)
      assert summary.status == "active"
      assert summary.participant_count == 2
      assert summary.max_participants == session.max_participants
      assert summary.title == "HQ"
      assert summary.map_id == "tavern_cafe_v1"

      :ok = SessionServer.leave(session.token, "registered:#{other.id}")

      assert {:ok, summary} = SessionServer.session_summary(session.token)
      assert summary.participant_count == 1
    end
  end
end
