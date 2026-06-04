defmodule RetroHexChatWeb.App.GameSessionMediaLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.Games.{Queries, Registry, Supervisor}
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :liveview

  setup do
    Application.put_env(:retro_hex_chat, :game_pending_timeout, :timer.minutes(5))
    Application.put_env(:retro_hex_chat, :game_lobby_warning_timeout, :timer.minutes(10))
    Application.put_env(:retro_hex_chat, :game_lobby_expiry_timeout, :timer.minutes(15))
    Application.put_env(:retro_hex_chat, :game_select_timeout, :timer.minutes(5))

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :game_pending_timeout)
      Application.delete_env(:retro_hex_chat, :game_lobby_warning_timeout)
      Application.delete_env(:retro_hex_chat, :game_lobby_expiry_timeout)
      Application.delete_env(:retro_hex_chat, :game_select_timeout)
    end)

    creator = create_registered_nick("gmediaa#{uid()}")
    peer = create_registered_nick("gmediab#{uid()}")
    token = "gm-#{System.unique_integer([:positive])}"

    {:ok, session} =
      Queries.insert_session(%{
        token: token,
        creator_id: creator.id,
        peer_id: peer.id,
        status: "pending"
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

  describe "game media DOM" do
    test "playing game renders media dock hook and start controls",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/game/#{token}")

      enter_playing(view)

      assert has_element?(view, ~s(#game-media[phx-hook="GameMediaHook"]))
      assert has_element?(view, ~s([data-testid="game-media-start-audio"]))
      assert has_element?(view, ~s([data-testid="game-media-start-video"]))
      assert has_element?(view, ~s(#game-remote-audio))
    end

    test "active video call renders remote and local video surfaces",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/game/#{token}")

      enter_playing(view)
      render_click(view, "game_media_call_started", %{"type" => "video"})

      assert has_element?(view, ~s([data-testid="game-media-call"]))
      assert has_element?(view, ~s(#game-remote-video))
      assert has_element?(view, ~s(#game-local-video))
      assert has_element?(view, ~s([data-testid="game-media-mute"]))
      assert has_element?(view, ~s([data-testid="game-media-camera"]))
    end
  end

  describe "game media lifecycle" do
    test "starting voice waits for media hook and RTC connection readiness",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/game/#{token}")

      enter_playing(view)
      render_click(view, "start_game_media", %{"type" => "audio"})

      refute_push_event(view, "game_media_start_audio", %{})

      render_hook(view, "game_media_hook_ready", %{})
      refute_push_event(view, "game_media_start_audio", %{})

      render_hook(view, "game_connected", %{})

      assert_push_event(view, "game_media_start_audio", %{})
    end

    test "starting video pushes video media start when ready",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/game/#{token}")

      enter_playing(view)
      render_hook(view, "game_media_hook_ready", %{})
      render_hook(view, "game_connected", %{})

      render_click(view, "start_game_media", %{"type" => "video"})

      assert_push_event(view, "game_media_start_video", %{})
    end

    test "peer-started video asks the host to renegotiate video receivers",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      {:ok, creator_view, _html} = live(chat_conn(conn, creator.nickname), "/game/#{token}")
      {:ok, peer_view, _html} = live(chat_conn(conn, peer.nickname), "/game/#{token}")

      enter_playing(creator_view)
      enter_playing(peer_view)

      render_click(peer_view, "game_media_call_started", %{"type" => "video"})

      assert_push_event(creator_view, "game_renegotiate", %{type: "video"})
    end

    test "ending media call keeps the game canvas open",
         %{conn: conn, token: token, creator: creator} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/game/#{token}")

      enter_playing(view)
      render_click(view, "game_media_call_started", %{"type" => "audio"})
      html = render_click(view, "game_media_call_ended", %{"reason" => "ended"})

      assert html =~ ~s(data-testid="game-canvas")
      refute html =~ ~s(data-testid="game-media-call")
      assert html =~ "Start Voice"
    end
  end

  describe "peer media indicators" do
    test "peer mute and camera events update active media UI",
         %{conn: conn, token: token, creator: creator, peer: peer} do
      {:ok, view, _html} = live(chat_conn(conn, creator.nickname), "/game/#{token}")

      enter_playing(view)
      render_click(view, "game_media_call_started", %{"type" => "video"})

      send(view.pid, %{
        event: "game_media_mute",
        payload: %{from: peer.id, muted: true}
      })

      assert render(view) =~ ~s(data-testid="game-media-peer-muted")

      send(view.pid, %{
        event: "game_media_camera",
        payload: %{from: peer.id, off: true}
      })

      assert render(view) =~ ~s(data-testid="game-media-peer-camera-off")
    end
  end

  defp enter_playing(view) do
    send(view.pid, %{
      event: "game_status_changed",
      payload: %{status: "playing", game_id: "hex_pong"}
    })

    render(view)
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
end
