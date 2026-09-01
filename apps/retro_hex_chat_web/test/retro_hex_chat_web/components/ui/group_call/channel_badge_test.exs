defmodule RetroHexChatWeb.Components.UI.GroupCall.ChannelBadgeTest do
  @moduledoc """
  The conference entry in the chat's tab strip, in its three shapes.

  A conference has one door and it is an address, so the entry is a link
  whenever there is a room to enter. The three shapes are: no room yet, where
  the click is what creates one; a room this person is not in a tab of, which is
  a way in; and a room they already have open, which is a way *to that tab* —
  because a second tab of a room you are in is a second seat nobody asked for.
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

  defp render_entry(open_paths, overrides \\ []) do
    render_component(
      &group_call_channel_entry/1,
      Keyword.merge(
        [channel: "#retro", active: true, summary: summary(), open_paths: open_paths],
        overrides
      )
    )
  end

  test "a live room is entered by its address, not by an event" do
    html = render_entry(MapSet.new())

    assert html =~ ~s(data-testid="group-call-open")
    assert html =~ ~s(href="/call/#{@room_token}")
    assert html =~ ~s(target="_blank")
    assert html =~ ~s(rel="noopener")
    # Nothing here opens a conference inside the chat any more.
    refute html =~ ~s(phx-click="group_call_open")
    refute html =~ ~s(data-testid="group-call-elsewhere")
  end

  test "points at the tab that exists instead, when there is one" do
    html = render_entry(MapSet.new(["/call/#{@room_token}"]))

    assert html =~ ~s(data-testid="group-call-elsewhere")
    assert html =~ ~s(href="/call/#{@room_token}")
    assert html =~ ~s(phx-hook="SurfaceTabLinkHook")
    # And it stops offering a second way in.
    refute html =~ ~s(data-testid="group-call-open")
  end

  # The set holds every address this person has open, and a tab of some other
  # room is not a tab of this one.
  test "another room's tab is not this room's tab" do
    html = render_entry(MapSet.new(["/call/someotherroom", "/space/abc"]))

    assert html =~ ~s(href="/call/#{@room_token}")
    refute html =~ ~s(data-testid="group-call-elsewhere")
  end

  test "a screen that was never told what is open still offers the way in" do
    html =
      render_component(&group_call_channel_entry/1,
        channel: "#retro",
        active: true,
        summary: summary()
      )

    assert html =~ ~s(href="/call/#{@room_token}")
  end

  # With no room there is no address, so the entry is the one click in the
  # product that creates a conference — and it is a click precisely because
  # there is nothing to link to yet.
  test "a channel with no room offers the click that creates one" do
    html =
      render_component(&group_call_channel_entry/1,
        channel: "#retro",
        active: false,
        summary: nil,
        open_paths: MapSet.new()
      )

    assert html =~ ~s(data-testid="group-call-open")
    assert html =~ ~s(phx-click="group_call_open")
    refute html =~ ~s(href="/call/)
  end

  # An anchor cannot be disabled, so a reader the room would refuse keeps the
  # button and the refusal that goes with it.
  test "an unidentified reader is refused rather than linked" do
    html = render_entry(MapSet.new(), identified: false)

    assert html =~ ~s(phx-click="group_call_open")
    assert html =~ "disabled"
    refute html =~ ~s(href="/call/#{@room_token}")
  end
end
