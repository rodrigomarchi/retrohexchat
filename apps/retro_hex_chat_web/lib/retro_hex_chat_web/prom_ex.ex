defmodule RetroHexChatWeb.PromEx do
  @moduledoc """
  PromEx configuration for RetroHexChat.

  Exposes Prometheus metrics and declares the built-in dashboards provisioned
  by the infrastructure repository.
  """

  use PromEx, otp_app: :retro_hex_chat_web

  @impl true
  @spec plugins() :: [module() | {module(), keyword()}]
  def plugins do
    [
      {PromEx.Plugins.Application, deps: [:phoenix, :phoenix_live_view, :bandit, :prom_ex]},
      PromEx.Plugins.Beam,
      {PromEx.Plugins.Phoenix,
       endpoint: RetroHexChatWeb.Endpoint,
       router: RetroHexChatWeb.Router,
       event_prefix: [:phoenix, :endpoint]},
      PromEx.Plugins.PhoenixLiveView
    ]
  end

  @impl true
  @spec dashboards() :: [{atom(), String.t()}]
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "phoenix_live_view.json"}
    ]
  end

  @impl true
  @spec dashboard_assigns() :: keyword()
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s"
    ]
  end
end
