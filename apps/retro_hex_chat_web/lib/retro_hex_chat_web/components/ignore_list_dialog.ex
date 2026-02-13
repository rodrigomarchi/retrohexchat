defmodule RetroHexChatWeb.Components.IgnoreListDialog do
  @moduledoc """
  Ignore List management dialog (Ctrl+Shift+G).
  Shows ignored users with type and expiration, Add/Remove buttons.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.IgnoreEntry

  attr :visible, :boolean, default: false
  attr :ignore_entries, :list, default: []
  attr :ignore_selected, :string, default: nil
  attr :show_ignore_add_dialog, :boolean, default: false

  @spec ignore_list_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def ignore_list_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      data-testid="ignore-list-dialog"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.3);"
    >
      <div class="window" style="width: 420px; min-height: 280px;">
        <div class="title-bar">
          <div class="title-bar-text">Ignore List</div>
          <div class="title-bar-controls">
            <button
              aria-label="Close"
              data-testid="ignore-dialog-close"
              phx-click="close_ignore_dialog"
            >
            </button>
          </div>
        </div>
        <div class="window-body" style="padding: 8px; display: flex; flex-direction: column;">
          <div class="sunken-panel" style="flex: 1; overflow-y: auto; min-height: 150px;">
            <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
              <thead>
                <tr style="background: #c0c0c0; position: sticky; top: 0;">
                  <th style="text-align: left; padding: 2px 4px;">Nickname</th>
                  <th style="text-align: left; padding: 2px 4px;">Type</th>
                  <th style="text-align: left; padding: 2px 4px;">Expires</th>
                </tr>
              </thead>
              <tbody>
                <%= if @ignore_entries == [] do %>
                  <tr>
                    <td colspan="3" style="text-align: center; padding: 16px; color: #808080;">
                      No users ignored
                    </td>
                  </tr>
                <% else %>
                  <tr
                    :for={entry <- @ignore_entries}
                    phx-click="ignore_select"
                    phx-value-nickname={entry.nickname}
                    data-testid={"ignore-entry-#{entry.nickname}"}
                    style={row_style(entry.nickname, @ignore_selected)}
                  >
                    <td style="padding: 2px 4px;">{entry.nickname}</td>
                    <td style="padding: 2px 4px;">{Atom.to_string(entry.ignore_type)}</td>
                    <td style="padding: 2px 4px;">{format_expires(entry)}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
          <div style="margin-top: 8px; display: flex; gap: 4px;">
            <button
              type="button"
              data-testid="ignore-add-btn"
              phx-click="ignore_dialog_add"
              style="font-size: 11px; padding: 1px 8px;"
            >
              Add...
            </button>
            <button
              type="button"
              data-testid="ignore-remove-btn"
              phx-click="ignore_dialog_remove"
              disabled={is_nil(@ignore_selected)}
              style="font-size: 11px; padding: 1px 8px;"
            >
              Remove
            </button>
          </div>
        </div>
      </div>
    </div>

    <%= if @show_ignore_add_dialog do %>
      <div
        class="dialog-overlay"
        data-testid="ignore-add-dialog"
        style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 210; background: rgba(0,0,0,0.2);"
      >
        <div class="window" style="width: 300px;">
          <div class="title-bar">
            <div class="title-bar-text">Add Ignore</div>
          </div>
          <div class="window-body" style="padding: 8px;">
            <form phx-submit="ignore_dialog_add_confirm">
              <div class="field-row-stacked" style="margin-bottom: 8px;">
                <label for="ignore-nick-input">Nickname:</label>
                <input
                  type="text"
                  id="ignore-nick-input"
                  name="nickname"
                  data-testid="ignore-nick-input"
                  maxlength="16"
                  required
                  autofocus
                />
              </div>
              <div class="field-row-stacked" style="margin-bottom: 8px;">
                <label for="ignore-type-select">Type:</label>
                <select id="ignore-type-select" name="type" data-testid="ignore-type-select">
                  <option value="all" selected>all</option>
                  <option value="messages">messages</option>
                  <option value="pms">pms</option>
                  <option value="invites">invites</option>
                  <option value="actions">actions</option>
                </select>
              </div>
              <div class="field-row-stacked" style="margin-bottom: 8px;">
                <label for="ignore-duration-input">Duration (optional, e.g. 5m, 2h, 1d):</label>
                <input
                  type="text"
                  id="ignore-duration-input"
                  name="duration"
                  data-testid="ignore-duration-input"
                  placeholder="Leave empty for permanent"
                />
              </div>
              <div style="display: flex; gap: 4px; justify-content: flex-end;">
                <button type="submit" data-testid="ignore-add-confirm">OK</button>
                <button
                  type="button"
                  phx-click="close_ignore_add_dialog"
                  data-testid="ignore-add-cancel"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp row_style(nickname, selected) when nickname == selected do
    "background: #000080; color: #ffffff; cursor: pointer;"
  end

  defp row_style(_nickname, _selected) do
    "cursor: pointer;"
  end

  defp format_expires(entry) do
    if IgnoreEntry.permanent?(entry) do
      "Permanent"
    else
      seconds = IgnoreEntry.remaining_seconds(entry)
      format_remaining(seconds)
    end
  end

  defp format_remaining(seconds) when seconds < 60, do: "#{seconds}s"
  defp format_remaining(seconds) when seconds < 3600, do: "#{div(seconds, 60)}m"
  defp format_remaining(seconds) when seconds < 86_400, do: "#{div(seconds, 3600)}h"
  defp format_remaining(seconds), do: "#{div(seconds, 86_400)}d"
end
