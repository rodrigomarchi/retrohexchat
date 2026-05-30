defmodule RetroHexChat.P2P.PolicyTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.P2P.Policy
  alias RetroHexChat.P2P.Queries
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

  defp create_ignore_entry(owner_nick, ignored_nick, ignore_type \\ "all") do
    Repo.insert_all("ignore_list_entries", [
      %{
        owner_nickname: owner_nick,
        ignored_nickname: ignored_nick,
        ignore_type: ignore_type,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])
  end

  defp create_session(creator_id, peer_id) do
    token = "tok-#{System.unique_integer([:positive])}"

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

  describe "can_create?/2" do
    test "allows creation between two registered users" do
      alice = create_registered_nick("alice_pol1")
      bob = create_registered_nick("bob_pol1")

      assert :ok = Policy.can_create?(alice.id, bob.id)
    end

    test "rejects self-session" do
      alice = create_registered_nick("alice_pol2")

      assert {:error, "Cannot create a session with yourself"} =
               Policy.can_create?(alice.id, alice.id)
    end

    test "rejects unregistered creator" do
      bob = create_registered_nick("bob_pol3")

      assert {:error, "You must be registered to use P2P"} =
               Policy.can_create?(999_999, bob.id)
    end

    test "rejects unregistered peer" do
      alice = create_registered_nick("alice_pol4")

      assert {:error, "Target user must be registered"} =
               Policy.can_create?(alice.id, 999_999)
    end

    test "rejects when active session exists between pair" do
      alice = create_registered_nick("alice_pol5")
      bob = create_registered_nick("bob_pol5")
      _session = create_session(alice.id, bob.id)

      assert {:error, "An active session already exists with this user"} =
               Policy.can_create?(alice.id, bob.id)
    end

    test "rejects when active session exists in reverse direction" do
      alice = create_registered_nick("alice_pol6")
      bob = create_registered_nick("bob_pol6")
      _session = create_session(bob.id, alice.id)

      assert {:error, "An active session already exists with this user"} =
               Policy.can_create?(alice.id, bob.id)
    end

    test "allows creation after previous session is closed" do
      alice = create_registered_nick("alice_pol7")
      bob = create_registered_nick("bob_pol7")
      session = create_session(alice.id, bob.id)

      Queries.update_status(session, "closed", %{
        closed_at: DateTime.utc_now(),
        closed_reason: "done"
      })

      assert :ok = Policy.can_create?(alice.id, bob.id)
    end

    test "rejects when creator has ignored peer for all events" do
      alice = create_registered_nick("alice_pol8")
      bob = create_registered_nick("bob_pol8")
      create_ignore_entry("alice_pol8", "bob_pol8")

      assert {:error, "User not available"} =
               Policy.can_create?(alice.id, bob.id)
    end

    test "rejects when peer has ignored creator invites" do
      alice = create_registered_nick("alice_pol9")
      bob = create_registered_nick("bob_pol9")
      create_ignore_entry("bob_pol9", "alice_pol9", "invites")

      assert {:error, "User not available"} =
               Policy.can_create?(alice.id, bob.id)
    end

    test "allows when peer has ignored creator channel messages only" do
      alice = create_registered_nick("alice_pol10")
      bob = create_registered_nick("bob_pol10")
      create_ignore_entry("bob_pol10", "alice_pol10", "messages")

      assert :ok = Policy.can_create?(alice.id, bob.id)
    end
  end

  describe "can_join?/2" do
    test "allows creator to join" do
      alice = create_registered_nick("alice_cj1")
      bob = create_registered_nick("bob_cj1")
      session = create_session(alice.id, bob.id)

      assert :ok = Policy.can_join?(alice.id, session)
    end

    test "allows peer to join" do
      alice = create_registered_nick("alice_cj2")
      bob = create_registered_nick("bob_cj2")
      session = create_session(alice.id, bob.id)

      assert :ok = Policy.can_join?(bob.id, session)
    end

    test "rejects non-participant" do
      alice = create_registered_nick("alice_cj3")
      bob = create_registered_nick("bob_cj3")
      charlie = create_registered_nick("char_cj3")
      session = create_session(alice.id, bob.id)

      assert {:error, "You are not a participant in this session"} =
               Policy.can_join?(charlie.id, session)
    end

    test "rejects join on terminal session" do
      alice = create_registered_nick("alice_cj4")
      bob = create_registered_nick("bob_cj4")
      session = create_session(alice.id, bob.id)

      {:ok, closed} =
        Queries.update_status(session, "closed", %{
          closed_at: DateTime.utc_now(),
          closed_reason: "done"
        })

      assert {:error, "Session is no longer active"} =
               Policy.can_join?(alice.id, closed)
    end
  end

  describe "can_close?/2" do
    test "allows participant to close" do
      alice = create_registered_nick("alice_cc1")
      bob = create_registered_nick("bob_cc1")
      session = create_session(alice.id, bob.id)

      assert :ok = Policy.can_close?(alice.id, session)
      assert :ok = Policy.can_close?(bob.id, session)
    end

    test "rejects non-participant" do
      alice = create_registered_nick("alice_cc2")
      bob = create_registered_nick("bob_cc2")
      charlie = create_registered_nick("char_cc2")
      session = create_session(alice.id, bob.id)

      assert {:error, "You are not a participant in this session"} =
               Policy.can_close?(charlie.id, session)
    end

    test "rejects close on terminal session" do
      alice = create_registered_nick("alice_cc3")
      bob = create_registered_nick("bob_cc3")
      session = create_session(alice.id, bob.id)

      {:ok, expired} =
        Queries.update_status(session, "expired", %{
          closed_at: DateTime.utc_now(),
          closed_reason: "timeout"
        })

      assert {:error, "Session is no longer active"} =
               Policy.can_close?(alice.id, expired)
    end
  end
end
