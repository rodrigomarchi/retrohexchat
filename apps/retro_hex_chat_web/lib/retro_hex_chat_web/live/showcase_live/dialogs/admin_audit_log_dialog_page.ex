defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AdminAuditLogDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AdminAuditLogDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Audit Log Dialog"),
       active_page: "admin-audit-log-dialog",
       open?: false
     )}
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    {:noreply, assign(socket, open?: !socket.assigns.open?)}
  end

  # Anything else this page draws has nowhere to go; answering it keeps a
  # click from taking the page down with an unmatched event.
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Audit Log Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Audit Log")}
        description="Admin window rendered with its dialog frame."
      >
        <.button variant="outline" phx-click="toggle">
          <:icon><Icons.icon_notepad class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open Audit Log")}
        </.button>
        <.admin_audit_log_dialog id="admin-audit-log-demo" show={@open?} on_cancel="toggle" />
        <.code_example>
          &lt;.admin_audit_log_dialog id="admin-audit-log" show=&#123;@open?&#125; /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
