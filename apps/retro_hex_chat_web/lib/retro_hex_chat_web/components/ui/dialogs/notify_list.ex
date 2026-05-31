defmodule RetroHexChatWeb.Components.UI.NotifyList do
  @moduledoc """
  Notify list dialog component for the showcase design system.

  Composed from dialog + table + button + checkbox primitives.
  Shows tracked nicks with online/offline status, last seen time,
  and Auto-Whois toggle. Supports Add/Edit/Remove CRUD actions.

  ## Usage

      <.notify_list id="notify-list" show={true} entries={@entries} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc "Renders the notify list dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :entries, :list,
    default: [],
    doc: "List of %{nickname, online (boolean), last_seen (string)} maps"

  attr :selected_entry, :string, default: nil, doc: "Currently selected nickname"
  attr :auto_whois, :boolean, default: false, doc: "Auto-Whois checkbox state"
  attr :on_select, :any, default: nil, doc: "Row click callback (phx-value-nickname)"
  attr :on_add, :any, default: nil, doc: "Add button callback"
  attr :on_edit, :any, default: nil, doc: "Edit button callback"
  attr :on_remove, :any, default: nil, doc: "Remove button callback"
  attr :show_add_dialog, :boolean, default: false, doc: "Show inline add sub-form"
  attr :show_edit_dialog, :boolean, default: false, doc: "Show inline edit sub-form"
  attr :selected_note, :string, default: "", doc: "Note for the selected entry (for edit form)"
  attr :on_toggle_auto_whois, :any, default: nil, doc: "Auto-Whois checkbox callback"
  attr :auto_add_pm, :boolean, default: true, doc: "Auto-add PM contacts checkbox state"
  attr :on_toggle_auto_add_pm, :any, default: nil, doc: "Auto-add PM checkbox callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"

  @spec notify_list(map()) :: Phoenix.LiveView.Rendered.t()
  def notify_list(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} lock={@show_add_dialog || @show_edit_dialog}>
      <div data-testid="notify-list">
        <.dialog_header id={@id} title={dgettext("dialogs", "Notify List")}>
          <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
        </.dialog_header>

        <.dialog_body class="space-y-retro-8">
          <%!-- Settings toggles --%>
          <div class="flex flex-col gap-retro-4">
            <div class="flex items-center gap-retro-4">
              <.checkbox
                name="auto_add_pm"
                value={@auto_add_pm}
                phx-click={@on_toggle_auto_add_pm}
                id={"#{@id}-auto-add-pm"}
              />
              <label for={"#{@id}-auto-add-pm"} class="text-xs cursor-pointer select-none">
                {dgettext("dialogs", "Auto-add PM contacts to notify list")}
              </label>
            </div>
            <div class="flex items-center gap-retro-4">
              <.checkbox
                name="auto_whois"
                value={@auto_whois}
                phx-click={@on_toggle_auto_whois}
                id={"#{@id}-auto-whois"}
              />
              <label for={"#{@id}-auto-whois"} class="text-xs cursor-pointer select-none">
                {dgettext("dialogs", "Perform WHOIS on notify nicks when they come online")}
              </label>
            </div>
          </div>

          <%!-- Entries table --%>
          <div class="max-h-[260px] overflow-y-auto retro-scrollbar">
            <.table>
              <.table_header>
                <.table_row>
                  <.table_head>{dgettext("dialogs", "Nick")}</.table_head>
                  <.table_head>{dgettext("dialogs", "Status")}</.table_head>
                  <.table_head>{dgettext("dialogs", "Last Seen")}</.table_head>
                </.table_row>
              </.table_header>
              <.table_body>
                <.table_row
                  :for={entry <- @entries}
                  class={
                    if(@selected_entry == entry.tracked_nickname,
                      do: "bg-selection-bg text-selection-fg",
                      else: ""
                    )
                  }
                  phx-click={@on_select}
                  phx-value-nickname={entry.tracked_nickname}
                  data-testid={"notify-list-row-#{entry.tracked_nickname}"}
                >
                  <.table_cell class="font-bold">{entry.tracked_nickname}</.table_cell>
                  <.table_cell>
                    <.online_status online={entry.online} />
                  </.table_cell>
                  <.table_cell class="text-xs">{Map.get(entry, :last_seen_at, "")}</.table_cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>

          <%!-- CRUD buttons --%>
          <div class="flex gap-retro-4">
            <.button size="sm" variant="outline" phx-click={@on_add}>
              <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Add")}
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_edit}
              disabled={@selected_entry == nil}
            >
              <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Edit")}
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_remove}
              phx-value-nickname={@selected_entry}
              disabled={@selected_entry == nil}
            >
              <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Remove")}
            </.button>
          </div>
        </.dialog_body>

        <.dialog_footer>
          <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Close")}
          </.button>
        </.dialog_footer>
      </div>
    </.dialog>

    <%!-- Notify Add Sub-Dialog --%>
    <.notify_add_sub_form :if={@show_add_dialog} />
    <%!-- Notify Edit Sub-Dialog --%>
    <.notify_edit_sub_form
      :if={@show_edit_dialog}
      selected_entry={@selected_entry}
      selected_note={@selected_note}
    />
    """
  end

  # ── Sub-Forms ────────────────────────────────────────

  defp notify_add_sub_form(assigns) do
    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">
            {dgettext("dialogs", "Add Notify Entry")}
          </span>
          <div class="ml-auto">
            <button
              type="button"
              aria-label={dgettext("dialogs", "Close")}
              phx-click="notify_add_cancel"
            />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="notify_add" data-testid="notify-add-form">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="notify-add-nickname">
                {dgettext("dialogs", "Nickname:")}
              </label>
              <.input
                type="text"
                id="notify-add-nickname"
                name="nickname"
                maxlength="16"
                required
                autocomplete="off"
                class="w-full"
              />
            </div>
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="notify-add-note">
                {dgettext("dialogs", "Note:")}
              </label>
              <.input
                type="text"
                id="notify-add-note"
                name="note"
                maxlength="200"
                autocomplete="off"
                class="w-full"
              />
            </div>
            <div class="flex justify-end gap-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "OK")}
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click="notify_add_cancel">
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "Cancel")}
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :selected_entry, :string, default: nil
  attr :selected_note, :string, default: ""

  defp notify_edit_sub_form(assigns) do
    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">
            {dgettext("dialogs", "Edit Notify Entry")}
          </span>
          <div class="ml-auto">
            <button
              type="button"
              aria-label={dgettext("dialogs", "Close")}
              phx-click="notify_edit_cancel"
            />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="notify_edit" data-testid="notify-edit-form">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="notify-edit-nickname">
                {dgettext("dialogs", "Nickname:")}
              </label>
              <.input
                type="text"
                id="notify-edit-nickname"
                name="nickname"
                value={@selected_entry}
                readonly
                class="w-full input-readonly"
              />
            </div>
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="notify-edit-note">
                {dgettext("dialogs", "Note:")}
              </label>
              <.input
                type="text"
                id="notify-edit-note"
                name="note"
                value={@selected_note}
                maxlength="200"
                autocomplete="off"
                class="w-full"
              />
            </div>
            <div class="flex justify-end gap-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "OK")}
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click="notify_edit_cancel">
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "Cancel")}
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # ── Private helpers ───────────────────────────────────

  attr :online, :boolean, required: true

  defp online_status(%{online: true} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-retro-2 text-xs">
      <span class="w-2 h-2 rounded-full bg-success inline-block" /> {dgettext("dialogs", "Online")}
    </span>
    """
  end

  defp online_status(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-retro-2 text-xs text-muted-foreground">
      <span class="w-2 h-2 rounded-full bg-muted-foreground inline-block" /> {dgettext(
        "dialogs",
        "Offline"
      )}
    </span>
    """
  end
end
