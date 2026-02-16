defmodule RetroHexChat.P2P.QueriesTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.P2P.Queries
  alias RetroHexChat.P2P.Schema.Session
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

  defp valid_session_attrs(
         creator_id,
         peer_id,
         token \\ "tok-#{System.unique_integer([:positive])}"
       ) do
    %{
      token: token,
      creator_id: creator_id,
      peer_id: peer_id,
      status: "pending",
      session_type: "generic"
    }
  end

  describe "insert_session/1" do
    test "inserts a valid session" do
      alice = create_registered_nick("alice_q")
      bob = create_registered_nick("bob_q")

      assert {:ok, %Session{} = session} =
               Queries.insert_session(valid_session_attrs(alice.id, bob.id))

      assert session.status == "pending"
      assert session.session_type == "generic"
      assert session.creator_id == alice.id
      assert session.peer_id == bob.id
    end

    test "rejects invalid session (missing token)" do
      assert {:error, changeset} =
               Queries.insert_session(%{
                 creator_id: 1,
                 peer_id: 2,
                 status: "pending",
                 session_type: "generic"
               })

      refute changeset.valid?
    end
  end

  describe "get_session_by_token/1" do
    test "returns session when found" do
      alice = create_registered_nick("alice_gbt")
      bob = create_registered_nick("bob_gbt")
      {:ok, session} = Queries.insert_session(valid_session_attrs(alice.id, bob.id, "find-me"))

      found = Queries.get_session_by_token("find-me")
      assert found.id == session.id
    end

    test "returns nil when not found" do
      assert Queries.get_session_by_token("nonexistent") == nil
    end
  end

  describe "get_session/1" do
    test "returns session by id" do
      alice = create_registered_nick("alice_gs")
      bob = create_registered_nick("bob_gs")
      {:ok, session} = Queries.insert_session(valid_session_attrs(alice.id, bob.id))

      found = Queries.get_session(session.id)
      assert found.id == session.id
    end
  end

  describe "update_status/3" do
    test "updates to non-terminal status" do
      alice = create_registered_nick("alice_us")
      bob = create_registered_nick("bob_us")
      {:ok, session} = Queries.insert_session(valid_session_attrs(alice.id, bob.id))

      assert {:ok, updated} = Queries.update_status(session, "lobby")
      assert updated.status == "lobby"
    end

    test "updates to terminal status with closed_at and closed_reason" do
      alice = create_registered_nick("alice_ust")
      bob = create_registered_nick("bob_ust")
      {:ok, session} = Queries.insert_session(valid_session_attrs(alice.id, bob.id))

      now = DateTime.utc_now()

      assert {:ok, updated} =
               Queries.update_status(session, "closed", %{
                 closed_at: now,
                 closed_reason: "user_closed"
               })

      assert updated.status == "closed"
      assert updated.closed_reason == "user_closed"
      assert updated.closed_at != nil
    end

    test "rejects terminal status without closed_at/closed_reason" do
      alice = create_registered_nick("alice_usr")
      bob = create_registered_nick("bob_usr")
      {:ok, session} = Queries.insert_session(valid_session_attrs(alice.id, bob.id))

      assert {:error, changeset} = Queries.update_status(session, "closed")
      refute changeset.valid?
    end
  end

  describe "active_session_exists?/2" do
    test "detects active session A→B" do
      alice = create_registered_nick("alice_ase1")
      bob = create_registered_nick("bob_ase1")
      {:ok, _session} = Queries.insert_session(valid_session_attrs(alice.id, bob.id))

      assert Queries.active_session_exists?(alice.id, bob.id)
    end

    test "detects active session bidirectionally B→A" do
      alice = create_registered_nick("alice_ase2")
      bob = create_registered_nick("bob_ase2")
      {:ok, _session} = Queries.insert_session(valid_session_attrs(alice.id, bob.id))

      # Check reverse direction
      assert Queries.active_session_exists?(bob.id, alice.id)
    end

    test "ignores terminal sessions" do
      alice = create_registered_nick("alice_ase3")
      bob = create_registered_nick("bob_ase3")
      {:ok, session} = Queries.insert_session(valid_session_attrs(alice.id, bob.id))

      Queries.update_status(session, "closed", %{
        closed_at: DateTime.utc_now(),
        closed_reason: "done"
      })

      refute Queries.active_session_exists?(alice.id, bob.id)
    end

    test "returns false when no session exists" do
      refute Queries.active_session_exists?(99_999, 99_998)
    end
  end

  describe "list_stale_sessions/1" do
    test "returns non-terminal sessions older than threshold" do
      alice = create_registered_nick("alice_lss")
      bob = create_registered_nick("bob_lss")
      {:ok, _session} = Queries.insert_session(valid_session_attrs(alice.id, bob.id))

      # Query with a future time to capture all sessions
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      stale = Queries.list_stale_sessions(future)
      assert stale != []
    end

    test "excludes terminal sessions" do
      alice = create_registered_nick("alice_lss2")
      bob = create_registered_nick("bob_lss2")
      {:ok, session} = Queries.insert_session(valid_session_attrs(alice.id, bob.id))

      Queries.update_status(session, "expired", %{
        closed_at: DateTime.utc_now(),
        closed_reason: "timeout"
      })

      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      stale = Queries.list_stale_sessions(future)
      refute Enum.any?(stale, &(&1.id == session.id))
    end
  end

  describe "expire_session/1" do
    test "sets status to expired with cleanup reason" do
      alice = create_registered_nick("alice_es")
      bob = create_registered_nick("bob_es")
      {:ok, session} = Queries.insert_session(valid_session_attrs(alice.id, bob.id))

      assert {:ok, expired} = Queries.expire_session(session)
      assert expired.status == "expired"
      assert expired.closed_reason == "stale_cleanup"
      assert expired.closed_at != nil
    end
  end
end
