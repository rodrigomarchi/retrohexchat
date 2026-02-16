defmodule RetroHexChatWeb.Components.NicklistTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.Nicklist

  describe "nicklist header" do
    @tag :unit
    test "renders header with user count and close button" do
      users = [
        %{nickname: "alice", role: :regular, away: false},
        %{nickname: "bob", role: :regular, away: false}
      ]

      html = render_component(&Nicklist.nicklist/1, users: users)

      assert html =~ "nicklist-header"
      assert html =~ "Users (2)"
      assert html =~ "nicklist-close"
      assert html =~ "phx-click=\"toggle_nicklist\""
    end

    @tag :unit
    test "renders header even when no users" do
      html = render_component(&Nicklist.nicklist/1, users: [])
      assert html =~ "nicklist-header"
      assert html =~ "Users (0)"
    end
  end

  describe "nicklist/1" do
    test "groups users by role: operators, voiced, regular" do
      users = [
        %{nickname: "alice", role: :operator, away: false},
        %{nickname: "bob", role: :regular, away: false},
        %{nickname: "carol", role: :voiced, away: false}
      ]

      html = render_component(&Nicklist.nicklist/1, users: users)

      assert html =~ "nick-operator"
      assert html =~ "nick-voiced"
      assert html =~ "nick-regular"
      assert html =~ "@alice"
      assert html =~ "+carol"
      assert html =~ "bob"
    end

    test "sorts alphabetically within groups" do
      users = [
        %{nickname: "zach", role: :operator, away: false},
        %{nickname: "alice", role: :operator, away: false},
        %{nickname: "mike", role: :regular, away: false},
        %{nickname: "bob", role: :regular, away: false}
      ]

      html = render_component(&Nicklist.nicklist/1, users: users)

      # alice should come before zach in operators
      alice_pos = :binary.match(html, "alice") |> elem(0)
      zach_pos = :binary.match(html, "zach") |> elem(0)
      assert alice_pos < zach_pos

      # bob should come before mike in regulars
      bob_pos = :binary.match(html, "bob") |> elem(0)
      mike_pos = :binary.match(html, "mike") |> elem(0)
      assert bob_pos < mike_pos
    end

    test "displays total user count" do
      users = [
        %{nickname: "alice", role: :operator, away: false},
        %{nickname: "bob", role: :regular, away: false},
        %{nickname: "carol", role: :voiced, away: false}
      ]

      html = render_component(&Nicklist.nicklist/1, users: users)

      assert html =~ "Users (3)"
    end

    test "displays group counts for non-empty groups" do
      users = [
        %{nickname: "alice", role: :operator, away: false},
        %{nickname: "zach", role: :operator, away: false},
        %{nickname: "carol", role: :voiced, away: false},
        %{nickname: "bob", role: :regular, away: false}
      ]

      html = render_component(&Nicklist.nicklist/1, users: users)

      assert html =~ "Operators (2)"
      assert html =~ "Voiced (1)"
      assert html =~ "Regular (1)"
    end

    @tag :unit
    test "hides empty groups" do
      users = [
        %{nickname: "alice", role: :operator, away: false},
        %{nickname: "bob", role: :regular, away: false}
      ]

      html = render_component(&Nicklist.nicklist/1, users: users)

      assert html =~ "Operators (1)"
      assert html =~ "Regular (1)"
      refute html =~ "Owners"
      refute html =~ "Voiced"
      refute html =~ "Half-Ops"
    end

    test "renders empty nicklist" do
      html = render_component(&Nicklist.nicklist/1, users: [])

      assert html =~ "Users (0)"
    end

    test "dims away users" do
      users = [
        %{nickname: "alice", role: :regular, away: true},
        %{nickname: "bob", role: :regular, away: false}
      ]

      html = render_component(&Nicklist.nicklist/1, users: users)

      assert html =~ "nick-away"
    end

    test "context menu trigger on right-click" do
      users = [
        %{nickname: "alice", role: :regular, away: false}
      ]

      html = render_component(&Nicklist.nicklist/1, users: users)

      assert html =~ "phx-click=\"nick_right_click\""
      assert html =~ "phx-value-nick=\"alice\""
    end
  end

  describe "5-group nicklist display (T011)" do
    test "displays all 5 groups with correct prefixes" do
      users = [
        %{nickname: "alpha", role: :owner, away: false},
        %{nickname: "bravo", role: :operator, away: false},
        %{nickname: "charlie", role: :half_operator, away: false},
        %{nickname: "delta", role: :voiced, away: false},
        %{nickname: "echo", role: :regular, away: false}
      ]

      html = render_component(&Nicklist.nicklist/1, users: users)

      # Check group headers
      assert html =~ "Owners (1)"
      assert html =~ "Operators (1)"
      assert html =~ "Half-Ops (1)"
      assert html =~ "Voiced (1)"
      assert html =~ "Regular (1)"

      # Check prefixes
      assert html =~ "~alpha"
      assert html =~ "@bravo"
      assert html =~ "%charlie"
      assert html =~ "+delta"
    end

    test "owner uses nick-owner CSS class" do
      users = [%{nickname: "alice", role: :owner, away: false}]
      html = render_component(&Nicklist.nicklist/1, users: users)
      assert html =~ "nick-owner"
    end

    test "half-operator uses nick-halfop CSS class" do
      users = [%{nickname: "alice", role: :half_operator, away: false}]
      html = render_component(&Nicklist.nicklist/1, users: users)
      assert html =~ "nick-halfop"
    end

    test "users sorted alphabetically within groups" do
      users = [
        %{nickname: "charlie", role: :owner, away: false},
        %{nickname: "alice", role: :owner, away: false},
        %{nickname: "bob", role: :owner, away: false}
      ]

      html = render_component(&Nicklist.nicklist/1, users: users)
      assert html =~ "Owners (3)"

      # All three should appear
      assert html =~ "alice"
      assert html =~ "bob"
      assert html =~ "charlie"
    end
  end
end
