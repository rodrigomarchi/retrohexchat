defmodule RetroHexChatWeb.ChatLive.Components.UserContextMenusTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.Components.UserContextMenus

  @moduletag :unit

  defp menus(overrides) do
    base = %{
      id: UserContextMenus.id(),
      session: Session.new("alice"),
      channel_users: [],
      nick_color_fn: fn _nick -> "nick-color-0" end
    }

    render_component(UserContextMenus, Map.merge(base, overrides))
  end

  test "exposes a stable id" do
    assert UserContextMenus.id() == "user-context-menus"
  end

  test "both menus are hidden by default (closed maps)" do
    html = menus(%{})
    assert html =~ ~s(id="user-context-menus-mount")
  end

  test "renders the nicklist menu open at its position" do
    html =
      menus(%{
        context_menu: %{
          visible: true,
          x: 120,
          y: 80,
          target_nick: "bob",
          is_target_registered: false
        }
      })

    assert html =~ "context-menu-item-context_query"
    assert html =~ "bob"
  end

  test "renders the chat menu open for a nick target" do
    html =
      menus(%{
        chat_context_menu: %{
          visible: true,
          type: :nick,
          x: 10,
          y: 20,
          target_nick: "carol",
          target_url: nil,
          target_channel: nil,
          target_message: nil,
          has_selection: false,
          is_target_registered: false
        }
      })

    assert html =~ "carol"
  end

  test "derives is_target_self (own nick disables Query) from session" do
    html =
      menus(%{
        session: Session.new("bob"),
        context_menu: %{
          visible: true,
          x: 0,
          y: 0,
          target_nick: "bob",
          is_target_registered: false
        }
      })

    # targeting your own nick disables the Query (PM) item
    assert html =~ "context-menu-item-context_query"
    assert html =~ "text-disabled cursor-default"
  end

  test "shows the inline color picker swatches when enabled" do
    html =
      menus(%{
        context_menu: %{
          visible: true,
          x: 0,
          y: 0,
          target_nick: "bob",
          is_target_registered: false
        },
        show_context_color_picker: true
      })

    assert html =~ "color-swatch-0"
    assert html =~ ~s(phx-value-nick="bob")
  end

  test "set_color_from_chat copies the chat menu position into the picker" do
    {:ok, socket} = UserContextMenus.mount(%Phoenix.LiveView.Socket{})

    {:ok, socket} =
      UserContextMenus.update(
        %{chat_context_menu: %{UserContextMenus.chat_closed() | x: 42, y: 7}},
        socket
      )

    {:ok, socket} = UserContextMenus.update(%{set_color_from_chat: "dave"}, socket)

    assert socket.assigns.show_context_color_picker
    assert socket.assigns.context_menu.target_nick == "dave"
    assert socket.assigns.context_menu.x == 42
    assert socket.assigns.context_menu.y == 7
    refute socket.assigns.chat_context_menu.visible
  end
end
