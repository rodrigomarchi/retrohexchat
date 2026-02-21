defmodule RetroHexChatWeb.Components.CustomMenusDialog do
  @moduledoc """
  98.css dialog for managing custom popup menu items for nicklist and channel context menus.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

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
    >
      <div
        class="window u-flex-col dialog-window--custom-menus"
        data-testid="custom-menus-dialog"
      >
        <div class="title-bar">
          <Icons.icon_dialog_custom_menus class="title-bar-icon" />
          <div class="title-bar-text">Custom Menus</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_custom_menus_dialog"></button>
          </div>
        </div>
        <div class="dialog-body--p8 u-flex-col u-gap-8 u-overflow-hidden">
          <div class="u-flex">
            <button
              class="btn-icon"
              phx-click="custom_menus_tab"
              phx-value-tab="nicklist"
              style={"padding: 4px 12px; #{if @active_tab == :nicklist, do: "font-weight: bold;", else: ""}"}
              data-testid="custom-menus-tab-nicklist"
            >
              <Icons.icon_tab_nicklist class="btn-icon__svg" /> Nicklist
            </button>
            <button
              class="btn-icon"
              phx-click="custom_menus_tab"
              phx-value-tab="channel"
              style={"padding: 4px 12px; #{if @active_tab == :channel, do: "font-weight: bold;", else: ""}"}
              data-testid="custom-menus-tab-channel"
            >
              <Icons.icon_tab_channel class="btn-icon__svg" /> Channel
            </button>
          </div>

          <fieldset class="u-flex-1 u-overflow-hidden u-flex-col">
            <legend>{tab_label(@active_tab)} Menu Items</legend>
            <div class="list-container custom-menus-list">
              <table class="table-standard">
                <thead>
                  <tr>
                    <th>Label</th>
                    <th>Command</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @filtered_entries == [] do %>
                    <tr class="table-empty">
                      <td colspan="2">
                        No custom menu items. Click "Add" to create one.
                      </td>
                    </tr>
                  <% else %>
                    <tr
                      :for={entry <- @filtered_entries}
                      phx-click="custom_menu_select"
                      phx-value-label={entry.label}
                      data-testid={"custom-menu-entry-#{entry.label}"}
                      class={[
                        "table-row--selectable",
                        entry.label == @selected_item && "table-row--selected"
                      ]}
                    >
                      <td>{entry.label}</td>
                      <td class="table-cell--ellipsis custom-menus-cmd-cell">
                        {entry.command}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </fieldset>

          <div :if={@editing} class="edit-panel">
            <form phx-submit="custom_menu_dialog_save" data-testid="custom-menu-edit-form">
              <div class="u-flex-col u-gap-4">
                <div class="form-row form-row--gap-8">
                  <label class="form-label--w80">Label:</label>
                  <input
                    type="text"
                    name="label"
                    value={@draft_label}
                    maxlength="50"
                    placeholder="e.g. Send greeting"
                    class="u-flex-1"
                    data-testid="custom-menu-label-input"
                  />
                </div>
                <div class="form-row form-row--gap-8">
                  <label class="form-label--w80">Command:</label>
                  <input
                    type="text"
                    name="command"
                    value={@draft_command}
                    maxlength="500"
                    placeholder="e.g. /notice $1 Welcome!"
                    class="u-flex-1"
                    data-testid="custom-menu-command-input"
                  />
                </div>
                <div class="form-hint form-hint--indented">
                  Variables: $1 (target nick/channel), $nick (your nick), $chan (channel)
                </div>
                <div
                  :if={@error_message}
                  class="form-error form-hint--indented"
                  data-testid="custom-menu-error"
                >
                  {@error_message}
                </div>
                <div class="dialog-buttons u-mt-4">
                  <button type="submit" class="btn-icon">
                    <Icons.icon_btn_save class="btn-icon__svg" /> Save
                  </button>
                  <button type="button" class="btn-icon" phx-click="custom_menu_dialog_cancel_edit">
                    <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
                  </button>
                </div>
              </div>
            </form>
          </div>

          <div class="dialog-buttons">
            <button
              class="btn-icon"
              phx-click="custom_menu_dialog_add"
              data-testid="custom-menu-add-btn"
            >
              <Icons.icon_btn_add class="btn-icon__svg" /> Add
            </button>
            <button
              class="btn-icon"
              phx-click="custom_menu_dialog_edit"
              disabled={@selected_item == nil}
              data-testid="custom-menu-edit-btn"
            >
              <Icons.icon_btn_edit class="btn-icon__svg" /> Edit
            </button>
            <button
              class="btn-icon"
              phx-click="custom_menu_dialog_delete"
              disabled={@selected_item == nil}
              data-testid="custom-menu-delete-btn"
            >
              <Icons.icon_btn_remove class="btn-icon__svg" /> Remove
            </button>
            <button class="btn-icon" phx-click="close_custom_menus_dialog">
              <Icons.icon_btn_cancel class="btn-icon__svg" /> Close
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp tab_label(:nicklist), do: "Nicklist"
  defp tab_label(:channel), do: "Channel"
end
