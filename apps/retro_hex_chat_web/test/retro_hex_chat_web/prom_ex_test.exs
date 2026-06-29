defmodule RetroHexChatWeb.PromExTest do
  use RetroHexChatWeb.ConnCase, async: false

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
      assert {PromEx.Plugins.Ecto, repos: [RetroHexChat.Repo]} in plugins
    end
  end

  describe "dashboards/0" do
    test "declares the built-in dashboards provisioned by infra" do
      assert {:prom_ex, "application.json"} in RetroHexChatWeb.PromEx.dashboards()
      assert {:prom_ex, "beam.json"} in RetroHexChatWeb.PromEx.dashboards()
      assert {:prom_ex, "phoenix.json"} in RetroHexChatWeb.PromEx.dashboards()
      assert {:prom_ex, "phoenix_live_view.json"} in RetroHexChatWeb.PromEx.dashboards()
      assert {:prom_ex, "ecto.json"} in RetroHexChatWeb.PromEx.dashboards()
    end
  end

  describe "GET /metrics" do
    test "returns Prometheus text format", %{conn: conn} do
      conn = get(conn, "/metrics")

      assert response_content_type(conn, :text) =~ "text/plain"
      assert response(conn, 200) =~ "retro_hex_chat_web_prom_ex"
    end
  end
end
