defmodule RetroHexChatWeb.Components.ContextMenuTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.ContextMenu

  describe "context_menu/1" do
    test "does not render when visible is false" do
      html =
        render_component(&ContextMenu.context_menu/1,
          visible: false,
          target_nick: "alice",
          viewer_is_op: false,
          x: 0,
          y: 0
        )

      refute html =~ "context-menu"
    end

    test "shows Query and Whois for all users" do
      html =
        render_component(&ContextMenu.context_menu/1,
          visible: true,
          target_nick: "alice",
          viewer_is_op: false,
          x: 100,
          y: 200
        )

      assert html =~ "Query (PM)"
      assert html =~ "Whois"
    end

    test "shows op actions when viewer_is_op is true" do
      html =
        render_component(&ContextMenu.context_menu/1,
          visible: true,
          target_nick: "alice",
          viewer_is_op: true,
          x: 100,
          y: 200
        )

      assert html =~ "Kick"
      assert html =~ "Ban"
      assert html =~ "Give Op"
      assert html =~ "Give Voice"
    end

    test "hides op actions when viewer_is_op is false" do
      html =
        render_component(&ContextMenu.context_menu/1,
          visible: true,
          target_nick: "alice",
          viewer_is_op: false,
          x: 100,
          y: 200
        )

      refute html =~ "Kick"
      refute html =~ "Ban"
    end

    test "sets phx-value-nick to target_nick" do
      html =
        render_component(&ContextMenu.context_menu/1,
          visible: true,
          target_nick: "alice",
          viewer_is_op: false,
          x: 100,
          y: 200
        )

      assert html =~ ~s(phx-value-nick="alice")
    end
  end
end
