defmodule RetroHexChatWeb.Components.UI.ChannelListRowsTest do
  @moduledoc """
  How the channel window draws a room nobody is in.

  The catalogue now carries registered channels that have no process, so a row
  can legitimately have zero people in it. Such a row must say when the room
  last had something happen instead of implying it is simply empty and dead.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ChannelList

  @moduletag :unit

  defp row(overrides) do
    Map.merge(
      %{
        name: "#lobby",
        topic: "Everyone starts here",
        user_count: 12,
        joined?: false,
        invite_only?: false,
        modes: "",
        live?: true,
        last_activity_at: nil
      },
      Map.new(overrides)
    )
  end

  defp render_list(channels) do
    render_component(&channel_list_panel/1, id: "channel-list", channels: channels)
  end

  test "a live row says how many people are in it and nothing about activity" do
    html = render_list([row([])])

    assert html =~ ~s(data-testid="channel-list-row-#lobby")
    assert html =~ "12"
    refute html =~ ~s(data-testid="channel-list-activity-#lobby")
  end

  test "an empty room says when it was last used" do
    cold =
      row(
        name: "#retro",
        live?: false,
        user_count: 0,
        last_activity_at: DateTime.add(DateTime.utc_now(), -3, :day)
      )

    html = render_list([cold])

    assert html =~ ~s(data-testid="channel-list-row-#retro")
    assert html =~ ~s(data-testid="channel-list-activity-#retro")
  end

  # Whether a process happens to be holding the channel open is not the
  # reader's question, and a registered channel keeps its process after the
  # last person leaves — so a live row with nobody in it is the common case.
  test "a running room with nobody in it says it too" do
    empty =
      row(
        name: "#quiet",
        live?: true,
        user_count: 0,
        last_activity_at: DateTime.add(DateTime.utc_now(), -2, :day)
      )

    html = render_list([empty])

    assert html =~ ~s(data-testid="channel-list-activity-#quiet")
  end

  test "an empty room with no recorded activity says nothing rather than guessing" do
    cold = row(name: "#void", live?: false, user_count: 0, last_activity_at: nil)

    html = render_list([cold])

    refute html =~ ~s(data-testid="channel-list-activity-#void")
  end
end
