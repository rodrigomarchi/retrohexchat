defmodule RetroHexChatWeb.Components.UI.Chat.ConversationToolbarActionsTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ConversationToolbarActions

  @moduletag :unit

  test "renders the three chat controls wired to their toggle events" do
    html = render_component(&conversation_toolbar_actions/1, %{})

    doc = Floki.parse_document!(html)

    for {testid, event} <- [
          {"conversation-toolbar-conversations", "toggle_conversations"},
          {"conversation-toolbar-nicklist", "toggle_nicklist"},
          {"conversation-toolbar-search", "toggle_search"}
        ] do
      assert [button] = Floki.find(doc, ~s([data-testid="#{testid}"]))
      assert Floki.attribute(button, "phx-click") == [event]
    end
  end

  test "the action cluster is shared by desktop and stacked layouts" do
    html = render_component(&conversation_toolbar_actions/1, %{})

    assert [cluster] =
             html
             |> Floki.parse_document!()
             |> Floki.find(~s([data-testid="conversation-toolbar-actions"]))

    refute cluster |> Floki.attribute("class") |> hd() =~ "md:hidden"
  end

  test "can omit sidebar toggles when the composed shell owns sidebar rails" do
    html = render_component(&conversation_toolbar_actions/1, %{show_sidebar_toggles: false})
    doc = Floki.parse_document!(html)

    assert Floki.find(doc, ~s([data-testid="conversation-toolbar-conversations"])) == []
    assert Floki.find(doc, ~s([data-testid="conversation-toolbar-nicklist"])) == []
    assert [_search] = Floki.find(doc, ~s([data-testid="conversation-toolbar-search"]))
  end

  test "visible state is reflected as pressed controls" do
    html =
      render_component(&conversation_toolbar_actions/1, %{
        conversations_open: true,
        nicklist_open: true,
        search_open: true
      })

    doc = Floki.parse_document!(html)

    for testid <- [
          "conversation-toolbar-conversations",
          "conversation-toolbar-nicklist",
          "conversation-toolbar-search"
        ] do
      assert [button] = Floki.find(doc, ~s([data-testid="#{testid}"]))
      assert Floki.attribute(button, "aria-pressed") == ["true"]
    end
  end

  test "renders Channel Central for an active channel conversation" do
    html =
      render_component(&conversation_toolbar_actions/1, %{
        active_channel: "#lobby"
      })

    doc = Floki.parse_document!(html)

    assert [button] = Floki.find(doc, ~s([data-testid="conversation-toolbar-channel-central"]))
    assert Floki.attribute(button, "phx-click") == ["open_channel_central"]
    assert Floki.find(doc, ~s([data-testid="conversation-toolbar-user-lookup"])) == []
  end

  test "renders User Lookup for an active PM conversation" do
    html =
      render_component(&conversation_toolbar_actions/1, %{
        active_channel: "#lobby",
        active_pm: "Alice"
      })

    doc = Floki.parse_document!(html)

    assert [button] = Floki.find(doc, ~s([data-testid="conversation-toolbar-user-lookup"]))
    assert Floki.attribute(button, "phx-click") == ["open_user_lookup"]
    assert Floki.attribute(button, "phx-value-nickname") == ["Alice"]
    assert Floki.find(doc, ~s([data-testid="conversation-toolbar-channel-central"])) == []
  end

  test "does not render context dialogs on the status tab" do
    html =
      render_component(&conversation_toolbar_actions/1, %{
        active_channel: "#lobby",
        show_status_tab: true
      })

    doc = Floki.parse_document!(html)

    assert Floki.find(doc, ~s([data-testid="conversation-toolbar-channel-central"])) == []
    assert Floki.find(doc, ~s([data-testid="conversation-toolbar-user-lookup"])) == []
  end
end
