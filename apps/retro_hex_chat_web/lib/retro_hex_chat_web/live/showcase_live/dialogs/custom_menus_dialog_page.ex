defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.CustomMenusDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.CustomMenusDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Custom Menus Dialog",
       active_page: "custom-menus-dialog",
       entries: [
         %{label: "Whois", command: "/whois $1", menu_type: :nicklist, position: 1},
         %{
           label: "Slap",
           command: "/me slaps $1 with a large trout",
           menu_type: :nicklist,
           position: 2
         },
         %{label: "Private Message", command: "/query $1", menu_type: :nicklist, position: 3},
         %{label: "Get Topic", command: "/topic $chan", menu_type: :channel, position: 4},
         %{label: "Leave Channel", command: "/part $chan Bye!", menu_type: :channel, position: 5}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Custom Menus Dialog</h2>

      <.showcase_card
        title="Nicklist Tab"
        description="Custom context menus editor. Nicklist tab shown by default with sample entries."
      >
        <.button variant="outline" phx-click={show_modal("custom-menus-nicklist")}>
          <:icon><Icons.icon_dialog_custom_menus class="w-4 h-4" /></:icon>
          Open Custom Menus (Nicklist)
        </.button>
        <.custom_menus_dialog
          id="custom-menus-nicklist"
          entries={@entries}
          active_tab={:nicklist}
        />
        <.code_example>
          &lt;.custom_menus_dialog
          id="custom-menus"
          entries=&#123;@entries&#125;
          active_tab=&#123;:nicklist&#125;
          on_tab="cm-tab"
          on_select="cm-select"
          on_add="cm-add"
          on_edit="cm-edit"
          on_delete="cm-delete"
          on_save="cm-save"
          on_cancel_edit="cm-cancel"
          on_close="cm-close"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Channel Tab"
        description="Channel context menu entries, filtered to menu_type: :channel."
      >
        <.button variant="outline" phx-click={show_modal("custom-menus-channel")}>
          <:icon><Icons.icon_dialog_custom_menus class="w-4 h-4" /></:icon>
          Open Custom Menus (Channel)
        </.button>
        <.custom_menus_dialog
          id="custom-menus-channel"
          entries={@entries}
          active_tab={:channel}
        />
      </.showcase_card>

      <.showcase_card
        title="Editing State"
        description="Edit form visible on the nicklist tab with a selected item pre-populated."
      >
        <.button variant="outline" phx-click={show_modal("custom-menus-editing")}>
          <:icon><Icons.icon_dialog_custom_menus class="w-4 h-4" /></:icon>
          Open Custom Menus (Editing)
        </.button>
        <.custom_menus_dialog
          id="custom-menus-editing"
          entries={@entries}
          active_tab={:nicklist}
          selected_item="Whois"
          editing={true}
          draft_label="Whois"
          draft_command="/whois $1"
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
