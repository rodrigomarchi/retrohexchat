defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AdminConsoleDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AdminConsoleDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Admin Console Dialog"),
       active_page: "admin-console-dialog",
       show_console: false,
       results: [
         %{
           line: "help",
           status: :ok,
           message: dgettext("showcase", "Available commands: kick, ban, mute, stats")
         },
         %{
           line: "stats",
           status: :ok,
           message: dgettext("showcase", "Users: 42, Channels: 8, Uptime: 3d 12h")
         },
         %{
           line: "invalid",
           status: :error,
           message: dgettext("showcase", "Unknown command: invalid")
         }
       ]
     )}
  end

  @impl true
  def handle_event("toggle_console", _params, socket) do
    {:noreply, assign(socket, show_console: !socket.assigns.show_console)}
  end

  def handle_event("close_admin_console", _params, socket) do
    {:noreply, assign(socket, show_console: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Admin Console Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Admin Console")}
        description="Command-line style admin interface with terminal output."
      >
        <.button variant="outline" phx-click="toggle_console">
          <:icon><Icons.icon_dialog_admin_console class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open Admin Console")}
        </.button>
        <.admin_console_dialog
          id="admin-console-demo"
          show={@show_console}
          results={@results}
          on_close="toggle_console"
        />
        <.code_example>
          &lt;.admin_console_dialog
          id="admin-console"
          show=&#123;@show_console&#125;
          results=&#123;@results&#125;
          on_close="close_admin_console"
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
