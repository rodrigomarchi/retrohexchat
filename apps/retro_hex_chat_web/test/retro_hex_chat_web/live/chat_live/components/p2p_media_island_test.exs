defmodule RetroHexChatWeb.ChatLive.Components.P2PMediaIslandTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.P2PMediaIsland

  @moduletag :unit

  test "id/0 is stable and distinct from the panel's hook element" do
    assert P2PMediaIsland.id() == "lobby-media-island"
  end

  test "prompts to connect before the lobby is connected" do
    html = render_component(P2PMediaIsland, id: P2PMediaIsland.id(), connected: false)

    refute html =~ ~s(data-testid="lobby-media-panel")
    assert html =~ "Connect to start"
  end

  test "mounts the media hook and offers start buttons when idle" do
    html = render_component(P2PMediaIsland, id: P2PMediaIsland.id(), connected: true)

    assert html =~ ~s(phx-hook="LobbyMediaHook")
    assert html =~ ~s(data-testid="lobby-call-start-audio")
    assert html =~ ~s(data-testid="lobby-call-start-video")
    refute html =~ "End call"
  end

  test "auto-joins and surfaces the call when the peer turns media on (surface_peer_media)" do
    html =
      render_component(P2PMediaIsland,
        id: P2PMediaIsland.id(),
        connected: true,
        peer_nick: "trinity",
        action: {:peer_media_changed, %{user_id: 2, audio: true, video: true}}
      )

    # We are now in the call (window opens via push) and the remote surface renders.
    # This is the synchronous interim state: the island also pushes a start event so
    # the hook opens our own mic/camera by default, then echoes the real call state.
    # Until that echo, we render as sending nothing (enable-on-demand controls).
    assert html =~ ~s(id="lobby-remote-video")
    assert html =~ "End call"
    assert html =~ ~s(data-lobby-media-action="enable-audio")
    assert html =~ ~s(data-lobby-media-action="enable-video")
    # Interim state has no live track yet → no mute/camera toggles.
    refute html =~ ~s(data-lobby-media-action="mute")
  end

  test "a peer camera update reflects on this side" do
    html =
      render_component(P2PMediaIsland,
        id: P2PMediaIsland.id(),
        connected: true,
        peer_nick: "trinity",
        action: {:peer_media_changed, %{user_id: 2, audio: true, video: true}}
      )

    # The surface is up with the peer present.
    assert html =~ ~s(id="lobby-remote-audio")
  end

  test "local screen sharing forces the call surface into focus layout" do
    html =
      render_component(P2PMediaIsland,
        id: P2PMediaIsland.id(),
        connected: true,
        action: {:media_event, "lobby_media_screen_share_changed", %{"active" => true}}
      )

    assert html =~ ~s(data-call-layout="focus")
    assert html =~ ~s(data-screen-share="true")
    assert html =~ "Screen session"
  end
end
