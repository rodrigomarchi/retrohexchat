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
        turn_only: true
      )

    assert html =~ ~s(data-testid="p2p-stats-session-header")
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
  end
end
