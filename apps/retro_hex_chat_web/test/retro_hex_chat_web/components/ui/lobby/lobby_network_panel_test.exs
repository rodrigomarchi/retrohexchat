defmodule RetroHexChatWeb.Components.UI.Lobby.LobbyNetworkPanelTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.Lobby.LobbyNetworkPanel

  alias RetroHexChatWeb.App.P2PStats

  @moduletag :unit

  test "renders a session header with active facets and relay state" do
    stats =
      P2PStats.empty()
      |> put_in([:video, :source], "screen")
      |> put_in([:summary, :signaling_epoch], 7)
      |> put_in([:summary, :offer_id], "p2p-7-1")

    html =
      render_component(&lobby_network_panel/1,
        stats: stats,
        nickname: "neo",
        peer_nick: "trinity",
        peer_online: true,
        session_status: "connected",
        connection_label: "Connected",
        call_summary: %{type: "video", duration: "00:01:02"},
        file_summary: %{status: "sending", file_name: "report.pdf"},
        game_summary: %{active?: true},
        recovery: %{
          state: :reconnecting,
          reason: "ice_disconnected",
          trigger: "auto",
          attempt: 2,
          manual_retry: false
        },
        turn_only: true
      )

    assert html =~ ~s(data-testid="p2p-stats-session-header")
    assert html =~ ~s(data-testid="p2p-stats-summary")
    assert html =~ ~s(data-testid="p2p-stats-summary-health")
    assert html =~ ~s(data-testid="p2p-stats-summary-latency")
    assert html =~ ~s(data-testid="p2p-stats-summary-media")
    assert html =~ ~s(data-testid="p2p-stats-summary-data")
    assert html =~ ~s(data-testid="p2p-stats-tab-network")
    assert html =~ ~s(data-testid="p2p-stats-tab-audio")
    assert html =~ ~s(data-testid="p2p-stats-tab-video")
    assert html =~ ~s(data-testid="p2p-stats-tab-game")
    assert html =~ ~s(data-testid="p2p-stats-tab-file")
    assert html =~ ~s(data-testid="p2p-stats-details-connection")
    assert html =~ ~s(data-testid="p2p-stats-details-recovery")
    assert html =~ ~s(data-testid="p2p-stats-details-audio")
    assert html =~ ~s(data-testid="p2p-stats-details-video")
    assert html =~ ~s(data-testid="p2p-stats-details-game")
    assert html =~ ~s(data-testid="p2p-stats-details-file")
    assert html =~ "P2P session with trinity"
    assert html =~ "Connected"
    assert html =~ "Peer online"
    assert html =~ ~s(data-testid="p2p-stats-facet-call")
    assert html =~ "Call 00:01:02"
    assert html =~ ~s(data-testid="p2p-stats-facet-file")
    assert html =~ ~s(data-testid="p2p-stats-facet-game")
    assert html =~ ~s(data-testid="p2p-stats-relay")
    assert html =~ "Source"
    assert html =~ "Screen"
    assert html =~ "ice_disconnected"
    assert html =~ "auto"
    assert html =~ "Epoch 7"
    assert html =~ "p2p-7-1"

    document = Floki.parse_document!(html)

    assert Floki.find(document, ~s([data-testid="p2p-stats-details-connection"][open])) != []
    assert Floki.find(document, ~s([data-testid="p2p-stats-details-audio"][open])) == []
    assert Floki.find(document, ~s([data-testid="p2p-stats-details-video"][open])) == []
    assert Floki.find(document, ~s([data-testid="p2p-stats-details-game"][open])) == []
    assert Floki.find(document, ~s([data-testid="p2p-stats-details-file"][open])) == []
  end
end
