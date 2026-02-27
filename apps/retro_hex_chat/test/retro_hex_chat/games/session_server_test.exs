defmodule RetroHexChat.Games.SessionServerTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Games.{Queries, SessionServer, Supervisor}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  # Use very short timeouts for testing
  setup do
    Application.put_env(:retro_hex_chat, :game_pending_timeout, 100)
    Application.put_env(:retro_hex_chat, :game_lobby_warning_timeout, 100)
    Application.put_env(:retro_hex_chat, :game_lobby_expiry_timeout, 200)
    Application.put_env(:retro_hex_chat, :game_select_timeout, 100)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :game_pending_timeout)
      Application.delete_env(:retro_hex_chat, :game_lobby_warning_timeout)
      Application.delete_env(:retro_hex_chat, :game_lobby_expiry_timeout)
      Application.delete_env(:retro_hex_chat, :game_select_timeout)
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
    token = Keyword.get(opts, :token, "gss-#{System.unique_integer([:positive])}")

    {:ok, session} =
      Queries.insert_session(%{
        token: token,
        creator_id: creator_id,
        peer_id: peer_id,
        status: "pending"
      })

    session
  end

  defp start_server(token) do
    {:ok, pid} = Supervisor.start_child(token)
    pid
  end

  defp stop_server(token) do
    case RetroHexChat.Games.Registry.lookup(token) do
      {:ok, pid} ->
        GenServer.stop(pid, :normal)
        Process.sleep(10)

      _ ->
        :ok
    end
  end

  describe "init/1" do
    test "starts with pending status" do
      alice = create_registered_nick("gss_alice1")
      bob = create_registered_nick("gss_bob1")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      assert {:ok, state} = SessionServer.get_state(session.token)
      assert state.session.status == "pending"
      assert state.creator_joined == false
      assert state.peer_joined == false

      stop_server(session.token)
    end
  end

  describe "join/2" do
    test "tracks creator and peer join" do
      alice = create_registered_nick("gss_alice2")
      bob = create_registered_nick("gss_bob2")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      assert :ok = SessionServer.join(session.token, alice.id)
      {:ok, state} = SessionServer.get_state(session.token)
      assert state.creator_joined == true
      assert state.peer_joined == false

      assert :ok = SessionServer.join(session.token, bob.id)
      {:ok, state} = SessionServer.get_state(session.token)
      assert state.peer_joined == true

      stop_server(session.token)
    end

    test "transitions to lobby when both join" do
      alice = create_registered_nick("gss_alice3")
      bob = create_registered_nick("gss_bob3")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "game:#{session.token}")

      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)

      assert_receive %{event: "game_status_changed", payload: %{status: "lobby"}}

      {:ok, state} = SessionServer.get_state(session.token)
      assert state.session.status == "lobby"

      stop_server(session.token)
    end

    test "rejects non-participant" do
      alice = create_registered_nick("gss_alice4")
      bob = create_registered_nick("gss_bob4")
      eve = create_registered_nick("gss_eve4")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      assert {:error, "Not a participant"} = SessionServer.join(session.token, eve.id)

      stop_server(session.token)
    end
  end

  describe "pending_timeout" do
    test "expires session after timeout" do
      alice = create_registered_nick("gss_alice5")
      bob = create_registered_nick("gss_bob5")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "game:#{session.token}")

      # Wait for the short timeout
      Process.sleep(150)

      assert_receive %{event: "game_status_changed", payload: %{status: "expired"}}

      # Server should have stopped
      assert {:error, :not_found} = RetroHexChat.Games.Registry.lookup(session.token)
    end
  end

  describe "select_game/4" do
    test "broadcasts game selection request" do
      alice = create_registered_nick("gss_alice6")
      bob = create_registered_nick("gss_bob6")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "game:#{session.token}")

      assert :ok = SessionServer.select_game(session.token, alice.id, "gss_alice6", "hex_pong")

      assert_receive %{
        event: "game_select_request",
        payload: %{requester_nick: "gss_alice6", game_id: "hex_pong"}
      }

      stop_server(session.token)
    end

    test "rejects when not in lobby" do
      alice = create_registered_nick("gss_alice7")
      bob = create_registered_nick("gss_bob7")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      assert {:error, :not_in_lobby} =
               SessionServer.select_game(session.token, alice.id, "gss_alice7", "hex_pong")

      stop_server(session.token)
    end

    test "rejects when request already pending" do
      alice = create_registered_nick("gss_alice8")
      bob = create_registered_nick("gss_bob8")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)

      assert :ok = SessionServer.select_game(session.token, alice.id, "gss_alice8", "hex_pong")

      assert {:error, :request_pending} =
               SessionServer.select_game(
                 session.token,
                 bob.id,
                 "gss_bob8",
                 "light_trails"
               )

      stop_server(session.token)
    end
  end

  describe "respond_game/4" do
    test "accepting transitions to playing" do
      alice = create_registered_nick("gss_alice9")
      bob = create_registered_nick("gss_bob9")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "game:#{session.token}")

      SessionServer.select_game(session.token, alice.id, "gss_alice9", "hex_pong")
      assert :ok = SessionServer.respond_game(session.token, bob.id, "gss_bob9", true)

      assert_receive %{
        event: "game_select_response",
        payload: %{accepted: true, game_id: "hex_pong"}
      }

      assert_receive %{event: "game_status_changed", payload: %{status: "playing"}}

      {:ok, state} = SessionServer.get_state(session.token)
      assert state.session.status == "playing"
      assert state.session.game_id == "hex_pong"

      stop_server(session.token)
    end

    test "rejecting clears the request" do
      alice = create_registered_nick("gss_alice10")
      bob = create_registered_nick("gss_bob10")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "game:#{session.token}")

      SessionServer.select_game(session.token, alice.id, "gss_alice10", "hex_pong")
      assert :ok = SessionServer.respond_game(session.token, bob.id, "gss_bob10", false)

      assert_receive %{event: "game_select_response", payload: %{accepted: false}}

      {:ok, state} = SessionServer.get_state(session.token)
      assert state.session.status == "lobby"
      assert state.game_request == nil

      stop_server(session.token)
    end

    test "requester cannot respond to own request" do
      alice = create_registered_nick("gss_alice11")
      bob = create_registered_nick("gss_bob11")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)

      SessionServer.select_game(session.token, alice.id, "gss_alice11", "hex_pong")

      assert {:error, :cannot_respond_own} =
               SessionServer.respond_game(session.token, alice.id, "gss_alice11", true)

      stop_server(session.token)
    end
  end

  describe "send_message/4" do
    test "stores and broadcasts messages in lobby" do
      alice = create_registered_nick("gss_alice12")
      bob = create_registered_nick("gss_bob12")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "game:#{session.token}")

      assert :ok =
               SessionServer.send_message(session.token, alice.id, "gss_alice12", "gg?")

      assert_receive %{
        event: "game_lobby_message",
        payload: %{sender_nick: "gss_alice12", content: "gg?"}
      }

      {:ok, state} = SessionServer.get_state(session.token)
      assert length(state.messages) == 1

      stop_server(session.token)
    end

    test "rejects messages when not in lobby or playing" do
      alice = create_registered_nick("gss_alice13")
      bob = create_registered_nick("gss_bob13")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      assert {:error, :not_in_lobby} =
               SessionServer.send_message(session.token, alice.id, "gss_alice13", "hi")

      stop_server(session.token)
    end
  end

  describe "audit columns" do
    test "lobby_at is set when transitioning to lobby" do
      alice = create_registered_nick("gss_aud1")
      bob = create_registered_nick("gss_aud2")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "lobby"
      assert updated.lobby_at != nil

      stop_server(session.token)
    end

    test "game_started_at is set when transitioning to playing" do
      alice = create_registered_nick("gss_aud3")
      bob = create_registered_nick("gss_aud4")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)
      SessionServer.select_game(session.token, alice.id, "gss_aud3", "hex_pong")
      SessionServer.respond_game(session.token, bob.id, "gss_aud4", true)

      updated = Queries.get_session_by_token(session.token)
      assert updated.status == "playing"
      assert updated.game_started_at != nil

      stop_server(session.token)
    end

    test "duration_seconds is set when game finishes after playing" do
      alice = create_registered_nick("gss_aud5")
      bob = create_registered_nick("gss_aud6")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)
      SessionServer.select_game(session.token, alice.id, "gss_aud5", "hex_pong")
      SessionServer.respond_game(session.token, bob.id, "gss_aud6", true)

      :ok = SessionServer.finish_game(session.token, alice.id, %{"winner" => "gss_aud5"})
      Process.sleep(50)

      updated = Queries.get_session_by_token(session.token)
      assert updated.duration_seconds != nil
      assert updated.duration_seconds >= 0
    end

    test "duration_seconds is nil when session closes before playing" do
      alice = create_registered_nick("gss_aud7")
      bob = create_registered_nick("gss_aud8")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      SessionServer.join(session.token, alice.id)
      SessionServer.join(session.token, bob.id)

      :ok = SessionServer.close(session.token, alice.id, "user_left")
      Process.sleep(50)

      updated = Queries.get_session_by_token(session.token)
      assert is_nil(updated.duration_seconds)
    end
  end

  describe "close/3" do
    test "closes the session" do
      alice = create_registered_nick("gss_alice14")
      bob = create_registered_nick("gss_bob14")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "game:#{session.token}")

      assert :ok = SessionServer.close(session.token, alice.id, "user_left")

      assert_receive %{event: "game_session_closed", payload: %{reason: "user_left"}}

      # Server should have stopped
      Process.sleep(50)
      assert {:error, :not_found} = RetroHexChat.Games.Registry.lookup(session.token)
    end
  end
end
