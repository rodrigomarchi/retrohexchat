defmodule RetroHexChatWeb.Components.NotifyListWindow do
  @moduledoc """
  98.css styled buddy/notify list window.
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
      class="window"
      style="position: absolute; top: 40px; right: 10px; width: 300px; height: 400px; z-index: 150; display: flex; flex-direction: column;"
    >
      <div class="title-bar">
        <div class="title-bar-text">Notify List</div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="toggle_notify_list"></button>
        </div>
      </div>
      <div
        class="window-body"
        style="padding: 4px; display: flex; flex-direction: column; flex: 1; overflow: hidden;"
      >
        <%!-- Toolbar --%>
        <div style="display: flex; gap: 4px; margin-bottom: 4px; align-items: center;">
          <button
            type="button"
            phx-click="notify_add_dialog"
            data-testid="notify-btn-add"
            style="font-size: 11px; padding: 1px 8px;"
          >
            Add
          </button>
          <button
            type="button"
            phx-click="notify_remove"
            phx-value-nickname={@selected_entry}
            disabled={is_nil(@selected_entry)}
            data-testid="notify-btn-remove"
            style="font-size: 11px; padding: 1px 8px;"
          >
            Remove
          </button>
          <button
            type="button"
            phx-click="notify_edit_dialog"
            disabled={is_nil(@selected_entry)}
            data-testid="notify-btn-edit"
            style="font-size: 11px; padding: 1px 8px;"
          >
            Edit
          </button>
          <label style="font-size: 11px; margin-left: auto; display: flex; align-items: center; gap: 2px;">
            <input
              type="checkbox"
              checked={@auto_whois}
              phx-click="toggle_auto_whois"
              data-testid="notify-auto-whois"
            /> Auto-Whois
          </label>
        </div>
        <%!-- Table --%>
        <div class="sunken-panel" style="flex: 1; overflow-y: auto;">
          <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
            <thead>
              <tr style="background: #c0c0c0; position: sticky; top: 0;">
                <th style="text-align: left; padding: 2px 4px; width: 24px;"></th>
                <th style="text-align: left; padding: 2px 4px;">Nickname</th>
                <th style="text-align: left; padding: 2px 4px;">Notes</th>
                <th style="text-align: left; padding: 2px 4px;">Last Seen</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={entry <- @entries}
                phx-click="notify_select"
                phx-value-nickname={entry.tracked_nickname}
                data-nickname={entry.tracked_nickname}
                data-testid={"notify-entry-#{entry.tracked_nickname}"}
                style={row_style(entry.tracked_nickname, @selected_entry)}
              >
                <td style="text-align: center; padding: 2px 4px;">
                  {status_dot(entry.online)}
                </td>
                <td style={"padding: 2px 4px; #{notify_nick_style(@nick_color_fn, entry.tracked_nickname)}"}>
                  {entry.tracked_nickname}
                </td>
                <td style="padding: 2px 4px;">{entry.note || ""}</td>
                <td style="padding: 2px 4px; white-space: nowrap;">
                  {format_last_seen(entry.last_seen_at)}
                </td>
              </tr>
              <tr :if={@entries == []}>
                <td
                  colspan="4"
                  style="text-align: center; padding: 8px; color: #808080; font-size: 11px;"
                >
                  No entries. Click Add to track a nickname.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    <%!-- Add Dialog --%>
    <div
      :if={@show_add_dialog}
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.5);"
    >
      <div class="window" style="min-width: 280px; max-width: 340px;">
        <div class="title-bar">
          <div class="title-bar-text">Add to Notify List</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="notify_add_cancel"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 12px;">
          <form phx-submit="notify_add" data-testid="notify-add-form">
            <div style="margin-bottom: 8px;">
              <label
                for="notify-add-nickname"
                style="font-size: 11px; display: block; margin-bottom: 2px;"
              >
                Nickname:
              </label>
              <input
                type="text"
                id="notify-add-nickname"
                name="nickname"
                required
                maxlength="16"
                autocomplete="off"
                style="width: 100%;"
                data-testid="notify-add-nickname"
              />
            </div>
            <div style="margin-bottom: 12px;">
              <label
                for="notify-add-note"
                style="font-size: 11px; display: block; margin-bottom: 2px;"
              >
                Notes:
              </label>
              <input
                type="text"
                id="notify-add-note"
                name="note"
                maxlength="200"
                autocomplete="off"
                style="width: 100%;"
                data-testid="notify-add-note"
              />
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 8px;">
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
    <div
      :if={@show_edit_dialog}
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.5);"
    >
      <div class="window" style="min-width: 280px; max-width: 340px;">
        <div class="title-bar">
          <div class="title-bar-text">Edit Notify Entry</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="notify_edit_cancel"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 12px;">
          <form phx-submit="notify_edit" data-testid="notify-edit-form">
            <div style="margin-bottom: 8px;">
              <label
                for="notify-edit-nickname"
                style="font-size: 11px; display: block; margin-bottom: 2px;"
              >
                Nickname:
              </label>
              <input
                type="text"
                id="notify-edit-nickname"
                name="nickname"
                value={@selected_entry}
                readonly
                style="width: 100%; background: #c0c0c0;"
                data-testid="notify-edit-nickname"
              />
            </div>
            <div style="margin-bottom: 12px;">
              <label
                for="notify-edit-note"
                style="font-size: 11px; display: block; margin-bottom: 2px;"
              >
                Notes:
              </label>
              <input
                type="text"
                id="notify-edit-note"
                name="note"
                value={@selected_note}
                maxlength="200"
                autocomplete="off"
                style="width: 100%;"
                data-testid="notify-edit-note"
              />
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 8px;">
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
    <span
      style="display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #00a000;"
      title="Online"
    >
    </span>
    """
  end

  defp status_dot(false) do
    assigns = %{}

    ~H"""
    <span
      style="display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #808080;"
      title="Offline"
    >
    </span>
    """
  end

  @spec format_last_seen(DateTime.t() | nil) :: String.t()
  defp format_last_seen(nil), do: "Never"
  defp format_last_seen(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  @spec notify_nick_style((String.t() -> String.t()) | nil, String.t()) :: String.t()
  defp notify_nick_style(nil, _nickname), do: ""
  defp notify_nick_style(color_fn, nickname), do: "color: #{color_fn.(nickname)};"

  @spec row_style(String.t(), String.t() | nil) :: String.t()
  defp row_style(nickname, selected) when nickname == selected do
    "background: #000080; color: #ffffff; cursor: pointer;"
  end

  defp row_style(_nickname, _selected) do
    "cursor: pointer;"
  end
end
