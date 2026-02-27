defmodule RetroHexChatWeb.ShowcaseLive.P2PLobbyPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.P2PLobby
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "P2P Lobby", active_page: "p2p-lobby")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">P2P Lobby</h2>

      <.showcase_card title="Idle" description="Waiting to connect.">
        <.p2p_lobby peer="alice" state="idle" />
      </.showcase_card>

      <.showcase_card title="Connecting" description="Connection in progress.">
        <.p2p_lobby peer="bob" state="connecting" />
      </.showcase_card>

      <.showcase_card title="Connected" description="Successfully connected.">
        <.p2p_lobby peer="carol" state="connected" />
      </.showcase_card>

      <.showcase_card title="Failed" description="Connection attempt failed.">
        <.p2p_lobby peer="dave" state="failed" />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
