defmodule RetroHexChatWeb.ChatLive.Components.ChannelListDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.ChannelListDialog

  @moduletag :unit

  @channels [
    %{name: "#elixir", user_count: 42, topic: "Elixir talk", invite_only?: false, joined?: false},
    %{name: "#secret", user_count: 3, topic: "Members only", invite_only?: true, joined?: false}
  ]

  test "id/0 is stable" do
    assert ChannelListDialog.id() == "channel-list-dialog"
  end

  test "renders the bare panel by default" do
    html = render_component(ChannelListDialog, id: ChannelListDialog.id())

    assert html =~ ~s(data-testid="channel-list-panel")
    refute html =~ "phx-show-modal"
  end

  test "renders the supplied channels and bubbling event names" do
    html =
      render_component(ChannelListDialog,
        id: ChannelListDialog.id(),
        channels: @channels
      )

    assert html =~ "#elixir"
    assert html =~ "#secret"
    # The filter/select events bubble to the parent as string events.
    assert html =~ "channel_list_filter"
    assert html =~ "channel_list_select"
  end
end
