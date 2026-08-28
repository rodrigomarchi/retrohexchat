defmodule RetroHexChatWeb.Components.UI.GroupCall.PreJoinTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.GroupCall.PreJoin

  @moduletag :unit

  defp render_panel(prejoin, participants \\ []) do
    render_component(&group_call_pre_join_panel/1,
      id: "group-call-prejoin",
      prejoin: prejoin,
      participants: participants,
      on_join: "group_call_prejoin_join",
      on_cancel: "group_call_prejoin_cancel"
    )
  end

  test "keeps the two-column antechamber layout" do
    html =
      render_panel(%{
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

    assert html =~ ~s|md:grid-cols-[260px_minmax(0,1fr)]|
    assert html =~ ~s(data-testid="group-call-prejoin-devices")
    assert html =~ ~s(data-testid="group-call-prejoin-audio-input")
    assert html =~ ~s(data-testid="group-call-prejoin-advanced")
    assert html =~ ~s(min-w-0)
    assert html =~ "Join #lobby"
    assert html =~ "Media defaults"
    assert html =~ "Layout and route"
    assert html =~ "Auto / Tile"
    assert html =~ "Conference route"
    assert html =~ "Layout defaults"
    assert Floki.find(document, ~s([data-testid="group-call-prejoin-advanced"][open])) == []
  end

  # The roster is what makes the antechamber a door rather than a settings
  # screen, and an empty room has to say so in words: a blank list reads as
  # "still loading".
  test "names who is already inside, and says so when nobody is" do
    assert render_panel(%{channel_name: "#lobby", user_id: 1}, ["ana", "bob"]) =~ "ana"

    assert render_panel(%{channel_name: "#lobby", user_id: 1}, ["ana", "bob"]) =~
             "Already inside"

    empty = render_panel(%{channel_name: "#lobby", user_id: 1}, [])
    assert empty =~ "Nobody yet"
    refute empty =~ ~s(data-testid="group-call-prejoin-roster-entry")
  end

  # A browser that has granted the microphone but not the camera reports one
  # kind. The dialog still renders three pickers, so every kind has to reach it
  # even when the browser did not mention it.
  test "renders all three pickers when the browser reported only one kind" do
    html =
      render_panel(%{
        channel_name: "#lobby",
        user_id: 1,
        devices: %{"audioinput" => [%{"id" => "mic-1", "label" => "Only microphone"}]}
      })

    assert html =~ ~s(data-testid="group-call-prejoin-audio-input")
    assert html =~ ~s(data-testid="group-call-prejoin-video-input")
    assert html =~ ~s(data-testid="group-call-prejoin-audio-output")
    assert html =~ "Only microphone"
  end

  test "renders before the browser has reported anything at all" do
    html = render_panel(%{channel_name: "#lobby", user_id: 1})

    assert html =~ ~s(data-testid="group-call-prejoin-devices")
    assert html =~ "Join #lobby"
  end
end
