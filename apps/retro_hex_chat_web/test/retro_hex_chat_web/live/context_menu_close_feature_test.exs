defmodule RetroHexChatWeb.ContextMenuCloseFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  test "global click-away event closes nicklist and chat context menus", %{conn: conn} do
    view = connect_user(conn, "MenuClose#{uid()}")

    render_click(view, "nick_right_click", %{"nick" => "Target", "x" => 100, "y" => 120})
    assert render(view) =~ "context-menu-item-context_query"

    render_click(view, "close_all_context_menus", %{})
    refute render(view) =~ "context-menu-item-context_query"

    render_click(view, "chat_context_menu", %{
      "type" => "nick",
      "nick" => "Target",
      "x" => 140,
      "y" => 160,
      "author" => "Target",
      "message_id" => "msg-1",
      "message_text" => "hello",
      "message_urls" => [],
      "has_selection" => false,
      "is_system" => false
    })

    assert render(view) =~ "context-menu-item-ctx_chat_pm"

    render_click(view, "close_all_context_menus", %{})
    refute render(view) =~ "context-menu-item-ctx_chat_pm"
  end

  test "opening one user context menu closes the other user context menu", %{conn: conn} do
    view = connect_user(conn, "MenuSwap#{uid()}")

    render_click(view, "chat_context_menu", %{
      "type" => "nick",
      "nick" => "Target",
      "x" => 140,
      "y" => 160,
      "author" => "Target",
      "message_id" => "msg-1",
      "message_text" => "hello",
      "message_urls" => [],
      "has_selection" => false,
      "is_system" => false
    })

    assert render(view) =~ "context-menu-item-ctx_chat_pm"

    render_click(view, "nick_right_click", %{"nick" => "Target", "x" => 100, "y" => 120})
    html = render(view)
    assert html =~ "context-menu-item-context_query"
    refute html =~ "context-menu-item-ctx_chat_pm"
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end
end
