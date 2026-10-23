defmodule RetroHexChatWeb.P2PLive.Components.P2PMediaIslandTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.P2PLive.Components.P2PMediaIsland

  @moduletag :unit

  test "shows a waiting state before the P2P session is connected" do
    html = render_component(P2PMediaIsland, id: P2PMediaIsland.id(), connected: false)

    refute html =~ ~s(data-testid="lobby-media-panel")
    assert html =~ "Waiting for peer"
    assert html =~ "Call controls become available"
  end

  test "mounts the media hook and offers start buttons when idle" do
    html = render_component(P2PMediaIsland, id: P2PMediaIsland.id(), connected: true)

    assert html =~ ~s(phx-hook="LobbyMediaHook")
    assert html =~ ~s(data-testid="lobby-call-start-audio")
    assert html =~ ~s(data-testid="lobby-call-start-video")
    refute html =~ "Leave call"
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
    # This is the synchronous interim state before the hook echoes the real call
    # state, so we render as sending nothing (enable-on-demand controls).
    assert html =~ ~s(id="lobby-remote-video")
    assert html =~ "Leave call"
    assert html =~ ~s(data-lobby-media-action="enable-audio")
    assert html =~ ~s(data-lobby-media-action="enable-video")
    # Interim state has no live track yet → no mute/camera toggles.
    refute html =~ ~s(data-lobby-media-action="mute")
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

    assert html =~
             ~r/aria-pressed="true"[^>]*data-testid="p2p-call-screen-share"|data-testid="p2p-call-screen-share"[^>]*aria-pressed="true"/
  end

  # The panel, the taskbar badge and the diagram all read the grade's name
  # from the call, so it is the server's word for a grade it knows.
  test "a quality update names the grade in the server's words" do
    render_component(P2PMediaIsland,
      id: P2PMediaIsland.id(),
      connected: true,
      action:
        {:media_event, "lobby_media_quality_update", %{"level" => "fair", "label" => "browser"}}
    )

    assert_received {:feature_summary, :call, %{quality_label: "Fair"}}
  end

  test "a grade the server does not know keeps the browser's word" do
    render_component(P2PMediaIsland,
      id: P2PMediaIsland.id(),
      connected: true,
      action:
        {:media_event, "lobby_media_quality_update",
         %{"level" => "measuring", "label" => "Measuring"}}
    )

    assert_received {:feature_summary, :call, %{quality_label: "Measuring"}}
  end
end
