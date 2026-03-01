defmodule RetroHexChatWeb.ShowcaseLive.P2P.P2PLobbyPage do
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

      <.showcase_card title="Pending" description="Waiting to connect. Shows Connect button.">
        <.p2p_lobby peer="alice" state="pending" />
        <.code_example>
          &lt;.p2p_lobby peer="alice" state="pending" on_connect="p2p_connect" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Lobby"
        description="Invitation sent, waiting for peer to accept. Shows Connect button."
      >
        <.p2p_lobby peer="bob" state="lobby" />
      </.showcase_card>

      <.showcase_card
        title="Connecting"
        description="Connection in progress. Shows progress bar and Cancel button."
      >
        <.p2p_lobby peer="carol" state="connecting" />
      </.showcase_card>

      <.showcase_card title="Active" description="Successfully connected. Shows Disconnect button.">
        <.p2p_lobby peer="dave" state="active" />
      </.showcase_card>

      <.showcase_card title="Failed" description="Connection attempt failed. Shows Connect to retry.">
        <.p2p_lobby peer="eve" state="failed" />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
