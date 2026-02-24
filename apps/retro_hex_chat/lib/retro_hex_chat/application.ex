defmodule RetroHexChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RetroHexChat.Repo,
      {DNSCluster, query: Application.get_env(:retro_hex_chat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RetroHexChat.PubSub},
      {Registry, keys: :unique, name: RetroHexChat.Channels.ChannelRegistry},
      RetroHexChat.Channels.Supervisor,
      {Registry, keys: :unique, name: RetroHexChat.P2P.SessionRegistry},
      RetroHexChat.P2P.RateLimitTable,
      RetroHexChat.P2P.Supervisor,
      RetroHexChat.P2P.CleanupTask,
      RetroHexChat.P2P.Turn.Supervisor,
      {Registry, keys: :unique, name: RetroHexChat.Games.SessionRegistry},
      RetroHexChat.Games.RateLimitTable,
      RetroHexChat.Games.Supervisor,
      RetroHexChat.Games.CleanupTask,
      RetroHexChat.Admin.BanCache,
      RetroHexChat.Admin.BanExpiry,
      RetroHexChat.Admin.RoleCache,
      RetroHexChat.Admin.GlobalMuteTable,
      RetroHexChat.Presence.Tracker,
      RetroHexChat.RateLimit.Table,
      RetroHexChat.Chat.LinkPreview.Cache,
      {Task.Supervisor, name: RetroHexChat.LinkPreviewTasks},
      RetroHexChat.Presence.WhowasCache,
      RetroHexChat.Services.NickServ,
      RetroHexChat.Services.NickExpiry,
      RetroHexChat.Services.ChanServ,
      RetroHexChat.Services.ChanExpiry,
      {Registry, keys: :unique, name: RetroHexChat.Bots.BotRegistry},
      RetroHexChat.Bots.Supervisor,
      RetroHexChat.Bots.Loader
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: RetroHexChat.Supervisor)
  end
end
