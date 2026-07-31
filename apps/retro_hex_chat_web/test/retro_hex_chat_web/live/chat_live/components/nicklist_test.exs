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
        active_channel: "#lobby",
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
end
