defmodule RetroHexChatWeb.ShowcaseLive.AdminConsolePage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AdminConsole
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Admin Console",
       active_page: "admin-console",
       log_lines: [
         "RetroHexChat Admin Console v2.1.0",
         "Type 'help' for available commands.",
         "",
         "> stats",
         "Users online: 142",
         "Channels active: 38",
         "Uptime: 14d 6h 23m",
         "Memory: 256 MB / 1024 MB",
         "",
         "> channels #lobby",
         "#lobby: 42 users, topic: \"Welcome!\""
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Admin Console</h2>

      <.showcase_card
        title="Admin Console"
        description="Terminal-like interface for server administration."
      >
        <.button variant="outline" phx-click={show_modal("admin-console-demo")}>
          <:icon><Icons.icon_terminal class="w-4 h-4" /></:icon>
          Admin Console
        </.button>
        <.admin_console id="admin-console-demo" lines={@log_lines} />
        <.code_example>
          &lt;.admin_console id="admin-console" lines={@log_lines} /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
