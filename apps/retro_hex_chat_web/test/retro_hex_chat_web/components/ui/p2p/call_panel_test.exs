defmodule RetroHexChatWeb.Components.UI.P2P.CallPanelTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.P2P.CallPanel

  @moduletag :unit

  defp render_panel(assigns) do
    render_component(
      &call_panel/1,
      Keyword.merge(
        [
          connected: true,
          call: nil,
          call_layout: "focus",
          peer_nick: "trinity",
          nickname: "neo",
          local_muted: false,
          local_camera_off: false,
          peer_media: %{audio: false, video: false},
          peer_camera_off: false,
          peer_muted: false,
          devices: nil
        ],
        assigns
      )
    )
  end

  test "renders a disconnected media state without mounting the hook" do
    html = render_panel(connected: false)

    assert html =~ ~s(data-testid="p2p-call-panel")
    assert html =~ ~s(data-testid="p2p-call-disconnected")
    assert html =~ "Connect to start"
    refute html =~ ~s(phx-hook="LobbyMediaHook")
  end

  test "mounts the media hook and start controls while connected but idle" do
    html = render_panel([])

    assert html =~ ~s(id="lobby-media")
    assert html =~ ~s(phx-hook="LobbyMediaHook")
    assert html =~ ~s(data-testid="p2p-call-header")
    assert html =~ ~s(data-testid="p2p-call-idle")
    assert html =~ ~s(data-testid="lobby-call-start-audio")
    assert html =~ ~s(data-testid="lobby-call-start-video")
    refute html =~ ~s(data-lobby-media-action="end-call")
  end

  test "active video call preserves hook ids and exposes rich controls" do
    html =
      render_panel(
        call: %{
          type: "video",
          audio_on: true,
          video_on: true,
          duration: "00:01:02",
          quality_label: "Good",
          quality_level: "good"
        },
        peer_media: %{audio: true, video: true},
        devices: %{
          "audioinput" => [%{"id" => "mic-1", "label" => "Mic 1"}],
          "videoinput" => [%{"id" => "cam-1", "label" => "Cam 1"}],
          "audiooutput" => [%{"id" => "out-1", "label" => "Output 1"}]
        }
      )

    assert html =~ ~s(data-testid="p2p-call-surface")
    assert html =~ ~s(id="lobby-remote-video")
    assert html =~ ~s(id="lobby-local-video")
    assert html =~ ~s(id="lobby-remote-audio")
    assert html =~ ~s(data-lobby-media-action="mute")
    assert html =~ ~s(data-lobby-media-action="camera")
    assert html =~ ~s(data-lobby-media-action="pip")
    assert html =~ ~s(data-lobby-media-action="screen-share")
    assert html =~ ~s(data-lobby-media-action="device-settings")
    assert html =~ ~s(data-lobby-media-action="end-call")
    assert html =~ ~s(data-testid="p2p-call-dock-stats")
    assert html =~ ~s(data-testid="p2p-call-mini-toggle")
    assert html =~ ~s(data-testid="p2p-call-layout-controls")
    assert html =~ ~s(phx-value-layout="auto")
    assert html =~ ~s(phx-value-layout="focus")
    assert html =~ ~s(phx-value-layout="split")
    assert html =~ ~s(phx-value-layout="speaker")
    assert html =~ ~s(phx-value-layout="compact")
    assert html =~ ~s(data-testid="p2p-call-self-view-toggle")
    assert html =~ ~s(data-testid="p2p-call-reaction-heart")
    assert html =~ ~s(data-testid="p2p-call-reaction-thumbs_up")
    assert html =~ ~s(phx-click="send_call_reaction")
    refute html =~ ~s(phx-value-preset=)
    refute html =~ "High quality"
    refute html =~ "Medium quality"
    refute html =~ "Low quality"
    assert html =~ ~s(data-testid="lobby-call-quality")
    assert html =~ "00:01:02"
    assert html =~ ~s(data-device-kind="audioinput")
    assert html =~ ~s(data-device-kind="videoinput")
    assert html =~ ~s(data-device-kind="audiooutput")
  end

  test "mini mode keeps essential call controls and hides wide controls" do
    html =
      render_panel(
        mini: true,
        call: %{
          type: "video",
          audio_on: true,
          video_on: true,
          duration: "00:00:11",
          quality_label: "Good"
        },
        peer_media: %{audio: true, video: true},
        devices: %{
          "audioinput" => [%{"id" => "mic-1", "label" => "Mic 1"}],
          "videoinput" => [%{"id" => "cam-1", "label" => "Cam 1"}]
        }
      )

    assert html =~ ~s(data-call-mini="true")
    assert html =~ ~s(data-testid="p2p-call-toggle-mute")
    assert html =~ ~s(data-testid="p2p-call-toggle-camera")
    assert html =~ ~s(data-testid="p2p-call-screen-share")
    assert html =~ ~s(data-testid="p2p-call-dock-stats")
    assert html =~ ~s(data-testid="p2p-call-mini-toggle")
    assert html =~ ~s(data-testid="p2p-call-end")
    refute html =~ ~s(data-testid="p2p-call-layout-controls")
    refute html =~ ~s(data-testid="p2p-call-reaction-heart")
    refute html =~ ~s(data-testid="lobby-devices")
  end

  test "tile self-view renders local video as a layout tile" do
    html =
      render_panel(
        call: %{type: "video", audio_on: true, video_on: true},
        peer_media: %{audio: true, video: true},
        call_layout: "split",
        self_view: "tile"
      )

    assert html =~ ~s(data-call-layout="split")
    assert html =~ ~s(data-self-view="tile")
    assert html =~ ~s(data-testid="p2p-call-local-tile")
    assert html =~ ~s(id="lobby-local-video")
  end

  test "screen sharing state renders local and peer badges" do
    html =
      render_panel(
        call: %{type: "video", audio_on: true, video_on: true, screen_sharing: true},
        peer_media: %{audio: true, video: true},
        screen_sharing: true,
        peer_screen_sharing: true
      )

    assert html =~ ~s(data-testid="p2p-call-screen-share")
    assert html =~ ~s(data-screen-share="true")
    assert html =~ "Your screen"
    assert html =~ "Screen session"
  end

  test "renders local and peer reaction overlays" do
    html =
      render_panel(
        call: %{type: "video", audio_on: true, video_on: true},
        peer_media: %{audio: true, video: true},
        reactions: [
          %{id: "local-1", source: :local, reaction: "heart"},
          %{id: "peer-1", source: :peer, reaction: "clap"}
        ]
      )

    assert html =~ ~s(data-testid="p2p-local-reactions")
    assert html =~ ~s(data-testid="p2p-peer-reactions")
    assert html =~ ~s(data-reaction="heart")
    assert html =~ ~s(data-reaction="clap")
  end
end
