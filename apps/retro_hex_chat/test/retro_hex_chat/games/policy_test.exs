defmodule RetroHexChat.Games.PolicyTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Games.Policy
  alias RetroHexChat.Games.Schema.GameSession
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  defp create_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{
        nickname: nickname,
        password: "password123"
      })
      |> Repo.insert()

    nick
  end

  defp create_session(creator_id, peer_id, attrs \\ %{}) do
    defaults = %{
      token: "gpol_#{System.unique_integer([:positive])}",
      creator_id: creator_id,
      peer_id: peer_id,
      status: "pending"
    }

    {:ok, session} =
      %GameSession{}
      |> GameSession.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    session
  end

  defp add_ignore(owner_nick, ignored_nick) do
    Repo.insert_all("ignore_list_entries", [
      %{
        owner_nickname: owner_nick,
        ignored_nickname: ignored_nick,
        ignore_type: "all",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])
  end

  describe "can_create?/2" do
    test "allows two registered users" do
      alice = create_nick("gpol_alice1")
      bob = create_nick("gpol_bob1")

      assert :ok = Policy.can_create?(alice.id, bob.id)
    end

    test "rejects self-invite" do
      alice = create_nick("gpol_alice2")

      assert {:error, "Cannot start a game with yourself"} =
               Policy.can_create?(alice.id, alice.id)
    end

    test "rejects unregistered creator" do
      bob = create_nick("gpol_bob3")

      assert {:error, "You must be registered to play games"} =
               Policy.can_create?(999_999, bob.id)
    end

    test "rejects unregistered peer" do
      alice = create_nick("gpol_alice4")

      assert {:error, "Target user must be registered"} =
               Policy.can_create?(alice.id, 999_999)
    end

    test "rejects when active session exists between users" do
      alice = create_nick("gpol_alice5")
      bob = create_nick("gpol_bob5")

      _session = create_session(alice.id, bob.id)

      assert {:error, "An active game session already exists with this user"} =
               Policy.can_create?(alice.id, bob.id)
    end

    test "allows when only terminal sessions exist" do
      alice = create_nick("gpol_alice6")
      bob = create_nick("gpol_bob6")

      _session =
        create_session(alice.id, bob.id, %{
          status: "closed",
          closed_at: DateTime.utc_now(),
          closed_reason: "user_left"
        })

      assert :ok = Policy.can_create?(alice.id, bob.id)
    end

    test "rejects when creator has blocked peer" do
      alice = create_nick("gpol_alice7")
      bob = create_nick("gpol_bob7")

      add_ignore("gpol_alice7", "gpol_bob7")

      assert {:error, "User not available"} =
               Policy.can_create?(alice.id, bob.id)
    end

    test "rejects when peer has blocked creator" do
      alice = create_nick("gpol_alice8")
      bob = create_nick("gpol_bob8")

      add_ignore("gpol_bob8", "gpol_alice8")

      assert {:error, "User not available"} =
               Policy.can_create?(alice.id, bob.id)
    end
  end

  describe "can_join?/2" do
    test "allows participant to join active session" do
      alice = create_nick("gpol_alice9")
      bob = create_nick("gpol_bob9")
      session = create_session(alice.id, bob.id)

      assert :ok = Policy.can_join?(alice.id, session)
      assert :ok = Policy.can_join?(bob.id, session)
    end

    test "rejects non-participant" do
      alice = create_nick("gpol_alice10")
      bob = create_nick("gpol_bob10")
      charlie = create_nick("gpol_charlie10")
      session = create_session(alice.id, bob.id)

      assert {:error, "You are not a participant in this game session"} =
               Policy.can_join?(charlie.id, session)
    end

    test "rejects join on terminal session" do
      alice = create_nick("gpol_alice11")
      bob = create_nick("gpol_bob11")

      session =
        create_session(alice.id, bob.id, %{
          status: "expired",
          closed_at: DateTime.utc_now(),
          closed_reason: "timeout"
        })

      assert {:error, "Game session is no longer active"} =
               Policy.can_join?(alice.id, session)
    end
  end

  describe "can_close?/2" do
    test "allows participant to close active session" do
      alice = create_nick("gpol_alice12")
      bob = create_nick("gpol_bob12")
      session = create_session(alice.id, bob.id)

      assert :ok = Policy.can_close?(alice.id, session)
      assert :ok = Policy.can_close?(bob.id, session)
    end

    test "rejects non-participant" do
      alice = create_nick("gpol_alice13")
      bob = create_nick("gpol_bob13")
      charlie = create_nick("gpol_charlie13")
      session = create_session(alice.id, bob.id)

      assert {:error, "You are not a participant in this game session"} =
               Policy.can_close?(charlie.id, session)
    end

    test "rejects close on terminal session" do
      alice = create_nick("gpol_alice14")
      bob = create_nick("gpol_bob14")

      session =
        create_session(alice.id, bob.id, %{
          status: "closed",
          closed_at: DateTime.utc_now(),
          closed_reason: "user_left"
        })

      assert {:error, "Game session is no longer active"} =
               Policy.can_close?(alice.id, session)
    end
  end
end
