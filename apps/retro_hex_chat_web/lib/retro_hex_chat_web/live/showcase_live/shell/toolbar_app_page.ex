defmodule RetroHexChatWeb.ShowcaseLive.Shell.ToolbarAppPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ToolbarApp
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Toolbar App"),
       active_page: "toolbar-app",
       last_action: nil
     )}
  end

  @impl true
  def handle_event("toolbar-action", %{"action" => action}, socket) do
    {:noreply, assign(socket, last_action: action)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Toolbar App")}</h2>

      <.showcase_card
        title={gettext("Disconnected State")}
        description="Full application toolbar showing the Connect button when not connected."
      >
        <.toolbar_app connected={false} on_action="toolbar-action" />
        <.code_example>
          &lt;.toolbar_app connected=&#123;false&#125; on_action="toolbar-action" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Connected State (Admin)")}
        description="Toolbar with Disconnect button and admin option visible in the Options dropdown."
      >
        <.toolbar_app connected={true} is_admin={true} on_action="toolbar-action" />
        <.code_example>
          &lt;.toolbar_app connected=&#123;true&#125; is_admin=&#123;true&#125; on_action="toolbar-action" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Action Log")}
        description="Click any toolbar button to see its action value here."
      >
        <p class="text-sm">
          {gettext("Last action:")} <span class="font-bold font-mono">{@last_action || "none"}</span>
        </p>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
