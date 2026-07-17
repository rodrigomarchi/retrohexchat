defmodule RetroHexChatWeb.Components.UI.P2P.SessionBadgeTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.P2P.SessionBadge

  @moduletag :unit

  test "renders the rich PM entry with live facets and actions" do
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
    assert html =~ ~s(data-testid="p2p-peer-badge")
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
