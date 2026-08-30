defmodule RetroHexChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RetroHexChat.PromEx,
      RetroHexChat.Repo,
      {Oban, Application.fetch_env!(:retro_hex_chat, Oban)},
      {DNSCluster, query: Application.get_env(:retro_hex_chat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RetroHexChat.PubSub},
      {Registry, keys: :unique, name: RetroHexChat.Channels.ChannelRegistry},
      RetroHexChat.Channels.Supervisor,
      RetroHexChat.P2P.RateLimitTable,
      RetroHexChat.P2P.Turn.Supervisor,
      {Registry, keys: :unique, name: RetroHexChat.Lobby.SessionRegistry},
      RetroHexChat.Lobby.Supervisor,
      {Registry, keys: :unique, name: RetroHexChat.GroupCall.RoomRegistry},
      {Registry, keys: :unique, name: RetroHexChat.GroupCall.PeerRegistry},
      RetroHexChat.GroupCall.Supervisor,
      {Registry, keys: :unique, name: RetroHexChat.VirtualSpace.SessionRegistry},
      RetroHexChat.VirtualSpace.Supervisor,
      {Registry, keys: :unique, name: RetroHexChat.Arcade.SessionRegistry},
      RetroHexChat.Arcade.Supervisor,
      RetroHexChat.Admin.BanCache,
      RetroHexChat.Admin.RoleCache,
      RetroHexChat.Admin.GlobalMuteTable,
      RetroHexChat.Presence.Tracker,
      # Ahead of nothing in particular, but after the channel servers it parts
      # people from: it decides when the last of someone's screens has closed.
      RetroHexChat.Surfaces,
      RetroHexChat.RateLimit.Table,
      RetroHexChat.Scraper.Cache,
      RetroHexChat.Presence.WhowasCache,
      RetroHexChat.Services.NickServ,
      RetroHexChat.Services.ChanServ,
      {Registry, keys: :unique, name: RetroHexChat.Bots.BotRegistry},
      # Ahead of the bots themselves: a bot that speaks before the pacer exists
      # would speak unpaced, which is the burst this prevents.
      RetroHexChat.Bots.Pace,
      RetroHexChat.Bots.Supervisor,
      RetroHexChat.Bots.Loader
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: RetroHexChat.Supervisor)
  end
end
