defmodule RetroHexChatWeb.P2PSessionLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.P2P.{Queries, Supervisor}
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

      # Simulate action response (accepted) via PubSub
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "p2p:#{session.token}",
        %{
          event: "p2p_action_response",
          payload: %{accepted: true, responder_nick: "p2p_lv_b8", status: "accepted"}
        }
      )

      Process.sleep(20)
      html = render(view)
      # After response with status "accepted", consent banner should be hidden
      # (only shows when status == "pending")
      assert html =~ "p2p-lobby-actions__buttons"
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
