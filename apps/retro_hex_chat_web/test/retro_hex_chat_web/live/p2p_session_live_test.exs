defmodule RetroHexChatWeb.V2.P2PSessionLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.P2P.{Queries, Registry, SessionServer, Supervisor}
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :liveview

  setup do
    Application.put_env(:retro_hex_chat, :p2p_pending_timeout, :timer.minutes(5))
    Application.put_env(:retro_hex_chat, :p2p_lobby_warning_timeout, :timer.minutes(10))
    Application.put_env(:retro_hex_chat, :p2p_lobby_expiry_timeout, :timer.minutes(15))
    Application.put_env(:retro_hex_chat, :p2p_connecting_timeout, :timer.seconds(30))

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :p2p_pending_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_lobby_warning_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_lobby_expiry_timeout)
      Application.delete_env(:retro_hex_chat, :p2p_connecting_timeout)
    end)

    creator = create_registered_nick("p2pc#{uid()}")
    peer = create_registered_nick("p2pp#{uid()}")

    token = "lv-#{System.unique_integer([:positive])}"

    {:ok, session} =
      Queries.insert_session(%{
        token: token,
        creator_id: creator.id,
        peer_id: peer.id,
        status: "pending",
        session_type: "generic"
      })

    {:ok, _pid} = Supervisor.start_child(token)

    on_exit(fn ->
      case Registry.lookup(token) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        _ -> :ok
      end
    end)

    {:ok, session: session, token: token, creator: creator, peer: peer}
  end

  describe "action buttons in lobby" do
    test "action buttons are visible in lobby state",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      SessionServer.join(token, peer.id)
      Process.sleep(50)

      html = render(view)
      assert html =~ "Audio Call"
      assert html =~ "Video Call"
      assert html =~ "Send File"
    end

    test "action buttons are not visible in pending state",
         %{conn: conn, token: token, creator: creator} do
      {:ok, _view, html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      refute html =~ "Audio Call"
      refute html =~ "Video Call"
      refute html =~ "Send File"
    end

    test "request_action triggers consent flow and transitions to connecting",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      {:ok, creator_view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")
      {:ok, peer_view, _html} = live(chat_conn(conn, peer.nickname), "/p2p/#{token}")

      SessionServer.join(token, peer.id)
      Process.sleep(50)

      render_click(creator_view, "request_action", %{"action_type" => "audio_call"})
      Process.sleep(50)

      # Peer sees consent banner
      html = render(peer_view)
      assert html =~ "audio_call"

      # Peer accepts → triggers connecting → WebRTC starts
      render_click(peer_view, "respond_action", %{"accepted" => "true"})

      assert_push_event(creator_view, "p2p_start_offer", %{role: "initiator"})
    end
  end

  describe "hooks and DOM elements" do
    test "WebRTCHook element is present on mount",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      assert has_element?(view, ~s(#p2p-webrtc[phx-hook="WebRTCHook"]))
    end

    test "P2PCapabilityHook element is present on mount",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      assert has_element?(view, ~s(#p2p-capabilities[phx-hook="P2PCapabilityHook"]))
    end

    test "P2PDiagramHook element is present on mount",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      assert has_element?(view, ~s(#p2p-diagram[phx-hook="P2PDiagramHook"]))
    end
  end

  describe "connection diagram" do
    test "shows waiting state when peer not online",
         %{conn: conn, token: token, creator: creator} do
      {:ok, _view, html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      assert html =~ "Waiting..."
      assert html =~ creator.nickname
    end

    test "shows ready state when peer is online",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      SessionServer.join(token, peer.id)
      Process.sleep(50)

      html = render(view)
      assert html =~ "Ready"
    end

    test "shows connecting state during WebRTC setup",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      # Simulate status change to connecting via direct message
      send(view.pid, %{
        event: "p2p_status_changed",
        payload: %{status: "connecting"}
      })

      html = render(view)
      assert html =~ "Connecting..."
    end
  end

  describe "media call area" do
    test "MediaHook renders with video/audio elements when call is active",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      # Simulate call being active
      send(view.pid, %{
        event: "p2p_status_changed",
        payload: %{status: "active"}
      })

      # Set call state via a media_call_started event
      render_click(view, "media_call_started", %{"type" => "audio"})
      Process.sleep(50)
      html = render(view)

      assert html =~ ~s(id="media-call")
      assert html =~ ~s(phx-hook="MediaHook")
      assert html =~ ~s(id="remote-audio")
      assert has_element?(view, ~s([data-testid="media-controls-mute"]))
      assert has_element?(view, ~s([data-testid="media-controls-end-call"]))
    end

    test "media controls use data-media-action for hook wiring",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      send(view.pid, %{
        event: "p2p_status_changed",
        payload: %{status: "active"}
      })

      render_click(view, "media_call_started", %{"type" => "audio"})
      Process.sleep(50)
      html = render(view)

      assert html =~ ~s(data-media-action="mute")
      assert html =~ ~s(data-media-action="end-call")
    end

    test "video elements render for video call",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      send(view.pid, %{
        event: "p2p_status_changed",
        payload: %{status: "active"}
      })

      render_click(view, "media_call_started", %{"type" => "video"})
      Process.sleep(50)
      html = render(view)

      assert html =~ ~s(id="remote-video")
      assert html =~ ~s(id="local-video")
      assert html =~ ~s(data-media-action="camera")
    end

    test "no media area when no call is active",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      refute has_element?(view, ~s([data-testid="media-call"]))
    end
  end

  describe "file transfer area" do
    test "FileTransferHook renders with file input when file transfer is active",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      # Action response sets accepted_action_type (must come before status change)
      send(view.pid, %{
        event: "p2p_action_response",
        payload: %{
          accepted: true,
          responder_id: 0,
          responder_nick: "peer",
          action_type: "file_transfer"
        }
      })

      Process.sleep(50)

      # Status change to active triggers maybe_init_file_transfer
      send(view.pid, %{
        event: "p2p_status_changed",
        payload: %{status: "active"}
      })

      Process.sleep(50)
      html = render(view)

      assert html =~ ~s(id="p2p-file-transfer")
      assert html =~ ~s(phx-hook="FileTransferHook")
      assert html =~ ~s(id="p2p-file-input")
      assert html =~ "Browse Files"
    end

    test "no file transfer area when not active",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      refute has_element?(view, ~s([data-testid="file-transfer-hook"]))
    end

    test "cancelled file transfer keeps file context and renders cancelled status",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      render_hook(view, "ft_offer_sent", %{
        "file_name" => "cancel-me.txt",
        "file_size" => 12,
        "formatted_size" => "12 B"
      })

      html = render_hook(view, "ft_cancelled", %{"cancelled_by" => creator.nickname})

      assert html =~ "cancel-me.txt"
      assert html =~ "Cancelled by #{creator.nickname}"
      refute html =~ "Failed"
    end

    test "file validation error stays visible and keeps file picker available",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      html =
        render_hook(view, "ft_validation_error", %{
          "error" => "Tipo de arquivo bloqueado: .exe"
        })

      assert html =~ ~s(data-testid="file-transfer-validation-error")
      assert html =~ "Tipo de arquivo bloqueado: .exe"
      assert html =~ "Browse Files"
    end
  end

  # -- Helpers --

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
end
