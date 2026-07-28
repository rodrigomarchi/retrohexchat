defmodule RetroHexChatWeb.Components.UI.GroupCall.StatsPanelTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.GroupCall.StatsPanel

  alias RetroHexChatWeb.App.GroupCallStats

  @moduletag :unit

  test "renders recovery and handshake diagnostics" do
    stats =
      GroupCallStats.empty()
      |> put_in([:summary, :offer_id], "gc-3-2")
      |> put_in([:summary, :rejoin_epoch], 1)

    html =
      render_component(&group_call_stats_panel/1,
        call: %{
          channel_name: "#lobby",
          status: :reconnecting,
          connection_state: "disconnected",
          room: %{status: "active", max_participants: 8},
          participants: [],
          pending_participants: [],
          tracks: [],
          server_stats: GroupCallStats.empty_server(),
          recovery: %{
            state: :reconnecting,
            reason: "ice_disconnected",
            trigger: "auto",
            attempt: 2,
            max_attempts: 3,
            next_retry_ms: 2000,
            manual_retry: false,
            message: "Trying to recover"
          }
        },
        stats: stats
      )

    assert html =~ ~s(data-testid="group-call-stats-details-recovery")
    assert html =~ "ice_disconnected"
    assert html =~ "auto"
    assert html =~ "2/3"
    assert html =~ "2000 ms"
    assert html =~ "gc-3-2"
    assert html =~ "Epoch 1"
  end
end
