defmodule RetroHexChat.P2P.CleanupTaskTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.P2P.{CleanupTask, Queries, Supervisor}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  defp create_registered_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{
        nickname: nickname,
        password: "password123"
      })
      |> Repo.insert()

    nick
  end

  defp create_session_record(creator_id, peer_id, opts \\ []) do
    token = Keyword.get(opts, :token, "ct-#{System.unique_integer([:positive])}")

    {:ok, session} =
      Queries.insert_session(%{
        token: token,
        creator_id: creator_id,
        peer_id: peer_id,
        status: "pending",
        session_type: "generic"
      })

    session
  end

  defp make_stale(session) do
    # Set inserted_at and updated_at to 1 hour ago to make it stale
    past = DateTime.add(DateTime.utc_now(), -3600, :second)

    import Ecto.Query

    from(s in "p2p_sessions", where: s.id == ^session.id)
    |> Repo.update_all(set: [inserted_at: past, updated_at: past])

    Queries.get_session(session.id)
  end

  setup do
    # Use very long pending timeout so GenServers don't expire during test
    Application.put_env(:retro_hex_chat, :p2p_pending_timeout, 60_000)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :p2p_pending_timeout)
    end)
  end

  describe "run_cleanup/0" do
    test "expires stale pending sessions with no GenServer" do
      alice = create_registered_nick("alice_ct1")
      bob = create_registered_nick("bob_ct1")
      session = create_session_record(alice.id, bob.id)
      stale_session = make_stale(session)

      assert stale_session.status == "pending"

      assert {:ok, count} = CleanupTask.run_cleanup()
      assert count >= 1

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "expired"
      assert updated.closed_reason == "stale_cleanup"
    end

    test "leaves active sessions with running GenServer untouched" do
      alice = create_registered_nick("alice_ct2")
      bob = create_registered_nick("bob_ct2")
      session = create_session_record(alice.id, bob.id)
      _stale_session = make_stale(session)

      # Start a GenServer for this session
      {:ok, _pid} = Supervisor.start_child(session.token)

      assert {:ok, count} = CleanupTask.run_cleanup()
      # This specific session should NOT be expired
      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "pending"

      # Clean up
      {:ok, pid} = RetroHexChat.P2P.Registry.lookup(session.token)
      GenServer.stop(pid, :normal)
      assert count >= 0
    end

    test "ignores terminal sessions" do
      alice = create_registered_nick("alice_ct3")
      bob = create_registered_nick("bob_ct3")
      session = create_session_record(alice.id, bob.id)

      Queries.update_status(session, "closed", %{
        closed_at: DateTime.utc_now(),
        closed_reason: "done"
      })

      _stale = make_stale(session)

      assert {:ok, _count} = CleanupTask.run_cleanup()

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "closed"
    end

    test "returns count including expired sessions" do
      alice = create_registered_nick("alice_ct4")
      bob = create_registered_nick("bob_ct4")
      charlie = create_registered_nick("char_ct4")

      session1 = create_session_record(alice.id, bob.id)
      session2 = create_session_record(alice.id, charlie.id)

      make_stale(session1)
      make_stale(session2)

      assert {:ok, count} = CleanupTask.run_cleanup()
      assert count >= 2

      assert Queries.get_session_by_token(session1.token).status == "expired"
      assert Queries.get_session_by_token(session2.token).status == "expired"
    end
  end

  describe "process" do
    test "CleanupTask is running" do
      assert Process.whereis(CleanupTask) != nil
    end
  end
end
