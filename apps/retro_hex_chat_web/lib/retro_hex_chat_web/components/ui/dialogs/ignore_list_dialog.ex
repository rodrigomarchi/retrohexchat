defmodule RetroHexChatWeb.Components.UI.IgnoreListDialog do
  @moduledoc """
  Ignore List dialog component for the showcase design system.

  Lists the ignored nicknames with their scope and expiry, and adds new entries
  with an optional duration. Composed from dialog + table + button primitives.

  ## Usage

      <.ignore_list_panel
        id="ignore-list"
        entries={@entries}
        on_select="ignore_select"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc """
  Renders the ignore list content (the table plus its window-scoped add sub-form
  modal) without any frame — compose it inside a desktop window body.
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :entries, :list, default: [], doc: "List of ignore entries"
  attr :selected, :string, default: nil, doc: "Selected nickname"
  attr :show_add_dialog, :boolean, default: false
  attr :on_select, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_remove, :any, default: nil

  @spec ignore_list_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def ignore_list_panel(assigns) do
    ~H"""
    <div id={@id} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="ignore-list-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "#{@id}-content")}
          class="ab-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <.control_table
            target={@target}
            control_list={@entries}
            selected={@selected}
            on_select={@on_select}
          />
          <div class="ab-action-row flex gap-retro-4 mt-retro-4">
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_add}
              phx-target={@target}
              data-testid="control-add"
              class="ab-action-button"
            >
              <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Add")}
            </.button>
            <.button
              size="sm"
              variant="outline"
              phx-click={@on_remove}
              phx-target={@target}
              disabled={@selected == nil}
              data-testid="control-remove"
              class="ab-action-button"
            >
              <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Remove")}
            </.button>
          </div>

          <%!-- Add Sub-Dialog --%>
          <.control_add_form :if={@show_add_dialog} target={@target} />
        </div>
      </.focus_wrap>
    </div>
    """
  end

  # ── Control Table ───────────────────────────────────

  attr :target, :any, default: nil
  attr :control_list, :list, required: true
  attr :selected, :any, default: nil
  attr :on_select, :any, default: nil

  defp control_table(assigns) do
    ~H"""
    <div class="ab-table-wrap">
      <.table class="ab-mobile-list-table">
        <.table_header>
          <.table_row>
            <.table_head>{dgettext("dialogs", "Nick")}</.table_head>
            <.table_head>{dgettext("dialogs", "Type")}</.table_head>
            <.table_head>{dgettext("dialogs", "Expires")}</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row :if={@control_list == []} class="ab-empty-row">
            <.table_cell colspan="3" class="ab-empty-cell text-center text-muted-foreground py-4">
              {dgettext("dialogs", "No ignored users. Click Add to ignore a nickname.")}
            </.table_cell>
          </.table_row>
          <.table_row
            :for={entry <- @control_list}
            id={"control-entry-#{control_nick(entry)}"}
            class={row_class("ab-mobile-list-row", @selected == control_nick(entry))}
            phx-click={@on_select}
            phx-target={@target}
            phx-value-nickname={control_nick(entry)}
          >
            <.table_cell
              class="ab-mobile-list-primary font-bold text-xs"
              data-label={dgettext("dialogs", "Nick")}
            >
              {control_nick(entry)}
            </.table_cell>
            <.table_cell
              class="ab-mobile-list-meta text-xs"
              data-label={dgettext("dialogs", "Type")}
            >
              {to_string(Map.get(entry, :ignore_type, Map.get(entry, :level, "")))}
            </.table_cell>
            <.table_cell
              class="ab-mobile-list-meta text-xs text-muted-foreground"
              data-label={dgettext("dialogs", "Expires")}
            >
              {format_expires(Map.get(entry, :expires_at))}
            </.table_cell>
          </.table_row>
        </.table_body>
      </.table>
    </div>
    """
  end

  # ── Control Add Sub-Form ────────────────────────────

  attr :target, :any, default: nil

  defp control_add_form(assigns) do
    ~H"""
    <.dialog
      id="ab-control-add-modal"
      show
      scope={:window}
      on_cancel={JS.push("control_add_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="ab-control-add-modal"
        title={dgettext("dialogs", "Add Ignore Entry")}
        on_close={JS.push("control_add_cancel", target: @target)}
      >
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form phx-submit="control_add_confirm" phx-target={@target} data-testid="control-add-form">
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="control-add-nick">
              {dgettext("dialogs", "Nickname")}:
            </label>
            <.input
              type="text"
              id="control-add-nick"
              name="nickname"
              maxlength="16"
              required
              autocomplete="off"
              class="w-full"
            />
          </div>
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="control-add-type">
              {dgettext("dialogs", "Type")}:
            </label>
            <select id="control-add-type" name="type" class="w-full">
              <option value="all" selected>{dgettext("dialogs", "All")}</option>
              <option value="messages">{dgettext("dialogs", "Messages")}</option>
              <option value="pms">{dgettext("dialogs", "PMs")}</option>
              <option value="actions">{dgettext("dialogs", "Actions")}</option>
              <option value="notices">{dgettext("dialogs", "Notices")}</option>
              <option value="invites">{dgettext("dialogs", "Invites")}</option>
            </select>
          </div>
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="control-add-duration">
              {dgettext("dialogs", "Duration (leave empty for permanent)")}:
            </label>
            <.input
              type="text"
              id="control-add-duration"
              name="duration"
              placeholder={dgettext("dialogs", "e.g. 5m, 1h, 2d")}
              autocomplete="off"
              class="w-full"
            />
          </div>
          <div class="flex justify-end gap-2">
            <.button type="submit" size="sm">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="control_add_cancel"
              phx-target={@target}
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

  # ── Helpers ────────────────────────────────────────

  defp row_class(base, true), do: "#{base} bg-selection-bg text-selection-fg"
  defp row_class(base, false), do: base

  # Support both IgnoreEntry structs (:nickname) and showcase maps (:nick)
  @spec control_nick(map()) :: String.t()
  defp control_nick(entry), do: Map.get(entry, :nickname) || Map.get(entry, :nick, "")

  @spec format_expires(DateTime.t() | nil) :: String.t()
  defp format_expires(nil), do: dgettext("dialogs", "Permanent")

  defp format_expires(dt) do
    remaining = DateTime.diff(dt, DateTime.utc_now(), :second)

    cond do
      remaining <= 0 -> dgettext("dialogs", "Expired")
      remaining < 60 -> "#{remaining}s"
      remaining < 3600 -> "#{div(remaining, 60)}m"
      remaining < 86_400 -> "#{div(remaining, 3600)}h"
      true -> "#{div(remaining, 86_400)}d"
    end
  end
end
