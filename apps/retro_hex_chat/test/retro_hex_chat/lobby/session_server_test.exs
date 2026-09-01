defmodule RetroHexChat.Lobby.SessionServerTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Lobby.{Queries, Registry, SessionServer, Supervisor}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  # Only the rejoin grace is shortened, because only the leave tests wait for a
  # timer to fire. The others used to be shortened too — pending and warning to
  # 100ms, expiry and connecting to 200ms — and no test in this file needed
  # them: nothing here asserts an inactivity timeout, and the one test about
  # those timers asserts that rescheduling changes the handle rather than that
  # anything expires.
  #
  # What they did instead was kill the session under the tests. A setup that
  # joins both peers and then transitions to connected does database work in
  # between, and under a loaded `make ci` partition that gap can outlast 200ms —
  # so `lobby_expiry` or `connecting_timeout` fired mid-setup, the server
  # stopped normally, and the next call found no process. That is the flake.
  setup do
    Application.put_env(:retro_hex_chat, :lobby_rejoin_grace_timeout, 120)

    on_exit(fn -> Application.delete_env(:retro_hex_chat, :lobby_rejoin_grace_timeout) end)
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
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "lobby:#{session.token}")

    start_and_join!(session.token, [creator.id, peer.id])
    :ok = SessionServer.transition(session.token, :connected)

    %{token: session.token, creator: creator, peer: peer}
  end

  # `start_child` hands back a live pid, so a later "no process" means the server
  # died in between — and only a monitor holds the reason why. Without one the
  # failure reads `(EXIT) no process` and says nothing about the cause, which is
  # how this survived several `make ci` runs unexplained.
  defp start_and_join!(token, user_ids) do
    supervisor = Process.whereis(Supervisor)
    {:ok, pid} = Supervisor.start_child(token)
    ref = Process.monitor(pid)

    Enum.each(user_ids, &join!(token, &1, pid, ref, supervisor))

    Process.demonitor(ref, [:flush])
    pid
  end

  # An exit reason of `:shutdown` comes from a supervisor, not from the server's
  # own `{:stop, :normal, …}` paths — so the question it raises is whether the
  # DynamicSupervisor itself went down and took every session with it, which is
  # what `max_restarts` does after three child failures in five seconds. Its
  # identity before and after answers that.
  defp join!(token, user_id, pid, ref, supervisor) do
    case SessionServer.join(token, user_id) do
      :ok -> :ok
      other -> flunk("joining #{inspect(user_id)} answered #{inspect(other)}")
    end
  catch
    :exit, reason ->
      receive do
        {:DOWN, ^ref, :process, ^pid, down} ->
          flunk("""
          the lobby session server died before it could be joined.

          it exited with: #{inspect(down)}
          the join exited with: #{inspect(reason)}
          the supervisor was: #{inspect(supervisor)}
          the supervisor is now: #{inspect(Process.whereis(Supervisor))}
          """)
      after
        0 ->
          flunk("the join exited with #{inspect(reason)} while #{inspect(pid)} is still alive")
      end
  end

  defp stop_server(token) do
    case Registry.lookup(token) do
      {:ok, pid} -> stop_pid(pid)
      {:error, :not_found} -> :ok
    end
  end

  # A test that stops its own server still runs the `on_exit` that stops it
  # again, and the registry entry outlives the process it points at — so by the
  # time this call lands, the pid may already be gone. Looking it up says
  # nothing about it still being alive, which is why the exit is caught rather
  # than guarded against.
  defp stop_pid(pid) do
    GenServer.stop(pid, :normal)
  catch
    :exit, _reason -> :ok
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
      # The bound is set far past the 120ms grace on purpose. What is asserted is
      # that the session closes once the window passes, never how quickly — and
      # the close runs a database write before it broadcasts. Alone, or merely on
      # a busy CPU, it lands in milliseconds; sharing the machine with the other
      # six `make ci` partitions, all queueing on the same Postgres, it has
      # overrun both 500ms and 2s. Timing it tightly measures the box, not the
      # code.
      assert_receive %{event: "lobby_session_closed", payload: %{reason: "peer_left"}}, 10_000
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

    test "a takeover moves the seat, tells the old holder, and re-arms signalling" do
      ctx = setup_connected_lobby("life5")
      parent = self()

      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.creator.id)
      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.peer.id)
      assert_receive %{event: "lobby_start_signaling"}

      # The creator's seat is held by the test process. A second page of the
      # same person asks for it with `takeover: true` and gets it.
      taker =
        spawn(fn ->
          send(parent, {:joined, SessionServer.join(ctx.token, ctx.creator.id, takeover: true)})

          receive do
            :stop -> :ok
          end
        end)

      assert_receive {:joined, :ok}

      # The page that lost it is told, so it can stop pretending to be the
      # connection instead of quietly holding a dead one.
      assert_receive {:lobby_slot_taken, token}
      assert token == ctx.token

      # And the seat was released the way a disconnect releases it: readiness
      # reset, signalling un-started. Without that, the new page would join a
      # session whose negotiation had already run and sit there with no media.
      {:ok, state} = SessionServer.get_state(ctx.token)
      refute state.signaling_started
      refute state.webrtc_ready.creator
      assert state.webrtc_ready.peer

      # The gate fires again as soon as the new page reports ready.
      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.creator.id)
      assert_receive %{event: "lobby_start_signaling", payload: %{restart: true}}

      send(taker, :stop)
      stop_server(ctx.token)
    end

    test "without a takeover the seat is still refused" do
      ctx = setup_connected_lobby("life6")
      parent = self()

      pid =
        spawn(fn ->
          send(parent, {:joined, SessionServer.join(ctx.token, ctx.creator.id)})

          receive do
            :stop -> :ok
          end
        end)

      assert_receive {:joined, {:error, :already_joined}}
      refute_received {:lobby_slot_taken, _token}

      send(pid, :stop)
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
      start_and_join!(session.token, [creator.id, peer.id])

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
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "lobby:#{session.token}")
      start_and_join!(session.token, [creator.id, peer.id])
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

    test "connected session without replay snapshot requests a clean WebRTC restart", ctx do
      :ok = SessionServer.transition(ctx.token, :connected)
      stop_server(ctx.token)
      start_and_join!(ctx.token, [ctx.creator.id, ctx.peer.id])
      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.creator.id)
      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.peer.id)

      assert_receive %{
        event: "lobby_start_signaling",
        payload: %{restart: true, reason: "signaling_snapshot_lost"}
      }

      stop_server(ctx.token)
    end

    # The peer reloads while the first offer is still being applied: the session
    # never left `lobby`, but the page that stayed is negotiating against one
    # that no longer exists. A `restart` is the only thing that makes it offer
    # again — without it the second `start` reads as the first and it returns
    # holding a connection nobody will answer.
    test "a peer that rejoins mid-negotiation gets a clean WebRTC restart", ctx do
      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.creator.id)
      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.peer.id)
      assert_receive %{event: "lobby_start_signaling", payload: %{}}

      :ok =
        SessionServer.record_signaling_event(ctx.token, ctx.creator.id, "lobby_signal", %{
          type: "offer",
          sdp: "offer-sdp",
          epoch: 1,
          offer_id: "p2p-1-1",
          from: ctx.creator.id
        })

      :ok = SessionServer.leave(ctx.token, ctx.peer.id)
      :ok = SessionServer.join(ctx.token, ctx.peer.id, takeover: true)

      # The side that stayed keeps trickling candidates into the snapshot the
      # disconnect wiped. Loose candidates are not a negotiation, and reading
      # them as one is what left the returning page with no offer to answer.
      :ok =
        SessionServer.record_signaling_event(ctx.token, ctx.creator.id, "lobby_signal", %{
          type: "ice-candidate",
          candidate: %{candidate: "candidate:1 1 udp 1 127.0.0.1 1 typ host"},
          epoch: 1,
          from: ctx.creator.id
        })

      :ok = SessionServer.mark_webrtc_ready(ctx.token, ctx.peer.id)

      assert_receive %{
        event: "lobby_start_signaling",
        payload: %{restart: true, reason: "signaling_snapshot_lost"}
      }
    end

    test "rejects readiness from a non-participant", ctx do
      stranger = create_registered_nick("rdys#{System.unique_integer([:positive])}")
      assert {:error, :not_participant} = SessionServer.mark_webrtc_ready(ctx.token, stranger.id)
    end

    test "stores bounded signaling replay for the opposite participant", ctx do
      assert :ok =
               SessionServer.record_signaling_event(ctx.token, ctx.creator.id, "lobby_signal", %{
                 type: "offer",
                 sdp: "offer-sdp",
                 epoch: 3,
                 offer_id: "p2p-3-1",
                 from: ctx.creator.id
               })

      for index <- 1..70 do
        assert :ok =
                 SessionServer.record_signaling_event(
                   ctx.token,
                   ctx.creator.id,
                   "lobby_signal",
                   %{
                     type: "ice-candidate",
                     candidate: %{
                       "candidate" => "candidate:#{index} 1 udp 1 127.0.0.1 #{index} typ host",
                       "sdpMid" => "0"
                     },
                     epoch: 3,
                     from: ctx.creator.id
                   }
                 )
      end

      assert :ok =
               SessionServer.record_signaling_event(
                 ctx.token,
                 ctx.peer.id,
                 "lobby_renegotiate",
                 %{
                   from: ctx.peer.id,
                   kinds: ["video"],
                   recover: true,
                   epoch: 4,
                   reason: "media_recover",
                   attempt: 1,
                   connection_reset: false
                 }
               )

      assert {:ok, peer_events} = SessionServer.signaling_replay(ctx.token, ctx.peer.id)

      assert [%{event: "lobby_signal", payload: %{type: "offer", replay: true}} | rest] =
               peer_events

      assert length(rest) == 64
      assert List.first(rest).payload.candidate["candidate"] =~ "candidate:7 "
      assert List.last(rest).payload.candidate["candidate"] =~ "candidate:70 "

      assert {:ok, creator_events} = SessionServer.signaling_replay(ctx.token, ctx.creator.id)

      assert [
               %{
                 event: "lobby_renegotiate",
                 payload: %{reason: "media_recover", replay: true}
               }
             ] = creator_events
    end

    test "clears signaling replay when a participant disconnects", ctx do
      assert :ok =
               SessionServer.record_signaling_event(ctx.token, ctx.creator.id, "lobby_signal", %{
                 type: "offer",
                 sdp: "offer-sdp",
                 epoch: 1,
                 offer_id: "p2p-1-1",
                 from: ctx.creator.id
               })

      assert {:ok, [_event]} = SessionServer.signaling_replay(ctx.token, ctx.peer.id)

      SessionServer.leave(ctx.token, ctx.creator.id)
      assert_receive %{event: "lobby_peer_disconnected", payload: %{role: :creator}}

      assert {:ok, []} = SessionServer.signaling_replay(ctx.token, ctx.peer.id)
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
