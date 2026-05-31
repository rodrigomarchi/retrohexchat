defmodule RetroHexChatWeb.Components.UI.AliasDialog do
  @moduledoc """
  Alias configuration CRUD dialog for the showcase design system.

  Composed from dialog + table + button + input primitives.
  CRUD pattern: list (top) + edit form panel (bottom when editing).

  ## Usage

      <.alias_dialog
        id="aliases"
        show={true}
        aliases={[%{name: "hi", expansion: "/msg $1 hello!"}]}
        editing={false}
        on_add="alias_add"
        on_edit="alias_edit"
        on_delete="alias_delete"
        on_save="alias_save"
        on_cancel_edit="alias_cancel_edit"
        on_close="close_alias_dialog"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc "Renders the alias configuration CRUD dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :aliases, :list,
    default: [],
    doc: "List of alias maps with :name and :expansion keys"

  attr :selected_alias, :string, default: nil, doc: "Name of the currently selected alias"
  attr :editing, :boolean, default: false, doc: "True when the edit form is visible"
  attr :draft_name, :string, default: "", doc: "Current value of the name input in the edit form"

  attr :draft_expansion, :string,
    default: "",
    doc: "Current value of the expansion input in the edit form"

  attr :warning_message, :string, default: nil, doc: "Optional warning message to display"
  attr :error_message, :string, default: nil, doc: "Optional error message inside the edit form"
  attr :on_select, :any, default: nil, doc: "Row click callback (receives phx-value-name)"
  attr :on_add, :any, default: nil, doc: "Add button callback"
  attr :on_edit, :any, default: nil, doc: "Edit button callback"
  attr :on_delete, :any, default: nil, doc: "Remove button callback"
  attr :on_save, :any, default: nil, doc: "Save button callback inside the edit form"
  attr :on_cancel_edit, :any, default: nil, doc: "Cancel edit button callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"

  @spec alias_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def alias_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_close}>
      <.dialog_header id={@id} title={gettext("Alias Editor")} on_close={@on_close}>
        <:icon><Icons.icon_dialog_alias class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body class="space-y-retro-8">
        <%!-- Alias table --%>
        <div class="max-h-[200px] overflow-y-auto retro-scrollbar shadow-retro-sunken">
          <.table>
            <.table_header>
              <.table_row>
                <.table_head>{gettext("Name")}</.table_head>
                <.table_head>{gettext("Expansion")}</.table_head>
              </.table_row>
            </.table_header>
            <.table_body>
              <tr :if={@aliases == []}>
                <td colspan="2" class="p-4 text-center text-muted-foreground text-xs">
                  {gettext("No aliases configured. Click \"Add\" to create one.")}
                </td>
              </tr>
              <.table_row
                :for={entry <- @aliases}
                data-testid="alias-row"
                data-alias-name={entry.name}
                class={
                  if(entry.name == @selected_alias,
                    do: "bg-selection-bg text-selection-fg cursor-pointer",
                    else: "cursor-pointer"
                  )
                }
                phx-click={@on_select}
                phx-value-name={entry.name}
              >
                <.table_cell class="font-mono text-xs">/{entry.name}</.table_cell>
                <.table_cell class="text-xs truncate max-w-[180px]">{entry.expansion}</.table_cell>
              </.table_row>
            </.table_body>
          </.table>
        </div>

        <%!-- Warning message --%>
        <div
          :if={@warning_message}
          data-testid="alias-warning"
          class="text-xs text-warning font-bold px-retro-2"
        >
          {@warning_message}
        </div>

        <%!-- Edit / Add form panel --%>
        <form
          :if={@editing}
          phx-submit={@on_save}
          data-testid="alias-edit-form"
          class="shadow-retro-field bg-white p-retro-8 space-y-retro-4"
        >
          <h3 class="font-bold text-xs mb-retro-4">
            {if @selected_alias, do: gettext("Edit Alias"), else: gettext("Add Alias")}
          </h3>

          <div class="space-y-retro-4">
            <div>
              <label class="text-xs font-bold block mb-retro-2">{gettext("Name")}</label>
              <.input
                type="text"
                name="name"
                value={@draft_name}
                placeholder={gettext("e.g. hi")}
                data-testid="alias-name-input"
                class="w-full text-xs h-7"
                maxlength="30"
                disabled={@selected_alias != nil}
              />
            </div>
            <div>
              <label class="text-xs font-bold block mb-retro-2">{gettext("Expansion")}</label>
              <.input
                type="text"
                name="expansion"
                value={@draft_expansion}
                placeholder={gettext("e.g. /msg $1 hello!")}
                data-testid="alias-expansion-input"
                class="w-full text-xs h-7"
                maxlength="500"
              />
            </div>
            <p class="text-[10px] text-muted-foreground">
              {gettext("Variables: $1–$9 (args), $nick (your nick), $chan (channel)")}
            </p>
          </div>

          <div
            :if={@error_message}
            data-testid="alias-error"
            class="text-xs text-destructive font-bold"
          >
            {@error_message}
          </div>

          <div class="flex gap-retro-4 pt-retro-4">
            <.button type="submit" size="sm" variant="default">
              <:icon><Icons.icon_btn_save class="w-4 h-4" /></:icon>
              {gettext("Save")}
            </.button>
            <.button type="button" size="sm" variant="outline" phx-click={@on_cancel_edit}>
              <:icon><Icons.icon_btn_cancel class="w-4 h-4" /></:icon>
              {gettext("Cancel")}
            </.button>
          </div>
        </form>

        <%!-- Action buttons --%>
        <div class="flex gap-retro-4">
          <.button size="sm" variant="outline" phx-click={@on_add}>
            <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
            {gettext("Add")}
          </.button>
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_edit}
            disabled={@selected_alias == nil}
          >
            <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
            {gettext("Edit")}
          </.button>
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_delete}
            disabled={@selected_alias == nil}
          >
            <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
            {gettext("Remove")}
          </.button>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {gettext("Close")}
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
