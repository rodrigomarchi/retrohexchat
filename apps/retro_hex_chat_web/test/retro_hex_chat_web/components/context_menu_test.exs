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

  describe "P2P context menu items" do
    @tag :unit
    test "renders P2P items when viewer_is_identified is true and target is registered" do
      html =
        render_component(&ContextMenu.context_menu/1,
          visible: true,
          target_nick: "alice",
          viewer_is_identified: true,
          is_target_registered: true,
          is_target_self: false,
          viewer_is_op: false,
          x: 100,
          y: 200
        )

      assert html =~ ~s(data-testid="context-p2p")
      assert html =~ ~s(data-testid="context-call")
      assert html =~ ~s(data-testid="context-video-call")
      assert html =~ ~s(data-testid="context-sendfile")
      assert html =~ "P2P Session"
      assert html =~ "Audio Call"
      assert html =~ "Video Call"
      assert html =~ "Send File"
      # Items should be enabled (have phx-click)
      assert html =~ ~s(phx-click="context_p2p")
      assert html =~ ~s(phx-click="context_call")
      assert html =~ ~s(phx-click="context_video_call")
      assert html =~ ~s(phx-click="context_sendfile")
    end

    @tag :unit
    test "does not render P2P items for guest user (viewer_is_identified false)" do
      html =
        render_component(&ContextMenu.context_menu/1,
          visible: true,
          target_nick: "alice",
          viewer_is_identified: false,
          is_target_registered: true,
          is_target_self: false,
          viewer_is_op: false,
          x: 100,
          y: 200
        )

      refute html =~ ~s(data-testid="context-p2p")
      refute html =~ ~s(data-testid="context-call")
      refute html =~ "P2P Session"
    end

    @tag :unit
    test "P2P items disabled with tooltip when target is not registered" do
      html =
        render_component(&ContextMenu.context_menu/1,
          visible: true,
          target_nick: "guest_user",
          viewer_is_identified: true,
          is_target_registered: false,
          is_target_self: false,
          viewer_is_op: false,
          x: 100,
          y: 200
        )

      assert html =~ ~s(data-testid="context-p2p")
      # Items should be disabled (class="disabled")
      assert html =~ ~r/disabled[^>]*context-p2p/
      # Should have tooltip
      assert html =~ "User not registered"
      # Should NOT have phx-click
      refute html =~ ~s(phx-click="context_p2p")
    end

    @tag :unit
    test "P2P items disabled without tooltip when target is self" do
      html =
        render_component(&ContextMenu.context_menu/1,
          visible: true,
          target_nick: "myself",
          viewer_is_identified: true,
          is_target_registered: true,
          is_target_self: true,
          viewer_is_op: false,
          x: 100,
          y: 200
        )

      assert html =~ ~s(data-testid="context-p2p")
      # Items should be disabled
      assert html =~ ~r/disabled[^>]*context-p2p/
      # Should NOT have tooltip (self-targeting)
      refute html =~ "User not registered"
      # Should NOT have phx-click
      refute html =~ ~s(phx-click="context_p2p")
    end
  end
end
