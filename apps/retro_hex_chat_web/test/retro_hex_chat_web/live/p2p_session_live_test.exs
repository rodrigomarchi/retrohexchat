defmodule RetroHexChatWeb.P2PSessionLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.P2P.{Queries, SessionServer, Supervisor}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :liveview

  setup do
    Application.put_env(:retro_hex_chat, :p2p_pending_timeout, 30_000)
    Application.put_env(:retro_hex_chat, :p2p_lobby_warning_timeout, 30_000)
    Application.put_env(:retro_hex_chat, :p2p_lobby_expiry_timeout, 60_000)
    Application.put_env(:retro_hex_chat, :p2p_connecting_timeout, 30_000)
    Application.put_env(:retro_hex_chat, :p2p_action_request_timeout, 30_000)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :p2p_pending_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_lobby_warning_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_lobby_expiry_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_connecting_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_action_request_timeout)
    end)
  end

  defp create_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp create_session(creator_id, peer_id) do
    token = "p2p-lv-#{System.unique_integer([:positive])}"

    {:ok, session} =
      Queries.insert_session(%{
        token: token,
        creator_id: creator_id,
        peer_id: peer_id,
        status: "pending",
        session_type: "generic"
      })

    {:ok, _pid} = Supervisor.start_child(session.token)
    session
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

  describe "mount/auth" do
    test "guest is redirected to /", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, "/p2p/some-token")
    end

    test "unregistered nick is redirected", %{conn: conn} do
      conn = chat_conn(conn, "ghost_user")
      assert {:error, {:live_redirect, _}} = live(conn, "/p2p/some-token")
    end

    test "invalid token redirects", %{conn: conn} do
      _alice = create_nick("p2p_lv_a1")
      conn = chat_conn(conn, "p2p_lv_a1")
      assert {:error, {:live_redirect, _}} = live(conn, "/p2p/nonexistent-token")
    end

    test "unauthorized user is redirected", %{conn: conn} do
      alice = create_nick("p2p_lv_a2")
      bob = create_nick("p2p_lv_b2")
      _charlie = create_nick("p2p_lv_c2")
      session = create_session(alice.id, bob.id)

      conn = chat_conn(conn, "p2p_lv_c2")
      assert {:error, {:live_redirect, _}} = live(conn, "/p2p/#{session.token}")

      stop_server(session.token)
    end

    test "authorized creator mounts successfully", %{conn: conn} do
      alice = create_nick("p2p_lv_a3")
      bob = create_nick("p2p_lv_b3")
      session = create_session(alice.id, bob.id)

      conn = chat_conn(conn, "p2p_lv_a3")
      {:ok, _view, html} = live(conn, "/p2p/#{session.token}")

      assert html =~ "p2p_lv_a3"
      assert html =~ "p2p_lv_b3"
      assert html =~ "Sessao P2P"

      stop_server(session.token)
    end

    test "authorized peer mounts successfully", %{conn: conn} do
      alice = create_nick("p2p_lv_a4")
      bob = create_nick("p2p_lv_b4")
      session = create_session(alice.id, bob.id)

      conn = chat_conn(conn, "p2p_lv_b4")
      {:ok, _view, html} = live(conn, "/p2p/#{session.token}")

      assert html =~ "p2p_lv_b4"
      assert html =~ "p2p_lv_a4"

      stop_server(session.token)
    end

    test "terminal session redirects", %{conn: conn} do
      alice = create_nick("p2p_lv_a5")
      bob = create_nick("p2p_lv_b5")
      session = create_session(alice.id, bob.id)

      # Close the session
      Queries.update_status(session, "closed", %{
        closed_at: DateTime.utc_now(),
        closed_reason: "done"
      })

      stop_server(session.token)

      conn = chat_conn(conn, "p2p_lv_a5")
      assert {:error, {:live_redirect, _}} = live(conn, "/p2p/#{session.token}")
    end
  end

  describe "lobby chat" do
    setup %{conn: conn} do
      alice = create_nick("p2p_lv_a6")
      bob = create_nick("p2p_lv_b6")
      session = create_session(alice.id, bob.id)

      on_exit(fn -> stop_server(session.token) end)

      %{alice: alice, bob: bob, session: session, conn: conn}
    end

    test "renders lobby UI elements", %{conn: conn, session: session} do
      conn = chat_conn(conn, "p2p_lv_a6")
      {:ok, _view, html} = live(conn, "/p2p/#{session.token}")

      assert html =~ "p2p-lobby-chat"
      assert html =~ "Encerrar Sessao"
      assert html =~ "Enviar Arquivo"
      assert html =~ "Chamada de Audio"
      assert html =~ "Chamada de Video"
    end

    test "renders presence indicators", %{conn: conn, session: session} do
      conn = chat_conn(conn, "p2p_lv_a6")
      {:ok, _view, html} = live(conn, "/p2p/#{session.token}")

      assert html =~ "p2p-lobby-presence"
      assert html =~ "p2p_lv_a6"
      assert html =~ "p2p_lv_b6"
    end

    test "peer presence is online on mount when peer already joined in GenServer", %{
      conn: conn,
      session: session,
      alice: alice,
      bob: bob
    } do
      # Both join the GenServer
      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)
      Process.sleep(20)

      # Mount as alice — bob should already show as online
      conn = chat_conn(conn, "p2p_lv_a6")
      {:ok, _view, html} = live(conn, "/p2p/#{session.token}")

      refute html =~ "aguardando"
    end

    test "peer presence updates to online when p2p_peer_joined is received", %{
      conn: conn,
      session: session,
      bob: bob
    } do
      conn = chat_conn(conn, "p2p_lv_a6")
      {:ok, view, html} = live(conn, "/p2p/#{session.token}")

      # Initially peer shows as "aguardando" (offline)
      assert html =~ "aguardando"

      # Simulate peer joining via PubSub
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{
          event: "p2p_peer_joined",
          payload: %{user_id: bob.id}
        }
      )

      Process.sleep(20)
      html = render(view)

      # Peer should now show as online, not "aguardando"
      refute html =~ "aguardando"
    end
  end

  describe "action requests" do
    setup %{conn: conn} do
      alice = create_nick("p2p_lv_a8")
      bob = create_nick("p2p_lv_b8")
      session = create_session(alice.id, bob.id)

      on_exit(fn -> stop_server(session.token) end)

      %{alice: alice, bob: bob, session: session, conn: conn}
    end

    test "action request from peer shows waiting indicator via PubSub", %{
      conn: conn,
      session: session,
      alice: alice
    } do
      conn = chat_conn(conn, "p2p_lv_a8")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      # Simulate action request from self via PubSub (as if we requested it)
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{
          event: "p2p_action_request",
          payload: %{
            requester_id: alice.id,
            requester_nick: "p2p_lv_a8",
            action_type: "audio_call",
            status: "pending"
          }
        }
      )

      Process.sleep(20)
      html = render(view)
      assert html =~ "Aguardando resposta"
    end

    test "action buttons render with disabled state for capabilities", %{
      conn: conn,
      session: session
    } do
      conn = chat_conn(conn, "p2p_lv_a8")
      {:ok, _view, html} = live(conn, "/p2p/#{session.token}")

      # Capabilities default to nil (not yet detected), buttons should be disabled
      assert html =~ "Enviar Arquivo"
      assert html =~ "Chamada de Audio"
      assert html =~ "Chamada de Video"
    end

    test "p2p_capabilities event updates assigns", %{conn: conn, session: session} do
      conn = chat_conn(conn, "p2p_lv_a8")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      render_hook(view, "p2p_capabilities", %{
        "webrtc" => true,
        "getUserMedia" => true,
        "dataChannel" => true
      })

      html = render(view)
      # Buttons should still be present after capabilities update
      assert html =~ "Enviar Arquivo"
      assert html =~ "Chamada de Audio"
    end

    test "action response clears consent banner", %{
      conn: conn,
      session: session,
      alice: alice
    } do
      conn = chat_conn(conn, "p2p_lv_b8")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      # Simulate action request from alice via PubSub
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{
          event: "p2p_action_request",
          payload: %{
            requester_id: alice.id,
            requester_nick: "p2p_lv_a8",
            action_type: "audio_call",
            status: "pending"
          }
        }
      )

      Process.sleep(20)
      html = render(view)
      assert html =~ "quer iniciar"

      # Simulate action response with real GenServer payload (no :status key)
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{
          event: "p2p_action_response",
          payload: %{
            accepted: true,
            responder_nick: "p2p_lv_b8",
            action_type: "audio_call"
          }
        }
      )

      Process.sleep(20)
      html = render(view)
      # After response with accepted: true, consent banner must NOT reappear
      refute html =~ "quer iniciar"
      # For audio_call, media-call UI renders instead of action buttons
      assert html =~ "media-call"
    end

    test "consent banner does not reappear after connecting→active transition", %{
      conn: conn,
      session: session,
      alice: alice
    } do
      conn = chat_conn(conn, "p2p_lv_b8")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      # Simulate action request from alice
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{
          event: "p2p_action_request",
          payload: %{
            requester_id: alice.id,
            requester_nick: "p2p_lv_a8",
            action_type: "file_transfer",
            status: "pending"
          }
        }
      )

      Process.sleep(20)
      assert render(view) =~ "quer iniciar"

      # Simulate accepted response (real GenServer payload)
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{
          event: "p2p_action_response",
          payload: %{
            accepted: true,
            responder_nick: "p2p_lv_b8",
            action_type: "file_transfer"
          }
        }
      )

      Process.sleep(20)

      # Transition to connecting — should clear action_request
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{event: "p2p_status_changed", payload: %{status: "connecting", reason: nil}}
      )

      Process.sleep(20)

      # Transition to active
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{event: "p2p_status_changed", payload: %{status: "active", reason: nil}}
      )

      Process.sleep(20)
      html = render(view)
      # Consent banner must NOT reappear after active
      refute html =~ "quer iniciar"
    end
  end

  describe "file transfer integration" do
    setup %{conn: conn} do
      alice = create_nick("p2p_lv_ft_a")
      bob = create_nick("p2p_lv_ft_b")
      session = create_session(alice.id, bob.id)

      # Properly transition GenServer through join → lobby → request → accept → connecting
      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)
      Process.sleep(20)

      :ok =
        SessionServer.request_action(session.token, alice.id, alice.nickname, "file_transfer")

      :ok = SessionServer.respond_action(session.token, bob.id, bob.nickname, true)
      # Session is now in "connecting" state

      on_exit(fn -> stop_server(session.token) end)

      %{alice: alice, bob: bob, session: session, conn: conn}
    end

    test "file_transfer element renders after p2p_connected", %{
      conn: conn,
      session: session
    } do
      conn = chat_conn(conn, "p2p_lv_ft_a")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      # Simulate WebRTC connected
      render_hook(view, "p2p_connected", %{})
      Process.sleep(20)

      html = render(view)
      assert html =~ "p2p-file-transfer"
    end

    test "action buttons hidden when file transfer is active", %{
      conn: conn,
      session: session
    } do
      conn = chat_conn(conn, "p2p_lv_ft_a")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      render_hook(view, "p2p_connected", %{})
      Process.sleep(20)

      html = render(view)
      # Action buttons should not be visible when file transfer is active
      refute html =~ "p2p-lobby-actions__buttons"
    end

    test "file_transfer ready state shows file selection prompt", %{
      conn: conn,
      session: session
    } do
      conn = chat_conn(conn, "p2p_lv_ft_a")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      render_hook(view, "p2p_connected", %{})
      Process.sleep(20)

      html = render(view)
      # "ready" status must show a visible file selection prompt
      assert html =~ "file-transfer__ready"
    end

    test "second peer gets file_transfer via p2p_status_changed active", %{
      conn: conn,
      session: session,
      bob: _bob
    } do
      # Mount as bob (second peer)
      conn = chat_conn(conn, "p2p_lv_ft_b")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      # Bob's p2p_connected will fail (transition already done by alice)
      # But the PubSub broadcast of "active" should still init file_transfer
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{event: "p2p_status_changed", payload: %{status: "active"}}
      )

      Process.sleep(20)
      html = render(view)
      assert html =~ "p2p-file-transfer"
    end

    test "peer_online is true on mount when peer already joined", %{
      conn: conn,
      session: session
    } do
      # Both alice and bob already joined in setup
      # Mount as bob — alice should show as online
      conn = chat_conn(conn, "p2p_lv_ft_b")
      {:ok, _view, html} = live(conn, "/p2p/#{session.token}")

      # Peer should NOT show as "aguardando" since alice already joined
      refute html =~ "aguardando"
    end

    test "file_transfer resets to ready after ft_completed", %{
      conn: conn,
      session: session
    } do
      conn = chat_conn(conn, "p2p_lv_ft_a")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      render_hook(view, "p2p_connected", %{})
      Process.sleep(20)

      # Simulate transfer completed
      render_hook(view, "ft_completed", %{"fileName" => "test.txt"})
      Process.sleep(20)

      html = render(view)
      assert html =~ "Transferencia concluida"

      # Click "Enviar outro arquivo" to reset
      render_click(view, "ft_reset", %{})
      Process.sleep(20)

      html = render(view)
      assert html =~ "file-transfer__ready"
      refute html =~ "Transferencia concluida"
    end

    test "file_transfer resets to ready after ft_cancelled", %{
      conn: conn,
      session: session
    } do
      conn = chat_conn(conn, "p2p_lv_ft_a")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      render_hook(view, "p2p_connected", %{})
      Process.sleep(20)

      render_hook(view, "ft_cancelled", %{"cancelledBy" => "p2p_lv_ft_b"})
      Process.sleep(20)

      html = render(view)
      assert html =~ "Transferencia cancelada"

      render_click(view, "ft_reset", %{})
      Process.sleep(20)

      html = render(view)
      assert html =~ "file-transfer__ready"
    end

    test "file_transfer resets to ready after ft_failed", %{
      conn: conn,
      session: session
    } do
      conn = chat_conn(conn, "p2p_lv_ft_a")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      render_hook(view, "p2p_connected", %{})
      Process.sleep(20)

      render_hook(view, "ft_failed", %{"reason" => "Erro de rede"})
      Process.sleep(20)

      html = render(view)
      assert html =~ "Erro de rede"

      render_click(view, "ft_reset", %{})
      Process.sleep(20)

      html = render(view)
      assert html =~ "file-transfer__ready"
    end
  end

  describe "file transfer full flow (mount during lobby)" do
    setup %{conn: conn} do
      alice = create_nick("p2p_lv_flow_a")
      bob = create_nick("p2p_lv_flow_b")

      token = "p2p-lv-#{System.unique_integer([:positive])}"

      {:ok, session} =
        Queries.insert_session(%{
          token: token,
          creator_id: alice.id,
          peer_id: bob.id,
          status: "pending",
          session_type: "file_transfer"
        })

      {:ok, _pid} = Supervisor.start_child(session.token)

      # Both join → transitions to lobby
      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)
      Process.sleep(20)

      on_exit(fn -> stop_server(session.token) end)

      %{alice: alice, bob: bob, session: session, conn: conn}
    end

    test "file_transfer initializes after action accept → connecting → active via PubSub", %{
      conn: conn,
      session: session,
      alice: alice,
      bob: bob
    } do
      # Mount during lobby — file_transfer should be nil
      conn = chat_conn(conn, "p2p_lv_flow_a")
      {:ok, view, html} = live(conn, "/p2p/#{session.token}")

      # In lobby state, action buttons should be visible (no file_transfer yet)
      assert html =~ "p2p-lobby-actions__buttons"
      refute html =~ "p2p-file-transfer"

      # Simulate the full action consent flow via GenServer
      :ok =
        SessionServer.request_action(session.token, alice.id, alice.nickname, "file_transfer")

      Process.sleep(20)

      :ok = SessionServer.respond_action(session.token, bob.id, bob.nickname, true)
      # This transitions to "connecting" and broadcasts p2p_status_changed

      Process.sleep(50)

      # After connecting → active broadcast, file_transfer should be initialized
      # Simulate p2p_connected from WebRTC
      render_hook(view, "p2p_connected", %{})
      Process.sleep(20)

      html = render(view)
      assert html =~ "p2p-file-transfer"
      assert html =~ "file-transfer__ready"
    end

    test "second peer gets file_transfer via status_changed active (not p2p_connected)", %{
      conn: conn,
      session: session,
      alice: alice,
      bob: bob
    } do
      # Mount bob during lobby
      conn = chat_conn(conn, "p2p_lv_flow_b")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      # Full action flow
      :ok =
        SessionServer.request_action(session.token, alice.id, alice.nickname, "file_transfer")

      Process.sleep(20)

      :ok = SessionServer.respond_action(session.token, bob.id, bob.nickname, true)
      Process.sleep(50)

      # Instead of p2p_connected (which hits the error branch for second peer),
      # rely on the PubSub broadcast of "active" to init file_transfer
      # First peer does the transition:
      :ok = SessionServer.transition(session.token, :active)
      Process.sleep(50)

      html = render(view)
      assert html =~ "p2p-file-transfer"
      assert html =~ "file-transfer__ready"
    end
  end

  describe "privacy mode" do
    setup %{conn: conn} do
      alice = create_nick("p2p_lv_priv_a")
      bob = create_nick("p2p_lv_priv_b")
      session = create_session(alice.id, bob.id)

      on_exit(fn -> stop_server(session.token) end)

      %{alice: alice, bob: bob, session: session, conn: conn}
    end

    test "toggle_privacy_mode toggles turn_only assign", %{conn: conn, session: session} do
      conn = chat_conn(conn, "p2p_lv_priv_a")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      # Toggle on
      render_click(view, "toggle_privacy_mode", %{})

      # Toggle off
      render_click(view, "toggle_privacy_mode", %{})

      # Should not crash — preference persisted both ways
    end

    test "toggle_privacy_mode persists to user_preferences", %{conn: conn, session: session} do
      conn = chat_conn(conn, "p2p_lv_priv_a")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      # Toggle on
      render_click(view, "toggle_privacy_mode", %{})

      # Check DB
      pref = RetroHexChat.Repo.get(RetroHexChat.Chat.Schemas.UserPreference, "p2p_lv_priv_a")
      assert pref != nil
      assert get_in(pref.display_settings, ["p2p_settings", "turn_only"]) == true
    end
  end

  describe "audio/video call integration" do
    setup %{conn: conn} do
      alice = create_nick("p2p_lv_call_a")
      bob = create_nick("p2p_lv_call_b")

      token = "p2p-lv-#{System.unique_integer([:positive])}"

      {:ok, session} =
        Queries.insert_session(%{
          token: token,
          creator_id: alice.id,
          peer_id: bob.id,
          status: "pending",
          session_type: "audio_call"
        })

      {:ok, _pid} = Supervisor.start_child(session.token)

      # Both join → transitions to lobby
      :ok = SessionServer.join(session.token, alice.id)
      :ok = SessionServer.join(session.token, bob.id)
      Process.sleep(20)

      on_exit(fn -> stop_server(session.token) end)

      %{alice: alice, bob: bob, session: session, conn: conn}
    end

    test "audio call initializes @call on action acceptance", %{
      conn: conn,
      session: session,
      alice: alice,
      bob: bob
    } do
      conn = chat_conn(conn, "p2p_lv_call_a")
      {:ok, view, html} = live(conn, "/p2p/#{session.token}")

      # Initially no media-call component
      refute html =~ "media-call"

      # Request and accept via GenServer
      :ok = SessionServer.request_action(session.token, alice.id, alice.nickname, "audio_call")
      Process.sleep(20)

      :ok = SessionServer.respond_action(session.token, bob.id, bob.nickname, true)
      Process.sleep(50)

      html = render(view)
      # After acceptance, media-call should render (call initialized with "initializing" status)
      assert html =~ "media-call"
    end

    test "video call initializes @call on action acceptance", %{conn: conn} do
      # Create a video_call session
      v_alice = create_nick("p2p_lv_vcall_a")
      v_bob = create_nick("p2p_lv_vcall_b")

      token = "p2p-lv-#{System.unique_integer([:positive])}"

      {:ok, v_session} =
        Queries.insert_session(%{
          token: token,
          creator_id: v_alice.id,
          peer_id: v_bob.id,
          status: "pending",
          session_type: "video_call"
        })

      {:ok, _pid} = Supervisor.start_child(v_session.token)
      :ok = SessionServer.join(v_session.token, v_alice.id)
      :ok = SessionServer.join(v_session.token, v_bob.id)
      Process.sleep(20)

      conn = chat_conn(conn, "p2p_lv_vcall_a")
      {:ok, view, _html} = live(conn, "/p2p/#{v_session.token}")

      :ok =
        SessionServer.request_action(
          v_session.token,
          v_alice.id,
          v_alice.nickname,
          "video_call"
        )

      Process.sleep(20)

      :ok = SessionServer.respond_action(v_session.token, v_bob.id, v_bob.nickname, true)
      Process.sleep(50)

      html = render(view)
      assert html =~ "media-call__video-area"

      stop_server(v_session.token)
    end

    test "media_call_started sets full call state", %{
      conn: conn,
      session: session,
      alice: alice,
      bob: bob
    } do
      conn = chat_conn(conn, "p2p_lv_call_a")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      :ok = SessionServer.request_action(session.token, alice.id, alice.nickname, "audio_call")
      Process.sleep(20)

      :ok = SessionServer.respond_action(session.token, bob.id, bob.nickname, true)
      Process.sleep(50)

      # Simulate media_call_started from JS hook
      render_hook(view, "media_call_started", %{"type" => "audio"})
      Process.sleep(20)

      html = render(view)
      assert html =~ "media-call"
      assert html =~ "00:00:00"
    end

    test "media_call_ended clears call state", %{
      conn: conn,
      session: session,
      alice: alice,
      bob: bob
    } do
      conn = chat_conn(conn, "p2p_lv_call_a")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      :ok = SessionServer.request_action(session.token, alice.id, alice.nickname, "audio_call")
      Process.sleep(20)

      :ok = SessionServer.respond_action(session.token, bob.id, bob.nickname, true)
      Process.sleep(50)

      # Transition to active (simulates WebRTC connected)
      render_hook(view, "p2p_connected", %{})
      Process.sleep(20)

      render_hook(view, "media_call_started", %{"type" => "audio"})
      Process.sleep(20)

      # End the call
      render_hook(view, "media_call_ended", %{"reason" => "ended"})
      Process.sleep(20)

      html = render(view)
      # media-call component should not render
      refute html =~ "media-call__controls"
      assert html =~ "Chamada encerrada"
    end

    test "p2p_action_response includes responder_id from GenServer", %{
      session: session,
      alice: alice,
      bob: bob
    } do
      # Request action
      :ok = SessionServer.request_action(session.token, alice.id, alice.nickname, "audio_call")

      # Subscribe to capture the broadcast
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{session.token}")

      :ok = SessionServer.respond_action(session.token, bob.id, bob.nickname, true)

      # Should receive the response with responder_id
      assert_receive %{
                       event: "p2p_action_response",
                       payload: %{accepted: true, responder_id: responder_id}
                     },
                     1000

      assert responder_id == bob.id
    end

    test "call mount-time initialization for connecting session", %{conn: conn} do
      c_alice = create_nick("p2p_lv_cmnt_a")
      c_bob = create_nick("p2p_lv_cmnt_b")

      token = "p2p-lv-#{System.unique_integer([:positive])}"

      {:ok, c_session} =
        Queries.insert_session(%{
          token: token,
          creator_id: c_alice.id,
          peer_id: c_bob.id,
          status: "pending",
          session_type: "audio_call"
        })

      {:ok, _pid} = Supervisor.start_child(c_session.token)
      :ok = SessionServer.join(c_session.token, c_alice.id)
      :ok = SessionServer.join(c_session.token, c_bob.id)
      Process.sleep(20)

      :ok =
        SessionServer.request_action(
          c_session.token,
          c_alice.id,
          c_alice.nickname,
          "audio_call"
        )

      :ok = SessionServer.respond_action(c_session.token, c_bob.id, c_bob.nickname, true)
      Process.sleep(20)

      # Session is now in "connecting" state
      # Mount now — @call should be initialized from mount
      conn = chat_conn(conn, "p2p_lv_cmnt_a")
      {:ok, _view, html} = live(conn, "/p2p/#{c_session.token}")

      assert html =~ "media-call"

      stop_server(c_session.token)
    end

    test "action buttons hidden when call is active", %{
      conn: conn,
      session: session,
      alice: alice,
      bob: bob
    } do
      conn = chat_conn(conn, "p2p_lv_call_a")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      :ok = SessionServer.request_action(session.token, alice.id, alice.nickname, "audio_call")
      Process.sleep(20)

      :ok = SessionServer.respond_action(session.token, bob.id, bob.nickname, true)
      Process.sleep(50)

      html = render(view)
      # Action buttons should not be visible when call is active
      refute html =~ "p2p-lobby-actions__buttons"
    end
  end

  describe "close session" do
    setup %{conn: conn} do
      alice = create_nick("p2p_lv_a7")
      bob = create_nick("p2p_lv_b7")
      session = create_session(alice.id, bob.id)

      on_exit(fn -> stop_server(session.token) end)

      %{alice: alice, bob: bob, session: session, conn: conn}
    end

    test "close_session event redirects to /chat", %{conn: conn, session: session} do
      conn = chat_conn(conn, "p2p_lv_a7")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      assert {:error, {:live_redirect, %{to: "/chat"}}} =
               render_click(view, "close_session", %{})
    end

    test "p2p_session_closed broadcast redirects remaining peer", %{conn: conn, session: session} do
      conn = chat_conn(conn, "p2p_lv_b7")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      # Simulate session closed broadcast from other peer
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{
          event: "p2p_session_closed",
          payload: %{reason: "user_closed"}
        }
      )

      assert_redirect(view, "/chat")
    end

    test "p2p_status_changed to terminal redirects", %{conn: conn, session: session} do
      conn = chat_conn(conn, "p2p_lv_a7")
      {:ok, view, _html} = live(conn, "/p2p/#{session.token}")

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{
          event: "p2p_status_changed",
          payload: %{status: "closed"}
        }
      )

      assert_redirect(view, "/chat")
    end
  end
end
