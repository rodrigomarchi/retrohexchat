defmodule RetroHexChatWeb.Components.UI.GroupCall.ChannelBadgeTest do
  @moduledoc """
  The conference entry in the chat's tab strip, in the one shape it has.

  It had three, and two of them were anchors into the room's own address: a way
  in, and a way to the tab you already had. Both were doors that skipped the
  conversation, which is how somebody came to walk into a conference the channel
  was never told about. The entry writes the card and the card is the door, so
  what is left here is a button — always the same one, whether or not the room
  is already running.
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

  defp render_entry(overrides \\ []) do
    render_component(
      &group_call_channel_entry/1,
      Keyword.merge([channel: "#retro", active: true, summary: summary()], overrides)
    )
  end

  test "a live room is still asked for, never linked to" do
    html = render_entry()

    assert html =~ ~s(data-testid="group-call-open")
    assert html =~ ~s(phx-click="group_call_open")

    # No address anywhere in the entry: not as a way in, not as a way to a tab.
    refute html =~ ~s(href="/call/)
    refute html =~ ~s(target="_blank")
    refute html =~ ~s(data-testid="group-call-elsewhere")
  end

  test "a channel with no room asks in exactly the same way" do
    html = render_entry(active: false, summary: nil)

    assert html =~ ~s(data-testid="group-call-open")
    assert html =~ ~s(phx-click="group_call_open")
    refute html =~ ~s(href="/call/)
  end

  test "the popover reports the room without offering a way into it" do
    html = render_entry()

    assert html =~ ~s(data-testid="group-call-channel-popover")
    refute html =~ ~s(data-testid="group-call-channel-popover-tab")
    refute html =~ ~s(href="/call/)
  end

  test "an unidentified reader is refused" do
    html = render_entry(identified: false)

    assert html =~ ~s(phx-click="group_call_open")
    assert html =~ "disabled"
  end
end
