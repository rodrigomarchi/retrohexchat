defmodule RetroHexChatWeb.Components.PerformDialog do
  @moduledoc """
  Perform / Auto-Commands dialog (Ctrl+Shift+E).
  Manages perform commands and auto-join channels with tabbed interface.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.PerformList
  alias RetroHexChatWeb.Icons

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
    >
      <div class="window dialog-window--perform">
        <div class="title-bar">
          <Icons.icon_dialog_perform class="title-bar-icon" />
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
        <div class="window-body dialog-body--p8 u-flex-col">
          <menu role="tablist" class="u-mb-0">
            <li role="tab" aria-selected={@active_tab == "commands"}>
              <a
                href="#"
                phx-click="perform_dialog_tab"
                phx-value-tab="commands"
                data-testid="perform-tab-commands"
                class="tab-icon"
              >
                <Icons.icon_tab_commands class="btn-icon__svg" /> Commands
              </a>
            </li>
            <li role="tab" aria-selected={@active_tab == "autojoin"}>
              <a
                href="#"
                phx-click="perform_dialog_tab"
                phx-value-tab="autojoin"
                data-testid="perform-tab-autojoin"
                class="tab-icon"
              >
                <Icons.icon_tab_autojoin class="btn-icon__svg" /> Auto-Join
              </a>
            </li>
          </menu>
          <div class="window perform-tab-panel" role="tabpanel">
            <div class="window-body dialog-body--p8">
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
    <div class="u-flex-col perform-tab-content">
      <div class="table-container perform-cmd-list">
        <table class="table-standard">
          <thead>
            <tr class="u-sticky-top">
              <th class="perform-num-col">#</th>
              <th>Command</th>
            </tr>
          </thead>
          <tbody>
            <%= if @entries == [] do %>
              <tr>
                <td
                  colspan="2"
                  class="table-empty u-p-16"
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
                class={["table-row--selectable", entry.position == @selected && "table-row--selected"]}
              >
                <td>{entry.position}</td>
                <td>{PerformList.mask_command(entry.command)}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      <div class="u-flex u-gap-4 u-items-center u-mt-8">
        <button
          type="button"
          class="btn-sm btn-icon"
          data-testid="perform-add-btn"
          phx-click="perform_dialog_add"
        >
          <Icons.icon_btn_add class="btn-icon__svg" /> Add...
        </button>
        <button
          type="button"
          class="btn-sm btn-icon"
          data-testid="perform-edit-btn"
          phx-click="perform_dialog_edit"
          disabled={is_nil(@selected)}
        >
          <Icons.icon_btn_edit class="btn-icon__svg" /> Edit...
        </button>
        <button
          type="button"
          class="btn-sm btn-icon"
          data-testid="perform-remove-btn"
          phx-click="perform_dialog_remove"
          disabled={is_nil(@selected)}
        >
          <Icons.icon_btn_remove class="btn-icon__svg" /> Remove
        </button>
        <div class="vertical-separator"></div>
        <button
          type="button"
          class="btn-sm btn-icon"
          data-testid="perform-move-up-btn"
          phx-click="perform_dialog_move_up"
          disabled={is_nil(@selected) or @selected == 0}
        >
          <Icons.icon_btn_up class="btn-icon__svg" /> Move Up
        </button>
        <button
          type="button"
          class="btn-sm btn-icon"
          data-testid="perform-move-down-btn"
          phx-click="perform_dialog_move_down"
          disabled={is_nil(@selected) or @selected == length(@entries) - 1}
        >
          <Icons.icon_btn_down class="btn-icon__svg" /> Move Down
        </button>
      </div>
      <div class="u-mt-8">
        <label class="form-row u-text-sm">
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
    <div class="u-flex-col perform-tab-content">
      <div class="table-container perform-cmd-list">
        <table class="table-standard">
          <thead>
            <tr class="u-sticky-top">
              <th>Channel</th>
              <th>Key</th>
            </tr>
          </thead>
          <tbody>
            <%= if @entries == [] do %>
              <tr>
                <td
                  colspan="2"
                  class="table-empty u-p-16"
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
                class={[
                  "table-row--selectable",
                  entry.channel_name == @selected && "table-row--selected"
                ]}
              >
                <td>{entry.channel_name}</td>
                <td>{if entry.channel_key, do: "****", else: ""}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      <div class="dialog-buttons dialog-buttons--start u-mt-8">
        <button
          type="button"
          class="btn-sm btn-icon"
          data-testid="autojoin-add-btn"
          phx-click="autojoin_dialog_add"
        >
          <Icons.icon_btn_add class="btn-icon__svg" /> Add...
        </button>
        <button
          type="button"
          class="btn-sm btn-icon"
          data-testid="autojoin-edit-btn"
          phx-click="autojoin_dialog_edit"
          disabled={is_nil(@selected)}
        >
          <Icons.icon_btn_edit class="btn-icon__svg" /> Edit...
        </button>
        <button
          type="button"
          class="btn-sm btn-icon"
          data-testid="autojoin-remove-btn"
          phx-click="autojoin_dialog_remove"
          disabled={is_nil(@selected)}
        >
          <Icons.icon_btn_remove class="btn-icon__svg" /> Remove
        </button>
      </div>
    </div>
    """
  end

  defp perform_add_sub_dialog(assigns) do
    ~H"""
    <div
      class="dialog-overlay dialog-overlay--light dialog-overlay--above"
      data-testid="perform-add-dialog"
    >
      <div class="window dialog-window--360">
        <div class="title-bar">
          <Icons.icon_dialog_perform class="title-bar-icon" />
          <div class="title-bar-text">Add Perform Command</div>
        </div>
        <div class="window-body dialog-body--p8">
          <form phx-submit="perform_dialog_add_confirm">
            <div class="field-row-stacked u-mb-8">
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
            <div class="dialog-buttons">
              <button type="submit" class="btn-icon" data-testid="perform-add-confirm">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button
                type="button"
                class="btn-icon"
                phx-click="close_perform_add_dialog"
                data-testid="perform-add-cancel"
              >
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
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
      class="dialog-overlay dialog-overlay--light dialog-overlay--above"
      data-testid="perform-edit-dialog"
    >
      <div class="window dialog-window--360">
        <div class="title-bar">
          <Icons.icon_dialog_perform class="title-bar-icon" />
          <div class="title-bar-text">Edit Perform Command</div>
        </div>
        <div class="window-body dialog-body--p8">
          <form phx-submit="perform_dialog_edit_confirm">
            <div class="field-row-stacked u-mb-8">
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
            <div class="dialog-buttons">
              <button type="submit" class="btn-icon" data-testid="perform-edit-confirm">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button
                type="button"
                class="btn-icon"
                phx-click="close_perform_edit_dialog"
                data-testid="perform-edit-cancel"
              >
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
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
      class="dialog-overlay dialog-overlay--light dialog-overlay--above"
      data-testid="autojoin-add-dialog"
    >
      <div class="window dialog-window--320">
        <div class="title-bar">
          <Icons.icon_dialog_perform class="title-bar-icon" />
          <div class="title-bar-text">Add Auto-Join Channel</div>
        </div>
        <div class="window-body dialog-body--p8">
          <form phx-submit="autojoin_dialog_add_confirm">
            <div class="field-row-stacked u-mb-8">
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
            <div class="field-row-stacked u-mb-8">
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
            <div class="dialog-buttons">
              <button type="submit" class="btn-icon" data-testid="autojoin-add-confirm">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button
                type="button"
                class="btn-icon"
                phx-click="close_autojoin_add_dialog"
                data-testid="autojoin-add-cancel"
              >
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
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
      class="dialog-overlay dialog-overlay--light dialog-overlay--above"
      data-testid="autojoin-edit-dialog"
    >
      <div class="window dialog-window--320">
        <div class="title-bar">
          <Icons.icon_dialog_perform class="title-bar-icon" />
          <div class="title-bar-text">Edit Auto-Join Channel</div>
        </div>
        <div class="window-body dialog-body--p8">
          <form phx-submit="autojoin_dialog_edit_confirm">
            <div class="field-row-stacked u-mb-8">
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
            <div class="field-row-stacked u-mb-8">
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
            <div class="dialog-buttons">
              <button type="submit" class="btn-icon" data-testid="autojoin-edit-confirm">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button
                type="button"
                class="btn-icon"
                phx-click="close_autojoin_edit_dialog"
                data-testid="autojoin-edit-cancel"
              >
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp find_entry(entries, position) do
    Enum.find(entries, fn e -> e.position == position end)
  end

  defp find_autojoin_entry(entries, channel) do
    Enum.find(entries, fn e -> e.channel_name == channel end)
  end
end
