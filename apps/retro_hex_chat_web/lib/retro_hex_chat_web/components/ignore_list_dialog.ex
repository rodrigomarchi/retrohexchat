defmodule RetroHexChatWeb.Components.IgnoreListDialog do
  @moduledoc """
  Ignore List management dialog (Ctrl+Shift+G).
  Shows ignored users with type and expiration, Add/Remove buttons.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.IgnoreEntry
  alias RetroHexChatWeb.Icons

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
    >
      <div class="window dialog-window--md">
        <div class="title-bar">
          <Icons.icon_dialog_ignore class="title-bar-icon" />
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
        <div class="window-body dialog-body--p8 u-flex-col">
          <div class="sunken-panel table-container ignore-list-panel">
            <table class="table-standard">
              <thead>
                <tr class="u-sticky-top">
                  <th>Nickname</th>
                  <th>Type</th>
                  <th>Expires</th>
                </tr>
              </thead>
              <tbody>
                <%= if @ignore_entries == [] do %>
                  <tr>
                    <td colspan="3" class="table-empty u-p-16">
                      No users ignored
                    </td>
                  </tr>
                <% else %>
                  <tr
                    :for={entry <- @ignore_entries}
                    phx-click="ignore_select"
                    phx-value-nickname={entry.nickname}
                    data-testid={"ignore-entry-#{entry.nickname}"}
                    class={[
                      "table-row--selectable",
                      entry.nickname == @ignore_selected && "table-row--selected"
                    ]}
                  >
                    <td>{entry.nickname}</td>
                    <td>{Atom.to_string(entry.ignore_type)}</td>
                    <td>{format_expires(entry)}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
          <div class="dialog-buttons dialog-buttons--start u-mt-8">
            <button
              type="button"
              class="btn-sm btn-icon"
              data-testid="ignore-add-btn"
              phx-click="ignore_dialog_add"
            >
              <Icons.icon_btn_add class="btn-icon__svg" /> Add...
            </button>
            <button
              type="button"
              class="btn-sm btn-icon"
              data-testid="ignore-remove-btn"
              phx-click="ignore_dialog_remove"
              disabled={is_nil(@ignore_selected)}
            >
              <Icons.icon_btn_remove class="btn-icon__svg" /> Remove
            </button>
          </div>
        </div>
      </div>
    </div>

    <%= if @show_ignore_add_dialog do %>
      <div
        class="dialog-overlay dialog-overlay--light dialog-overlay--above"
        data-testid="ignore-add-dialog"
      >
        <div class="window dialog-window--sm">
          <div class="title-bar">
            <Icons.icon_dialog_ignore class="title-bar-icon" />
            <div class="title-bar-text">Add Ignore</div>
          </div>
          <div class="window-body dialog-body--p8">
            <form phx-submit="ignore_dialog_add_confirm">
              <div class="field-row-stacked u-mb-8">
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
              <div class="field-row-stacked u-mb-8">
                <label for="ignore-type-select">Type:</label>
                <select id="ignore-type-select" name="type" data-testid="ignore-type-select">
                  <option value="all" selected>all</option>
                  <option value="messages">messages</option>
                  <option value="pms">pms</option>
                  <option value="invites">invites</option>
                  <option value="actions">actions</option>
                </select>
              </div>
              <div class="field-row-stacked u-mb-8">
                <label for="ignore-duration-input">Duration (optional, e.g. 5m, 2h, 1d):</label>
                <input
                  type="text"
                  id="ignore-duration-input"
                  name="duration"
                  data-testid="ignore-duration-input"
                  placeholder="Leave empty for permanent"
                />
              </div>
              <div class="dialog-buttons">
                <button type="submit" class="btn-icon" data-testid="ignore-add-confirm">
                  <Icons.icon_btn_ok class="btn-icon__svg" /> OK
                </button>
                <button
                  type="button"
                  class="btn-icon"
                  phx-click="close_ignore_add_dialog"
                  data-testid="ignore-add-cancel"
                >
                  <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
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
