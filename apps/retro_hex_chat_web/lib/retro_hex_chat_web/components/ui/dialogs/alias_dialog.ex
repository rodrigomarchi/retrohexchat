defmodule RetroHexChatWeb.Components.UI.AliasDialog do
  @moduledoc """
  Alias configuration CRUD dialog for the showcase design system.

  Composed from dialog + button + input primitives.
  CRUD pattern: mobile-first list + responsive edit form panel.

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
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Textarea

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
      <.dialog_header id={@id} title={dgettext("dialogs", "Alias Editor")} on_close={@on_close}>
        <:icon><Icons.icon_dialog_alias class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <.alias_panel
          id={@id}
          aliases={@aliases}
          selected_alias={@selected_alias}
          editing={@editing}
          draft_name={@draft_name}
          draft_expansion={@draft_expansion}
          warning_message={@warning_message}
          error_message={@error_message}
          on_select={@on_select}
          on_add={@on_add}
          on_edit={@on_edit}
          on_delete={@on_delete}
          on_save={@on_save}
          on_cancel_edit={@on_cancel_edit}
          on_close={@on_close}
        />
      </.dialog_body>
    </.dialog>
    """
  end

  @doc """
  Renders the alias editor content (table + CRUD + edit form) without any
  frame — compose it inside a dialog or a desktop window body.
  """
  attr :id, :string, required: true
  attr :aliases, :list, default: []
  attr :selected_alias, :string, default: nil
  attr :editing, :boolean, default: false
  attr :draft_name, :string, default: ""
  attr :draft_expansion, :string, default: ""
  attr :warning_message, :string, default: nil
  attr :error_message, :string, default: nil
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_delete, :any, default: nil
  attr :on_save, :any, default: nil
  attr :on_cancel_edit, :any, default: nil
  attr :on_close, :any, default: nil

  @spec alias_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def alias_panel(assigns) do
    ~H"""
    <div id={"#{@id}-panel-root"} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="alias-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="al-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <div class={
            classes([
              "al-editor min-h-0 flex-1",
              @editing && "al-editor--editing"
            ])
          }>
            <div class="al-list-pane min-h-0">
              <div class="al-entry-list overflow-y-auto retro-scrollbar">
                <div :if={@aliases == []} class="al-empty-state text-center text-muted-foreground">
                  {dgettext("dialogs", "No aliases configured. Click \"Add\" to create one.")}
                </div>

                <button
                  :for={entry <- @aliases}
                  type="button"
                  data-testid="alias-row"
                  data-alias-name={entry.name}
                  aria-pressed={entry.name == @selected_alias}
                  aria-label={"/#{entry.name}"}
                  class={alias_entry_class(entry.name == @selected_alias)}
                  phx-click={@on_select}
                  phx-value-name={entry.name}
                >
                  <span class="al-entry-name">/{entry.name}</span>
                  <span class="al-entry-expansion">
                    <span class="al-entry-expansion-label">
                      {dgettext("dialogs", "Expansion")}
                    </span>
                    <code>{entry.expansion}</code>
                  </span>
                </button>
              </div>

              <div
                :if={@warning_message}
                data-testid="alias-warning"
                class="al-warning text-xs text-warning font-bold"
              >
                {@warning_message}
              </div>

              <div class="al-action-row flex gap-retro-4">
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_add}
                  class="al-action-button"
                >
                  <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Add")}
                </.button>
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_edit}
                  disabled={@selected_alias == nil}
                  class="al-action-button"
                >
                  <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Edit")}
                </.button>
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_delete}
                  disabled={@selected_alias == nil}
                  class="al-action-button"
                >
                  <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Remove")}
                </.button>
              </div>
            </div>

            <form
              :if={@editing}
              phx-submit={@on_save}
              data-testid="alias-edit-form"
              class="al-edit-form shadow-retro-field bg-white p-retro-8"
            >
              <h3 class="font-bold text-xs">
                {if @selected_alias,
                  do: dgettext("dialogs", "Edit Alias"),
                  else: dgettext("dialogs", "Add Alias")}
              </h3>

              <div class="al-form-fields">
                <div class="al-field">
                  <label class="al-form-label" for={"#{@id}-name-input"}>
                    {dgettext("dialogs", "Name")}
                  </label>
                  <.input
                    id={"#{@id}-name-input"}
                    type="text"
                    name="name"
                    value={@draft_name}
                    placeholder={dgettext("dialogs", "e.g. hi")}
                    data-testid="alias-name-input"
                    class="al-input w-full text-xs h-7"
                    maxlength="30"
                    disabled={@selected_alias != nil}
                  />
                </div>
                <div class="al-field">
                  <label class="al-form-label" for={"#{@id}-expansion-input"}>
                    {dgettext("dialogs", "Expansion")}
                  </label>
                  <.textarea
                    id={"#{@id}-expansion-input"}
                    name="expansion"
                    value={@draft_expansion}
                    placeholder={dgettext("dialogs", "e.g. /msg $1 hello!")}
                    data-testid="alias-expansion-input"
                    class="al-input al-expansion-input w-full resize-none text-xs"
                    maxlength="500"
                    rows="3"
                  />
                </div>
                <p class="al-hint text-[10px] text-muted-foreground">
                  {dgettext("dialogs", "Variables: $1–$9 (args), $nick (your nick), $chan (channel)")}
                </p>
              </div>

              <div
                :if={@error_message}
                data-testid="alias-error"
                class="al-error text-xs text-destructive font-bold"
              >
                {@error_message}
              </div>

              <div class="al-form-actions flex gap-retro-4 pt-retro-4">
                <.button type="submit" size="sm" variant="default" class="al-action-button">
                  <:icon><Icons.icon_btn_save class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Save")}
                </.button>
                <.button
                  type="button"
                  size="sm"
                  variant="outline"
                  phx-click={@on_cancel_edit}
                  class="al-action-button"
                >
                  <:icon><Icons.icon_btn_cancel class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Cancel")}
                </.button>
              </div>
            </form>
          </div>

          <div :if={@on_close} class="al-dialog-footer flex justify-end">
            <.button type="button" size="sm" phx-click={@on_close} class="al-action-button">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  defp alias_entry_class(true), do: "al-alias-entry bg-selection-bg text-selection-fg"
  defp alias_entry_class(false), do: "al-alias-entry"
end
