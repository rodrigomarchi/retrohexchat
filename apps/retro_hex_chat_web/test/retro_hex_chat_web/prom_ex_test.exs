defmodule RetroHexChatWeb.PromExTest do
  use RetroHexChatWeb.ConnCase, async: false

  alias RetroHexChat.PromEx.Plugins.Domain

  describe "RetroHexChat.PromEx.plugins/0" do
    test "includes domain metrics and Ecto before the Repo starts" do
      assert [
               Domain,
               {PromEx.Plugins.Ecto,
                repos: [RetroHexChat.Repo], metric_prefix: [:retro_hex_chat_web, :prom_ex, :ecto]},
               {RetroHexChat.PromEx.Plugins.Oban,
                oban_supervisors: [Oban],
                poll_rate: 5_000,
                metric_prefix: [:retro_hex_chat, :prom_ex, :oban]}
             ] = RetroHexChat.PromEx.plugins()
    end
  end

  describe "Domain.event_metrics/1" do
    test "exports P2P game session metrics to Prometheus" do
      # The LiveDashboard metric list is a separate surface; only what this
      # plugin declares reaches /metrics and therefore Grafana.
      names =
        [metric_prefix: [:retro_hex_chat, :domain]]
        |> Domain.event_metrics()
        |> List.wrap()
        |> Enum.flat_map(& &1.metrics)
        |> Enum.map(& &1.name)

      assert [:retro_hex_chat, :domain, :games, :session, :samples, :total] in names
      assert [:retro_hex_chat, :domain, :games, :session, :render_fps] in names
      assert [:retro_hex_chat, :domain, :games, :session, :state_gap, :milliseconds] in names
      assert [:retro_hex_chat, :domain, :games, :session, :rtt, :milliseconds] in names
      assert [:retro_hex_chat, :domain, :games, :session, :state_drops, :total] in names
      assert [:retro_hex_chat, :domain, :games, :session, :stalls, :total] in names
    end

    test "tags game metrics by the role that reported them" do
      metric =
        [metric_prefix: [:retro_hex_chat, :domain]]
        |> Domain.event_metrics()
        |> List.wrap()
        |> Enum.flat_map(& &1.metrics)
        |> Enum.find(&(&1.name == [:retro_hex_chat, :domain, :games, :session, :render_fps]))

      # Host versus guest is the comparison the whole thing exists to make.
      assert :role in metric.tags
      assert :game_id in metric.tags

      assert metric.tag_values.(%{game_id: "hex_pong", role: "guest"}) == %{
               game_id: "hex_pong",
               role: "guest"
             }
    end
  end

  describe "plugins/0" do
    test "includes the expected runtime instrumentation plugins" do
      plugins = RetroHexChatWeb.PromEx.plugins()

      assert {PromEx.Plugins.Application, deps: [:phoenix, :phoenix_live_view, :bandit, :prom_ex]} in plugins

      assert PromEx.Plugins.Beam in plugins

      assert {PromEx.Plugins.Phoenix,
              endpoint: RetroHexChatWeb.Endpoint,
              router: RetroHexChatWeb.Router,
              event_prefix: [:phoenix, :endpoint]} in plugins

      assert PromEx.Plugins.PhoenixLiveView in plugins
      refute {PromEx.Plugins.Ecto, repos: [RetroHexChat.Repo]} in plugins
    end
  end

  describe "dashboards/0" do
    test "declares the built-in dashboards provisioned by infra" do
      assert {:prom_ex, "ecto.json"} in RetroHexChat.PromEx.dashboards()
      assert {:prom_ex, "oban.json"} in RetroHexChat.PromEx.dashboards()

      assert {:prom_ex, "application.json"} in RetroHexChatWeb.PromEx.dashboards()
      assert {:prom_ex, "beam.json"} in RetroHexChatWeb.PromEx.dashboards()
      assert {:prom_ex, "phoenix.json"} in RetroHexChatWeb.PromEx.dashboards()
      assert {:prom_ex, "phoenix_live_view.json"} in RetroHexChatWeb.PromEx.dashboards()
    end
  end

  describe "RetroHexChatWeb.Telemetry.metrics/0" do
    test "declares live Oban metrics for the system metrics window" do
      oban_metrics =
        RetroHexChatWeb.Telemetry.metrics()
        |> Enum.filter(&(&1.reporter_options[:nav] == "Oban"))

      assert Enum.any?(oban_metrics, &(&1.event_name == [:oban, :job, :stop]))
      assert Enum.any?(oban_metrics, &(&1.event_name == [:oban, :job, :exception]))

      assert Enum.any?(
               oban_metrics,
               &(&1.event_name == [:prom_ex, :plugin, :oban, :queue, :length, :count])
             )
    end
  end

  describe "GET /metrics" do
    test "returns Prometheus text format", %{conn: conn} do
      conn = get(conn, "/metrics")

      assert response_content_type(conn, :text) =~ "text/plain"
      assert response(conn, 200) =~ "retro_hex_chat_web_prom_ex"
      assert response(conn, 200) =~ "retro_hex_chat_web_prom_ex_ecto_repo_init_status_info"
      assert response(conn, 200) =~ ~s(repo="RetroHexChat.Repo")
    end
  end
end
