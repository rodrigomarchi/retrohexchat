defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.OptionsDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.OptionsDialog
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Options Dialog",
       active_page: "options-dialog",
       options_draft: %{
         display: %{
           show_toolbar: true,
           show_conversations: true,
           show_switchbar: true,
           show_statusbar: true
         }
       }
     )}
  end

  @impl true
  def handle_event("options_toggle_display", %{"setting" => setting}, socket) do
    key = String.to_existing_atom(setting)
    draft = socket.assigns.options_draft
    current = Map.get(draft.display, key)
    new_display = Map.put(draft.display, key, !current)
    {:noreply, assign(socket, options_draft: %{draft | display: new_display})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Options Dialog</h2>

      <.showcase_card
        title="Options Dialog"
        description="Tree-view navigation with settings panels."
      >
        <.button variant="outline" phx-click={show_modal("options-demo")}>
          <:icon><Icons.icon_dialog_options class="w-4 h-4" /></:icon>
          Open Options
        </.button>
        <.options_dialog
          id="options-demo"
          active_panel="display"
          options_draft={@options_draft}
        />
        <.code_example>
          &lt;.options_dialog
          id="options"
          active_panel="display"
          options_draft=&#123;@options_draft&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
