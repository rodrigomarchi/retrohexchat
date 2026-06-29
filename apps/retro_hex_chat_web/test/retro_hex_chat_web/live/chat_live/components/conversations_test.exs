defmodule RetroHexChatWeb.ChatLive.Components.ConversationsTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.Conversations

  @moduletag :unit

  defp render_conv(extra) do
    render_component(
      Conversations,
      Keyword.merge(
        [
          id: Conversations.id(),
          visible: true,
          channels: ["#lobby", "#elixir"],
          active_channel: "#lobby"
        ],
        extra
      )
    )
  end

  test "id/0 is stable" do
    assert Conversations.id() == "conversations"
  end

  test "renders the joined channels" do
    html = render_conv([])
    assert html =~ "#lobby"
    assert html =~ "#elixir"
    # Row events bubble to the parent unchanged.
    assert html =~ "switch_channel"
  end

  test "is hidden when not visible and shown when visible" do
    assert render_conv(visible: false) =~ "md:min-w-[180px] hidden"
    refute render_conv(visible: true) =~ "md:min-w-[180px] hidden"
  end

  test "derives unread channels and PMs from unread_counts" do
    html =
      render_conv(
        unread_counts: %{"#elixir" => 3, "pm:alice" => 2, "#lobby" => 0},
        pm_conversations: ["alice"]
      )

    # #elixir has unread (3) → its unread badge count shows; #lobby (0) does not.
    assert html =~ "alice"
    assert html =~ "3"
  end
end
