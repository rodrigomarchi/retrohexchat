defmodule RetroHexChatWeb.Components.UI.NotifyList do
  @moduledoc """
  Notify list dialog component for the showcase design system.

  Composed from dialog + button + checkbox + input/textarea primitives.
  Shows tracked nicks with online/offline status, last seen time,
  and Auto-Whois toggle. Supports Add/Edit/Remove CRUD actions.

  ## Usage

      <.notify_list id="notify-list" show={true} entries={@entries} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChatWeb.Icons

  @doc "Renders the notify list dialog."
  attr :id, :string, required: true
  attr :target, :any, default: nil
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
  attr :timezone, :string, default: nil, doc: "Timezone for the Last Seen column"

  @spec notify_list(map()) :: Phoenix.LiveView.Rendered.t()
  def notify_list(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} lock={@show_add_dialog || @show_edit_dialog} on_cancel={@on_close}>
      <.dialog_header id={@id} title={dgettext("dialogs", "Notify List")} on_close={@on_close}>
        <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.notify_panel
          id={@id}
          target={@target}
          entries={@entries}
          selected_entry={@selected_entry}
          selected_note={@selected_note}
          auto_whois={@auto_whois}
          auto_add_pm={@auto_add_pm}
          show_add_dialog={@show_add_dialog}
          show_edit_dialog={@show_edit_dialog}
          on_select={@on_select}
          on_add={@on_add}
          on_edit={@on_edit}
          on_remove={@on_remove}
          on_toggle_auto_whois={@on_toggle_auto_whois}
          on_toggle_auto_add_pm={@on_toggle_auto_add_pm}
        />
      </.dialog_body>
      <.dialog_footer>
        <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Close")}
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  @doc """
  Renders the notify list content (settings toggles + buddy table + CRUD +
  Add/Edit sub-form modals) without any frame — compose it inside a desktop
  window body. Sub-forms are window-scoped modals.
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :entries, :list, default: []
  attr :selected_entry, :string, default: nil
  attr :auto_whois, :boolean, default: false
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :show_add_dialog, :boolean, default: false
  attr :show_edit_dialog, :boolean, default: false
  attr :selected_note, :string, default: ""
  attr :on_toggle_auto_whois, :any, default: nil
  attr :auto_add_pm, :boolean, default: true
  attr :on_toggle_auto_add_pm, :any, default: nil
  attr :on_close, :any, default: nil
  attr :timezone, :string, default: nil

  @spec notify_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def notify_panel(assigns) do
    ~H"""
    <div id={"#{@id}-panel-root"} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="notify-list"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="nl-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <%!-- Settings toggles --%>
          <div class="nl-settings">
            <label class="nl-setting-row">
              <.checkbox
                name="auto_add_pm"
                value={@auto_add_pm}
                phx-click={@on_toggle_auto_add_pm}
                phx-target={@target}
                id={"#{@id}-auto-add-pm"}
              />
              <span>{dgettext("dialogs", "Auto-add PM contacts to notify list")}</span>
            </label>
            <label class="nl-setting-row">
              <.checkbox
                name="auto_whois"
                value={@auto_whois}
                phx-click={@on_toggle_auto_whois}
                phx-target={@target}
                id={"#{@id}-auto-whois"}
              />
              <span>
                {dgettext("dialogs", "Perform WHOIS on notify nicks when they come online")}
              </span>
            </label>
          </div>

          <%!-- Entries list --%>
          <div class="nl-entry-list flex-1 overflow-y-auto retro-scrollbar">
            <div :if={@entries == []} class="nl-empty-state text-center text-muted-foreground">
              {dgettext("dialogs", "No notify nicks yet. Add a nick to track online status.")}
            </div>

            <button
              :for={entry <- @entries}
              type="button"
              class={entry_class(@selected_entry == entry.tracked_nickname)}
              phx-click={@on_select}
              phx-target={@target}
              phx-value-nickname={entry.tracked_nickname}
              data-testid={"notify-list-row-#{entry.tracked_nickname}"}
              aria-pressed={@selected_entry == entry.tracked_nickname}
              aria-label={entry.tracked_nickname}
            >
              <span class="nl-entry-header">
                <span class="nl-entry-name">{entry.tracked_nickname}</span>
                <.online_status online={entry.online} />
              </span>
              <span class="nl-entry-meta">
                <span class="nl-entry-meta-label">{dgettext("dialogs", "Last Seen")}</span>
                {last_seen_label(entry, @timezone)}
              </span>
              <span class="nl-entry-note">
                <span class="nl-entry-meta-label">{dgettext("dialogs", "Note")}</span>
                {note_label(entry)}
              </span>
            </button>
          </div>

          <%!-- CRUD buttons --%>
          <div class="nl-action-row flex gap-retro-4">
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_add}
              phx-target={@target}
              data-testid="notify-list-add"
              class="nl-action-button"
            >
              <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Add")}
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_edit}
              phx-target={@target}
              disabled={@selected_entry == nil}
              data-testid="notify-list-edit"
              class="nl-action-button"
            >
              <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Edit")}
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_remove}
              phx-target={@target}
              phx-value-nickname={@selected_entry}
              disabled={@selected_entry == nil}
              data-testid="notify-list-remove"
              class="nl-action-button"
            >
              <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Remove")}
            </.button>
          </div>

          <div :if={@on_close} class="nl-dialog-footer flex justify-end">
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click={@on_close}
              phx-target={@target}
              class="nl-action-button"
              data-testid="notify-list-close"
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Close")}
            </.button>
          </div>

          <%!-- Notify Add Sub-Dialog --%>
          <.notify_add_sub_form :if={@show_add_dialog} target={@target} />
          <%!-- Notify Edit Sub-Dialog --%>
          <.notify_edit_sub_form
            :if={@show_edit_dialog}
            target={@target}
            selected_entry={@selected_entry}
            selected_note={@selected_note}
          />
        </div>
      </.focus_wrap>
    </div>
    """
  end

  # ── Sub-Forms ────────────────────────────────────────

  attr :target, :any, default: nil

  defp notify_add_sub_form(assigns) do
    ~H"""
    <.dialog
      id="notify-add-modal"
      show
      scope={:window}
      on_cancel={JS.push("notify_add_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="notify-add-modal"
        title={dgettext("dialogs", "Add Notify Entry")}
        on_close={JS.push("notify_add_cancel", target: @target)}
      >
        <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="notify_add"
          phx-target={@target}
          data-testid="notify-add-form"
          class="nl-sub-form"
        >
          <div class="nl-field">
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
              class="nl-input w-full"
            />
          </div>
          <div class="nl-field">
            <label class="text-xs font-bold" for="notify-add-note">
              {dgettext("dialogs", "Note:")}
            </label>
            <.textarea
              id="notify-add-note"
              name="note"
              maxlength="200"
              autocomplete="off"
              rows="3"
              class="nl-note-input nl-input w-full resize-none text-xs"
            />
          </div>
          <div class="nl-form-actions flex justify-end gap-2">
            <.button type="submit" size="sm" class="nl-action-button">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="notify_add_cancel"
              phx-target={@target}
              class="nl-action-button"
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  attr :target, :any, default: nil
  attr :selected_entry, :string, default: nil
  attr :selected_note, :string, default: ""

  defp notify_edit_sub_form(assigns) do
    ~H"""
    <.dialog
      id="notify-edit-modal"
      show
      scope={:window}
      on_cancel={JS.push("notify_edit_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="notify-edit-modal"
        title={dgettext("dialogs", "Edit Notify Entry")}
        on_close={JS.push("notify_edit_cancel", target: @target)}
      >
        <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="notify_edit"
          phx-target={@target}
          data-testid="notify-edit-form"
          class="nl-sub-form"
        >
          <div class="nl-field">
            <label class="text-xs font-bold" for="notify-edit-nickname">
              {dgettext("dialogs", "Nickname:")}
            </label>
            <.input
              type="text"
              id="notify-edit-nickname"
              name="nickname"
              value={@selected_entry}
              readonly
              class="nl-input w-full input-readonly"
            />
          </div>
          <div class="nl-field">
            <label class="text-xs font-bold" for="notify-edit-note">
              {dgettext("dialogs", "Note:")}
            </label>
            <.textarea
              id="notify-edit-note"
              name="note"
              value={@selected_note}
              maxlength="200"
              autocomplete="off"
              rows="3"
              class="nl-note-input nl-input w-full resize-none text-xs"
            />
          </div>
          <div class="nl-form-actions flex justify-end gap-2">
            <.button type="submit" size="sm" class="nl-action-button">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="notify_edit_cancel"
              phx-target={@target}
              class="nl-action-button"
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  # ── Private helpers ───────────────────────────────────

  attr :online, :boolean, required: true

  defp online_status(%{online: true} = assigns) do
    ~H"""
    <span class="nl-status nl-status--online">
      <span class="nl-status-dot" /> {dgettext("dialogs", "Online")}
    </span>
    """
  end

  defp online_status(assigns) do
    ~H"""
    <span class="nl-status nl-status--offline">
      <span class="nl-status-dot" /> {dgettext("dialogs", "Offline")}
    </span>
    """
  end

  defp entry_class(true), do: "nl-entry bg-selection-bg text-selection-fg"
  defp entry_class(false), do: "nl-entry"

  defp note_label(entry) do
    case Map.get(entry, :note) do
      nil -> dgettext("dialogs", "No note")
      "" -> dgettext("dialogs", "No note")
      note -> note
    end
  end

  # Timestamps are rendered in the viewer's timezone — the behaviour the Address
  # Book's Notify tab had, adopted here when that tab was absorbed.
  defp last_seen_label(%{online: true}, _timezone), do: dgettext("dialogs", "Now")

  defp last_seen_label(entry, timezone) do
    case Map.get(entry, :last_seen_at) do
      nil -> dgettext("dialogs", "Never")
      "" -> dgettext("dialogs", "Never")
      %DateTime{} = value -> value |> shift_timezone(timezone) |> Calendar.strftime("%d/%m %H:%M")
      value -> to_string(value)
    end
  end

  @spec shift_timezone(DateTime.t(), String.t() | nil) :: DateTime.t()
  defp shift_timezone(dt, nil), do: dt
  defp shift_timezone(dt, "Etc/UTC"), do: dt

  defp shift_timezone(dt, timezone) do
    case DateTime.shift_zone(dt, timezone) do
      {:ok, shifted} -> shifted
      {:error, _} -> dt
    end
  end
end
