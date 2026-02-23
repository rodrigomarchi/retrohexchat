defmodule RetroHexChatWeb.Components.NotifyListWindow do
  @moduledoc """
  Retro-styled buddy/notify list window.
  Displays tracked nicknames with online/offline status, notes, and last-seen times.
  Supports add, remove, edit operations and an auto-whois toggle.
  """
  use Phoenix.Component

  attr :entries, :list, default: []
  attr :visible, :boolean, default: false
  attr :selected_entry, :string, default: nil
  attr :show_add_dialog, :boolean, default: false
  attr :show_edit_dialog, :boolean, default: false
  attr :auto_whois, :boolean, default: false
  attr :nick_color_fn, :any, default: nil
  attr :timezone, :string, default: "Etc/UTC"

  @spec notify_list_window(map()) :: Phoenix.LiveView.Rendered.t()
  def notify_list_window(assigns) do
    selected_note =
      case Enum.find(assigns.entries, &(&1.tracked_nickname == assigns.selected_entry)) do
        nil -> ""
        entry -> entry.note || ""
      end

    assigns = assign(assigns, :selected_note, selected_note)

    ~H"""
    <div
      :if={@visible}
      data-testid="notify-list-window"
      class="window u-flex-col notify-list-window"
    >
      <div class="title-bar">
        <div class="title-bar-text">Notify List</div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="toggle_notify_list"></button>
        </div>
      </div>
      <div class="window-body u-p-4 u-flex-col u-flex-1 u-overflow-hidden">
        <%!-- Toolbar --%>
        <div class="u-flex u-gap-4 u-mb-4 u-items-center">
          <button
            type="button"
            class="btn-sm"
            phx-click="notify_add_dialog"
            data-testid="notify-btn-add"
          >
            Add
          </button>
          <button
            type="button"
            class="btn-sm"
            phx-click="notify_remove"
            phx-value-nickname={@selected_entry}
            disabled={is_nil(@selected_entry)}
            data-testid="notify-btn-remove"
          >
            Remove
          </button>
          <button
            type="button"
            class="btn-sm"
            phx-click="notify_edit_dialog"
            disabled={is_nil(@selected_entry)}
            data-testid="notify-btn-edit"
          >
            Edit
          </button>
          <label class="u-text-sm u-ml-auto u-flex u-items-center u-gap-2">
            <input
              type="checkbox"
              checked={@auto_whois}
              phx-click="toggle_auto_whois"
              data-testid="notify-auto-whois"
            /> Auto-Whois
          </label>
        </div>
        <%!-- Table --%>
        <div class="table-container">
          <table class="table-standard">
            <thead>
              <tr class="u-sticky-top">
                <th class="notify-status-col"></th>
                <th>Nickname</th>
                <th>Notes</th>
                <th>Last Seen</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={entry <- @entries}
                phx-click="notify_select"
                phx-value-nickname={entry.tracked_nickname}
                data-nickname={entry.tracked_nickname}
                data-testid={"notify-entry-#{entry.tracked_nickname}"}
                class={[
                  "table-row--selectable",
                  entry.tracked_nickname == @selected_entry && "table-row--selected"
                ]}
              >
                <td class="u-text-center">
                  {status_dot(entry.online)}
                </td>
                <td class={@nick_color_fn && @nick_color_fn.(entry.tracked_nickname)}>
                  {entry.tracked_nickname}
                </td>
                <td>{entry.note || ""}</td>
                <td class="table-cell--nowrap">
                  {format_last_seen(entry.last_seen_at, @timezone)}
                </td>
              </tr>
              <tr :if={@entries == []}>
                <td colspan="4" class="table-empty">
                  No entries. Click Add to track a nickname.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    <%!-- Add Dialog --%>
    <div :if={@show_add_dialog} class="dialog-overlay dialog-overlay--dark">
      <div class="window dialog-window--narrow">
        <div class="title-bar">
          <div class="title-bar-text">Add to Notify List</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="notify_add_cancel"></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          <form phx-submit="notify_add" data-testid="notify-add-form">
            <div class="u-mb-8">
              <label for="notify-add-nickname" class="form-label">
                Nickname:
              </label>
              <input
                type="text"
                id="notify-add-nickname"
                name="nickname"
                class="u-w-full"
                required
                maxlength="16"
                autocomplete="off"
                data-testid="notify-add-nickname"
              />
            </div>
            <div class="u-mb-12">
              <label for="notify-add-note" class="form-label">
                Notes:
              </label>
              <input
                type="text"
                id="notify-add-note"
                name="note"
                class="u-w-full"
                maxlength="200"
                autocomplete="off"
                data-testid="notify-add-note"
              />
            </div>
            <div class="dialog-buttons dialog-buttons--gap-8">
              <button type="submit" data-testid="notify-add-ok">OK</button>
              <button type="button" phx-click="notify_add_cancel" data-testid="notify-add-cancel">
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <%!-- Edit Dialog --%>
    <div :if={@show_edit_dialog} class="dialog-overlay dialog-overlay--dark">
      <div class="window dialog-window--narrow">
        <div class="title-bar">
          <div class="title-bar-text">Edit Notify Entry</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="notify_edit_cancel"></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          <form phx-submit="notify_edit" data-testid="notify-edit-form">
            <div class="u-mb-8">
              <label for="notify-edit-nickname" class="form-label">
                Nickname:
              </label>
              <input
                type="text"
                id="notify-edit-nickname"
                name="nickname"
                class="u-w-full"
                value={@selected_entry}
                readonly
                class="input-readonly"
                data-testid="notify-edit-nickname"
              />
            </div>
            <div class="u-mb-12">
              <label for="notify-edit-note" class="form-label">
                Notes:
              </label>
              <input
                type="text"
                id="notify-edit-note"
                name="note"
                class="u-w-full"
                value={@selected_note}
                maxlength="200"
                autocomplete="off"
                data-testid="notify-edit-note"
              />
            </div>
            <div class="dialog-buttons dialog-buttons--gap-8">
              <button type="submit" data-testid="notify-edit-ok">OK</button>
              <button type="button" phx-click="notify_edit_cancel" data-testid="notify-edit-cancel">
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  @spec status_dot(boolean()) :: Phoenix.LiveView.Rendered.t()
  defp status_dot(true) do
    assigns = %{}

    ~H"""
    <span class="u-status-dot u-status-dot--online" title="Online"></span>
    """
  end

  defp status_dot(false) do
    assigns = %{}

    ~H"""
    <span class="u-status-dot u-status-dot--offline" title="Offline"></span>
    """
  end

  @spec format_last_seen(DateTime.t() | nil, String.t()) :: String.t()
  defp format_last_seen(nil, _tz), do: "Never"

  defp format_last_seen(%DateTime{} = dt, tz),
    do: dt |> RetroHexChatWeb.Timezone.shift(tz) |> Calendar.strftime("%Y-%m-%d %H:%M")
end
