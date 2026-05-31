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
      category: dgettext("showcase", "Navigation"),
      items: [
        %{
          action: dgettext("showcase", "Focus input"),
          keys: "Alt+I",
          description: dgettext("showcase", "Jump to the chat input field")
        },
        %{
          action: dgettext("showcase", "Next tab"),
          keys: "Ctrl+Tab",
          description: dgettext("showcase", "Switch to the next conversation tab")
        },
        %{
          action: dgettext("showcase", "Prev tab"),
          keys: "Ctrl+Shift+Tab",
          description: dgettext("showcase", "Switch to the previous tab")
        },
        %{
          action: dgettext("showcase", "Close tab"),
          keys: "Ctrl+W",
          description: dgettext("showcase", "Close the current tab")
        }
      ]
    },
    %{
      category: dgettext("showcase", "Chat"),
      items: [
        %{
          action: dgettext("showcase", "Send message"),
          keys: "Enter",
          description: dgettext("showcase", "Send the composed message")
        },
        %{
          action: dgettext("showcase", "History up"),
          keys: dgettext("showcase", "Up Arrow"),
          description: dgettext("showcase", "Recall previous message")
        },
        %{
          action: dgettext("showcase", "History down"),
          keys: dgettext("showcase", "Down Arrow"),
          description: dgettext("showcase", "Recall next message")
        },
        %{
          action: dgettext("showcase", "Search"),
          keys: "Ctrl+F",
          description: dgettext("showcase", "Open message search")
        }
      ]
    },
    %{
      category: dgettext("showcase", "Help"),
      items: [
        %{
          action: dgettext("showcase", "Open help"),
          keys: dgettext("showcase", "Menu"),
          description: dgettext("showcase", "Open the help topics dialog")
        },
        %{
          action: dgettext("showcase", "Cheatsheet"),
          keys: "Ctrl+/",
          description: dgettext("showcase", "Show this keyboard shortcut reference")
        }
      ]
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Cheatsheet Dialog"),
       active_page: "cheatsheet-dialog"
     )}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :sample_bindings, @sample_bindings)

    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Cheatsheet Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "With Sample Shortcuts")}
        description="Grouped keyboard shortcuts displayed in a table. Navigation, Chat, and Help categories."
      >
        <.button variant="outline" phx-click={show_modal("cheatsheet-sample")}>
          <:icon><Icons.icon_dialog_cheatsheet class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open Cheatsheet")}
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
        title={dgettext("showcase", "Empty State")}
        description="Dialog with no shortcuts defined — shows placeholder message."
      >
        <.button variant="outline" phx-click={show_modal("cheatsheet-empty")}>
          <:icon><Icons.icon_dialog_cheatsheet class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Open Empty Cheatsheet")}
        </.button>
        <.cheatsheet_dialog id="cheatsheet-empty" bindings={[]} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
