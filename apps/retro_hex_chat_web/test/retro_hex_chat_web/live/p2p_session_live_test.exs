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

  describe "p2p_connect event" do
    test "transitions session from lobby to connecting and pushes WebRTC start",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      # Mount as creator
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      # Simulate peer joining so session transitions to lobby
      SessionServer.join(token, peer.id)
      Process.sleep(50)

      # Click the Connect button
      render_click(view, "p2p_connect")

      # Assert WebRTC start event was pushed to the creator (initiator)
      assert_push_event(view, "p2p_start_offer", %{role: "initiator"})
    end

    test "connect button is visible in lobby state",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      # Both join -> lobby
      SessionServer.join(token, peer.id)
      Process.sleep(50)
      html = render(view)

      assert has_element?(view, ~s([data-testid="p2p-lobby-connect"]))
      assert html =~ "Connect"
    end

    test "connect button is visible in pending state",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/p2p/#{token}")

      # Still pending (only creator joined)
      assert has_element?(view, ~s([data-testid="p2p-lobby-connect"]))
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
