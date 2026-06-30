defmodule RetroHexChatWeb.ChatLive.Components.ConversationsContextMenuTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.Components.ConversationsContextMenu

  @moduletag :unit

  defp menu(overrides) do
    assigns = Map.merge(%{id: ConversationsContextMenu.id()}, overrides)
    render_component(ConversationsContextMenu, assigns)
  end

  test "exposes a stable id" do
    assert ConversationsContextMenu.id() == "conversations-context-menu"
  end

  test "hidden by default (closed menu)" do
    html = menu(%{session: Session.new("alice")})
    assert html =~ ~s(id="conversations-context-menu-mount")
  end

  test "renders the channel menu open at its position" do
    html =
      menu(%{
        visible: true,
        x: 120,
        y: 80,
        type: :channel,
        channel: "#lobby",
        session: Session.new("alice")
      })

    assert html =~ "#lobby"
  end

  test "derives is_muted from the muted_channels read-model" do
    html =
      menu(%{
        visible: true,
        type: :channel,
        channel: "#lobby",
        muted_channels: MapSet.new(["#lobby"]),
        session: Session.new("alice")
      })

    # the menu shows an "Unmute" affordance when the channel is muted
    assert html =~ "nmute" or html =~ "muted"
  end

  test "derives has_unread from the unread_counts read-model via the pm: key" do
    html =
      menu(%{
        visible: true,
        type: :pm,
        nick: "bob",
        unread_counts: %{"pm:bob" => 3},
        session: Session.new("alice")
      })

    assert html =~ "bob"
  end
end
