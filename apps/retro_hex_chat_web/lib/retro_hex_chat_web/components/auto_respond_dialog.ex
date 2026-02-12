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
    <div
      :if={@visible}
      class="dialog-overlay"
      style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 200; display: flex; align-items: center; justify-content: center;"
    >
      <div
        class="window"
        style="width: 500px; max-height: 80vh; display: flex; flex-direction: column;"
        data-testid="autorespond-dialog"
      >
        <div class="title-bar">
          <div class="title-bar-text">Auto-Respond Rules</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_autorespond_dialog"></button>
          </div>
        </div>
        <div
          class="window-body"
          style="padding: 8px; display: flex; flex-direction: column; gap: 8px; overflow: hidden;"
        >
          <fieldset style="flex: 1; overflow: hidden; display: flex; flex-direction: column;">
            <legend>Rules</legend>
            <div style="overflow-y: auto; max-height: 200px; border: 1px inset;">
              <table style="width: 100%; border-collapse: collapse;">
                <thead>
                  <tr>
                    <th style="text-align: left; padding: 2px 4px; background: #c0c0c0; border-bottom: 1px solid #808080; width: 20px;">
                    </th>
                    <th style="text-align: left; padding: 2px 4px; background: #c0c0c0; border-bottom: 1px solid #808080;">
                      Trigger
                    </th>
                    <th style="text-align: left; padding: 2px 4px; background: #c0c0c0; border-bottom: 1px solid #808080;">
                      Channel
                    </th>
                    <th style="text-align: left; padding: 2px 4px; background: #c0c0c0; border-bottom: 1px solid #808080;">
                      Command
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @rules == [] do %>
                    <tr>
                      <td colspan="4" style="padding: 8px; text-align: center; color: #808080;">
                        No auto-respond rules. Click "Add" to create one.
                      </td>
                    </tr>
                  <% else %>
                    <tr
                      :for={entry <- @rules}
                      phx-click="autorespond_select"
                      phx-value-position={entry.position}
                      data-testid={"autorespond-entry-#{entry.position}"}
                      style={row_style(entry.position, @selected_position)}
                    >
                      <td style="padding: 2px 4px; text-align: center;">
                        <input
                          type="checkbox"
                          checked={entry.enabled}
                          phx-click="autorespond_toggle"
                          phx-value-position={entry.position}
                          data-testid={"autorespond-toggle-#{entry.position}"}
                          style="cursor: pointer;"
                        />
                      </td>
                      <td style="padding: 2px 4px;">{trigger_label(entry.trigger_event)}</td>
                      <td style={"padding: 2px 4px; color: #{if entry.channel_filter, do: "inherit", else: "#808080"};"}>
                        {entry.channel_filter || "(all)"}
                      </td>
                      <td style="padding: 2px 4px; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                        {entry.command}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </fieldset>

          <div :if={@editing} style="border: 1px inset; padding: 8px;">
            <form phx-submit="autorespond_dialog_save" data-testid="autorespond-edit-form">
              <div style="display: flex; flex-direction: column; gap: 4px;">
                <div style="display: flex; align-items: center; gap: 8px;">
                  <label style="width: 80px;">Trigger:</label>
                  <select
                    name="trigger"
                    style="flex: 1;"
                    data-testid="autorespond-trigger-select"
                  >
                    <option value="on_join" selected={@draft_trigger == "on_join"}>On Join</option>
                    <option value="on_part" selected={@draft_trigger == "on_part"}>On Part</option>
                    <option value="on_nick_change" selected={@draft_trigger == "on_nick_change"}>
                      On Nick Change
                    </option>
                  </select>
                </div>
                <div style="display: flex; align-items: center; gap: 8px;">
                  <label style="width: 80px;">Channel:</label>
                  <input
                    type="text"
                    name="channel"
                    value={@draft_channel}
                    maxlength="50"
                    placeholder="e.g. #welcome (leave empty for all)"
                    style="flex: 1;"
                    data-testid="autorespond-channel-input"
                  />
                </div>
                <div style="display: flex; align-items: center; gap: 8px;">
                  <label style="width: 80px;">Command:</label>
                  <input
                    type="text"
                    name="command"
                    value={@draft_command}
                    maxlength="500"
                    placeholder="e.g. /notice $nick Welcome!"
                    style="flex: 1;"
                    data-testid="autorespond-command-input"
                  />
                </div>
                <div style="font-size: 10px; color: #808080; padding-left: 88px;">
                  Variables: $nick (triggering user), $chan (channel name)
                </div>
                <div
                  :if={@error_message}
                  style="color: red; font-size: 11px; padding-left: 88px;"
                  data-testid="autorespond-error"
                >
                  {@error_message}
                </div>
                <div style="display: flex; justify-content: flex-end; gap: 4px; margin-top: 4px;">
                  <button type="submit" data-testid="autorespond-save-btn">Save</button>
                  <button type="button" phx-click="autorespond_dialog_cancel_edit">Cancel</button>
                </div>
              </div>
            </form>
          </div>

          <div style="display: flex; justify-content: flex-end; gap: 4px;">
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

  defp row_style(position, selected) when position == selected do
    "background: #000080; color: #ffffff; cursor: pointer;"
  end

  defp row_style(_position, _selected) do
    "cursor: pointer;"
  end

  defp trigger_label(:on_join), do: "On Join"
  defp trigger_label(:on_part), do: "On Part"
  defp trigger_label(:on_nick_change), do: "On Nick Change"
  defp trigger_label(other), do: to_string(other)
end
