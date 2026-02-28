defmodule RetroHexChatWeb.ShowcaseLive.AliasDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AliasDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @sample_aliases [
    %{name: "hi", expansion: "/msg $1 hello!"},
    %{name: "bye", expansion: "/msg $1 goodbye!"},
    %{name: "away", expansion: "/away $1-"},
    %{name: "op", expansion: "/mode $chan +o $1"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Alias Dialog",
       active_page: "alias-dialog",
       aliases: @sample_aliases
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Alias Dialog</h2>

      <.showcase_card
        title="Default State"
        description="Alias editor with sample entries. No row selected — Edit and Remove buttons are disabled."
      >
        <.button variant="outline" phx-click={show_modal("alias-dialog-default")}>
          <:icon><Icons.icon_dialog_alias class="w-4 h-4" /></:icon>
          Open Alias Editor
        </.button>
        <.alias_dialog id="alias-dialog-default" aliases={@aliases} />
        <.code_example>
          &lt;.alias_dialog
          id="aliases"
          aliases=&#123;@aliases&#125;
          on_add="alias_add"
          on_edit="alias_edit"
          on_delete="alias_delete"
          on_save="alias_save"
          on_cancel_edit="alias_cancel"
          on_close="close_alias_dialog"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Row Selected"
        description="A row is selected (highlighted). Edit and Remove buttons become active."
      >
        <.button variant="outline" phx-click={show_modal("alias-dialog-selected")}>
          <:icon><Icons.icon_dialog_alias class="w-4 h-4" /></:icon>
          Open (Row Selected)
        </.button>
        <.alias_dialog
          id="alias-dialog-selected"
          aliases={@aliases}
          selected_alias="away"
        />
      </.showcase_card>

      <.showcase_card
        title="Editing State"
        description="Edit form panel is visible below the table. Form shows 'Edit Alias' with pre-filled values."
      >
        <.button variant="outline" phx-click={show_modal("alias-dialog-editing")}>
          <:icon><Icons.icon_dialog_alias class="w-4 h-4" /></:icon>
          Open (Editing)
        </.button>
        <.alias_dialog
          id="alias-dialog-editing"
          aliases={@aliases}
          selected_alias="hi"
          editing={true}
          draft_name="hi"
          draft_expansion="/msg $1 hello!"
        />
      </.showcase_card>

      <.showcase_card
        title="Adding New Alias"
        description="Edit form in 'add' mode — name field is editable, form shows 'Add Alias'."
      >
        <.button variant="outline" phx-click={show_modal("alias-dialog-adding")}>
          <:icon><Icons.icon_dialog_alias class="w-4 h-4" /></:icon>
          Open (Adding)
        </.button>
        <.alias_dialog
          id="alias-dialog-adding"
          aliases={@aliases}
          editing={true}
          draft_name=""
          draft_expansion=""
        />
      </.showcase_card>

      <.showcase_card
        title="Empty List"
        description="No aliases configured — table shows empty state message."
      >
        <.button variant="outline" phx-click={show_modal("alias-dialog-empty")}>
          <:icon><Icons.icon_dialog_alias class="w-4 h-4" /></:icon>
          Open (Empty)
        </.button>
        <.alias_dialog id="alias-dialog-empty" aliases={[]} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
