defmodule RetroHexChatWeb.Components.UI.P2P.SessionBadgeTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.P2P.SessionBadge

  @moduletag :unit

  defp entry(session, opts \\ []) do
    render_component(
      &p2p_peer_entry/1,
      Keyword.merge([peer: "alice", current: true, session: session], opts)
    )
  end

  test "renders an idle PM entry that starts a P2P session for the peer" do
    html = entry(%{state: :idle, peer_nick: "alice"})

    assert html =~ ~s(data-testid="p2p-peer-entry")
    assert html =~ ~s(data-p2p-state="idle")
    assert html =~ ~s(data-p2p-status="idle")
    assert html =~ ~s(phx-click="p2p_start_pm_session")
    assert html =~ ~s(phx-value-peer="alice")

    [item] =
      html
      |> Floki.parse_document!()
      |> Floki.find(~s([data-testid="p2p-peer-entry"]))

    # The entry sits beside the tabs and carries its label in the open, so a
    # glyph alone would read as decoration next to three labelled tabs.
    assert item |> Floki.text() |> String.trim() == "P2P Session"
    assert Floki.attribute(item, "aria-label") == []
  end

  # The card and this entry are the same door. Following either one has to leave
  # the conversation standing, which is what a tab of its own means.
  test "a session is entered at its own address, in a tab of its own" do
    html =
      entry(%{
        state: :pending_received,
        role: :peer,
        token: "tok123",
        peer_nick: "alice",
        path: "/p2p/tok123"
      })

    [item] =
      html
      |> Floki.parse_document!()
      |> Floki.find(~s(a[data-testid="p2p-peer-entry"]))

    assert Floki.attribute(item, "href") == ["/p2p/tok123"]
    assert Floki.attribute(item, "target") == ["_blank"]
    assert Floki.attribute(item, "rel") == ["noopener"]
    assert html =~ ~s(data-p2p-state="pending")
    assert html =~ ~s(data-p2p-status="invite")
  end

  test "an invite this reader received can still be refused from the conversation" do
    html =
      entry(%{
        state: :pending_received,
        role: :peer,
        token: "tok123",
        peer_nick: "alice",
        path: "/p2p/tok123"
      })

    assert html =~ ~s(data-testid="p2p-peer-decline")
    assert html =~ ~s(phx-click="p2p_decline_invite")
    assert html =~ ~s(phx-value-token="tok123")

    doc = Floki.parse_document!(html)
    assert [decline] = Floki.find(doc, ~s([data-testid="p2p-peer-decline"]))
    assert Floki.attribute(decline, "aria-label") == ["Decline P2P request"]
  end

  # A second tab of a session you are in moves the session into it, so the entry
  # for one you already have open is a way *to that tab* and never a new one.
  test "a session this reader already has open is a way back to its tab" do
    html =
      entry(
        %{state: :connected, token: "tok123", peer_nick: "alice", path: "/p2p/tok123"},
        open_paths: MapSet.new(["/p2p/tok123"])
      )

    assert html =~ ~s(data-testid="p2p-peer-elsewhere")
    assert html =~ ~s(phx-hook="SurfaceTabLinkHook")
    refute html =~ ~s(data-testid="p2p-peer-entry")

    [item] =
      html
      |> Floki.parse_document!()
      |> Floki.find(~s([data-testid="p2p-peer-elsewhere"]))

    assert Floki.attribute(item, "target") == []
  end

  # Nothing that happens inside a session reaches the chat any more, so the
  # entry says how far along it is and not one thing more.
  test "the entry carries no in-session controls" do
    html = entry(%{state: :connected, token: "tok123", peer_nick: "alice", path: "/p2p/tok123"})

    assert html =~ ~s(data-p2p-status="live")
    refute html =~ "p2p_console_select"
    refute html =~ "p2p_statusbar_stop"
    refute html =~ "p2p_accept_invite"
    refute html =~ "data-p2p-facets"
  end

  test "maps lifecycle states to stable compact glyph semantics" do
    cases = [
      {:invite_sent, "pending", "invite", "P2P invite pending"},
      {:joining, "connecting", "link", "P2P session connecting"},
      {:connected, "connected", "live", "Troll"}
    ]

    for {state, visual_state, status, title} <- cases do
      html =
        render_component(&p2p_peer_glyph/1,
          peer: "Troll",
          session: %{state: state}
        )

      assert html =~ ~s(data-testid="p2p-peer-glyph")
      assert html =~ ~s(data-p2p-state="#{visual_state}")
      assert html =~ ~s(data-p2p-status="#{status}")
      assert html =~ title
    end
  end

  test "accepts direct visual state strings for compatibility with low-level tab callers" do
    html =
      render_component(&p2p_peer_glyph/1,
        peer: "Troll",
        state: "pending"
      )

    assert html =~ ~s(data-p2p-state="pending")
    assert html =~ ~s(data-p2p-status="invite")
  end
end
