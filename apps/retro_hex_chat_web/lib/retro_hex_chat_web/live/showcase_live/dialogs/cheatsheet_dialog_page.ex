defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.CheatsheetDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.CheatsheetDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @sample_bindings [
    %{
      category: "Navigation",
      items: [
        %{action: "Focus input", keys: "Alt+I", description: "Jump to the chat input field"},
        %{
          action: "Next tab",
          keys: "Ctrl+Tab",
          description: "Switch to the next conversation tab"
        },
        %{action: "Prev tab", keys: "Ctrl+Shift+Tab", description: "Switch to the previous tab"},
        %{action: "Close tab", keys: "Ctrl+W", description: "Close the current tab"}
      ]
    },
    %{
      category: "Chat",
      items: [
        %{action: "Send message", keys: "Enter", description: "Send the composed message"},
        %{action: "History up", keys: "Up Arrow", description: "Recall previous message"},
        %{action: "History down", keys: "Down Arrow", description: "Recall next message"},
        %{action: "Search", keys: "Ctrl+F", description: "Open message search"}
      ]
    },
    %{
      category: "Help",
      items: [
        %{action: "Open help", keys: "F1", description: "Open the help topics dialog"},
        %{
          action: "Cheatsheet",
          keys: "Ctrl+/",
          description: "Show this keyboard shortcut reference"
        }
      ]
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Cheatsheet Dialog", active_page: "cheatsheet-dialog")}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :sample_bindings, @sample_bindings)

    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Cheatsheet Dialog</h2>

      <.showcase_card
        title="With Sample Shortcuts"
        description="Grouped keyboard shortcuts displayed in a table. Navigation, Chat, and Help categories."
      >
        <.button variant="outline" phx-click={show_modal("cheatsheet-sample")}>
          <:icon><Icons.icon_dialog_cheatsheet class="w-4 h-4" /></:icon>
          Open Cheatsheet
        </.button>
        <.cheatsheet_dialog id="cheatsheet-sample" bindings={@sample_bindings} />
        <.code_example>
          &lt;.cheatsheet_dialog
          id="cheatsheet"
          bindings=&#123;[
          %&#123;category: "Navigation",
          items: [%&#123;action: "Focus input", keys: "Alt+I", description: "Jump to input"&#125;]&#125;
          ]&#125;
          on_close="close_cheatsheet"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Empty State"
        description="Dialog with no shortcuts defined — shows placeholder message."
      >
        <.button variant="outline" phx-click={show_modal("cheatsheet-empty")}>
          <:icon><Icons.icon_dialog_cheatsheet class="w-4 h-4" /></:icon>
          Open Empty Cheatsheet
        </.button>
        <.cheatsheet_dialog id="cheatsheet-empty" bindings={[]} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
