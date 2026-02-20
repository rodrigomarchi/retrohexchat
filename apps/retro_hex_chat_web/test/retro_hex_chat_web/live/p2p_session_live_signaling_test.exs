defmodule RetroHexChatWeb.P2PSessionLiveSignalingTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.P2P
  alias RetroHexChat.P2P.Service

  @moduletag :integration

  setup do
    # Create two registered users
    {:ok, creator} =
      RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
        nickname: "SignalCreator",
        password_hash: Bcrypt.hash_pwd_salt("pass123")
      })

    {:ok, peer} =
      RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
        nickname: "SignalPeer",
        password_hash: Bcrypt.hash_pwd_salt("pass123")
      })

    {:ok, %{session: session}} =
      P2P.create_session(creator.id, peer.id, session_type: "audio_call")

    %{creator: creator, peer: peer, session: session, token: session.token}
  end

  describe "ICE server configuration (US3)" do
    test "ice_servers/1 returns valid config with TURN credentials" do
      ice_servers = P2P.ice_servers("user123")

      assert [server] = ice_servers
      assert is_list(server.urls)
      assert [url] = server.urls
      assert String.contains?(url, "turn:")
      assert is_binary(server.username)
      assert String.contains?(server.username, ":")
      assert is_binary(server.credential)
    end

    test "start_signaling/3 returns role-specific payloads", %{
      creator: creator,
      peer: peer,
      token: token
    } do
      result = Service.start_signaling(token, creator.id, peer.id)

      assert %{creator_payload: creator_payload, peer_payload: peer_payload} = result
      assert creator_payload.role == "initiator"
      assert [_ | _] = creator_payload.ice_servers
      assert [_ | _] = peer_payload.ice_servers
      # Peer payload should not have role
      refute Map.has_key?(peer_payload, :role)
    end
  end

  describe "signal validation (US1)" do
    test "validate_signal/1 accepts valid offer" do
      assert {:ok, %{type: "offer", sdp: "v=0"}} =
               P2P.validate_signal(%{"type" => "offer", "sdp" => "v=0"})
    end

    test "validate_signal/1 rejects invalid type" do
      assert {:error, :invalid_signal} =
               P2P.validate_signal(%{"type" => "bogus", "sdp" => "v=0"})
    end
  end

  describe "p2p_signal event relay" do
    test "handle_event p2p_signal broadcasts to PubSub", %{
      creator: creator,
      token: token
    } do
      conn =
        build_conn()
        |> init_test_session(%{"chat_nickname" => creator.nickname})

      {:ok, view, _html} = live(conn, "/p2p/#{token}")

      # Subscribe to the P2P topic
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{token}")

      # Send a signal event
      render_hook(view, "p2p_signal", %{
        "type" => "offer",
        "sdp" => "v=0\r\no=- 1234 2 IN IP4 127.0.0.1"
      })

      assert_receive %{event: "p2p_signal", payload: %{type: "offer", from: _}}, 1000
    end
  end

  describe "p2p_connected event" do
    test "transitions session to active when in connecting state", %{
      creator: creator,
      peer: peer,
      token: token
    } do
      # Walk the session through the state machine: pending → lobby → connecting
      P2P.join_session(token, creator.id)
      P2P.join_session(token, peer.id)
      # Both joined → auto-transitions to "lobby"
      :ok = P2P.transition_status(token, :connecting)

      conn =
        build_conn()
        |> init_test_session(%{"chat_nickname" => creator.nickname})

      {:ok, view, _html} = live(conn, "/p2p/#{token}")

      render_hook(view, "p2p_connected", %{})

      # Session should now be active
      {:ok, session} = P2P.get_session(token)
      assert session.status == "active"
    end

    test "ignores p2p_connected when session not in connecting state", %{
      creator: creator,
      token: token
    } do
      conn =
        build_conn()
        |> init_test_session(%{"chat_nickname" => creator.nickname})

      {:ok, view, _html} = live(conn, "/p2p/#{token}")

      # Session is still "pending" — transition should be rejected
      render_hook(view, "p2p_connected", %{})

      {:ok, session} = P2P.get_session(token)
      assert session.status == "pending"
    end
  end

  describe "p2p_retry event (T031)" do
    test "tracks retry attempt in assigns", %{creator: creator, token: token} do
      conn =
        build_conn()
        |> init_test_session(%{"chat_nickname" => creator.nickname})

      {:ok, view, _html} = live(conn, "/p2p/#{token}")

      render_hook(view, "p2p_retry", %{"attempt" => 2})

      # Verify the retry state is broadcast via PubSub
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "p2p:#{token}")

      render_hook(view, "p2p_retry", %{"attempt" => 3})

      assert_receive %{event: "p2p_retry", payload: %{attempt: 3}}, 1000
    end
  end

  describe "p2p_state_change event (T036)" do
    test "updates webrtc_state assign", %{creator: creator, token: token} do
      conn =
        build_conn()
        |> init_test_session(%{"chat_nickname" => creator.nickname})

      {:ok, view, _html} = live(conn, "/p2p/#{token}")

      render_hook(view, "p2p_state_change", %{"state" => "connecting"})

      html = render(view)
      assert html =~ "Connecting..."
    end

    test "shows connected state", %{creator: creator, token: token} do
      conn =
        build_conn()
        |> init_test_session(%{"chat_nickname" => creator.nickname})

      {:ok, view, _html} = live(conn, "/p2p/#{token}")

      render_hook(view, "p2p_state_change", %{"state" => "connected"})

      html = render(view)
      assert html =~ "Connected"
    end

    test "shows failed state", %{creator: creator, token: token} do
      conn =
        build_conn()
        |> init_test_session(%{"chat_nickname" => creator.nickname})

      {:ok, view, _html} = live(conn, "/p2p/#{token}")

      render_hook(view, "p2p_state_change", %{"state" => "failed"})

      html = render(view)
      assert html =~ "Connection failed"
    end
  end
end
