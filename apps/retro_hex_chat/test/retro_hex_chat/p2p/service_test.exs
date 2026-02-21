defmodule RetroHexChat.P2P.ServiceTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.P2P.{Queries, Registry, Service, SessionServer}
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

  describe "create_session/3" do
    test "successfully creates a session" do
      alice = create_registered_nick("alice_svc1")
      bob = create_registered_nick("bob_svc1")

      assert {:ok, %{session: session, token: token}} =
               Service.create_session(alice.id, bob.id)

      assert session.status == "pending"
      assert session.creator_id == alice.id
      assert session.peer_id == bob.id
      assert is_binary(token)
    end

    test "starts a GenServer for the session" do
      alice = create_registered_nick("alice_svc2")
      bob = create_registered_nick("bob_svc2")

      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      assert {:ok, _pid} = Registry.lookup(session.token)
    end

    test "sends PubSub notification to peer" do
      alice = create_registered_nick("alice_svc3")
      bob = create_registered_nick("bob_svc3")

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:bob_svc3")

      {:ok, _result} = Service.create_session(alice.id, bob.id)

      assert_receive %{
        event: "p2p_invite",
        payload: %{
          from: "alice_svc3",
          session_type: "generic"
        }
      }
    end

    test "rejects duplicate session" do
      alice = create_registered_nick("alice_svc4")
      bob = create_registered_nick("bob_svc4")

      {:ok, _result} = Service.create_session(alice.id, bob.id)

      assert {:error, "An active session already exists with this user"} =
               Service.create_session(alice.id, bob.id)
    end

    test "rejects self-session" do
      alice = create_registered_nick("alice_svc5")

      assert {:error, "Cannot create a session with yourself"} =
               Service.create_session(alice.id, alice.id)
    end

    test "rejects unregistered user" do
      alice = create_registered_nick("alice_svc6")

      assert {:error, _msg} = Service.create_session(alice.id, 999_999)
    end

    test "supports session_type option" do
      alice = create_registered_nick("alice_svc7")
      bob = create_registered_nick("bob_svc7")

      assert {:ok, %{session: session}} =
               Service.create_session(alice.id, bob.id, session_type: "file_transfer")

      assert session.session_type == "file_transfer"
    end
  end

  describe "join_session/2" do
    test "allows participant to join" do
      alice = create_registered_nick("alice_jsvc1")
      bob = create_registered_nick("bob_jsvc1")
      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      assert :ok = Service.join_session(session.token, alice.id)
    end

    test "rejects non-participant" do
      alice = create_registered_nick("alice_jsvc2")
      bob = create_registered_nick("bob_jsvc2")
      charlie = create_registered_nick("char_jsvc2")
      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      assert {:error, "You are not a participant in this session"} =
               Service.join_session(session.token, charlie.id)
    end

    test "rejects join on terminal session" do
      alice = create_registered_nick("alice_jsvc3")
      bob = create_registered_nick("bob_jsvc3")
      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      # Close the session
      :ok = Service.close_session(session.token, alice.id, "done")

      assert {:error, "Session is no longer active"} =
               Service.join_session(session.token, bob.id)
    end

    test "transitions to lobby when both join" do
      alice = create_registered_nick("alice_jsvc4")
      bob = create_registered_nick("bob_jsvc4")
      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      :ok = Service.join_session(session.token, alice.id)
      :ok = Service.join_session(session.token, bob.id)

      {:ok, state} = SessionServer.get_state(session.token)
      assert state.session.status == "lobby"
    end
  end

  describe "close_session/3" do
    test "closes an active session" do
      alice = create_registered_nick("alice_csvc1")
      bob = create_registered_nick("bob_csvc1")
      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{session.token}")

      assert :ok = Service.close_session(session.token, alice.id, "leaving")

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "closed"
      assert updated.closed_reason == "leaving"

      assert_receive %{event: "p2p_session_closed", payload: %{reason: "leaving"}}
    end

    test "closes session even when GenServer not running" do
      alice = create_registered_nick("alice_csvc2")
      bob = create_registered_nick("bob_csvc2")
      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      # Stop the GenServer directly
      {:ok, pid} = Registry.lookup(session.token)
      GenServer.stop(pid, :normal)
      Process.sleep(50)

      assert :ok = Service.close_session(session.token, alice.id, "cleanup")

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "closed"
    end

    test "rejects close from non-participant" do
      alice = create_registered_nick("alice_csvc3")
      bob = create_registered_nick("bob_csvc3")
      charlie = create_registered_nick("char_csvc3")
      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      assert {:error, "You are not a participant in this session"} =
               Service.close_session(session.token, charlie.id, "leaving")
    end
  end

  describe "authorization integration" do
    test "join rejects guest user (no registered_nick)" do
      alice = create_registered_nick("alice_auth1")
      bob = create_registered_nick("bob_auth1")
      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      # User 999999 has no registered_nick record
      assert {:error, "You are not a participant in this session"} =
               Service.join_session(session.token, 999_999)
    end

    test "create rejects blocked user with generic message" do
      alice = create_registered_nick("alice_auth2")
      bob = create_registered_nick("bob_auth2")

      Repo.insert_all("ignore_list_entries", [
        %{
          owner_nickname: "alice_auth2",
          ignored_nickname: "bob_auth2",
          ignore_type: "ignore",
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      ])

      assert {:error, "User not available"} =
               Service.create_session(alice.id, bob.id)
    end

    test "session not found returns error" do
      assert {:error, "Session not found"} =
               Service.join_session("nonexistent-token", 1)
    end
  end

  describe "close_sessions_between/2" do
    test "closes non-terminal sessions between two users" do
      alice = create_registered_nick("alice_csb1")
      bob = create_registered_nick("bob_csb1")

      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      assert :ok = Service.close_sessions_between(alice.id, bob.id)

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "closed"
      assert updated.closed_reason == "user_blocked"
    end

    test "does not affect already-closed sessions" do
      alice = create_registered_nick("alice_csb2")
      bob = create_registered_nick("bob_csb2")

      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)
      :ok = Service.close_session(session.token, alice.id, "user_closed")

      # Should not crash
      assert :ok = Service.close_sessions_between(alice.id, bob.id)
    end

    test "returns ok when no sessions exist" do
      alice = create_registered_nick("alice_csb3")
      bob = create_registered_nick("bob_csb3")

      assert :ok = Service.close_sessions_between(alice.id, bob.id)
    end
  end

  describe "bidirectional duplicate detection" do
    test "B cannot create session with A when A→B session exists" do
      alice = create_registered_nick("alice_bidir1")
      bob = create_registered_nick("bob_bidir1")

      {:ok, _result} = Service.create_session(alice.id, bob.id)

      assert {:error, "An active session already exists with this user"} =
               Service.create_session(bob.id, alice.id)
    end

    test "B can create session with A after A→B session closes" do
      alice = create_registered_nick("alice_bidir2")
      bob = create_registered_nick("bob_bidir2")

      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)
      :ok = Service.close_session(session.token, alice.id, "done")

      assert {:ok, %{session: new_session}} = Service.create_session(bob.id, alice.id)
      assert new_session.creator_id == bob.id
      assert new_session.peer_id == alice.id
    end
  end
end
