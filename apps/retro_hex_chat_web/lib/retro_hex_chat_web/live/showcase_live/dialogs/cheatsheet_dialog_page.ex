defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.CheatsheetDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

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
      category: gettext("Navigation"),
      items: [
        %{
          action: gettext("Focus input"),
          keys: "Alt+I",
          description: gettext("Jump to the chat input field")
        },
        %{
          action: gettext("Next tab"),
          keys: "Ctrl+Tab",
          description: gettext("Switch to the next conversation tab")
        },
        %{
          action: gettext("Prev tab"),
          keys: "Ctrl+Shift+Tab",
          description: gettext("Switch to the previous tab")
        },
        %{
          action: gettext("Close tab"),
          keys: "Ctrl+W",
          description: gettext("Close the current tab")
        }
      ]
    },
    %{
      category: gettext("Chat"),
      items: [
        %{
          action: gettext("Send message"),
          keys: "Enter",
          description: gettext("Send the composed message")
        },
        %{
          action: gettext("History up"),
          keys: gettext("Up Arrow"),
          description: gettext("Recall previous message")
        },
        %{
          action: gettext("History down"),
          keys: gettext("Down Arrow"),
          description: gettext("Recall next message")
        },
        %{action: gettext("Search"), keys: "Ctrl+F", description: gettext("Open message search")}
      ]
    },
    %{
      category: gettext("Help"),
      items: [
        %{
          action: gettext("Open help"),
          keys: gettext("Menu"),
          description: gettext("Open the help topics dialog")
        },
        %{
          action: gettext("Cheatsheet"),
          keys: "Ctrl+/",
          description: gettext("Show this keyboard shortcut reference")
        }
      ]
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: gettext("Cheatsheet Dialog"), active_page: "cheatsheet-dialog")}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :sample_bindings, @sample_bindings)

    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Cheatsheet Dialog")}</h2>

      <.showcase_card
        title={gettext("With Sample Shortcuts")}
        description="Grouped keyboard shortcuts displayed in a table. Navigation, Chat, and Help categories."
      >
        <.button variant="outline" phx-click={show_modal("cheatsheet-sample")}>
          <:icon><Icons.icon_dialog_cheatsheet class="w-4 h-4" /></:icon>
          {gettext("Open Cheatsheet")}
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
        title={gettext("Empty State")}
        description="Dialog with no shortcuts defined — shows placeholder message."
      >
        <.button variant="outline" phx-click={show_modal("cheatsheet-empty")}>
          <:icon><Icons.icon_dialog_cheatsheet class="w-4 h-4" /></:icon>
          {gettext("Open Empty Cheatsheet")}
        </.button>
        <.cheatsheet_dialog id="cheatsheet-empty" bindings={[]} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
