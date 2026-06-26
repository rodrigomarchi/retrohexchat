defmodule RetroHexChat.Lobby.SessionServerTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Lobby.{Queries, Registry, SessionServer, Supervisor}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :lobby_pending_timeout, 100)
    Application.put_env(:retro_hex_chat, :lobby_warning_timeout, 100)
    Application.put_env(:retro_hex_chat, :lobby_expiry_timeout, 200)
    Application.put_env(:retro_hex_chat, :lobby_connecting_timeout, 200)
    Application.put_env(:retro_hex_chat, :lobby_game_request_timeout, 150)

    on_exit(fn ->
      for key <- ~w(
            lobby_pending_timeout lobby_warning_timeout lobby_expiry_timeout
            lobby_connecting_timeout lobby_game_request_timeout
          )a do
        Application.delete_env(:retro_hex_chat, key)
      end
    end)
  end

  defp create_registered_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> Repo.insert()

    nick
  end

  defp create_session_record(creator_id, peer_id) do
    {:ok, session} =
      Queries.insert_session(%{
        token: "lobby-#{System.unique_integer([:positive])}",
        creator_id: creator_id,
        peer_id: peer_id,
        status: "pending"
      })

    session
  end

  defp setup_connected_lobby(suffix) do
    creator = create_registered_nick("creator_#{suffix}")
    peer = create_registered_nick("peer_#{suffix}")
    session = create_session_record(creator.id, peer.id)
    {:ok, _pid} = Supervisor.start_child(session.token)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "lobby:#{session.token}")

    :ok = SessionServer.join(session.token, creator.id)
    :ok = SessionServer.join(session.token, peer.id)
    :ok = SessionServer.transition(session.token, :connected)

    %{token: session.token, creator: creator, peer: peer}
  end

  defp stop_server(token) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.stop(pid, :normal)
      {:error, :not_found} -> :ok
    end
  end

  describe "lifecycle" do
    test "transitions to lobby once both peers join, then to connected" do
      ctx = setup_connected_lobby("life1")
      {:ok, state} = SessionServer.get_state(ctx.token)

      assert state.session.status == "connected"
      assert state.creator_joined and state.peer_joined
      assert_received %{event: "lobby_status_changed", payload: %{status: "lobby"}}
      assert_received %{event: "lobby_status_changed", payload: %{status: "connected"}}

      stop_server(ctx.token)
    end

    test "leaving closes the session" do
      ctx = setup_connected_lobby("life2")
      SessionServer.leave(ctx.token, ctx.creator.id)

      assert_receive %{event: "lobby_session_closed", payload: %{reason: "peer_left"}}
      assert Queries.get_session_by_token(ctx.token).status == "closed"
    end
  end

  describe "webrtc readiness coordination" do
    setup do
      creator = create_registered_nick("rdyc#{System.unique_integer([:positive])}")
      peer = create_registered_nick("rdyp#{System.unique_integer([:positive])}")
      session = create_session_record(creator.id, peer.id)
      {:ok, _pid} = Supervisor.start_child(session.token)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "lobby:#{session.token}")

      :ok = SessionServer.join(session.token, creator.id)
      :ok = SessionServer.join(session.token, peer.id)
      assert_received %{event: "lobby_status_changed", payload: %{status: "lobby"}}

      on_exit(fn -> stop_server(session.token) end)
      %{token: session.token, creator: creator, peer: peer}
    end

    test "signaling starts only after BOTH peers report ready", ctx do
      # Only one peer ready → signaling must NOT start yet (prevents the offer being
      # broadcast before the answerer's hook is listening).
      assert :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.creator.id)
      refute_received %{event: "lobby_start_signaling"}

      {:ok, state} = SessionServer.get_state(ctx.token)
      assert state.webrtc_ready == %{creator: true, peer: false}
      refute state.signaling_started

      # Second peer ready → signaling fires exactly once.
      assert :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.peer.id)
      assert_received %{event: "lobby_start_signaling"}

      {:ok, state} = SessionServer.get_state(ctx.token)
      assert state.signaling_started
    end

    test "readiness is idempotent and signaling broadcasts only once", ctx do
      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.creator.id)
      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.peer.id)
      assert_received %{event: "lobby_start_signaling"}

      # Repeated readiness reports must not re-trigger signaling.
      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.creator.id)
      refute_received %{event: "lobby_start_signaling"}
    end

    test "rejects readiness from a non-participant", ctx do
      stranger = create_registered_nick("rdys#{System.unique_integer([:positive])}")
      assert {:error, :not_participant} = SessionServer.mark_webrtc_ready(ctx.token, stranger.id)
    end
  end

  describe "concurrent features stay alive" do
    test "media toggle broadcasts presence without closing the session" do
      ctx = setup_connected_lobby("feat1")

      assert :ok = SessionServer.set_media(ctx.token, ctx.creator.id, true, true)

      assert_receive %{
        event: "lobby_media_changed",
        payload: %{role: :creator, audio: true, video: true}
      }

      {:ok, state} = SessionServer.get_state(ctx.token)
      assert state.media.creator == %{audio: true, video: true}
      assert state.session.status == "connected"

      stop_server(ctx.token)
    end

    test "a full game cycle leaves the connection open for more features" do
      ctx = setup_connected_lobby("feat2")

      assert :ok = SessionServer.propose_game(ctx.token, ctx.creator.id, "creator", "hex_pong")
      assert_receive %{event: "lobby_game_request", payload: %{game_id: "hex_pong"}}

      assert :ok = SessionServer.respond_game(ctx.token, ctx.peer.id, "peer", true)

      assert_receive %{
        event: "lobby_game_status_changed",
        payload: %{status: "playing", game_id: "hex_pong"}
      }

      {:ok, playing} = SessionServer.get_state(ctx.token)
      assert playing.game.status == "playing"
      assert playing.game.host_id == ctx.creator.id

      # Ending the game returns to idle but the session stays connected.
      assert :ok = SessionServer.end_game(ctx.token, ctx.creator.id)
      assert_receive %{event: "lobby_game_status_changed", payload: %{status: "idle"}}

      {:ok, idle} = SessionServer.get_state(ctx.token)
      assert idle.game.status == "idle"
      assert idle.session.status == "connected"

      # Still able to start another feature afterwards.
      assert :ok = SessionServer.set_media(ctx.token, ctx.peer.id, true, false)

      stop_server(ctx.token)
    end

    test "cannot respond to your own game proposal" do
      ctx = setup_connected_lobby("feat3")

      :ok = SessionServer.propose_game(ctx.token, ctx.creator.id, "creator", "hex_pong")

      assert {:error, :cannot_respond_own} =
               SessionServer.respond_game(ctx.token, ctx.creator.id, "creator", true)

      stop_server(ctx.token)
    end

    test "a second proposal is rejected while one is pending" do
      ctx = setup_connected_lobby("feat4")

      :ok = SessionServer.propose_game(ctx.token, ctx.creator.id, "creator", "hex_pong")

      assert {:error, :request_pending} =
               SessionServer.propose_game(ctx.token, ctx.peer.id, "peer", "light_trails")

      stop_server(ctx.token)
    end
  end

  describe "chat" do
    test "messages are broadcast and retained while connected" do
      ctx = setup_connected_lobby("chat1")

      assert :ok = SessionServer.send_message(ctx.token, ctx.creator.id, "creator", "hello")

      assert_receive %{
        event: "lobby_message",
        payload: %{content: "hello", sender_nick: "creator"}
      }

      {:ok, state} = SessionServer.get_state(ctx.token)
      assert length(state.messages) == 1

      stop_server(ctx.token)
    end
  end
end
