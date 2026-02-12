defmodule RetroHexChatWeb.Components.CustomMenusDialog do
  @moduledoc """
  98.css dialog for managing custom popup menu items for nicklist and channel context menus.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :custom_menus, :map, default: %{entries: []}
  attr :active_tab, :atom, default: :nicklist
  attr :selected_item, :string, default: nil
  attr :editing, :boolean, default: false
  attr :draft_label, :string, default: ""
  attr :draft_command, :string, default: ""
  attr :error_message, :string, default: nil

  @spec custom_menus_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def custom_menus_dialog(assigns) do
    entries =
      assigns.custom_menus.entries
      |> Enum.filter(&(&1.menu_type == assigns.active_tab))
      |> Enum.sort_by(& &1.position)

    assigns = assign(assigns, :filtered_entries, entries)

    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 200; display: flex; align-items: center; justify-content: center;"
    >
      <div
        class="window"
        style="width: 460px; max-height: 80vh; display: flex; flex-direction: column;"
        data-testid="custom-menus-dialog"
      >
        <div class="title-bar">
          <div class="title-bar-text">Custom Menus</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_custom_menus_dialog"></button>
          </div>
        </div>
        <div
          class="window-body"
          style="padding: 8px; display: flex; flex-direction: column; gap: 8px; overflow: hidden;"
        >
          <div style="display: flex; gap: 0;">
            <button
              phx-click="custom_menus_tab"
              phx-value-tab="nicklist"
              style={"padding: 4px 12px; #{if @active_tab == :nicklist, do: "font-weight: bold;", else: ""}"}
              data-testid="custom-menus-tab-nicklist"
            >
              Nicklist
            </button>
            <button
              phx-click="custom_menus_tab"
              phx-value-tab="channel"
              style={"padding: 4px 12px; #{if @active_tab == :channel, do: "font-weight: bold;", else: ""}"}
              data-testid="custom-menus-tab-channel"
            >
              Channel
            </button>
          </div>

          <fieldset style="flex: 1; overflow: hidden; display: flex; flex-direction: column;">
            <legend>{tab_label(@active_tab)} Menu Items</legend>
            <div style="overflow-y: auto; max-height: 180px; border: 1px inset;">
              <table style="width: 100%; border-collapse: collapse;">
                <thead>
                  <tr>
                    <th style="text-align: left; padding: 2px 4px; background: #c0c0c0; border-bottom: 1px solid #808080;">
                      Label
                    </th>
                    <th style="text-align: left; padding: 2px 4px; background: #c0c0c0; border-bottom: 1px solid #808080;">
                      Command
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @filtered_entries == [] do %>
                    <tr>
                      <td colspan="2" style="padding: 8px; text-align: center; color: #808080;">
                        No custom menu items. Click "Add" to create one.
                      </td>
                    </tr>
                  <% else %>
                    <tr
                      :for={entry <- @filtered_entries}
                      phx-click="custom_menu_select"
                      phx-value-label={entry.label}
                      data-testid={"custom-menu-entry-#{entry.label}"}
                      style={row_style(entry.label, @selected_item)}
                    >
                      <td style="padding: 2px 4px;">{entry.label}</td>
                      <td style="padding: 2px 4px; max-width: 260px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                        {entry.command}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </fieldset>

          <div :if={@editing} style="border: 1px inset; padding: 8px;">
            <form phx-submit="custom_menu_dialog_save" data-testid="custom-menu-edit-form">
              <div style="display: flex; flex-direction: column; gap: 4px;">
                <div style="display: flex; align-items: center; gap: 8px;">
                  <label style="width: 80px;">Label:</label>
                  <input
                    type="text"
                    name="label"
                    value={@draft_label}
                    maxlength="50"
                    placeholder="e.g. Send greeting"
                    style="flex: 1;"
                    data-testid="custom-menu-label-input"
                  />
                </div>
                <div style="display: flex; align-items: center; gap: 8px;">
                  <label style="width: 80px;">Command:</label>
                  <input
                    type="text"
                    name="command"
                    value={@draft_command}
                    maxlength="500"
                    placeholder="e.g. /notice $1 Welcome!"
                    style="flex: 1;"
                    data-testid="custom-menu-command-input"
                  />
                </div>
                <div style="font-size: 10px; color: #808080; padding-left: 88px;">
                  Variables: $1 (target nick/channel), $nick (your nick), $chan (channel)
                </div>
                <div
                  :if={@error_message}
                  style="color: red; font-size: 11px; padding-left: 88px;"
                  data-testid="custom-menu-error"
                >
                  {@error_message}
                </div>
                <div style="display: flex; justify-content: flex-end; gap: 4px; margin-top: 4px;">
                  <button type="submit">Save</button>
                  <button type="button" phx-click="custom_menu_dialog_cancel_edit">Cancel</button>
                </div>
              </div>
            </form>
          </div>

          <div style="display: flex; justify-content: flex-end; gap: 4px;">
            <button phx-click="custom_menu_dialog_add" data-testid="custom-menu-add-btn">Add</button>
            <button
              phx-click="custom_menu_dialog_edit"
              disabled={@selected_item == nil}
              data-testid="custom-menu-edit-btn"
            >
              Edit
            </button>
            <button
              phx-click="custom_menu_dialog_delete"
              disabled={@selected_item == nil}
              data-testid="custom-menu-delete-btn"
            >
              Remove
            </button>
            <button phx-click="close_custom_menus_dialog">Close</button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp row_style(label, selected) when label == selected,
    do: "background: #000080; color: #ffffff; cursor: pointer;"

  defp row_style(_label, _selected), do: "cursor: pointer;"

  defp tab_label(:nicklist), do: "Nicklist"
  defp tab_label(:channel), do: "Channel"
end
