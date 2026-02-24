defmodule RetroHexChat.Games.ServiceTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Games.{Registry, Service}
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

  describe "create_session/2" do
    test "successfully creates a session" do
      alice = create_registered_nick("gsvc_alice1")
      bob = create_registered_nick("gsvc_bob1")

      assert {:ok, %{session: session, token: token}} =
               Service.create_session(alice.id, bob.id)

      assert session.status == "pending"
      assert session.creator_id == alice.id
      assert session.peer_id == bob.id
      assert is_binary(token)
    end

    test "starts a GenServer for the session" do
      alice = create_registered_nick("gsvc_alice2")
      bob = create_registered_nick("gsvc_bob2")

      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      assert {:ok, _pid} = Registry.lookup(session.token)
    end

    test "sends PubSub notification to peer" do
      alice = create_registered_nick("gsvc_alice3")
      bob = create_registered_nick("gsvc_bob3")

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:gsvc_bob3")

      {:ok, _result} = Service.create_session(alice.id, bob.id)

      assert_receive %{
        event: "game_invite",
        payload: %{from: "gsvc_alice3"}
      }
    end

    test "rejects self-sessions" do
      alice = create_registered_nick("gsvc_alice4")

      assert {:error, "Cannot start a game with yourself"} =
               Service.create_session(alice.id, alice.id)
    end

    test "rejects duplicate active sessions" do
      alice = create_registered_nick("gsvc_alice5")
      bob = create_registered_nick("gsvc_bob5")

      {:ok, _} = Service.create_session(alice.id, bob.id)

      assert {:error, "An active game session already exists with this user"} =
               Service.create_session(alice.id, bob.id)
    end
  end

  describe "join_session/2" do
    test "allows participant to join" do
      alice = create_registered_nick("gsvc_alice6")
      bob = create_registered_nick("gsvc_bob6")

      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      assert :ok = Service.join_session(session.token, alice.id)
      assert :ok = Service.join_session(session.token, bob.id)
    end

    test "rejects non-existent token" do
      alice = create_registered_nick("gsvc_alice7")

      assert {:error, "Session not found"} =
               Service.join_session("nonexistent_token", alice.id)
    end
  end

  describe "close_session/3" do
    test "closes the session" do
      alice = create_registered_nick("gsvc_alice8")
      bob = create_registered_nick("gsvc_bob8")

      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)

      assert :ok = Service.close_session(session.token, alice.id, "user_left")
    end
  end

  describe "select_game/3" do
    test "selects a valid game" do
      alice = create_registered_nick("gsvc_alice9")
      bob = create_registered_nick("gsvc_bob9")

      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)
      Service.join_session(session.token, alice.id)
      Service.join_session(session.token, bob.id)

      assert :ok = Service.select_game(session.token, alice.id, "hex_pong")
    end

    test "rejects invalid game id" do
      alice = create_registered_nick("gsvc_alice10")
      bob = create_registered_nick("gsvc_bob10")

      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)
      Service.join_session(session.token, alice.id)
      Service.join_session(session.token, bob.id)

      assert {:error, :invalid_game_id} =
               Service.select_game(session.token, alice.id, "nonexistent_game")
    end
  end

  describe "send_lobby_message/3" do
    test "sends a message in lobby" do
      alice = create_registered_nick("gsvc_alice11")
      bob = create_registered_nick("gsvc_bob11")

      {:ok, %{session: session}} = Service.create_session(alice.id, bob.id)
      Service.join_session(session.token, alice.id)
      Service.join_session(session.token, bob.id)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "game:#{session.token}")

      assert :ok = Service.send_lobby_message(session.token, alice.id, "ready?")

      assert_receive %{event: "game_lobby_message", payload: %{content: "ready?"}}
    end
  end
end
