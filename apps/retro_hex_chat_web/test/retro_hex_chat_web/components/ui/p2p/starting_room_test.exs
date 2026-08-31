defmodule RetroHexChatWeb.Components.UI.P2P.StartingRoomTest do
  @moduledoc """
  The starting room draws two things at once: the devices, which moved here
  whole from the old setup dialog, and the wait, which never had a screen.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.P2P.StartingRoom

  @moduletag :unit

  defp room(overrides) do
    Map.merge(
      %{
        nickname: "neo",
        peer_nick: "trinity",
        host?: true,
        host_nick: "neo",
        ready?: false,
        peer_present?: false,
        peer_ready?: false,
        can_start?: false
      },
      overrides
    )
  end

  defp render_room(setup, room_overrides \\ %{}) do
    render_component(&p2p_starting_room/1,
      id: "p2p-starting-room",
      setup: setup,
      room: room(room_overrides)
    )
  end

  test "renders media posture choices and the selected default" do
    html =
      render_room(%{
        media_mode: "audio",
        devices: %{
          "audioinput" => [%{"id" => "mic-1", "label" => "Mic 1"}],
          "videoinput" => [%{"id" => "cam-1", "label" => "Cam 1"}],
          "audiooutput" => [%{"id" => "out-1", "label" => "Output 1"}]
        },
        device_preferences: %{audio_input_id: "mic-1", video_input_id: nil, audio_output_id: nil},
        turn_only: true,
        turn_configured: true
      })

    document = Floki.parse_document!(html)

    assert html =~ ~s(data-testid="p2p-starting-room")
    assert html =~ ~s|md:grid-cols-[260px_minmax(0,1fr)]|
    assert html =~ ~s(phx-hook="P2PSetupHook")
    assert html =~ ~s(data-testid="p2p-setup-preview")
    assert html =~ "Media defaults"
    assert html =~ "Start with microphone"
    assert html =~ "Start with camera"
    assert html =~ "Turn both off to join receive-only"
    assert html =~ ~s(data-testid="p2p-setup-audio-input")
    assert html =~ ~s(value="mic-1" selected)
    assert html =~ ~s(data-testid="p2p-setup-advanced")
    assert html =~ "Route and privacy"
    assert html =~ "Relay on"
    assert html =~ "Privacy relay"
    assert Floki.find(document, ~s([data-testid="p2p-setup-audio"][checked])) != []
    assert Floki.find(document, ~s([data-testid="p2p-setup-video"][checked])) == []
    assert Floki.find(document, ~s([data-testid="p2p-setup-advanced"][open])) == []
    assert Floki.find(document, ~s([data-testid="p2p-setup-turn-only"][checked])) != []
  end

  test "both seats are always drawn, and the empty one names what it is waiting for" do
    html = render_room(%{media_mode: "video"})

    assert html =~ ~s(data-testid="p2p-room-occupant-you")
    assert html =~ ~s(data-testid="p2p-room-occupant-peer")
    assert html =~ "neo"
    assert html =~ "trinity"
    assert html =~ "(host)"
    assert html =~ "Choose your devices, then press Ready."
  end

  test "the wait says whose it is, in each of its three shapes" do
    invited = render_room(%{media_mode: "video"}, %{ready?: true})
    assert invited =~ "Waiting for trinity to accept the invite."

    unready =
      render_room(%{media_mode: "video"}, %{ready?: true, peer_present?: true})

    assert unready =~ "Waiting for trinity to be ready."

    guest =
      render_room(%{media_mode: "video"}, %{
        host?: false,
        host_nick: "trinity",
        ready?: true,
        peer_present?: true,
        peer_ready?: true
      })

    assert guest =~ "Waiting for trinity to start."
  end

  test "only the creator gets Start, and only once both sides are ready" do
    document =
      %{media_mode: "video"}
      |> render_room(%{ready?: true, peer_present?: true})
      |> Floki.parse_document!()

    assert Floki.find(document, ~s([data-testid="p2p-room-start"][disabled])) != []

    ready =
      %{media_mode: "video"}
      |> render_room(%{ready?: true, peer_present?: true, peer_ready?: true, can_start?: true})
      |> Floki.parse_document!()

    assert Floki.find(ready, ~s([data-testid="p2p-room-start"][disabled])) == []
    assert Floki.find(ready, ~s([data-testid="p2p-room-start"])) != []

    # A second offerer is the one thing this negotiation has never survived.
    peer =
      %{media_mode: "video"}
      |> render_room(%{host?: false, host_nick: "trinity", ready?: true, peer_ready?: true})
      |> Floki.parse_document!()

    assert Floki.find(peer, ~s([data-testid="p2p-room-start"])) == []
  end

  test "disables privacy relay when TURN is unavailable" do
    document =
      %{media_mode: "receive", turn_only: true, turn_configured: false}
      |> render_room()
      |> Floki.parse_document!()

    assert Floki.raw_html(document) =~ "Relay privacy is unavailable"
    assert Floki.find(document, ~s([data-testid="p2p-setup-audio"][checked])) == []
    assert Floki.find(document, ~s([data-testid="p2p-setup-video"][checked])) == []
    assert Floki.find(document, ~s([data-testid="p2p-setup-turn-only"][disabled])) != []

    refute Floki.raw_html(Floki.find(document, ~s([data-testid="p2p-setup-turn-only"]))) =~
             "checked"
  end
end
