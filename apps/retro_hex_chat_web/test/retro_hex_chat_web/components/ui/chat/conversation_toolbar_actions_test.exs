defmodule RetroHexChatWeb.Components.UI.Chat.ConversationToolbarActionsTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ConversationToolbarActions

  @moduletag :unit

  test "renders the sidebar toggles wired to their events" do
    html = render_component(&conversation_toolbar_actions/1, %{})

    doc = Floki.parse_document!(html)

    for {testid, event} <- [
          {"conversation-toolbar-conversations", "toggle_conversations"},
          {"conversation-toolbar-nicklist", "toggle_nicklist"}
        ] do
      assert [button] = Floki.find(doc, ~s([data-testid="#{testid}"]))
      assert Floki.attribute(button, "phx-click") == [event]
    end
  end

  test "every control carries its label in the open, not just in a tooltip" do
    html =
      render_component(&conversation_toolbar_actions/1, %{active_channel: "#lobby"})

    doc = Floki.parse_document!(html)

    for {testid, text} <- [
          {"conversation-toolbar-conversations", "Conversations"},
          {"conversation-toolbar-nicklist", "Users"},
          {"conversation-toolbar-channel-central", "Channel Central"}
        ] do
      assert [button] = Floki.find(doc, ~s([data-testid="#{testid}"]))
      assert Floki.text(button) =~ text
      # The visible text is the accessible name; the tooltip carries the longer
      # description, so no aria-label competes with it.
      assert Floki.attribute(button, "aria-label") == []
      assert Floki.attribute(button, "title") != []
    end
  end

  test "a PM shows the user-lookup label" do
    html = render_component(&conversation_toolbar_actions/1, %{active_pm: "bob"})

    assert [button] =
             html
             |> Floki.parse_document!()
             |> Floki.find(~s([data-testid="conversation-toolbar-user-lookup"]))

    assert Floki.text(button) =~ "User Lookup"
  end

  test "the action cluster is shared by desktop and stacked layouts" do
    html = render_component(&conversation_toolbar_actions/1, %{})

    assert [cluster] =
             html
             |> Floki.parse_document!()
             |> Floki.find(~s([data-testid="conversation-toolbar-actions"]))

    refute cluster |> Floki.attribute("class") |> hd() =~ "md:hidden"
  end

  test "the sidebar toggles are one cluster a layout can scope to its widths" do
    html =
      render_component(&conversation_toolbar_actions/1, %{sidebar_toggles_class: "md:hidden"})

    doc = Floki.parse_document!(html)

    assert [cluster] =
             Floki.find(doc, ~s([data-testid="conversation-toolbar-sidebar-toggles"]))

    assert cluster |> Floki.attribute("class") |> hd() =~ "md:hidden"

    for testid <- ["conversation-toolbar-conversations", "conversation-toolbar-nicklist"] do
      assert [_button] = Floki.find(cluster, ~s([data-testid="#{testid}"]))
    end

    # Search stays outside the cluster — it is not a sidebar.
    # Find lives in the menu bar, not here.
    assert Floki.find(doc, ~s([data-testid="conversation-toolbar-search"])) == []
  end

  test "can omit sidebar toggles when the composed shell owns sidebar rails" do
    html = render_component(&conversation_toolbar_actions/1, %{show_sidebar_toggles: false})
    doc = Floki.parse_document!(html)

    assert Floki.find(doc, ~s([data-testid="conversation-toolbar-conversations"])) == []
    assert Floki.find(doc, ~s([data-testid="conversation-toolbar-nicklist"])) == []
  end

  test "visible state is reflected as pressed controls" do
    html =
      render_component(&conversation_toolbar_actions/1, %{
        conversations_open: true,
        nicklist_open: true
      })

    doc = Floki.parse_document!(html)

    for testid <- [
          "conversation-toolbar-conversations",
          "conversation-toolbar-nicklist"
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

  # A desktop keeps a 36px rail that carries this count; below the stacking
  # breakpoint the rail is not rendered at all, and this button is the only
  # thing left that can say another conversation is waiting.
  test "the conversations toggle carries the unread total a phone has no rail for" do
    html =
      render_component(&conversation_toolbar_actions/1, %{
        active_channel: "#lobby",
        conversations_unread: 7
      })

    doc = Floki.parse_document!(html)

    assert [badge] =
             Floki.find(doc, ~s([data-testid="conversation-toolbar-conversations-badge"]))

    assert Floki.text(badge) =~ "7"

    # The count says itself in the tooltip too: where the visible label is
    # hidden by CSS, the title is what a screen reader reads.
    assert [button] = Floki.find(doc, ~s([data-testid="conversation-toolbar-conversations"]))
    assert Floki.attribute(button, "title") |> to_string() =~ "7"
  end

  test "no badge when nothing is waiting" do
    html = render_component(&conversation_toolbar_actions/1, %{active_channel: "#lobby"})

    assert html
           |> Floki.parse_document!()
           |> Floki.find(~s([data-testid="conversation-toolbar-conversations-badge"])) == []
  end
end
