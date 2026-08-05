defmodule RetroHexChat.PromEx do
  @moduledoc """
  PromEx configuration for core RetroHexChat metrics.

  This module starts before `RetroHexChat.Repo` so the Ecto plugin captures the
  repo init event required by the PromEx Ecto dashboard.
  """

  use PromEx, otp_app: :retro_hex_chat

  @ecto_metric_prefix [:retro_hex_chat_web, :prom_ex, :ecto]
  @oban_metric_prefix [:retro_hex_chat, :prom_ex, :oban]

  @impl true
  @spec plugins() :: [module() | {module(), keyword()}]
  def plugins do
    [
      RetroHexChat.PromEx.Plugins.Domain,
      {PromEx.Plugins.Ecto, repos: [RetroHexChat.Repo], metric_prefix: @ecto_metric_prefix},
      {RetroHexChat.PromEx.Plugins.Oban,
       oban_supervisors: [Oban], poll_rate: 5_000, metric_prefix: @oban_metric_prefix}
    ]
  end

  @impl true
  @spec dashboards() :: [{atom(), String.t()}]
  def dashboards do
    [
      {:prom_ex, "ecto.json"},
      {:prom_ex, "oban.json"}
    ]
  end

  @impl true
  @spec dashboard_assigns() :: keyword()
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s",
      ecto_metric_prefix: Enum.join(@ecto_metric_prefix, "_"),
      oban_metric_prefix: Enum.join(@oban_metric_prefix, "_")
    ]
  end
end
