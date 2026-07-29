defmodule RetroHexChatWeb.Components.UI.P2P.SessionBadgeTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.P2P.SessionBadge

  @moduletag :unit

  test "renders an idle PM entry that starts a P2P session for the peer" do
    html =
      render_component(&p2p_peer_entry/1,
        peer: "alice",
        current: true,
        session: %{state: :idle, peer_nick: "alice"}
      )

    assert html =~ ~s(data-testid="p2p-peer-entry")
    assert html =~ ~s(data-p2p-state="idle")
    assert html =~ ~s(data-p2p-status="idle")
    assert html =~ ~s(phx-click="p2p_start_pm_session")
    assert html =~ ~s(phx-value-peer="alice")

    [entry] =
      html
      |> Floki.parse_document!()
      |> Floki.find(~s([data-testid="p2p-peer-entry"]))

    assert entry |> Floki.text() |> String.trim() == ""
  end

  test "renders a received pending request with icon-only join and decline actions" do
    html =
      render_component(&p2p_peer_entry/1,
        peer: "alice",
        current: true,
        session: %{state: :pending_received, role: :peer, token: "tok123", peer_nick: "alice"}
      )

    assert html =~ ~s(data-testid="p2p-peer-entry")
    assert html =~ ~s(data-p2p-state="pending")
    assert html =~ ~s(data-p2p-status="invite")
    assert html =~ ~s(data-testid="p2p-peer-join")
    assert html =~ ~s(phx-click="p2p_accept_invite")
    assert html =~ ~s(phx-value-token="tok123")
    assert html =~ ~s(data-testid="p2p-peer-decline")
    assert html =~ ~s(phx-click="p2p_decline_invite")

    doc = Floki.parse_document!(html)

    assert [join] = Floki.find(doc, ~s([data-testid="p2p-peer-join"]))
    assert Floki.attribute(join, "aria-label") == ["Accept P2P request"]
    assert join |> Floki.text() |> String.trim() == ""
  end

  test "renders the icon-only PM entry with rich facets and actions in the popover" do
    html =
      render_component(&p2p_peer_entry/1,
        peer: "Troll",
        current: true,
        session: %{
          state: :connected,
          peer_nick: "Troll",
          call_summary: %{duration: "00:03:14", quality_label: "Good"},
          file_summary: %{status: "offer_received"},
          game_summary: %{active?: true},
          turn_only: true,
          turn_configured: true
        }
      )

    assert html =~ ~s(data-testid="p2p-peer-entry")
    refute html =~ ~s(data-testid="p2p-peer-badge")
    assert html =~ ~s(data-p2p-state="connected")
    assert html =~ ~s(data-p2p-status="live")
    assert html =~ ~s(data-p2p-facets="call,file,game,relay")
    assert html =~ ~s(data-testid="p2p-peer-facet-call")
    assert html =~ ~s(data-testid="p2p-peer-facet-file")
    assert html =~ ~s(data-testid="p2p-peer-facet-game")
    assert html =~ ~s(data-testid="p2p-peer-facet-relay")
    assert html =~ ~s(phx-click="p2p_console_select")
    assert html =~ ~s(phx-value-section="call")
    assert html =~ ~s(phx-value-section="stats")
    assert html =~ ~s(phx-click="p2p_statusbar_stop")
  end

  test "maps lifecycle states to stable compact glyph semantics" do
    cases = [
      {:invite_sent, "pending", "invite", "P2P invite pending"},
      {:joining, "connecting", "link", "P2P session connecting"},
      {:connected, "connected", "ready", "P2P session active"}
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
