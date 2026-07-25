defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AdminServerSettingsDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AdminServerSettingsDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Server Settings Dialog"),
       active_page: "admin-server-settings-dialog",
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
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Server Settings Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Server Settings")}
        description="Admin window rendered with its dialog frame."
      >
        <.button variant="outline" phx-click="toggle">
          <:icon><Icons.icon_server class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open Server Settings")}
        </.button>
        <.admin_server_settings_dialog
          id="admin-server-settings-demo"
          show={@open?}
          on_cancel="toggle"
        />
        <.code_example>
          &lt;.admin_server_settings_dialog id="admin-server-settings" show=&#123;@open?&#125; /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
