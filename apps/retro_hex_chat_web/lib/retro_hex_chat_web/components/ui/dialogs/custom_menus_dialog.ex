defmodule RetroHexChatWeb.Components.UI.CustomMenusDialog do
  @moduledoc """
  Custom context menu editor dialog component for the showcase design system.

  Composed from dialog + tabs + table + button + input primitives.
  Three tabs: Nicklist, Channel, and Chat. Each tab lists custom menu entries
  (label + command) filtered by menu_type. Supports CRUD and an inline edit form.

  ## Usage

      <.custom_menus_dialog
        id="custom-menus"
        show={true}
        entries={@entries}
        active_tab={:nicklist}
        on_tab="cm-tab"
        on_add="cm-add"
        on_close="cm-close"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc "Renders the custom menus dialog with Nicklist/Channel tabs."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :active_tab, :atom,
    default: :nicklist,
    values: [:nicklist, :channel, :chat],
    doc: "Currently active tab"

  attr :entries, :list,
    default: [],
    doc: "List of %{label, command, menu_type, position} maps"

  attr :selected_item, :string, default: nil, doc: "Currently selected entry label"
  attr :editing, :boolean, default: false, doc: "True when edit form is visible"
  attr :draft_label, :string, default: "", doc: "Draft label for edit form"
  attr :draft_command, :string, default: "", doc: "Draft command for edit form"
  attr :error_message, :string, default: nil, doc: "Validation error to display in the form"

  attr :on_tab, :any, default: nil, doc: "Tab change callback (phx-value-tab)"
  attr :on_select, :any, default: nil, doc: "Row click callback (phx-value-label)"
  attr :on_add, :any, default: nil, doc: "Add button callback"
  attr :on_edit, :any, default: nil, doc: "Edit button callback"
  attr :on_delete, :any, default: nil, doc: "Remove button callback"
  attr :on_save, :any, default: nil, doc: "Save edit callback"
  attr :on_cancel_edit, :any, default: nil, doc: "Cancel edit callback"
  attr :on_close, :any, default: nil, doc: "Close (X) button callback"

  @spec custom_menus_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def custom_menus_dialog(assigns) do
    assigns =
      assign(assigns, :active_tab_str, Atom.to_string(assigns.active_tab))

    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_close}>
      <.dialog_header id={@id} title={dgettext("dialogs", "Custom Menus")} on_close={@on_close}>
        <:icon><Icons.icon_dialog_custom_menus class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <.custom_menus_panel
          id={@id}
          active_tab={@active_tab}
          entries={@entries}
          selected_item={@selected_item}
          editing={@editing}
          draft_label={@draft_label}
          draft_command={@draft_command}
          error_message={@error_message}
          on_tab={@on_tab}
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
  Renders the custom menus editor (tabs + CRUD + edit form) without any frame — compose it inside a dialog or a
  desktop window body.
  """
  attr :id, :string, required: true
  attr :active_tab, :any, default: nil
  attr :entries, :any, default: nil
  attr :selected_item, :any, default: nil
  attr :editing, :any, default: nil
  attr :draft_label, :any, default: nil
  attr :draft_command, :any, default: nil
  attr :error_message, :any, default: nil
  attr :on_tab, :any, default: nil
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_delete, :any, default: nil
  attr :on_save, :any, default: nil
  attr :on_cancel_edit, :any, default: nil
  attr :on_close, :any, default: nil

  @spec custom_menus_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def custom_menus_panel(assigns) do
    assigns = assign(assigns, :active_tab_str, Atom.to_string(assigns.active_tab))

    ~H"""
    <div id={@id} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="custom-menus-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="cm-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <.tabs :let={builder} id={"#{@id}-tabs"} default={@active_tab_str} class="cm-tabs min-h-0">
            <div class="cm-tabs-shell">
              <.tabs_list class="cm-main-tabs">
                <.tabs_trigger
                  builder={builder}
                  value="nicklist"
                  phx-click={@on_tab}
                  phx-value-tab="nicklist"
                >
                  <:icon><Icons.icon_tab_nicklist class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Nicklist")}
                </.tabs_trigger>
                <.tabs_trigger
                  builder={builder}
                  value="channel"
                  phx-click={@on_tab}
                  phx-value-tab="channel"
                >
                  <:icon><Icons.icon_tab_channel class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Channel")}
                </.tabs_trigger>
                <.tabs_trigger
                  builder={builder}
                  value="chat"
                  phx-click={@on_tab}
                  phx-value-tab="chat"
                >
                  <:icon><Icons.icon_tab_pm class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Chat")}
                </.tabs_trigger>
              </.tabs_list>
            </div>

            <%!-- Nicklist Tab --%>
            <.tabs_content value="nicklist" class="cm-tab-content">
              <.menu_entries_section
                id={@id}
                entries={filter_entries(@entries, :nicklist)}
                selected_item={if(@active_tab == :nicklist, do: @selected_item)}
                editing={@editing && @active_tab == :nicklist}
                draft_label={@draft_label}
                draft_command={@draft_command}
                error_message={@error_message}
                on_select={@on_select}
                on_add={@on_add}
                on_edit={@on_edit}
                on_delete={@on_delete}
                on_save={@on_save}
                on_cancel_edit={@on_cancel_edit}
              />
            </.tabs_content>

            <%!-- Channel Tab --%>
            <.tabs_content value="channel" class="cm-tab-content">
              <.menu_entries_section
                id={@id}
                entries={filter_entries(@entries, :channel)}
                selected_item={if(@active_tab == :channel, do: @selected_item)}
                editing={@editing && @active_tab == :channel}
                draft_label={@draft_label}
                draft_command={@draft_command}
                error_message={@error_message}
                on_select={@on_select}
                on_add={@on_add}
                on_edit={@on_edit}
                on_delete={@on_delete}
                on_save={@on_save}
                on_cancel_edit={@on_cancel_edit}
              />
            </.tabs_content>

            <%!-- Chat Tab --%>
            <.tabs_content value="chat" class="cm-tab-content">
              <.menu_entries_section
                id={@id}
                entries={filter_entries(@entries, :chat)}
                selected_item={if(@active_tab == :chat, do: @selected_item)}
                editing={@editing && @active_tab == :chat}
                draft_label={@draft_label}
                draft_command={@draft_command}
                error_message={@error_message}
                on_select={@on_select}
                on_add={@on_add}
                on_edit={@on_edit}
                on_delete={@on_delete}
                on_save={@on_save}
                on_cancel_edit={@on_cancel_edit}
              />
            </.tabs_content>
          </.tabs>

          <div class="cm-dialog-footer flex justify-end">
            <.button type="button" size="sm" phx-click={@on_close} class="cm-action-button">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  # ── Menu Entries Section ─────────────────────────────

  attr :id, :string, required: true
  attr :entries, :list, required: true
  attr :selected_item, :string, default: nil
  attr :editing, :boolean, default: false
  attr :draft_label, :string, default: ""
  attr :draft_command, :string, default: ""
  attr :error_message, :string, default: nil
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_delete, :any, default: nil
  attr :on_save, :any, default: nil
  attr :on_cancel_edit, :any, default: nil

  defp menu_entries_section(assigns) do
    ~H"""
    <div class="cm-editor flex gap-retro-8">
      <%!-- Entries list --%>
      <div class="cm-list-pane flex-1 space-y-retro-4">
        <div
          class="cm-entry-list max-h-[220px] overflow-y-auto retro-scrollbar"
          aria-label={dgettext("dialogs", "Custom menu entries")}
        >
          <div :if={@entries == []} class="cm-empty-state text-center text-muted-foreground">
            {dgettext("dialogs", "No custom menu entries yet.")}
          </div>

          <button
            :for={entry <- @entries}
            type="button"
            data-testid="custom-menu-row"
            data-menu-type={entry.menu_type}
            data-menu-label={entry.label}
            aria-pressed={@selected_item == entry.label}
            class={row_class("cm-menu-entry", @selected_item == entry.label)}
            phx-click={@on_select}
            phx-value-label={entry.label}
          >
            <span class="cm-entry-label">{entry.label}</span>
            <span class="cm-entry-command">
              <span class="cm-entry-command-label">{dgettext("dialogs", "Command")}</span>
              <code>{entry.command}</code>
            </span>
          </button>
        </div>

        <div class="cm-action-row flex gap-retro-4">
          <.button size="sm" variant="outline" phx-click={@on_add} class="cm-action-button">
            <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Add")}
          </.button>
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_edit}
            disabled={@selected_item == nil}
            class="cm-action-button"
          >
            <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Edit")}
          </.button>
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_delete}
            disabled={@selected_item == nil}
            class="cm-action-button"
          >
            <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Remove")}
          </.button>
        </div>
      </div>

      <%!-- Edit form --%>
      <form
        :if={@editing}
        phx-submit={@on_save}
        data-testid="custom-menu-edit-form"
        class="cm-edit-form shrink-0 shadow-retro-field bg-white p-retro-8 space-y-retro-8"
      >
        <h3 class="font-bold text-xs mb-retro-4">
          {if @selected_item == nil,
            do: dgettext("dialogs", "Add Entry"),
            else: dgettext("dialogs", "Edit Entry")}
        </h3>

        <div class="space-y-retro-4">
          <div>
            <label class="cm-form-label text-xs font-bold block mb-retro-2">
              {dgettext("dialogs", "Label")}
            </label>
            <.input
              type="text"
              name="label"
              value={@draft_label}
              placeholder={dgettext("dialogs", "Menu item text")}
              data-testid="custom-menu-label-input"
              class="cm-input w-full"
              maxlength="50"
            />
          </div>

          <div>
            <label class="cm-form-label text-xs font-bold block mb-retro-2">
              {dgettext("dialogs", "Command")}
            </label>
            <.input
              type="text"
              name="command"
              value={@draft_command}
              placeholder={dgettext("dialogs", "/command $1")}
              data-testid="custom-menu-command-input"
              class="cm-input w-full"
              maxlength="500"
            />
          </div>

          <p :if={@error_message} data-testid="custom-menu-error" class="text-xs text-destructive">
            {@error_message}
          </p>

          <div class="cm-form-actions flex gap-retro-4 pt-retro-4">
            <.button type="submit" size="sm" variant="default" class="cm-action-button">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Save")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click={@on_cancel_edit}
              class="cm-action-button"
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </div>
      </form>
    </div>
    """
  end

  @spec filter_entries(list(), atom()) :: list()
  defp filter_entries(entries, menu_type) do
    Enum.filter(entries, &(Map.get(&1, :menu_type) == menu_type))
  end

  defp row_class(base, true), do: "#{base} bg-selection-bg text-selection-fg"
  defp row_class(base, false), do: base
end
