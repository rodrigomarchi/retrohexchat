defmodule RetroHexChatWeb.Components.PerformDialog do
  @moduledoc """
  Perform / Auto-Commands dialog (Alt+P).
  Manages perform commands and auto-join channels with tabbed interface.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.PerformList

  attr :visible, :boolean, default: false
  attr :active_tab, :string, default: "commands"
  attr :perform_entries, :list, default: []
  attr :perform_selected, :integer, default: nil
  attr :perform_enabled, :boolean, default: true
  attr :autojoin_entries, :list, default: []
  attr :autojoin_selected, :string, default: nil
  attr :show_perform_add_dialog, :boolean, default: false
  attr :show_perform_edit_dialog, :boolean, default: false
  attr :show_autojoin_add_dialog, :boolean, default: false
  attr :show_autojoin_edit_dialog, :boolean, default: false

  @spec perform_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def perform_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      data-testid="perform-dialog"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.3);"
    >
      <div class="window" style="width: 460px; min-height: 340px;">
        <div class="title-bar">
          <div class="title-bar-text">Perform / Auto-Commands</div>
          <div class="title-bar-controls">
            <button
              aria-label="Close"
              data-testid="perform-dialog-close"
              phx-click="close_perform_dialog"
            >
            </button>
          </div>
        </div>
        <div class="window-body" style="padding: 8px; display: flex; flex-direction: column;">
          <menu role="tablist" style="margin-bottom: 0;">
            <li role="tab" aria-selected={@active_tab == "commands"}>
              <a
                href="#"
                phx-click="perform_dialog_tab"
                phx-value-tab="commands"
                data-testid="perform-tab-commands"
              >
                Commands
              </a>
            </li>
            <li role="tab" aria-selected={@active_tab == "autojoin"}>
              <a
                href="#"
                phx-click="perform_dialog_tab"
                phx-value-tab="autojoin"
                data-testid="perform-tab-autojoin"
              >
                Auto-Join
              </a>
            </li>
          </menu>
          <div class="window" role="tabpanel" style="min-height: 220px;">
            <div class="window-body" style="padding: 8px;">
              <%= if @active_tab == "commands" do %>
                <.commands_tab
                  entries={@perform_entries}
                  selected={@perform_selected}
                  enabled={@perform_enabled}
                />
              <% else %>
                <.autojoin_tab
                  entries={@autojoin_entries}
                  selected={@autojoin_selected}
                />
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>

    <.perform_add_sub_dialog :if={@show_perform_add_dialog} />
    <.perform_edit_sub_dialog
      :if={@show_perform_edit_dialog}
      selected={@perform_selected}
      entries={@perform_entries}
    />
    <.autojoin_add_sub_dialog :if={@show_autojoin_add_dialog} />
    <.autojoin_edit_sub_dialog
      :if={@show_autojoin_edit_dialog}
      selected={@autojoin_selected}
      entries={@autojoin_entries}
    />
    """
  end

  defp commands_tab(assigns) do
    ~H"""
    <div style="display: flex; flex-direction: column; height: 100%;">
      <div class="sunken-panel" style="flex: 1; overflow-y: auto; min-height: 120px;">
        <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
          <thead>
            <tr style="background: #c0c0c0; position: sticky; top: 0;">
              <th style="text-align: left; padding: 2px 4px; width: 30px;">#</th>
              <th style="text-align: left; padding: 2px 4px;">Command</th>
            </tr>
          </thead>
          <tbody>
            <%= if @entries == [] do %>
              <tr>
                <td
                  colspan="2"
                  style="text-align: center; padding: 16px; color: #808080;"
                  data-testid="perform-empty"
                >
                  No perform commands configured
                </td>
              </tr>
            <% else %>
              <tr
                :for={entry <- @entries}
                phx-click="perform_select"
                phx-value-position={entry.position}
                data-testid={"perform-entry-#{entry.position}"}
                style={row_style(entry.position, @selected)}
              >
                <td style="padding: 2px 4px;">{entry.position}</td>
                <td style="padding: 2px 4px;">{PerformList.mask_command(entry.command)}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      <div style="margin-top: 8px; display: flex; gap: 4px; align-items: center;">
        <button
          type="button"
          data-testid="perform-add-btn"
          phx-click="perform_dialog_add"
          style="font-size: 11px; padding: 1px 8px;"
        >
          Add...
        </button>
        <button
          type="button"
          data-testid="perform-edit-btn"
          phx-click="perform_dialog_edit"
          disabled={is_nil(@selected)}
          style="font-size: 11px; padding: 1px 8px;"
        >
          Edit...
        </button>
        <button
          type="button"
          data-testid="perform-remove-btn"
          phx-click="perform_dialog_remove"
          disabled={is_nil(@selected)}
          style="font-size: 11px; padding: 1px 8px;"
        >
          Remove
        </button>
        <div style="width: 1px; height: 16px; background: #808080; margin: 0 4px;"></div>
        <button
          type="button"
          data-testid="perform-move-up-btn"
          phx-click="perform_dialog_move_up"
          disabled={is_nil(@selected) or @selected == 0}
          style="font-size: 11px; padding: 1px 8px;"
        >
          Move Up
        </button>
        <button
          type="button"
          data-testid="perform-move-down-btn"
          phx-click="perform_dialog_move_down"
          disabled={is_nil(@selected) or @selected == length(@entries) - 1}
          style="font-size: 11px; padding: 1px 8px;"
        >
          Move Down
        </button>
      </div>
      <div style="margin-top: 8px;">
        <label style="display: flex; align-items: center; gap: 4px; font-size: 11px;">
          <input
            type="checkbox"
            checked={@enabled}
            phx-click="perform_toggle_enabled"
            data-testid="perform-enable-checkbox"
          /> Enable on connect
        </label>
      </div>
    </div>
    """
  end

  defp autojoin_tab(assigns) do
    ~H"""
    <div style="display: flex; flex-direction: column; height: 100%;">
      <div class="sunken-panel" style="flex: 1; overflow-y: auto; min-height: 120px;">
        <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
          <thead>
            <tr style="background: #c0c0c0; position: sticky; top: 0;">
              <th style="text-align: left; padding: 2px 4px;">Channel</th>
              <th style="text-align: left; padding: 2px 4px;">Key</th>
            </tr>
          </thead>
          <tbody>
            <%= if @entries == [] do %>
              <tr>
                <td
                  colspan="2"
                  style="text-align: center; padding: 16px; color: #808080;"
                  data-testid="autojoin-empty"
                >
                  No auto-join channels configured
                </td>
              </tr>
            <% else %>
              <tr
                :for={entry <- @entries}
                phx-click="autojoin_select"
                phx-value-channel={entry.channel_name}
                data-testid={"autojoin-entry-#{entry.channel_name}"}
                style={autojoin_row_style(entry.channel_name, @selected)}
              >
                <td style="padding: 2px 4px;">{entry.channel_name}</td>
                <td style="padding: 2px 4px;">{if entry.channel_key, do: "****", else: ""}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      <div style="margin-top: 8px; display: flex; gap: 4px;">
        <button
          type="button"
          data-testid="autojoin-add-btn"
          phx-click="autojoin_dialog_add"
          style="font-size: 11px; padding: 1px 8px;"
        >
          Add...
        </button>
        <button
          type="button"
          data-testid="autojoin-edit-btn"
          phx-click="autojoin_dialog_edit"
          disabled={is_nil(@selected)}
          style="font-size: 11px; padding: 1px 8px;"
        >
          Edit...
        </button>
        <button
          type="button"
          data-testid="autojoin-remove-btn"
          phx-click="autojoin_dialog_remove"
          disabled={is_nil(@selected)}
          style="font-size: 11px; padding: 1px 8px;"
        >
          Remove
        </button>
      </div>
    </div>
    """
  end

  defp perform_add_sub_dialog(assigns) do
    ~H"""
    <div
      class="dialog-overlay"
      data-testid="perform-add-dialog"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 210; background: rgba(0,0,0,0.2);"
    >
      <div class="window" style="width: 360px;">
        <div class="title-bar">
          <div class="title-bar-text">Add Perform Command</div>
        </div>
        <div class="window-body" style="padding: 8px;">
          <form phx-submit="perform_dialog_add_confirm">
            <div class="field-row-stacked" style="margin-bottom: 8px;">
              <label for="perform-command-input">Command:</label>
              <input
                type="text"
                id="perform-command-input"
                name="command"
                data-testid="perform-command-input"
                maxlength="500"
                placeholder="/join #channel"
                required
                autofocus
              />
            </div>
            <div style="display: flex; gap: 4px; justify-content: flex-end;">
              <button type="submit" data-testid="perform-add-confirm">OK</button>
              <button
                type="button"
                phx-click="close_perform_add_dialog"
                data-testid="perform-add-cancel"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp perform_edit_sub_dialog(assigns) do
    entry = find_entry(assigns.entries, assigns.selected)
    assigns = assign(assigns, :edit_command, if(entry, do: entry.command, else: ""))

    ~H"""
    <div
      class="dialog-overlay"
      data-testid="perform-edit-dialog"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 210; background: rgba(0,0,0,0.2);"
    >
      <div class="window" style="width: 360px;">
        <div class="title-bar">
          <div class="title-bar-text">Edit Perform Command</div>
        </div>
        <div class="window-body" style="padding: 8px;">
          <form phx-submit="perform_dialog_edit_confirm">
            <div class="field-row-stacked" style="margin-bottom: 8px;">
              <label for="perform-edit-input">Command:</label>
              <input
                type="text"
                id="perform-edit-input"
                name="command"
                data-testid="perform-edit-input"
                maxlength="500"
                value={@edit_command}
                required
                autofocus
              />
            </div>
            <div style="display: flex; gap: 4px; justify-content: flex-end;">
              <button type="submit" data-testid="perform-edit-confirm">OK</button>
              <button
                type="button"
                phx-click="close_perform_edit_dialog"
                data-testid="perform-edit-cancel"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp autojoin_add_sub_dialog(assigns) do
    ~H"""
    <div
      class="dialog-overlay"
      data-testid="autojoin-add-dialog"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 210; background: rgba(0,0,0,0.2);"
    >
      <div class="window" style="width: 320px;">
        <div class="title-bar">
          <div class="title-bar-text">Add Auto-Join Channel</div>
        </div>
        <div class="window-body" style="padding: 8px;">
          <form phx-submit="autojoin_dialog_add_confirm">
            <div class="field-row-stacked" style="margin-bottom: 8px;">
              <label for="autojoin-channel-input">Channel:</label>
              <input
                type="text"
                id="autojoin-channel-input"
                name="channel"
                data-testid="autojoin-channel-input"
                maxlength="50"
                placeholder="#channel"
                required
                autofocus
              />
            </div>
            <div class="field-row-stacked" style="margin-bottom: 8px;">
              <label for="autojoin-key-input">Key (optional):</label>
              <input
                type="text"
                id="autojoin-key-input"
                name="key"
                data-testid="autojoin-key-input"
                maxlength="50"
                placeholder="Leave empty if no key"
              />
            </div>
            <div style="display: flex; gap: 4px; justify-content: flex-end;">
              <button type="submit" data-testid="autojoin-add-confirm">OK</button>
              <button
                type="button"
                phx-click="close_autojoin_add_dialog"
                data-testid="autojoin-add-cancel"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp autojoin_edit_sub_dialog(assigns) do
    entry = find_autojoin_entry(assigns.entries, assigns.selected)

    assigns =
      assigns
      |> assign(:edit_channel, if(entry, do: entry.channel_name, else: ""))
      |> assign(:edit_key, if(entry, do: entry.channel_key || "", else: ""))

    ~H"""
    <div
      class="dialog-overlay"
      data-testid="autojoin-edit-dialog"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 210; background: rgba(0,0,0,0.2);"
    >
      <div class="window" style="width: 320px;">
        <div class="title-bar">
          <div class="title-bar-text">Edit Auto-Join Channel</div>
        </div>
        <div class="window-body" style="padding: 8px;">
          <form phx-submit="autojoin_dialog_edit_confirm">
            <div class="field-row-stacked" style="margin-bottom: 8px;">
              <label for="autojoin-edit-channel">Channel:</label>
              <input
                type="text"
                id="autojoin-edit-channel"
                name="channel"
                data-testid="autojoin-edit-channel"
                value={@edit_channel}
                disabled
              />
            </div>
            <div class="field-row-stacked" style="margin-bottom: 8px;">
              <label for="autojoin-edit-key">Key (optional):</label>
              <input
                type="text"
                id="autojoin-edit-key"
                name="key"
                data-testid="autojoin-edit-key"
                maxlength="50"
                value={@edit_key}
                autofocus
              />
            </div>
            <div style="display: flex; gap: 4px; justify-content: flex-end;">
              <button type="submit" data-testid="autojoin-edit-confirm">OK</button>
              <button
                type="button"
                phx-click="close_autojoin_edit_dialog"
                data-testid="autojoin-edit-cancel"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp row_style(position, selected) when position == selected do
    "background: #000080; color: #ffffff; cursor: pointer;"
  end

  defp row_style(_position, _selected) do
    "cursor: pointer;"
  end

  defp autojoin_row_style(channel, selected) when channel == selected do
    "background: #000080; color: #ffffff; cursor: pointer;"
  end

  defp autojoin_row_style(_channel, _selected) do
    "cursor: pointer;"
  end

  defp find_entry(entries, position) do
    Enum.find(entries, fn e -> e.position == position end)
  end

  defp find_autojoin_entry(entries, channel) do
    Enum.find(entries, fn e -> e.channel_name == channel end)
  end
end
