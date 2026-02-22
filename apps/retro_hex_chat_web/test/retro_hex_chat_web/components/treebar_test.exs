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
      active_pm: nil,
      channel_users: [],
      nick_color_fn: nil
    ]

    render_component(&Treebar.treebar/1, Keyword.merge(defaults, overrides))
  end

  describe "treebar header" do
    @tag :unit
    test "renders treebar header with title" do
      html = render_treebar(channels: ["#lobby"])
      assert html =~ "sidebar-tab-bar"
      assert html =~ "Conversations"
    end

    @tag :unit
    test "header has close button with toggle_treebar event" do
      html = render_treebar(channels: ["#lobby"])
      assert html =~ "tab-close"
      assert html =~ "phx-click=\"toggle_treebar\""
    end

    @tag :unit
    test "renders header even when no channels" do
      html = render_treebar([])
      assert html =~ "sidebar-tab-bar"
      assert html =~ "Conversations"
    end
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

  # ── Inline user list ──────────────────────────────────────

  describe "treebar/1 inline user list" do
    @tag :unit
    test "renders users under active channel with role icons" do
      users = [
        %{nickname: "alice", role: :operator, away: false},
        %{nickname: "bob", role: :regular, away: false}
      ]

      html =
        render_treebar(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: users
        )

      assert html =~ "treebar-users"
      assert html =~ "alice"
      assert html =~ "bob"
      assert html =~ "nick-icon"
    end

    @tag :unit
    test "renders user count next to active channel" do
      users = [
        %{nickname: "alice", role: :regular, away: false},
        %{nickname: "bob", role: :regular, away: false}
      ]

      html =
        render_treebar(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: users
        )

      assert html =~ "treebar-user-count"
      assert html =~ "(2)"
    end

    @tag :unit
    test "does not render users under non-active channels" do
      users = [%{nickname: "alice", role: :regular, away: false}]

      html =
        render_treebar(
          channels: ["#lobby", "#general"],
          active_channel: "#lobby",
          channel_users: users
        )

      # Users only under #lobby (active), not #general
      assert html =~ "treebar-users"

      # Verify no user data-nick on non-active channel items
      assert html =~ ~s(data-nick="alice")
    end

    @tag :unit
    test "applies role CSS classes" do
      users = [
        %{nickname: "alpha", role: :owner, away: false},
        %{nickname: "bravo", role: :operator, away: false},
        %{nickname: "charlie", role: :half_operator, away: false},
        %{nickname: "delta", role: :voiced, away: false},
        %{nickname: "echo", role: :regular, away: false}
      ]

      html =
        render_treebar(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: users
        )

      assert html =~ "nick-owner"
      assert html =~ "nick-operator"
      assert html =~ "nick-halfop"
      assert html =~ "nick-voiced"
      assert html =~ "nick-regular"
    end

    @tag :unit
    test "applies nick-away class for away users" do
      users = [
        %{nickname: "alice", role: :regular, away: true},
        %{nickname: "bob", role: :regular, away: false}
      ]

      html =
        render_treebar(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: users
        )

      assert html =~ "nick-away"
    end

    @tag :unit
    test "sorts users by role priority then alphabetically" do
      users = [
        %{nickname: "zach", role: :regular, away: false},
        %{nickname: "alice", role: :operator, away: false},
        %{nickname: "bob", role: :owner, away: false},
        %{nickname: "carol", role: :regular, away: false}
      ]

      html =
        render_treebar(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: users
        )

      # bob (owner) < alice (operator) < carol (regular) < zach (regular)
      bob_pos = :binary.match(html, "bob") |> elem(0)
      alice_pos = :binary.match(html, "alice") |> elem(0)
      carol_pos = :binary.match(html, "carol") |> elem(0)
      zach_pos = :binary.match(html, "zach") |> elem(0)

      assert bob_pos < alice_pos
      assert alice_pos < carol_pos
      assert carol_pos < zach_pos
    end

    @tag :unit
    test "applies nick_color_fn inline style" do
      users = [%{nickname: "alice", role: :regular, away: false}]
      color_fn = fn _nick -> "#ff0000" end

      html =
        render_treebar(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: users,
          nick_color_fn: color_fn
        )

      assert html =~ "color: #ff0000;"
    end

    @tag :unit
    test "nick items have phx-click for context menu" do
      users = [%{nickname: "alice", role: :regular, away: false}]

      html =
        render_treebar(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: users
        )

      assert html =~ ~s(phx-click="nick_right_click")
      assert html =~ ~s(phx-value-nick="alice")
    end

    @tag :unit
    test "nick items have data-nick for double-click detection" do
      users = [%{nickname: "alice", role: :regular, away: false}]

      html =
        render_treebar(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: users
        )

      assert html =~ ~s(data-nick="alice")
    end

    @tag :unit
    test "no users rendered when channel_users is empty" do
      html =
        render_treebar(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: []
        )

      refute html =~ "treebar-users"
      refute html =~ "treebar-user-count"
    end

    @tag :unit
    test "active channel appears first in list" do
      html =
        render_treebar(
          channels: ["#alpha", "#beta", "#gamma"],
          active_channel: "#gamma",
          channel_users: [%{nickname: "alice", role: :regular, away: false}]
        )

      # #gamma (active) should appear before #alpha and #beta
      gamma_pos = :binary.match(html, "#gamma") |> elem(0)
      alpha_pos = :binary.match(html, "#alpha") |> elem(0)
      beta_pos = :binary.match(html, "#beta") |> elem(0)

      assert gamma_pos < alpha_pos
      assert gamma_pos < beta_pos
    end
  end
end
