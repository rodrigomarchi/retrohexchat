defmodule RetroHexChatWeb.ChatLive.Components.ConversationsContextMenuTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AutoJoinList
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
    assert html =~ ~s(phx-click-away="close_conversations_context_menu")
    assert html =~ ~s(phx-window-keydown="close_conversations_context_menu")
  end

  test "a private conversation offers Close Conversation, a channel does not" do
    pm =
      menu(%{
        visible: true,
        type: :pm,
        nick: "bob",
        session: Session.new("alice")
      })

    assert pm =~ ~s(data-testid="ctx-close-pm")
    assert pm =~ ~s(phx-value-nick="bob")
    # Leaving is for channels: a private conversation has nobody to leave.
    refute pm =~ ~s(data-testid="ctx-leave")

    channel =
      menu(%{
        visible: true,
        type: :channel,
        channel: "#lobby",
        session: Session.new("alice")
      })

    assert channel =~ ~s(data-testid="ctx-leave")
    refute channel =~ ~s(data-testid="ctx-close-pm")
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

  describe "join on connect" do
    defp channel_menu(session) do
      menu(%{visible: true, type: :channel, channel: "#elixir", session: session})
    end

    test "is offered on a channel and never on a private conversation" do
      session = Session.new("alice")

      assert channel_menu(session) =~ ~s(data-testid="ctx-toggle-autojoin")

      pm = menu(%{visible: true, type: :pm, nick: "bob", session: session})
      refute pm =~ ~s(data-testid="ctx-toggle-autojoin")
    end

    test "reads the state off the account's list, checked and unchecked" do
      off = "alice" |> Session.new() |> channel_menu()

      {:ok, list} = AutoJoinList.add_entry(AutoJoinList.new(), "#elixir")
      on = "alice" |> Session.new() |> Session.set_autojoin_list(list) |> channel_menu()

      assert [item] =
               off
               |> Floki.parse_document!()
               |> Floki.find(~s([data-testid="ctx-toggle-autojoin"]))

      assert Floki.attribute(item, "aria-checked") == ["false"]

      assert [item] =
               on
               |> Floki.parse_document!()
               |> Floki.find(~s([data-testid="ctx-toggle-autojoin"]))

      assert Floki.attribute(item, "aria-checked") == ["true"]
    end

    test "matches the channel regardless of case, the way the list itself does" do
      {:ok, list} = AutoJoinList.add_entry(AutoJoinList.new(), "#ELIXIR")
      html = "alice" |> Session.new() |> Session.set_autojoin_list(list) |> channel_menu()

      assert [item] =
               html
               |> Floki.parse_document!()
               |> Floki.find(~s([data-testid="ctx-toggle-autojoin"]))

      assert Floki.attribute(item, "aria-checked") == ["true"]
    end
  end

  # Same menu, same items, a frame a thumb can reach. The desktop keeps the
  # pointer-anchored placement it always had; the sheet is what the CSS makes
  # of it below the stacking breakpoint.
  test "opts into the bottom-sheet presentation and names what it is about" do
    html =
      menu(%{visible: true, type: :channel, channel: "#lobby", session: Session.new("alice")})

    doc = Floki.parse_document!(html)

    assert [menu_el] =
             Floki.find(doc, ~s([data-testid="context-menu-conversations-context-menu"]))

    assert Floki.attribute(menu_el, "data-sheet") == ["true"]
    assert Floki.attribute(menu_el, "class") |> to_string() =~ "context-menu--sheet"
    assert [title] = Floki.find(menu_el, ".context-menu__sheet-title")
    assert Floki.text(title) =~ "#lobby"

    # Dismissal is a target of its own: a sheet has no click-away area to aim at.
    assert [dismiss] = Floki.find(menu_el, ".context-menu__sheet-dismiss")
    assert Floki.attribute(dismiss, "phx-click") == ["close_conversations_context_menu"]
  end

  test "a private conversation's sheet is named by the nickname" do
    html = menu(%{visible: true, type: :pm, nick: "bob", session: Session.new("alice")})

    assert [title] =
             html |> Floki.parse_document!() |> Floki.find(".context-menu__sheet-title")

    assert Floki.text(title) =~ "bob"
  end
end
