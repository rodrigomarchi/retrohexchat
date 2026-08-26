defmodule RetroHexChatWeb.ChatLive.Components.NicklistTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.Nicklist

  @moduletag :unit

  @users [
    %{nickname: "alice", role: :operator, away: false, muted: false},
    %{nickname: "Bob", role: :regular, away: true, muted: false}
  ]

  @semantic_users [
    %{nickname: "Zed", role: :regular, away: false, muted: true},
    %{nickname: "Alice", role: :owner, away: false, muted: false},
    %{nickname: "Marta", role: :operator, away: false, muted: false},
    %{nickname: "Vic", role: :voiced, away: true, muted: false},
    %{nickname: "Bob", role: :regular, away: false, muted: false}
  ]

  test "id/0 is stable" do
    assert Nicklist.id() == "nicklist"
  end

  test "dom_id/1 keys rows by the normalized nick" do
    assert Nicklist.dom_id("Bob") == "nick-bob"
    assert Nicklist.dom_id("alice") == "nick-alice"
  end

  test "renders the shell and the backdrop toggle even when empty" do
    html = render_component(Nicklist, id: Nicklist.id())

    assert html =~ ~s(data-testid="nicklist-sidebar-shell")
    assert html =~ ~s(data-testid="nicklist-rail")
    assert html =~ ~s(data-testid="nicklist")
    assert html =~ ~s(id="nicklist-users")
    assert html =~ ~s(data-testid="nicklist-header")
    assert html =~ ~s(data-state="collapsed")
    # Rail/backdrop controls bubble toggle_nicklist to the parent.
    assert html =~ "toggle_nicklist"
  end

  test "collapses when not visible and hides when unavailable" do
    collapsed = render_component(Nicklist, id: Nicklist.id(), visible: false)
    assert collapsed =~ "chat-sidebar-shell--collapsed"
    assert collapsed =~ ~s(data-testid="nicklist-rail")

    shown = render_component(Nicklist, id: Nicklist.id(), visible: true)
    assert shown =~ "chat-sidebar-shell--expanded"
    assert shown =~ ~s(title="Collapse user list")
    refute shown =~ ~s(data-testid="nicklist-rail")

    unavailable = render_component(Nicklist, id: Nicklist.id(), available: false, visible: true)
    assert unavailable =~ "hidden"
  end

  test "a reset action streams one row per user, keyed by nick" do
    html =
      render_component(Nicklist,
        id: Nicklist.id(),
        visible: true,
        nick_color_fn: fn _nick -> nil end,
        action: {:reset, @users}
      )

    assert html =~ ~s(id="nick-alice")
    assert html =~ ~s(id="nick-bob")
    assert html =~ ~s(id="nicklist-users-operator")
    assert html =~ ~s(id="nicklist-users-regular")
    assert html =~ ~s(phx-update="stream")
    assert html =~ ~s(data-nick="alice")
    assert html =~ ~s(data-nick="Bob")
    assert html =~ ~s(data-testid="nicklist-item-alice")
  end

  test "renders a semantic channel roster grouped by IRC role and status" do
    html =
      render_component(Nicklist,
        id: Nicklist.id(),
        visible: true,
        conversation_label: "#lobby",
        current_modes: "+nt",
        current_nick: "Alice",
        nick_color_fn: fn _nick -> nil end,
        action: {:reset, @semantic_users}
      )

    assert html =~ ~s(data-testid="nicklist-header")
    assert html =~ "#lobby"
    assert html =~ "+nt"
    assert html =~ ~s(data-testid="nicklist-online-count")
    assert html =~ ~s(data-testid="nicklist-away-count")
    assert html =~ ~s(data-testid="nicklist-muted-count")

    document = Floki.parse_document!(html)

    for status <- ~w(online away muted) do
      assert [stat] = Floki.find(document, ".chat-nicklist-stat--#{status}")
      assert [_svg] = Floki.find(stat, "svg")
    end

    assert html =~ ~s(data-testid="nicklist-section-owner")
    assert html =~ ~s(data-testid="nicklist-section-operator")
    assert html =~ ~s(data-testid="nicklist-section-voiced")
    assert html =~ ~s(data-testid="nicklist-section-regular")

    assert html =~ ~r/data-testid="nicklist-section-owner".*data-nick="Alice"/s
    assert html =~ ~r/data-testid="nicklist-section-operator".*data-nick="Marta"/s
    assert html =~ ~r/data-testid="nicklist-section-voiced".*data-nick="Vic"/s
    assert html =~ ~r/data-testid="nicklist-section-regular".*data-nick="Bob"/s
    assert html =~ ~s(data-current="true")
    assert html =~ ~s(data-muted="true")
    assert html =~ ~s(data-status="away")
  end

  describe "a private conversation" do
    @participants [
      %{nickname: "Joe", role: :regular, away: false, muted: false, online: true, rank: 0},
      %{nickname: "Troll", role: :regular, away: false, muted: false, online: true, rank: 1}
    ]

    defp private_roster(users, overrides \\ []) do
      render_component(
        Nicklist,
        Keyword.merge(
          [
            id: Nicklist.id(),
            visible: true,
            conversation_kind: :private,
            conversation_label: "Joe",
            current_nick: "Troll",
            nick_color_fn: fn _nick -> nil end,
            action: {:reset, users}
          ],
          overrides
        )
      )
    end

    test "names the person on the other side, with the private-message icon" do
      html = private_roster(@participants)

      assert html =~ ~s(data-testid="nicklist-header")
      assert html =~ "Joe"
      assert html =~ "icon_tab_pm"
    end

    test "lists both people under one participants section, the peer first" do
      html = private_roster(@participants)

      assert html =~ "Participants"
      refute html =~ ~s(<span class="chat-nicklist-section__label">Users</span>)
      assert html =~ ~r/data-nick="Joe".*data-nick="Troll"/s
      assert html =~ ~s(data-testid="nicklist-item-Joe")
      assert html =~ ~s(data-current="true")
    end

    # Alphabetically "Joe" follows nothing and "Troll" would sort after it by
    # accident. Rank is what actually decides, so hand it the list backwards.
    test "the roster's rank decides the order, not the order it arrives in" do
      html = private_roster(Enum.reverse(@participants))

      assert html =~ ~r/data-nick="Joe".*data-nick="Troll"/s
    end

    test "a peer that outranks you alphabetically still comes first" do
      users = [
        %{nickname: "Zed", role: :regular, away: false, muted: false, online: true, rank: 0},
        %{nickname: "Ann", role: :regular, away: false, muted: false, online: true, rank: 1}
      ]

      html = private_roster(users, conversation_label: "Zed", current_nick: "Ann")

      assert html =~ ~r/data-nick="Zed".*data-nick="Ann"/s
    end

    # A channel member is present by being in the channel; the other person in a
    # query may simply not be connected, and the list has to say so.
    test "an unconnected peer reads as offline and is not counted online" do
      offline = [%{Enum.at(@participants, 0) | online: false} | tl(@participants)]

      html = private_roster(offline)

      assert html =~ ~r/data-testid="nicklist-item-Joe"[^>]*data-status="offline"/
      assert html =~ ~r/data-testid="nicklist-online-count">1</
    end

    test "a bot peer keeps its own section" do
      bot = [%{Enum.at(@participants, 0) | role: :bot} | tl(@participants)]

      html = private_roster(bot)

      assert html =~ ~s(data-testid="nicklist-section-bot")
      assert html =~ ~s(data-testid="nicklist-section-regular")
    end
  end
end
