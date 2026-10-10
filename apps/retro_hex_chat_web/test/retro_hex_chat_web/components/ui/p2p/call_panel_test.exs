defmodule RetroHexChatWeb.Components.UI.P2P.CallPanelTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.P2P.CallPanel

  @moduletag :unit

  defp button_tag(html, testid) do
    [tag] = Regex.run(~r/<button(?:(?!>)[\s\S])*data-testid="#{testid}"(?:(?!>)[\s\S])*>/, html)
    tag
  end

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
    assert html =~ "Waiting for peer"
    assert html =~ "Call controls become available"
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

  test "can delegate the canonical call header to the parent console" do
    html = render_panel(show_header: false)

    assert html =~ ~s(id="lobby-media")
    refute html =~ ~s(data-testid="p2p-call-header")
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
    assert html =~ ~s(data-testid="p2p-call-open-stats")
    assert html =~ ~s(data-testid="p2p-call-mini-toggle")
    assert html =~ ~s(data-testid="p2p-call-layout-controls")
    # A call between two has two layouts, and offers no button that changes nothing.
    assert html =~ ~s(phx-value-layout="focus")
    assert html =~ ~s(phx-value-layout="split")
    refute html =~ ~s(phx-value-layout="auto")
    refute html =~ ~s(phx-value-layout="speaker")
    refute html =~ ~s(phx-value-layout="compact")
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
    assert html =~ ~s(data-testid="p2p-call-dock")

    assert html =~ "media-dock-button--captioned"
    assert html =~ "media-dock-button--danger"
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
    assert html =~ ~s(data-testid="p2p-call-open-stats")
    assert html =~ ~s(data-testid="p2p-call-mini-toggle")
    assert html =~ ~s(data-testid="p2p-call-end")
    refute html =~ ~s(data-testid="p2p-call-layout-controls")
    refute html =~ ~s(data-testid="p2p-call-reaction-heart")
    refute html =~ ~s(data-testid="lobby-devices")
    assert html =~ "media-dock-button--captioned"
  end

  test "mic and camera are pressed while on; expand and leave are not toggles" do
    on =
      render_panel(
        mini: true,
        local_muted: false,
        local_camera_off: false,
        call: %{type: "video", audio_on: true, video_on: true}
      )

    off =
      render_panel(
        local_muted: true,
        local_camera_off: true,
        call: %{type: "video", audio_on: true, video_on: true}
      )

    assert button_tag(on, "p2p-call-toggle-mute") =~ ~s(aria-pressed="true")
    assert button_tag(on, "p2p-call-toggle-camera") =~ ~s(aria-pressed="true")
    assert button_tag(off, "p2p-call-toggle-mute") =~ ~s(aria-pressed="false")
    assert button_tag(off, "p2p-call-toggle-camera") =~ ~s(aria-pressed="false")
    refute button_tag(on, "p2p-call-mini-toggle") =~ "aria-pressed"
    refute button_tag(on, "p2p-call-end") =~ "aria-pressed"
  end

  test "mini mode sets your own camera aside whatever the self-view mode" do
    for self_view <- ["pip", "tile"] do
      html =
        render_panel(
          mini: true,
          self_view: self_view,
          call: %{type: "video", audio_on: true, video_on: true}
        )

      assert html =~ ~r/class="hidden"\s+data-testid="p2p-call-local-tile"/
    end
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

  test "the split layout puts your camera beside the peer's unless you hid it" do
    in_call = [
      call: %{type: "video", audio_on: true, video_on: true},
      peer_media: %{audio: true, video: true}
    ]

    split = render_panel(in_call ++ [call_layout: "split", self_view: "pip"])
    assert split =~ "sm:grid-cols-2"
    assert split =~ ~r/data-testid="p2p-call-local-tile"\s+data-self-view="tile"/
    refute split =~ ~s(class="p2p-call-pip)
    # Beside the peer's picture, yours is shown whole too, not cropped to fill.
    assert split =~ ~r/id="lobby-local-video" class="[^"]*object-contain/

    focus = render_panel(in_call ++ [call_layout: "focus", self_view: "pip"])
    refute focus =~ "sm:grid-cols-2"
    assert focus =~ ~s(class="p2p-call-pip)
    assert focus =~ ~r/id="lobby-local-video" class="[^"]*object-cover/

    hidden = render_panel(in_call ++ [call_layout: "split", self_view: "hidden"])
    assert hidden =~ ~r/class="hidden"\s+data-testid="p2p-call-local-tile"/
  end

  test "side by side, the self-view button shows and hides your camera with no dead step" do
    assert next_self_view("split", "tile") == "hidden"
    assert next_self_view("split", "pip") == "hidden"
    assert next_self_view("split", "hidden") == "tile"
    assert next_self_view("side_by_side", "hidden") == "tile"

    assert next_self_view("focus", "tile") == "pip"
    assert next_self_view("focus", "pip") == "hidden"
    assert next_self_view("focus", "hidden") == "tile"
  end

  test "a peer who left the call is said so, not shown as a frozen picture" do
    html =
      render_panel(
        call: %{type: "video", audio_on: true, video_on: true, quality_label: "Excellent"},
        peer_media: %{audio: false, video: false},
        peer_left: true
      )

    assert html =~ ~s(data-testid="p2p-call-peer-left")
    assert html =~ "trinity left the call"
    # Nothing is measured from a peer who is gone.
    refute html =~ ~s(data-testid="lobby-call-quality")
    assert html =~ ~r/id="lobby-remote-video"\s+class="[^"]*invisible/
  end

  test "out of the call while the peer is still in it, you are invited back" do
    html = render_panel(call: nil, peer_media: %{audio: true, video: true})

    refute html =~ ~s(data-testid="p2p-call-surface")
    assert html =~ ~s(data-testid="p2p-call-peer-in-call")
    assert html =~ "trinity is still in the call"
    assert html =~ ~s(data-testid="lobby-call-start-video")
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

    assert html =~
             ~r/aria-pressed="true"[^>]*data-testid="p2p-call-screen-share"|data-testid="p2p-call-screen-share"[^>]*aria-pressed="true"/
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
