defmodule RetroHexChatWeb.Components.TreebarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.Treebar

  # Default assigns helper — all new attrs have sensible defaults
  defp render_treebar(overrides) do
    defaults = [
      channels: [],
      active_channel: nil,
      unread_counts: %{},
      highlight_channels: [],
      flash_channels: [],
      muted_channels: [],
      disconnected_channels: [],
      pm_conversations: [],
      active_pm: nil
    ]

    render_component(&Treebar.treebar/1, Keyword.merge(defaults, overrides))
  end

  describe "treebar/1" do
    test "renders all channels" do
      html = render_treebar(channels: ["#lobby", "#general"])
      assert html =~ "#lobby"
      assert html =~ "#general"
    end

    test "marks active channel with tree-active class" do
      html = render_treebar(channels: ["#lobby", "#general"], active_channel: "#lobby")
      assert html =~ "tree-active"
    end

    test "marks unread channel with tree-unread class" do
      html =
        render_treebar(channels: ["#lobby", "#general"], unread_counts: %{"#general" => 3})

      assert html =~ "tree-unread"
    end

    test "renders PM conversations in Private section" do
      html = render_treebar(pm_conversations: ["bob", "carol"])
      assert html =~ "Private"
      assert html =~ "bob"
      assert html =~ "carol"
    end

    test "marks active PM with tree-active class" do
      html = render_treebar(pm_conversations: ["bob"], active_pm: "bob")
      assert html =~ "tree-active"
    end
  end

  describe "treebar/1 highlight_channels" do
    @tag :unit
    test "applies tree-highlight class to highlighted channel" do
      html =
        render_treebar(
          channels: ["#lobby", "#general"],
          active_channel: "#lobby",
          highlight_channels: ["#general"]
        )

      assert html =~ "tree-highlight"
    end

    @tag :unit
    test "does not apply tree-highlight to non-highlighted channels" do
      html = render_treebar(channels: ["#lobby"], active_channel: "#lobby")
      refute html =~ "tree-highlight"
    end

    @tag :unit
    test "highlight and unread can coexist on same channel" do
      html =
        render_treebar(
          channels: ["#lobby", "#general"],
          active_channel: "#lobby",
          unread_counts: %{"#general" => 5},
          highlight_channels: ["#general"]
        )

      assert html =~ "tree-highlight"
      assert html =~ "tree-unread"
    end
  end

  describe "treebar/1 unread badges" do
    @tag :unit
    test "renders numeric badge with count" do
      html = render_treebar(channels: ["#general"], unread_counts: %{"#general" => 3})
      assert html =~ "treebar-badge"
      assert html =~ "3"
    end

    @tag :unit
    test "renders 99+ for count above 99" do
      html = render_treebar(channels: ["#general"], unread_counts: %{"#general" => 150})
      assert html =~ "99+"
    end

    @tag :unit
    test "does not render badge when count is 0" do
      html = render_treebar(channels: ["#general"], unread_counts: %{})
      refute html =~ "treebar-badge"
    end

    @tag :unit
    test "renders highlight badge class for mentioned channel" do
      html =
        render_treebar(
          channels: ["#general"],
          unread_counts: %{"#general" => 2},
          highlight_channels: ["#general"]
        )

      assert html =~ "treebar-badge--highlight"
    end

    @tag :unit
    test "renders PM badge with pm: key prefix" do
      html =
        render_treebar(
          pm_conversations: ["bob"],
          unread_counts: %{"pm:bob" => 4}
        )

      assert html =~ "treebar-badge"
      assert html =~ "4"
    end
  end

  describe "treebar/1 muted state" do
    @tag :unit
    test "applies tree-muted class to muted channel" do
      html =
        render_treebar(
          channels: ["#general"],
          muted_channels: ["#general"]
        )

      assert html =~ "tree-muted"
    end

    @tag :unit
    test "suppresses badges for muted channels (badge hidden via CSS)" do
      html =
        render_treebar(
          channels: ["#general"],
          unread_counts: %{"#general" => 5},
          muted_channels: ["#general"]
        )

      # Muted class applied — CSS hides .tree-muted .treebar-badge
      assert html =~ "tree-muted"
    end
  end

  describe "treebar/1 disconnected state" do
    @tag :unit
    test "applies tree-disconnected class and shows lightning icon" do
      html =
        render_treebar(
          channels: ["#general"],
          disconnected_channels: ["#general"]
        )

      assert html =~ "tree-disconnected"
      assert html =~ "⚡"
    end
  end
end
