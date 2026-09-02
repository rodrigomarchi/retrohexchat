defmodule RetroHexChatWeb.ChatLive.Components.ConversationsTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.AutoJoinList
  alias RetroHexChatWeb.ChatLive.Components.Conversations

  @moduletag :unit

  defp render_conv(extra) do
    render_component(
      Conversations,
      Keyword.merge(
        [
          id: Conversations.id(),
          visible: true,
          channels: ["#lobby", "#elixir"],
          active_channel: "#lobby"
        ],
        extra
      )
    )
  end

  defp autojoin(entries) do
    Enum.reduce(entries, AutoJoinList.new(), fn
      {channel, key}, list ->
        {:ok, updated} = AutoJoinList.add_entry(list, channel, key)
        updated

      channel, list ->
        {:ok, updated} = AutoJoinList.add_entry(list, channel)
        updated
    end)
  end

  test "id/0 is stable" do
    assert Conversations.id() == "conversations"
  end

  test "renders the joined channels" do
    html = render_conv([])
    assert html =~ "#lobby"
    assert html =~ "#elixir"
    assert html =~ "OPEN CHANNELS"
    refute html =~ "MY CHANNELS"
    # Row events bubble to the parent unchanged.
    assert html =~ "switch_channel"
  end

  test "renders IRC-native sections without treeview labels" do
    html =
      render_conv(
        open_pm_tabs: ["alice"],
        pm_conversations: ["alice"],
        unread_counts: %{"#elixir" => 3, "pm:alice" => 2},
        highlight_channels: MapSet.new(["#elixir"]),
        flash_channels: MapSet.new(["#elixir"]),
        autojoin_list: autojoin(["#elixir", {"#secret", "hunter2"}]),
        popular_channels: [%{name: "#retro", user_count: 7}]
      )

    assert html =~ ~s(data-testid="conversations-section-channels")
    assert html =~ ~s(data-testid="conversations-section-pms")
    assert html =~ ~s(data-testid="conversations-section-autojoin")
    assert html =~ ~s(data-testid="conversations-section-popular")

    assert html =~ "OPEN CHANNELS"
    assert html =~ "RECENT PRIVATE MESSAGES"
    assert html =~ "AUTO-JOIN"
    assert html =~ "POPULAR CHANNELS"

    refute html =~ ~s(data-testid="conversations-section-alerts")
    refute html =~ "ACTIVITY"
    refute html =~ "MY CHANNELS"
  end

  test "renders compact conversation summary labels" do
    html =
      render_conv(
        pm_conversations: ["alice"],
        autojoin_list: autojoin(["#elixir"])
      )

    assert html =~ ~s(data-testid="conversations-stat-channels")
    assert html =~ ~s(data-testid="conversations-stat-pms")
    assert html =~ ~s(data-testid="conversations-stat-autojoin")
    assert html =~ "Channels"
    assert html =~ "PM"
    assert html =~ "Auto"
  end

  test "renders popular channels as a semantic section even when only browse is available" do
    html =
      render_conv(
        on_browse_channels: "browse_channels",
        popular_channels: []
      )

    assert html =~ ~s(data-testid="conversations-section-popular")
    assert html =~ ~s(data-testid="conversations-browse-all")
    assert html =~ "Browse All Channels..."
  end

  test "renders popular channels with join affordances and a browse-all action" do
    html =
      render_conv(
        on_browse_channels: "browse_channels",
        popular_channels: [%{name: "#retro", user_count: 7}]
      )

    assert html =~ ~s(data-testid="conversations-section-popular")
    assert html =~ "POPULAR CHANNELS"
    assert html =~ ~s(data-testid="popular-#retro")
    assert html =~ ~s(data-testid="join-#retro")
    assert html =~ ~s(data-testid="conversations-browse-all")
  end

  test "renders autojoin entries from the session without leaking keys" do
    html = render_conv(autojoin_list: autojoin([{"#secret", "hunter2"}]))

    assert html =~ ~s(data-testid="autojoin-#secret")
    assert html =~ "#secret"
    assert html =~ "+key"
    refute html =~ "hunter2"
  end

  test "draws highlights in the canonical conversation rows" do
    html =
      render_conv(
        pm_conversations: ["alice", "bob"],
        highlight_channels: MapSet.new(["#elixir", "pm:alice"])
      )

    document = Floki.parse_document!(html)

    alice = Floki.find(document, ~s([data-testid="pm-alice"]))
    channel = Floki.find(document, ~s([data-testid="channel-#elixir"]))

    assert alice != []
    assert Floki.attribute(alice, "class") |> to_string() =~ "text-error"

    assert Floki.find(alice, ".chat-conversations-row__signal--highlight") != []
    assert Floki.find(channel, ".chat-conversations-row__signal--highlight") != []
  end

  test "orders open channels by recent activity before join order" do
    html =
      render_conv(
        channels: ["#lobby", "#elixir", "#zig"],
        channel_activity_order: %{"#elixir" => 2, "#zig" => 3}
      )

    zig_pos = :binary.match(html, ~s(data-testid="channel-#zig")) |> elem(0)
    elixir_pos = :binary.match(html, ~s(data-testid="channel-#elixir")) |> elem(0)
    lobby_pos = :binary.match(html, ~s(data-testid="channel-#lobby")) |> elem(0)

    assert zig_pos < elixir_pos
    assert elixir_pos < lobby_pos
  end

  test "a PM nobody highlighted is drawn plainly" do
    html =
      render_conv(
        pm_conversations: ["alice"],
        open_pm_tabs: ["alice"],
        highlight_channels: MapSet.new([])
      )

    document = Floki.parse_document!(html)
    alice = Floki.find(document, ~s([data-testid="pm-alice"]))

    assert alice != []
    refute Floki.attribute(alice, "class") |> to_string() =~ "text-error"
    assert Floki.find(alice, ".chat-conversations-row__signal--highlight") == []
  end

  test "marks PMs that already have an open tab" do
    html =
      render_conv(
        open_pm_tabs: ["alice"],
        pm_conversations: ["alice", "bob"]
      )

    assert html =~ ~s(data-testid="pm-open-state-alice")
    refute html =~ ~s(data-testid="pm-open-state-bob")
  end

  test "collapses to the rail when not visible and expands when visible" do
    collapsed = render_conv(visible: false)
    assert collapsed =~ ~s(data-testid="conversations-sidebar-shell")
    assert collapsed =~ ~s(data-state="collapsed")
    assert collapsed =~ "chat-sidebar-shell--collapsed"
    assert collapsed =~ ~s(data-testid="conversations-rail")

    expanded = render_conv(visible: true)
    assert expanded =~ ~s(data-state="expanded")
    assert expanded =~ "chat-sidebar-shell--expanded"
    assert expanded =~ ~s(title="Collapse conversations")
    refute expanded =~ ~s(data-testid="conversations-rail")
  end

  test "places the expanded collapse control at the left edge of the titlebar" do
    html = render_conv(on_close: "toggle_conversations")
    document = Floki.parse_document!(html)
    [titlebar] = Floki.find(document, ".chat-conversations-titlebar")

    [first_element | _] =
      titlebar
      |> Floki.children()
      |> Enum.filter(&match?({_, _, _}, &1))

    assert {"button", attrs, _children} = first_element
    assert {"data-testid", "conversations-collapse-toggle"} in attrs
  end

  test "derives unread channels and PMs from unread_counts" do
    html =
      render_conv(
        unread_counts: %{"#elixir" => 3, "pm:alice" => 2, "#lobby" => 0},
        pm_conversations: ["alice"]
      )

    # #elixir has unread (3) → its unread badge count shows; #lobby (0) does not.
    assert html =~ "alice"
    assert html =~ "3"
  end

  test "renders the active P2P session glyph on the owning PM row" do
    html =
      render_conv(
        pm_conversations: ["alice", "bob"],
        p2p_pm_sessions: %{
          "alice" => %{peer_nick: "Alice", state: :connected, token: "tok"}
        }
      )

    assert html =~ ~s(data-testid="pm-p2p-glyph-alice")
    assert html =~ ~s(data-p2p-status="live")
    refute html =~ ~s(data-testid="pm-p2p-glyph-bob")
  end
end
