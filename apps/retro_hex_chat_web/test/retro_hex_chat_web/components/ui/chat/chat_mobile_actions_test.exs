defmodule RetroHexChatWeb.Components.UI.Chat.ChatMobileActionsTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ChatMobileActions

  @moduletag :unit

  test "renders the three chat controls wired to their toggle events" do
    html = render_component(&chat_mobile_actions/1, %{})

    doc = Floki.parse_document!(html)

    for {testid, event} <- [
          {"chat-mobile-conversations", "toggle_conversations"},
          {"chat-mobile-nicklist", "toggle_nicklist"},
          {"chat-mobile-search", "toggle_search"}
        ] do
      assert [button] = Floki.find(doc, ~s([data-testid="#{testid}"]))
      assert Floki.attribute(button, "phx-click") == [event]
    end
  end

  test "the cluster is hidden on desktop breakpoints" do
    html = render_component(&chat_mobile_actions/1, %{})

    assert [cluster] =
             html
             |> Floki.parse_document!()
             |> Floki.find(~s([data-testid="chat-mobile-actions"]))

    assert cluster |> Floki.attribute("class") |> hd() =~ "md:hidden"
  end
end
