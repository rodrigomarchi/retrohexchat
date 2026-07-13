defmodule RetroHexChatWeb.Components.UI.Chat.IrcTabsTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.IrcTabs

  @moduletag :unit

  test "renders a P2P glyph for low-level PM tab callers without an explicit state" do
    html =
      render_component(&irc_tab_item/1,
        type: "pm",
        label: "Troll",
        p2p: true,
        closeable: false
      )

    assert html =~ ~s(data-testid="tab-p2p-glyph")
    assert html =~ ~s(data-p2p-state="connected")
    assert html =~ ~s(data-p2p-status="ready")
  end
end
