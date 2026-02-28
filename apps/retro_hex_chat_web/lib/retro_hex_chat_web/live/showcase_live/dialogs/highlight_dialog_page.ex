defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.HighlightDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.HighlightDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Highlight Dialog",
       active_page: "highlight-dialog",
       words: [
         %{text: "important", color: "#ff0000"},
         %{text: "urgent", color: "#ff6600"},
         %{text: "mynick", color: "#0066ff"}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Highlight Dialog</h2>

      <.showcase_card
        title="Highlight Words"
        description="Manage highlight words with color assignments."
      >
        <.button variant="outline" phx-click={show_modal("highlight-demo")}>
          <:icon><Icons.icon_star class="w-4 h-4" /></:icon>
          Highlights
        </.button>
        <.highlight_dialog id="highlight-demo" words={@words} own_nick="MyNick" selected_color={4} />
        <.code_example>
          &lt;.highlight_dialog
          id="highlights"
          words=&#123;@words&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
