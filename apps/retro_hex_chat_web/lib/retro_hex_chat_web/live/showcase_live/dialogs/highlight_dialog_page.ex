defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.HighlightDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.HighlightDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChat.Chat.HighlightWord
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Highlight Dialog"),
       active_page: "highlight-dialog",
       words: [
         HighlightWord.new(word: "important", bg_color: 4, position: 0),
         HighlightWord.new(word: "urgent", bg_color: 7, position: 1),
         HighlightWord.new(word: "mynick", bg_color: 12, position: 2)
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Highlight Dialog")}</h2>

      <.showcase_card
        title={gettext("Highlight Words")}
        description="Manage highlight words with color assignments."
      >
        <.button variant="outline" phx-click={show_modal("highlight-demo")}>
          <:icon><Icons.icon_star class="w-4 h-4" /></:icon>
          {gettext("Highlights")}
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
