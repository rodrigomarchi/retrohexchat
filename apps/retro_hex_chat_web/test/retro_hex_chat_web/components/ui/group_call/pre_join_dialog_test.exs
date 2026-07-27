defmodule RetroHexChatWeb.Components.UI.GroupCall.PreJoinDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.GroupCall.PreJoinDialog

  @moduletag :unit

  defp render_dialog(prejoin) do
    render_component(&group_call_pre_join_dialog/1,
      id: "group-call-prejoin-dialog",
      prejoin: prejoin,
      on_join: "group_call_prejoin_join",
      on_cancel: "group_call_prejoin_cancel"
    )
  end

  test "keeps the desktop pre-join grid inside the dialog surface" do
    html =
      render_dialog(%{
        channel_name: "#lobby",
        user_id: 1,
        media: %{audio: true, video: true},
        layout: %{mode: :auto, self_view: :tile},
        devices: %{
          "audioinput" => [%{"id" => "mic-1", "label" => "External studio microphone"}],
          "videoinput" => [%{"id" => "cam-1", "label" => "External camera"}],
          "audiooutput" => [%{"id" => "out-1", "label" => "System output"}]
        }
      })

    document = Floki.parse_document!(html)

    assert html =~ ~s|md:max-w-[760px]|
    assert html =~ ~s|md:w-[720px]|
    assert html =~ ~s|md:grid-cols-[260px_minmax(0,1fr)]|
    assert html =~ ~s(data-testid="group-call-prejoin-devices")
    assert html =~ ~s(data-testid="group-call-prejoin-audio-input")
    assert html =~ ~s(data-testid="group-call-prejoin-advanced")
    assert html =~ ~s(min-w-0)
    assert html =~ "Join Channel Conference"
    assert html =~ "Join #lobby"
    assert html =~ "Media defaults"
    assert html =~ "Layout and route"
    assert html =~ "Auto / Tile"
    assert html =~ "Conference route"
    assert html =~ "Layout defaults"
    assert Floki.find(document, ~s([data-testid="group-call-prejoin-advanced"][open])) == []
  end
end
