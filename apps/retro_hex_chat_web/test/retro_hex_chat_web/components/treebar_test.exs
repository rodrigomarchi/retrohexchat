defmodule RetroHexChatWeb.Components.TreebarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.Treebar

  describe "treebar/1" do
    test "renders all channels" do
      html =
        render_component(&Treebar.treebar/1,
          channels: ["#lobby", "#general"],
          active_channel: nil,
          unread_channels: [],
          pm_conversations: [],
          active_pm: nil
        )

      assert html =~ "#lobby"
      assert html =~ "#general"
    end

    test "marks active channel with tree-active class" do
      html =
        render_component(&Treebar.treebar/1,
          channels: ["#lobby", "#general"],
          active_channel: "#lobby",
          unread_channels: [],
          pm_conversations: [],
          active_pm: nil
        )

      assert html =~ "tree-active"
    end

    test "marks unread channel with tree-unread class" do
      html =
        render_component(&Treebar.treebar/1,
          channels: ["#lobby", "#general"],
          active_channel: nil,
          unread_channels: ["#general"],
          pm_conversations: [],
          active_pm: nil
        )

      assert html =~ "tree-unread"
    end

    test "renders PM conversations in Private section" do
      html =
        render_component(&Treebar.treebar/1,
          channels: [],
          active_channel: nil,
          unread_channels: [],
          pm_conversations: ["bob", "carol"],
          active_pm: nil
        )

      assert html =~ "Private"
      assert html =~ "bob"
      assert html =~ "carol"
    end

    test "marks active PM with tree-active class" do
      html =
        render_component(&Treebar.treebar/1,
          channels: [],
          active_channel: nil,
          unread_channels: [],
          pm_conversations: ["bob"],
          active_pm: "bob"
        )

      assert html =~ "tree-active"
    end
  end
end
