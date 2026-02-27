defmodule RetroHexChat.P2P.SessionServerTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.P2P.{Queries, SessionServer, Supervisor}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  # Use very short timeouts for testing
  setup do
    Application.put_env(:retro_hex_chat, :p2p_pending_timeout, 100)
    Application.put_env(:retro_hex_chat, :p2p_lobby_warning_timeout, 100)
    Application.put_env(:retro_hex_chat, :p2p_lobby_expiry_timeout, 200)
    Application.put_env(:retro_hex_chat, :p2p_connecting_timeout, 100)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :p2p_pending_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_lobby_warning_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_lobby_expiry_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_connecting_timeout)
    end)
  end

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
    token = Keyword.get(opts, :token, "ss-#{System.unique_integer([:positive])}")

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

  defp start_server(token) do
    {:ok, pid} = Supervisor.start_child(token)
    pid
  end

  defp stop_server(token) do
    case RetroHexChat.P2P.Registry.lookup(token) do
      {:ok, pid} ->
        GenServer.stop(pid, :normal)
        Process.sleep(10)

      {:error, :not_found} ->
        :ok
    end
  end

  describe "start_link and init" do
    test "starts a GenServer for a pending session" do
      alice = create_registered_nick("alice_ss1")
      bob = create_registered_nick("bob_ss1")
      session = create_session_record(alice.id, bob.id)

      pid = start_server(session.token)
      assert Process.alive?(pid)
      stop_server(session.token)
    end

    test "ignores terminal sessions" do
      alice = create_registered_nick("alice_ss2")
      bob = create_registered_nick("bob_ss2")
      session = create_session_record(alice.id, bob.id)

      Queries.update_status(session, "closed", %{
        closed_at: DateTime.utc_now(),
        closed_reason: "done"
      })

      assert :ignore = SessionServer.start_link(session.token)
    end

    test "stops if session not found in DB" do
      Process.flag(:trap_exit, true)

      pid = spawn_link(fn -> SessionServer.start_link("nonexistent-token") end)

      assert_receive {:EXIT, ^pid, _reason}, 1000
    end
  end

  describe "get_state/1" do
    test "returns current state" do
      alice = create_registered_nick("alice_ss3")
      bob = create_registered_nick("bob_ss3")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      assert {:ok, state} = SessionServer.get_state(session.token)
      assert state.token == session.token
      assert state.session.status == "pending"
      assert state.creator_joined == false
      assert state.peer_joined == false

      stop_server(session.token)
    end
  end

  describe "join/2" do
    test "records creator joining" do
      alice = create_registered_nick("alice_ss4")
      bob = create_registered_nick("bob_ss4")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      assert :ok = SessionServer.join(session.token, alice.id)

      {:ok, state} = SessionServer.get_state(session.token)
      assert state.creator_joined == true
      assert state.peer_joined == false
      assert state.session.status == "pending"

      stop_server(session.token)
    end

    test "transitions to lobby when both peers join" do
      alice = create_registered_nick("alice_ss6")
      bob = create_registered_nick("bob_ss6")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{session.token}")

      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)

      {:ok, state} = SessionServer.get_state(session.token)
      assert state.session.status == "lobby"

      assert_receive %{event: "p2p_status_changed", payload: %{status: "lobby"}}

      stop_server(session.token)
    end

    test "rejects non-participant" do
      alice = create_registered_nick("alice_ss7")
      bob = create_registered_nick("bob_ss7")
      charlie = create_registered_nick("char_ss7")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      assert {:error, "Not a participant"} = SessionServer.join(session.token, charlie.id)

      stop_server(session.token)
    end

    test "returns error when process not running" do
      assert {:error, "Session process not running"} =
               SessionServer.join("nonexistent", 1)
    end
  end

  describe "close/3" do
    test "closes session and stops GenServer" do
      alice = create_registered_nick("alice_ss8")
      bob = create_registered_nick("bob_ss8")
      session = create_session_record(alice.id, bob.id)
      pid = start_server(session.token)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{session.token}")

      assert :ok = SessionServer.close(session.token, alice.id, "user_closed")

      Process.sleep(50)
      refute Process.alive?(pid)

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "closed"
      assert updated.closed_reason == "user_closed"
      assert updated.closed_at != nil

      assert_receive %{
        event: "p2p_session_closed",
        payload: %{reason: "user_closed", closed_by: "user"}
      }
    end
  end

  describe "transition/2" do
    test "lobby to connecting" do
      alice = create_registered_nick("alice_ss9")
      bob = create_registered_nick("bob_ss9")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{session.token}")

      assert :ok = SessionServer.transition(session.token, :connecting)

      {:ok, state} = SessionServer.get_state(session.token)
      assert state.session.status == "connecting"

      assert_receive %{event: "p2p_status_changed", payload: %{status: "connecting"}}

      stop_server(session.token)
    end

    test "connecting to active" do
      alice = create_registered_nick("alice_s10")
      bob = create_registered_nick("bob_s10")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)
      :ok = SessionServer.transition(session.token, :connecting)

      assert :ok = SessionServer.transition(session.token, :active)

      {:ok, state} = SessionServer.get_state(session.token)
      assert state.session.status == "active"

      stop_server(session.token)
    end

    test "rejects invalid transition" do
      alice = create_registered_nick("alice_s11")
      bob = create_registered_nick("bob_s11")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      assert {:error, "Invalid transition from pending to active"} =
               SessionServer.transition(session.token, :active)

      stop_server(session.token)
    end
  end

  describe "timeouts" do
    test "pending expires after timeout" do
      alice = create_registered_nick("alice_s12")
      bob = create_registered_nick("bob_s12")
      session = create_session_record(alice.id, bob.id)
      pid = start_server(session.token)

      # Wait for pending timeout (100ms in test)
      Process.sleep(200)
      refute Process.alive?(pid)

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "expired"
      assert updated.closed_reason == "pending_timeout"
    end

    test "lobby warning broadcast at warning timeout" do
      alice = create_registered_nick("alice_s13")
      bob = create_registered_nick("bob_s13")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{session.token}")

      # Wait for lobby warning (100ms in test)
      Process.sleep(150)

      assert_receive %{
        event: "p2p_inactivity_warning",
        payload: %{expires_in_seconds: 300}
      }

      stop_server(session.token)
    end

    test "lobby expires after expiry timeout" do
      alice = create_registered_nick("alice_s14")
      bob = create_registered_nick("bob_s14")
      session = create_session_record(alice.id, bob.id)
      pid = start_server(session.token)

      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)

      # Wait for lobby expiry (200ms in test)
      Process.sleep(300)
      refute Process.alive?(pid)

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "expired"
      assert updated.closed_reason == "lobby_inactivity"
    end

    test "connecting times out after timeout" do
      alice = create_registered_nick("alice_s15")
      bob = create_registered_nick("bob_s15")
      session = create_session_record(alice.id, bob.id)
      pid = start_server(session.token)

      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)
      :ok = SessionServer.transition(session.token, :connecting)

      # Wait for connecting timeout (100ms in test)
      Process.sleep(200)
      refute Process.alive?(pid)

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "failed"
      assert updated.closed_reason == "connecting_timeout"
    end
  end

  describe "activity/1" do
    test "resets lobby timers on activity" do
      alice = create_registered_nick("alice_s16")
      bob = create_registered_nick("bob_s16")
      session = create_session_record(alice.id, bob.id)
      pid = start_server(session.token)

      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)

      # Wait 100ms then send activity
      Process.sleep(100)
      :ok = SessionServer.activity(session.token)

      # Wait another 150ms — without reset this would have expired at 200ms
      Process.sleep(150)

      assert Process.alive?(pid)

      stop_server(session.token)
    end
  end

  describe "audit columns" do
    test "accepted_at is set when transitioning to lobby" do
      alice = create_registered_nick("alice_aud1")
      bob = create_registered_nick("bob_aud1")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "lobby"
      assert updated.accepted_at != nil

      stop_server(session.token)
    end

    test "connected_at is set when transitioning to active" do
      alice = create_registered_nick("alice_aud2")
      bob = create_registered_nick("bob_aud2")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)
      :ok = SessionServer.transition(session.token, :connecting)
      :ok = SessionServer.transition(session.token, :active)

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "active"
      assert updated.connected_at != nil

      stop_server(session.token)
    end

    test "duration_seconds is set when active session is closed" do
      alice = create_registered_nick("alice_aud3")
      bob = create_registered_nick("bob_aud3")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)
      :ok = SessionServer.transition(session.token, :connecting)
      :ok = SessionServer.transition(session.token, :active)

      :ok = SessionServer.close(session.token, alice.id, "user_closed")
      Process.sleep(50)

      updated = Queries.get_session_by_token(session.token)
      assert updated.duration_seconds != nil
      assert updated.duration_seconds >= 0
    end

    test "duration_seconds is nil when session closes before active" do
      alice = create_registered_nick("alice_aud4")
      bob = create_registered_nick("bob_aud4")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)

      :ok = SessionServer.close(session.token, alice.id, "user_closed")
      Process.sleep(50)

      updated = Queries.get_session_by_token(session.token)
      assert is_nil(updated.duration_seconds)
    end
  end

  describe "crash recovery" do
    test "supervisor restarts GenServer after crash and recovers state from DB" do
      alice = create_registered_nick("alice_cr1")
      bob = create_registered_nick("bob_cr1")
      session = create_session_record(alice.id, bob.id)
      pid = start_server(session.token)

      # Join both peers to move to lobby
      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)

      {:ok, state} = SessionServer.get_state(session.token)
      assert state.session.status == "lobby"

      # Kill the process
      Process.exit(pid, :kill)
      Process.sleep(100)

      # Supervisor should restart it, and it should recover from DB
      {:ok, new_pid} = RetroHexChat.P2P.Registry.lookup(session.token)
      refute new_pid == pid

      {:ok, recovered_state} = SessionServer.get_state(session.token)
      assert recovered_state.session.status == "lobby"

      stop_server(session.token)
    end

    test "init ignores terminal session after crash" do
      alice = create_registered_nick("alice_cr2")
      bob = create_registered_nick("bob_cr2")
      session = create_session_record(alice.id, bob.id)
      pid = start_server(session.token)

      # Close the session (GenServer stops normally)
      :ok = SessionServer.close(session.token, alice.id, "done")
      Process.sleep(50)
      refute Process.alive?(pid)

      # Trying to start again should return :ignore
      assert :ignore = SessionServer.start_link(session.token)
    end
  end
end
