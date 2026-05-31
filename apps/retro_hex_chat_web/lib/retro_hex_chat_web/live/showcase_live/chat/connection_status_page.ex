defmodule RetroHexChatWeb.ShowcaseLive.Chat.ConnectionStatusPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ConnectionStatus
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Connection Status"),
       active_page: "connection-status"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Connection Status")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Connected")}
        description="Successfully connected to server."
      >
        <.connection_status state="connected" server="irc.example.com" />
        <.code_example>
          &lt;.connection_status state="connected" server="irc.example.com" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Reconnecting")}
        description="Attempting to reconnect with progress."
      >
        <.connection_status state="reconnecting" attempt={3} max_attempts={5} />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Disconnected")}
        description="Connection lost with reconnect button."
      >
        <.connection_status state="disconnected" />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
