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
    Application.put_env(:retro_hex_chat, :lobby_rejoin_grace_timeout, 120)

    on_exit(fn ->
      for key <- ~w(
            lobby_pending_timeout lobby_warning_timeout lobby_expiry_timeout
            lobby_connecting_timeout lobby_game_request_timeout
            lobby_rejoin_grace_timeout
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

    test "leaving starts the rejoin grace instead of closing immediately" do
      ctx = setup_connected_lobby("life2")
      SessionServer.leave(ctx.token, ctx.creator.id)

      assert_receive %{event: "lobby_peer_disconnected", payload: %{role: :creator}}
      refute_received %{event: "lobby_session_closed"}
      assert Queries.get_session_by_token(ctx.token).status == "connected"

      # No rejoin within the grace window → the session closes for both peers.
      assert_receive %{event: "lobby_session_closed", payload: %{reason: "peer_left"}}, 500
      assert Queries.get_session_by_token(ctx.token).status == "closed"
    end

    test "a rejoin within the grace window keeps the session alive" do
      ctx = setup_connected_lobby("life3")
      SessionServer.leave(ctx.token, ctx.creator.id)
      assert_receive %{event: "lobby_peer_disconnected", payload: %{role: :creator}}

      assert :ok = SessionServer.join(ctx.token, ctx.creator.id)
      assert_receive %{event: "lobby_peer_joined", payload: %{user_id: _}}

      # Wait past the grace window: the session must still be alive.
      refute_receive %{event: "lobby_session_closed"}, 300
      assert Queries.get_session_by_token(ctx.token).status == "connected"

      stop_server(ctx.token)
    end

    test "the joined LiveView process dying starts the same grace window" do
      ctx = setup_connected_lobby("life4")
      parent = self()

      # A separate process takes over the creator's connection (simulating a
      # second LiveView after a reconnect), then dies without leaving.
      pid =
        spawn(fn ->
          send(parent, {:joined, SessionServer.join(ctx.token, ctx.creator.id)})

          receive do
            :stop -> :ok
          end
        end)

      # The creator connection currently belongs to the (alive) test process,
      # so the takeover attempt is rejected: one active tab per session.
      assert_receive {:joined, {:error, :already_joined}}

      # Release the creator slot, let the new process claim it, then kill it.
      SessionServer.leave(ctx.token, ctx.creator.id)
      assert_receive %{event: "lobby_peer_disconnected", payload: %{role: :creator}}

      pid2 =
        spawn(fn ->
          send(parent, {:joined2, SessionServer.join(ctx.token, ctx.creator.id)})

          receive do
            :stop -> :ok
          end
        end)

      assert_receive {:joined2, :ok}
      assert_receive %{event: "lobby_peer_joined"}

      Process.exit(pid2, :kill)
      assert_receive %{event: "lobby_peer_disconnected", payload: %{role: :creator}}, 500
      assert_receive %{event: "lobby_session_closed", payload: %{reason: "peer_left"}}, 500

      send(pid, :stop)
    end

    test "a disconnected peer rejoining re-establishes the signaling gate" do
      ctx = setup_connected_lobby("life5")

      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.creator.id)
      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.peer.id)
      assert_receive %{event: "lobby_start_signaling"}

      SessionServer.leave(ctx.token, ctx.creator.id)
      assert_receive %{event: "lobby_peer_disconnected", payload: %{role: :creator}}

      assert :ok = SessionServer.join(ctx.token, ctx.creator.id)
      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.creator.id)

      # The peer's readiness survived the disconnect; only the returning side
      # re-arms, and the same both-ready gate re-broadcasts signaling.
      assert_receive %{event: "lobby_start_signaling"}

      stop_server(ctx.token)
    end

    test "record_activity reschedules the pre-connection inactivity timers" do
      creator = create_registered_nick("act_c#{System.unique_integer([:positive])}")
      peer = create_registered_nick("act_p#{System.unique_integer([:positive])}")
      session = create_session_record(creator.id, peer.id)
      {:ok, _pid} = Supervisor.start_child(session.token)

      :ok = SessionServer.join(session.token, creator.id)
      :ok = SessionServer.join(session.token, peer.id)

      {:ok, before_state} = SessionServer.get_state(session.token)
      assert before_state.session.status == "lobby"

      :ok = SessionServer.record_activity(session.token)

      {:ok, after_state} = SessionServer.get_state(session.token)
      assert after_state.timers.lobby_expiry != before_state.timers.lobby_expiry

      stop_server(session.token)
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

    test "the host finishing a game relays the score to both peers" do
      ctx = setup_connected_lobby("fin1")

      :ok = SessionServer.propose_game(ctx.token, ctx.creator.id, "creator", "hex_pong")
      assert_receive %{event: "lobby_game_request"}
      :ok = SessionServer.respond_game(ctx.token, ctx.peer.id, "peer", true)
      assert_receive %{event: "lobby_game_status_changed", payload: %{status: "playing"}}

      result = %{"score" => %{"p1" => 11, "p2" => 7}, "winner" => 1}
      assert :ok = SessionServer.finish_game(ctx.token, ctx.creator.id, result)

      assert_receive %{
        event: "lobby_game_status_changed",
        payload: %{status: "finished", game_id: "hex_pong", result: ^result}
      }

      {:ok, finished} = SessionServer.get_state(ctx.token)
      assert finished.game.status == "finished"
      assert finished.game.result == result
      assert finished.session.status == "connected"

      stop_server(ctx.token)
    end

    test "only the game host may finish, and only while a game is in progress" do
      ctx = setup_connected_lobby("fin2")

      result = %{"score" => %{"p1" => 1, "p2" => 0}, "winner" => 1}

      assert {:error, :no_game_in_progress} =
               SessionServer.finish_game(ctx.token, ctx.creator.id, result)

      :ok = SessionServer.propose_game(ctx.token, ctx.creator.id, "creator", "hex_pong")
      assert_receive %{event: "lobby_game_request"}
      :ok = SessionServer.respond_game(ctx.token, ctx.peer.id, "peer", true)
      assert_receive %{event: "lobby_game_status_changed", payload: %{status: "playing"}}

      assert {:error, :not_host} =
               SessionServer.finish_game(ctx.token, ctx.peer.id, result)

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
end
