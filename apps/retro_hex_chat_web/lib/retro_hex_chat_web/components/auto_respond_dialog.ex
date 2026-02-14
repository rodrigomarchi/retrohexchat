defmodule RetroHexChatWeb.Components.AutoRespondDialog do
  @moduledoc """
  98.css dialog for managing event-triggered auto-respond rules.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :rules, :list, default: []
  attr :selected_position, :integer, default: nil
  attr :editing, :boolean, default: false
  attr :draft_trigger, :string, default: "on_join"
  attr :draft_channel, :string, default: ""
  attr :draft_command, :string, default: ""
  attr :error_message, :string, default: nil

  @spec auto_respond_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def auto_respond_dialog(assigns) do
    ~H"""
    <div :if={@visible} class="dialog-overlay">
      <div
        class="window u-flex-col dialog-window--auto-respond"
        data-testid="autorespond-dialog"
      >
        <div class="title-bar">
          <div class="title-bar-text">Auto-Respond Rules</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_autorespond_dialog"></button>
          </div>
        </div>
        <div class="window-body dialog-body--p8 u-flex-col u-gap-8 u-overflow-hidden">
          <fieldset class="u-flex-1 u-overflow-hidden u-flex-col">
            <legend>Rules</legend>
            <div class="list-container crud-list">
              <table class="table-standard">
                <thead>
                  <tr>
                    <th class="auto-respond-check-col"></th>
                    <th>Trigger</th>
                    <th>Channel</th>
                    <th>Command</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @rules == [] do %>
                    <tr>
                      <td colspan="4" class="table-empty">
                        No auto-respond rules. Click "Add" to create one.
                      </td>
                    </tr>
                  <% else %>
                    <tr
                      :for={entry <- @rules}
                      phx-click="autorespond_select"
                      phx-value-position={entry.position}
                      data-testid={"autorespond-entry-#{entry.position}"}
                      class={[
                        "table-row--selectable",
                        entry.position == @selected_position && "table-row--selected"
                      ]}
                    >
                      <td class="u-text-center">
                        <input
                          type="checkbox"
                          checked={entry.enabled}
                          phx-click="autorespond_toggle"
                          phx-value-position={entry.position}
                          data-testid={"autorespond-toggle-#{entry.position}"}
                          class="u-cursor-pointer"
                        />
                      </td>
                      <td>{trigger_label(entry.trigger_event)}</td>
                      <td style={"color: #{if entry.channel_filter, do: "inherit", else: "#808080"};"}>
                        {entry.channel_filter || "(all)"}
                      </td>
                      <td class="table-cell--ellipsis auto-respond-cmd-cell">
                        {entry.command}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </fieldset>

          <div :if={@editing} class="edit-panel">
            <form phx-submit="autorespond_dialog_save" data-testid="autorespond-edit-form">
              <div class="u-flex-col u-gap-4">
                <div class="form-row form-row--gap-8">
                  <label class="form-label--w80">Trigger:</label>
                  <select
                    name="trigger"
                    class="u-flex-1"
                    data-testid="autorespond-trigger-select"
                  >
                    <option value="on_join" selected={@draft_trigger == "on_join"}>On Join</option>
                    <option value="on_part" selected={@draft_trigger == "on_part"}>On Part</option>
                    <option value="on_nick_change" selected={@draft_trigger == "on_nick_change"}>
                      On Nick Change
                    </option>
                  </select>
                </div>
                <div class="form-row form-row--gap-8">
                  <label class="form-label--w80">Channel:</label>
                  <input
                    type="text"
                    name="channel"
                    value={@draft_channel}
                    maxlength="50"
                    placeholder="e.g. #welcome (leave empty for all)"
                    class="u-flex-1"
                    data-testid="autorespond-channel-input"
                  />
                </div>
                <div class="form-row form-row--gap-8">
                  <label class="form-label--w80">Command:</label>
                  <input
                    type="text"
                    name="command"
                    value={@draft_command}
                    maxlength="500"
                    placeholder="e.g. /notice $nick Welcome!"
                    class="u-flex-1"
                    data-testid="autorespond-command-input"
                  />
                </div>
                <div class="form-hint form-hint--indented">
                  Variables: $nick (triggering user), $chan (channel name)
                </div>
                <div
                  :if={@error_message}
                  class="form-error form-hint--indented"
                  data-testid="autorespond-error"
                >
                  {@error_message}
                </div>
                <div class="dialog-buttons u-mt-4">
                  <button type="submit" data-testid="autorespond-save-btn">Save</button>
                  <button type="button" phx-click="autorespond_dialog_cancel_edit">Cancel</button>
                </div>
              </div>
            </form>
          </div>

          <div class="dialog-buttons">
            <button phx-click="autorespond_dialog_add" data-testid="autorespond-add-btn">
              Add
            </button>
            <button
              phx-click="autorespond_dialog_edit"
              disabled={@selected_position == nil}
              data-testid="autorespond-edit-btn"
            >
              Edit
            </button>
            <button
              phx-click="autorespond_dialog_delete"
              disabled={@selected_position == nil}
              data-testid="autorespond-delete-btn"
            >
              Remove
            </button>
            <button phx-click="close_autorespond_dialog">Close</button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp trigger_label(:on_join), do: "On Join"
  defp trigger_label(:on_part), do: "On Part"
  defp trigger_label(:on_nick_change), do: "On Nick Change"
  defp trigger_label(other), do: to_string(other)
end
