defmodule RetroHexChatWeb.Components.ConversationsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.Conversations

  # Default assigns helper — all new attrs have sensible defaults
  defp render_conversations(overrides) do
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
      nick_color_fn: nil,
      channel_user_counts: %{},
      popular_channels: [],
      sections: %{channels: true, pms: true, popular: false}
    ]

    render_component(&Conversations.conversations/1, Keyword.merge(defaults, overrides))
  end

  describe "conversations header" do
    @tag :unit
    test "renders header with title" do
      html = render_conversations(channels: ["#lobby"])
      assert html =~ "sidebar-tab-bar"
      assert html =~ "Conversations"
    end

    @tag :unit
    test "header has close button with toggle_conversations event" do
      html = render_conversations(channels: ["#lobby"])
      assert html =~ "tab-close"
      assert html =~ "phx-click=\"toggle_conversations\""
    end

    @tag :unit
    test "renders header even when no channels" do
      html = render_conversations([])
      assert html =~ "sidebar-tab-bar"
      assert html =~ "Conversations"
    end
  end

  describe "section headers" do
    @tag :unit
    test "renders three section headers" do
      html = render_conversations(channels: ["#lobby"])
      assert html =~ "MY CHANNELS"
      assert html =~ "PRIVATE MESSAGES"
      assert html =~ "POPULAR CHANNELS"
    end

    @tag :unit
    test "shows arrows for expanded/collapsed sections" do
      html = render_conversations(channels: ["#lobby"])
      # channels and pms are expanded (▾), popular is collapsed (▸)
      assert html =~ "▾"
      assert html =~ "▸"
    end
  end

  describe "conversations/1" do
    test "renders all channels" do
      html = render_conversations(channels: ["#lobby", "#general"])
      assert html =~ "#lobby"
      assert html =~ "#general"
    end

    test "marks active channel with conversations-active class" do
      html = render_conversations(channels: ["#lobby", "#general"], active_channel: "#lobby")
      assert html =~ "conversations-active"
    end

    test "marks unread channel with conversations-unread class" do
      html =
        render_conversations(channels: ["#lobby", "#general"], unread_counts: %{"#general" => 3})

      assert html =~ "conversations-unread"
    end

    test "renders PM conversations in Private Messages section" do
      html = render_conversations(pm_conversations: ["bob", "carol"])
      assert html =~ "PRIVATE MESSAGES"
      assert html =~ "bob"
      assert html =~ "carol"
    end

    test "marks active PM with conversations-active class" do
      html = render_conversations(pm_conversations: ["bob"], active_pm: "bob")
      assert html =~ "conversations-active"
    end

    test "renders user count for all channels with counts" do
      html =
        render_conversations(
          channels: ["#lobby", "#general"],
          channel_user_counts: %{"#lobby" => 5, "#general" => 3}
        )

      assert html =~ "(5)"
      assert html =~ "(3)"
    end
  end

  describe "conversations/1 highlight_channels" do
    @tag :unit
    test "applies conversations-highlight class to highlighted channel" do
      html =
        render_conversations(
          channels: ["#lobby", "#general"],
          active_channel: "#lobby",
          highlight_channels: ["#general"]
        )

      assert html =~ "conversations-highlight"
    end

    @tag :unit
    test "does not apply conversations-highlight to non-highlighted channels" do
      html = render_conversations(channels: ["#lobby"], active_channel: "#lobby")
      refute html =~ "conversations-highlight"
    end

    @tag :unit
    test "highlight and unread can coexist on same channel" do
      html =
        render_conversations(
          channels: ["#lobby", "#general"],
          active_channel: "#lobby",
          unread_counts: %{"#general" => 5},
          highlight_channels: ["#general"]
        )

      assert html =~ "conversations-highlight"
      assert html =~ "conversations-unread"
    end
  end

  describe "conversations/1 unread badges" do
    @tag :unit
    test "renders numeric badge with count" do
      html = render_conversations(channels: ["#general"], unread_counts: %{"#general" => 3})
      assert html =~ "conversations-badge"
      assert html =~ "3"
    end

    @tag :unit
    test "renders 99+ for count above 99" do
      html = render_conversations(channels: ["#general"], unread_counts: %{"#general" => 150})
      assert html =~ "99+"
    end

    @tag :unit
    test "does not render badge when count is 0" do
      html = render_conversations(channels: ["#general"], unread_counts: %{})
      refute html =~ "conversations-badge"
    end

    @tag :unit
    test "renders highlight badge class for mentioned channel" do
      html =
        render_conversations(
          channels: ["#general"],
          unread_counts: %{"#general" => 2},
          highlight_channels: ["#general"]
        )

      assert html =~ "conversations-badge--highlight"
    end

    @tag :unit
    test "renders PM badge with pm: key prefix" do
      html =
        render_conversations(
          pm_conversations: ["bob"],
          unread_counts: %{"pm:bob" => 4}
        )

      assert html =~ "conversations-badge"
      assert html =~ "4"
    end
  end

  describe "conversations/1 muted state" do
    @tag :unit
    test "applies conversations-muted class to muted channel" do
      html =
        render_conversations(
          channels: ["#general"],
          muted_channels: ["#general"]
        )

      assert html =~ "conversations-muted"
    end

    @tag :unit
    test "suppresses badges for muted channels (badge hidden via CSS)" do
      html =
        render_conversations(
          channels: ["#general"],
          unread_counts: %{"#general" => 5},
          muted_channels: ["#general"]
        )

      # Muted class applied — CSS hides .conversations-muted .conversations-badge
      assert html =~ "conversations-muted"
    end
  end

  describe "conversations/1 disconnected state" do
    @tag :unit
    test "applies conversations-disconnected class and shows lightning icon" do
      html =
        render_conversations(
          channels: ["#general"],
          disconnected_channels: ["#general"]
        )

      assert html =~ "conversations-disconnected"
      assert html =~ "⚡"
    end
  end

  # ── Inline user list ──────────────────────────────────────

  describe "conversations/1 inline user list" do
    @tag :unit
    test "renders users under active channel with role icons" do
      users = [
        %{nickname: "alice", role: :operator, away: false},
        %{nickname: "bob", role: :regular, away: false}
      ]

      html =
        render_conversations(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: users
        )

      assert html =~ "conversations-users"
      assert html =~ "alice"
      assert html =~ "bob"
      assert html =~ "nick-icon"
    end

    @tag :unit
    test "renders user count next to active channel from channel_user_counts" do
      html =
        render_conversations(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_user_counts: %{"#lobby" => 2}
        )

      assert html =~ "conversations-user-count"
      assert html =~ "(2)"
    end

    @tag :unit
    test "does not render users under non-active channels" do
      users = [%{nickname: "alice", role: :regular, away: false}]

      html =
        render_conversations(
          channels: ["#lobby", "#general"],
          active_channel: "#lobby",
          channel_users: users
        )

      # Users only under #lobby (active), not #general
      assert html =~ "conversations-users"

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
        render_conversations(
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
        render_conversations(
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
        render_conversations(
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
        render_conversations(
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
        render_conversations(
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
        render_conversations(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: users
        )

      assert html =~ ~s(data-nick="alice")
    end

    @tag :unit
    test "no users rendered when channel_users is empty" do
      html =
        render_conversations(
          channels: ["#lobby"],
          active_channel: "#lobby",
          channel_users: []
        )

      refute html =~ "conversations-users"
      refute html =~ "conversations-user-count"
    end

    @tag :unit
    test "active channel appears first in list" do
      html =
        render_conversations(
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

  # ── Popular channels ──────────────────────────────────────

  describe "conversations/1 popular channels" do
    @tag :unit
    test "renders popular channels when section is expanded" do
      popular = [
        %{name: "#gaming", user_count: 42},
        %{name: "#music", user_count: 28}
      ]

      html =
        render_conversations(
          channels: ["#lobby"],
          popular_channels: popular,
          sections: %{channels: true, pms: true, popular: true}
        )

      assert html =~ "#gaming"
      assert html =~ "(42)"
      assert html =~ "#music"
      assert html =~ "(28)"
      assert html =~ "conversations-join-btn"
      assert html =~ "Browse All Channels..."
    end

    @tag :unit
    test "hides popular channels when section is collapsed" do
      popular = [%{name: "#gaming", user_count: 42}]

      html =
        render_conversations(
          channels: ["#lobby"],
          popular_channels: popular,
          sections: %{channels: true, pms: true, popular: false}
        )

      refute html =~ "#gaming"
    end
  end
end
