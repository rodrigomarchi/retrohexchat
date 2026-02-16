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
      RetroHexChat.P2P.Supervisor,
      RetroHexChat.P2P.CleanupTask,
      RetroHexChat.Presence.Tracker,
      RetroHexChat.RateLimit.Table,
      RetroHexChat.Chat.LinkPreview.Cache,
      {Task.Supervisor, name: RetroHexChat.LinkPreviewTasks},
      RetroHexChat.Presence.WhowasCache,
      RetroHexChat.Services.NickServ,
      RetroHexChat.Services.ChanServ
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: RetroHexChat.Supervisor)
  end
end
