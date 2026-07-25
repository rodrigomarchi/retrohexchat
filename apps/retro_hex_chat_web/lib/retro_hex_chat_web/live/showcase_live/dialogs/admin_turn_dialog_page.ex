defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AdminTurnDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AdminTurnDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "TURN Dialog"),
       active_page: "admin-turn-dialog",
       open?: false
     )}
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    {:noreply, assign(socket, open?: !socket.assigns.open?)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "TURN Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "TURN")}
        description="Admin window rendered with its dialog frame."
      >
        <.button variant="outline" phx-click="toggle">
          <:icon><Icons.icon_websocket class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open TURN")}
        </.button>
        <.admin_turn_dialog id="admin-turn-demo" show={@open?} on_cancel="toggle" />
        <.code_example>
          &lt;.admin_turn_dialog id="admin-turn" show=&#123;@open?&#125; /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
