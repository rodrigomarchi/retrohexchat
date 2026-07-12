defmodule RetroHexChatWeb.Components.UI.P2P.SetupDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.P2P.SetupDialog

  @moduletag :unit

  defp render_dialog(setup) do
    render_component(&p2p_setup_dialog/1,
      id: "p2p-setup",
      setup: setup,
      on_accept: "p2p_setup_accept",
      on_cancel: "p2p_setup_cancel"
    )
  end

  test "stays mounted but hides the form when there is no pending setup" do
    html = render_dialog(nil)

    assert html =~ ~s(data-testid="p2p-setup-dialog")
    refute html =~ ~s(data-testid="p2p-setup-form")
  end

  test "renders media posture choices and the selected default" do
    html =
      render_dialog(%{
        peer_nick: "trinity",
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

    assert html =~ "Connect with trinity"
    assert html =~ ~s(phx-hook="P2PSetupHook")
    assert html =~ ~s(data-testid="p2p-setup-preview")
    assert html =~ "Start with microphone"
    assert html =~ "Start with camera"
    assert html =~ "Turn both off to join receive-only"
    assert html =~ ~s(data-testid="p2p-setup-audio-input")
    assert html =~ ~s(value="mic-1" selected)
    assert html =~ "Privacy relay"
    assert html =~ ~s(<svg)
    assert Floki.find(document, ~s([data-testid="p2p-setup-audio"][checked])) != []
    assert Floki.find(document, ~s([data-testid="p2p-setup-video"][checked])) == []
    assert Floki.find(document, ~s([data-testid="p2p-setup-turn-only"][checked])) != []
  end

  test "uses outgoing invite copy before a creator sends the invite" do
    html =
      render_dialog(%{
        kind: :outgoing,
        peer_nick: "tank",
        media_mode: "video",
        payload: %{target: "tank", target_id: 42, creator_id: 7}
      })

    assert html =~ "Prepare P2P Invite"
    assert html =~ "The invite is sent after this setup"
    assert html =~ "Send invite"
  end

  test "disables privacy relay when TURN is unavailable" do
    html =
      render_dialog(%{
        created_by: "morpheus",
        media_mode: "receive",
        turn_only: true,
        turn_configured: false
      })

    document = Floki.parse_document!(html)

    assert html =~ "Connect with morpheus"
    assert html =~ "Relay privacy is unavailable"
    assert Floki.find(document, ~s([data-testid="p2p-setup-audio"][checked])) == []
    assert Floki.find(document, ~s([data-testid="p2p-setup-video"][checked])) == []
    assert Floki.find(document, ~s([data-testid="p2p-setup-turn-only"][disabled])) != []

    refute Floki.raw_html(Floki.find(document, ~s([data-testid="p2p-setup-turn-only"]))) =~
             "checked"
  end
end
