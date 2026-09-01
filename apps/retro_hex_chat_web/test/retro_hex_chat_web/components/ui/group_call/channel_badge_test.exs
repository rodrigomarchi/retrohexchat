defmodule RetroHexChatWeb.Components.UI.GroupCall.ChannelBadgeTest do
  @moduledoc """
  The conference entry in the chat's tab strip, in its two shapes.

  Which shape it takes is the server's answer — `RetroHexChat.Surfaces` monitors
  the process behind every tab — and the difference is not decoration. With the
  call already open in a tab of this person's, opening the embedded window
  alongside it puts the same conference on screen twice and they asked for
  neither.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.GroupCall.ChannelBadge

  @moduletag :unit

  @room_token "roomtoken123"

  defp summary(overrides \\ %{}) do
    Map.merge(
      %{
        status: :active,
        room: %{token: @room_token, channel_name: "#retro", status: "open", max_participants: 8},
        participants: [%{id: 1, nickname: "ana"}, %{id: 2, nickname: "bob"}]
      },
      overrides
    )
  end

  defp render_entry(open_paths) do
    render_component(&group_call_channel_entry/1,
      channel: "#retro",
      active: true,
      summary: summary(),
      open_paths: open_paths
    )
  end

  test "offers to open the window when this person has no tab for it" do
    html = render_entry(MapSet.new())

    assert html =~ ~s(data-testid="group-call-open")
    assert html =~ ~s(phx-click="group_call_open")
    refute html =~ ~s(data-testid="group-call-elsewhere")
  end

  test "points at the tab that exists instead, when there is one" do
    html = render_entry(MapSet.new(["/call/#{@room_token}"]))

    assert html =~ ~s(data-testid="group-call-elsewhere")
    assert html =~ ~s(href="/call/#{@room_token}")
    assert html =~ ~s(phx-hook="SurfaceTabLinkHook")
    # And it stops offering to open a second one.
    refute html =~ ~s(data-testid="group-call-open")
  end

  # The set holds every address this person has open, and a tab of some other
  # room is not a tab of this one.
  test "another room's tab is not this room's tab" do
    html = render_entry(MapSet.new(["/call/someotherroom", "/space/abc"]))

    assert html =~ ~s(data-testid="group-call-open")
    refute html =~ ~s(data-testid="group-call-elsewhere")
  end

  test "a screen that was never told what is open offers to open" do
    html =
      render_component(&group_call_channel_entry/1,
        channel: "#retro",
        active: true,
        summary: summary()
      )

    assert html =~ ~s(data-testid="group-call-open")
  end
end
