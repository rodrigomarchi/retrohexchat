defmodule RetroHexChatWeb.Components.UI.CustomMenusDialog do
  @moduledoc """
  Custom context menu editor dialog component for the showcase design system.

  Composed from dialog + tabs + table + button + input primitives.
  Two tabs: Nicklist and Channel. Each tab lists custom menu entries
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
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc "Renders the custom menus dialog with Nicklist/Channel tabs."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :active_tab, :atom,
    default: :nicklist,
    values: [:nicklist, :channel],
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
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title="Custom Menus">
        <:icon><Icons.icon_dialog_custom_menus class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body class="space-y-retro-8">
        <.tabs :let={builder} id={"#{@id}-tabs"} default={@active_tab_str}>
          <.tabs_list>
            <.tabs_trigger
              builder={builder}
              value="nicklist"
              phx-click={@on_tab}
              phx-value-tab="nicklist"
            >
              <:icon><Icons.icon_tab_nicklist class="w-4 h-4" /></:icon>
              Nicklist
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="channel"
              phx-click={@on_tab}
              phx-value-tab="channel"
            >
              <:icon><Icons.icon_tab_channel class="w-4 h-4" /></:icon>
              Channel
            </.tabs_trigger>
          </.tabs_list>

          <%!-- Nicklist Tab --%>
          <.tabs_content value="nicklist">
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
          <.tabs_content value="channel">
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
        </.tabs>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          OK
        </.button>
        <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Cancel
        </.button>
      </.dialog_footer>
    </.dialog>
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
    <div class="flex gap-retro-8">
      <%!-- Entries list --%>
      <div class="flex-1 space-y-retro-4">
        <div class="max-h-[180px] overflow-y-auto retro-scrollbar">
          <.table>
            <.table_header>
              <.table_row>
                <.table_head>Label</.table_head>
                <.table_head>Command</.table_head>
              </.table_row>
            </.table_header>
            <.table_body>
              <.table_row
                :for={entry <- @entries}
                class={
                  if(@selected_item == entry.label,
                    do: "bg-selection-bg text-selection-fg",
                    else: ""
                  )
                }
                phx-click={@on_select}
                phx-value-label={entry.label}
              >
                <.table_cell>{entry.label}</.table_cell>
                <.table_cell class="font-mono text-[11px]">{entry.command}</.table_cell>
              </.table_row>
            </.table_body>
          </.table>
        </div>

        <div class="flex gap-retro-4">
          <.button size="sm" variant="outline" phx-click={@on_add}>
            <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
            Add
          </.button>
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_edit}
            disabled={@selected_item == nil}
          >
            <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
            Edit
          </.button>
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_delete}
            disabled={@selected_item == nil}
          >
            <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
            Remove
          </.button>
        </div>
      </div>

      <%!-- Edit form --%>
      <div
        :if={@editing}
        class="w-[200px] shrink-0 shadow-retro-field bg-white p-retro-8 space-y-retro-8"
      >
        <h3 class="font-bold text-xs mb-retro-4">
          {if @selected_item == nil, do: "Add Entry", else: "Edit Entry"}
        </h3>

        <div class="space-y-retro-4">
          <div>
            <label class="text-xs font-bold block mb-retro-2">Label</label>
            <.input
              type="text"
              name="draft_label"
              value={@draft_label}
              placeholder="Menu item text"
              class="w-full"
            />
          </div>

          <div>
            <label class="text-xs font-bold block mb-retro-2">Command</label>
            <.input
              type="text"
              name="draft_command"
              value={@draft_command}
              placeholder="/command $1"
              class="w-full"
            />
          </div>

          <p :if={@error_message} class="text-xs text-destructive">{@error_message}</p>

          <div class="flex gap-retro-4 pt-retro-4">
            <.button size="sm" variant="default" phx-click={@on_save}>
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              Save
            </.button>
            <.button size="sm" variant="outline" phx-click={@on_cancel_edit}>
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              Cancel
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @spec filter_entries(list(), atom()) :: list()
  defp filter_entries(entries, menu_type) do
    Enum.filter(entries, &(Map.get(&1, :menu_type) == menu_type))
  end
end
