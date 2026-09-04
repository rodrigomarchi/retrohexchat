defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.CheatsheetDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.CheatsheetDialog
  import RetroHexChatWeb.ShowcaseHelpers

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
        <div class="h-[320px] shadow-retro-field overflow-hidden p-2 flex flex-col">
          <.cheatsheet_panel id="cheatsheet-sample" bindings={@sample_bindings} />
        </div>
        <.code_example>
          &lt;.cheatsheet_panel
          id="cheatsheet"
          bindings=&#123;[
          %&#123;category: "Navigation",
          items: [%&#123;action: "Focus input", keys: "Alt+I", description: "Jump to input"&#125;]&#125;
          ]&#125;
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Empty State")}
        description="Dialog with no shortcuts defined — shows placeholder message."
      >
        <div class="shadow-retro-field overflow-hidden p-2">
          <.cheatsheet_panel id="cheatsheet-empty" bindings={[]} />
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}
end
