defmodule RetroHexChat.P2P.SessionServerLobbyTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.P2P.{Queries, SessionServer, Supervisor}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :p2p_pending_timeout, 100)
    Application.put_env(:retro_hex_chat, :p2p_lobby_warning_timeout, 5_000)
    Application.put_env(:retro_hex_chat, :p2p_lobby_expiry_timeout, 10_000)
    Application.put_env(:retro_hex_chat, :p2p_connecting_timeout, 5_000)
    Application.put_env(:retro_hex_chat, :p2p_action_request_timeout, 100)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :p2p_pending_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_lobby_warning_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_lobby_expiry_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_connecting_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_action_request_timeout)
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

  defp create_session_record(creator_id, peer_id) do
    token = "lobby-#{System.unique_integer([:positive])}"

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

  defp setup_lobby_session(_context) do
    alice = create_registered_nick("alice_lb#{System.unique_integer([:positive])}")
    bob = create_registered_nick("bob_lb#{System.unique_integer([:positive])}")
    session = create_session_record(alice.id, bob.id)
    _pid = start_server(session.token)

    :ok = SessionServer.join(session.token, alice.id)
    :ok = SessionServer.join(session.token, bob.id)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{session.token}")

    # Drain the status_changed from join
    receive do
      %{event: "p2p_status_changed"} -> :ok
    after
      100 -> :ok
    end

    on_exit(fn -> stop_server(session.token) end)

    %{alice: alice, bob: bob, session: session, token: session.token}
  end

  describe "join/2 broadcasts peer_joined" do
    test "broadcasts p2p_peer_joined for each participant that joins", %{} do
      alice = create_registered_nick("alice_pj#{System.unique_integer([:positive])}")
      bob = create_registered_nick("bob_pj#{System.unique_integer([:positive])}")
      session = create_session_record(alice.id, bob.id)
      _pid = start_server(session.token)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{session.token}")

      alice_id = alice.id
      :ok = SessionServer.join(session.token, alice.id)

      assert_receive %{
        event: "p2p_peer_joined",
        payload: %{user_id: ^alice_id}
      }

      bob_id = bob.id
      :ok = SessionServer.join(session.token, bob.id)

      assert_receive %{
        event: "p2p_peer_joined",
        payload: %{user_id: ^bob_id}
      }

      stop_server(session.token)
    end
  end

  describe "send_message/4" do
    setup :setup_lobby_session

    test "sends a message and broadcasts it", %{alice: alice, token: token} do
      assert :ok = SessionServer.send_message(token, alice.id, alice.nickname, "Hello!")

      assert_receive %{
        event: "p2p_lobby_message",
        payload: %{sender_nick: sender, content: "Hello!"}
      }

      assert sender == alice.nickname
    end

    test "messages are stored in state", %{alice: alice, token: token} do
      :ok = SessionServer.send_message(token, alice.id, alice.nickname, "msg1")
      :ok = SessionServer.send_message(token, alice.id, alice.nickname, "msg2")

      {:ok, state} = SessionServer.get_state(token)
      assert length(state.messages) == 2
      assert Enum.at(state.messages, 0).content == "msg1"
      assert Enum.at(state.messages, 1).content == "msg2"
    end

    test "caps messages at 100", %{alice: alice, token: token} do
      for i <- 1..105 do
        :ok = SessionServer.send_message(token, alice.id, alice.nickname, "msg#{i}")
      end

      {:ok, state} = SessionServer.get_state(token)
      assert length(state.messages) == 100
      # Oldest messages were dropped
      assert Enum.at(state.messages, 0).content == "msg6"
    end

    test "rejects empty content", %{alice: alice, token: token} do
      assert {:error, :content_empty} =
               SessionServer.send_message(token, alice.id, alice.nickname, "")
    end

    test "rejects content exceeding max length", %{alice: alice, token: token} do
      long = String.duplicate("x", 501)

      assert {:error, :content_too_long} =
               SessionServer.send_message(token, alice.id, alice.nickname, long)
    end

    test "allows messages during connecting status", %{alice: alice, token: token} do
      :ok = SessionServer.transition(token, :connecting)

      assert :ok = SessionServer.send_message(token, alice.id, alice.nickname, "hi")
    end

    test "allows messages during active status", %{alice: alice, token: token} do
      :ok = SessionServer.transition(token, :connecting)
      :ok = SessionServer.transition(token, :active)

      assert :ok = SessionServer.send_message(token, alice.id, alice.nickname, "hi")
    end

    test "resets activity timer on message", %{alice: alice, token: token} do
      # Get initial timer refs
      {:ok, state_before} = SessionServer.get_state(token)
      lobby_expiry_before = state_before.timers[:lobby_expiry]

      Process.sleep(50)
      :ok = SessionServer.send_message(token, alice.id, alice.nickname, "activity")

      {:ok, state_after} = SessionServer.get_state(token)
      lobby_expiry_after = state_after.timers[:lobby_expiry]

      # Timer reference should have changed
      refute lobby_expiry_before == lobby_expiry_after
    end
  end

  describe "request_action/4" do
    setup :setup_lobby_session

    test "creates an action request and broadcasts", %{alice: alice, token: token} do
      assert :ok =
               SessionServer.request_action(token, alice.id, alice.nickname, "audio_call")

      assert_receive %{
        event: "p2p_action_request",
        payload: %{
          requester_nick: requester,
          action_type: "audio_call"
        }
      }

      assert requester == alice.nickname
    end

    test "stores action request in state", %{alice: alice, token: token} do
      :ok = SessionServer.request_action(token, alice.id, alice.nickname, "audio_call")

      {:ok, state} = SessionServer.get_state(token)
      assert state.action_request != nil
      assert state.action_request.requester_id == alice.id
      assert state.action_request.action_type == "audio_call"
      assert state.action_request.status == "pending"
    end

    test "rejects when request already pending", %{alice: alice, bob: bob, token: token} do
      :ok = SessionServer.request_action(token, alice.id, alice.nickname, "audio_call")

      assert {:error, :request_pending} =
               SessionServer.request_action(token, bob.id, bob.nickname, "video_call")
    end

    test "rejects when not in lobby", %{alice: alice, token: token} do
      :ok = SessionServer.transition(token, :connecting)

      assert {:error, :not_in_lobby} =
               SessionServer.request_action(token, alice.id, alice.nickname, "audio_call")
    end
  end

  describe "respond_action/4" do
    setup :setup_lobby_session

    test "accepts action and transitions to connecting", %{
      alice: alice,
      bob: bob,
      token: token
    } do
      :ok = SessionServer.request_action(token, alice.id, alice.nickname, "audio_call")
      # Drain request broadcast
      assert_receive %{event: "p2p_action_request"}

      assert :ok = SessionServer.respond_action(token, bob.id, bob.nickname, true)

      assert_receive %{
        event: "p2p_action_response",
        payload: %{accepted: true, responder_nick: responder}
      }

      assert responder == bob.nickname

      {:ok, state} = SessionServer.get_state(token)
      assert state.session.status == "connecting"
      assert state.action_request.status == "accepted"
    end

    test "rejects action and clears request", %{alice: alice, bob: bob, token: token} do
      :ok = SessionServer.request_action(token, alice.id, alice.nickname, "audio_call")
      assert_receive %{event: "p2p_action_request"}

      assert :ok = SessionServer.respond_action(token, bob.id, bob.nickname, false)

      assert_receive %{
        event: "p2p_action_response",
        payload: %{accepted: false}
      }

      {:ok, state} = SessionServer.get_state(token)
      assert state.action_request == nil
    end

    test "cannot respond to own request", %{alice: alice, token: token} do
      :ok = SessionServer.request_action(token, alice.id, alice.nickname, "audio_call")

      assert {:error, :cannot_respond_own} =
               SessionServer.respond_action(token, alice.id, alice.nickname, true)
    end

    test "errors when no pending request", %{bob: bob, token: token} do
      assert {:error, :no_pending_request} =
               SessionServer.respond_action(token, bob.id, bob.nickname, true)
    end

    test "rejects respond_action when session is already connecting", %{
      alice: alice,
      bob: bob,
      token: token
    } do
      :ok = SessionServer.request_action(token, alice.id, alice.nickname, "file_transfer")
      assert_receive %{event: "p2p_action_request"}

      # First accept — transitions lobby → connecting
      :ok = SessionServer.respond_action(token, bob.id, bob.nickname, true)
      assert_receive %{event: "p2p_action_response", payload: %{accepted: true}}
      assert_receive %{event: "p2p_status_changed", payload: %{status: "connecting"}}

      {:ok, state} = SessionServer.get_state(token)
      assert state.session.status == "connecting"

      # Second accept — must be rejected, not cause another transition
      assert {:error, :not_in_lobby} =
               SessionServer.respond_action(token, bob.id, bob.nickname, true)
    end

    test "rejects respond_action when session is already active", %{
      alice: alice,
      bob: bob,
      token: token
    } do
      :ok = SessionServer.request_action(token, alice.id, alice.nickname, "file_transfer")
      assert_receive %{event: "p2p_action_request"}

      :ok = SessionServer.respond_action(token, bob.id, bob.nickname, true)
      assert_receive %{event: "p2p_status_changed", payload: %{status: "connecting"}}

      # Transition to active (simulating WebRTC connected)
      :ok = SessionServer.transition(token, :active)

      {:ok, state} = SessionServer.get_state(token)
      assert state.session.status == "active"

      # Duplicate accept — must be rejected
      assert {:error, :not_in_lobby} =
               SessionServer.respond_action(token, bob.id, bob.nickname, true)
    end
  end

  describe "action request timeout" do
    setup :setup_lobby_session

    test "expires after timeout and broadcasts", %{alice: alice, token: token} do
      :ok = SessionServer.request_action(token, alice.id, alice.nickname, "audio_call")
      assert_receive %{event: "p2p_action_request"}

      # Wait for timeout (100ms in test)
      Process.sleep(200)

      assert_receive %{event: "p2p_action_expired"}

      {:ok, state} = SessionServer.get_state(token)
      assert state.action_request == nil
    end

    test "timer is cancelled when action is responded to", %{
      alice: alice,
      bob: bob,
      token: token
    } do
      :ok = SessionServer.request_action(token, alice.id, alice.nickname, "audio_call")
      assert_receive %{event: "p2p_action_request"}

      :ok = SessionServer.respond_action(token, bob.id, bob.nickname, false)
      assert_receive %{event: "p2p_action_response"}

      # Wait past timeout
      Process.sleep(200)

      refute_receive %{event: "p2p_action_expired"}
    end
  end
end
