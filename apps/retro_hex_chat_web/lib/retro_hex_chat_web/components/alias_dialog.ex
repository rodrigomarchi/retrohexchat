defmodule RetroHexChatWeb.Components.AliasDialog do
  @moduledoc """
  98.css dialog for managing user-defined command aliases.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :aliases, :list, default: []
  attr :selected_alias, :string, default: nil
  attr :editing, :boolean, default: false
  attr :draft_name, :string, default: ""
  attr :draft_expansion, :string, default: ""
  attr :warning_message, :string, default: nil
  attr :error_message, :string, default: nil

  @spec alias_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def alias_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 200; display: flex; align-items: center; justify-content: center;"
    >
      <div
        class="window"
        style="width: 440px; max-height: 80vh; display: flex; flex-direction: column;"
        data-testid="alias-dialog"
      >
        <div class="title-bar">
          <div class="title-bar-text">Alias Editor</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_alias_dialog"></button>
          </div>
        </div>
        <div
          class="window-body"
          style="padding: 8px; display: flex; flex-direction: column; gap: 8px; overflow: hidden;"
        >
          <fieldset style="flex: 1; overflow: hidden; display: flex; flex-direction: column;">
            <legend>Aliases</legend>
            <div style="overflow-y: auto; max-height: 200px; border: 1px inset;">
              <table style="width: 100%; border-collapse: collapse;">
                <thead>
                  <tr>
                    <th style="text-align: left; padding: 2px 4px; background: #c0c0c0; border-bottom: 1px solid #808080;">
                      Name
                    </th>
                    <th style="text-align: left; padding: 2px 4px; background: #c0c0c0; border-bottom: 1px solid #808080;">
                      Expansion
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @aliases == [] do %>
                    <tr>
                      <td colspan="2" style="padding: 8px; text-align: center; color: #808080;">
                        No aliases configured. Click "Add" to create one.
                      </td>
                    </tr>
                  <% else %>
                    <tr
                      :for={entry <- @aliases}
                      phx-click="alias_select"
                      phx-value-name={entry.name}
                      data-testid={"alias-entry-#{entry.name}"}
                      style={row_style(entry.name, @selected_alias)}
                    >
                      <td style="padding: 2px 4px;">/{entry.name}</td>
                      <td style="padding: 2px 4px; max-width: 280px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                        {entry.expansion}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </fieldset>

          <div :if={@warning_message} style="color: #808000; font-size: 11px; padding: 2px 4px;">
            {raw_warning(@warning_message)}
          </div>

          <div :if={@editing} style="border: 1px inset; padding: 8px;">
            <form phx-submit="alias_dialog_save" data-testid="alias-edit-form">
              <div style="display: flex; flex-direction: column; gap: 4px;">
                <div style="display: flex; align-items: center; gap: 8px;">
                  <label style="width: 80px;">Name:</label>
                  <input
                    type="text"
                    name="name"
                    value={@draft_name}
                    maxlength="30"
                    placeholder="e.g. hi"
                    style="flex: 1;"
                    data-testid="alias-name-input"
                    disabled={@selected_alias != nil}
                  />
                </div>
                <div style="display: flex; align-items: center; gap: 8px;">
                  <label style="width: 80px;">Expansion:</label>
                  <input
                    type="text"
                    name="expansion"
                    value={@draft_expansion}
                    maxlength="500"
                    placeholder="e.g. /me says hello!"
                    style="flex: 1;"
                    data-testid="alias-expansion-input"
                  />
                </div>
                <div style="font-size: 10px; color: #808080; padding-left: 88px;">
                  Variables: $1-$9 (args), $nick (your nick), $chan (channel)
                </div>
                <div
                  :if={@error_message}
                  style="color: red; font-size: 11px; padding-left: 88px;"
                  data-testid="alias-error"
                >
                  {@error_message}
                </div>
                <div style="display: flex; justify-content: flex-end; gap: 4px; margin-top: 4px;">
                  <button type="submit" data-testid="alias-save-btn">Save</button>
                  <button type="button" phx-click="alias_dialog_cancel_edit">Cancel</button>
                </div>
              </div>
            </form>
          </div>

          <div style="display: flex; justify-content: flex-end; gap: 4px;">
            <button phx-click="alias_dialog_add" data-testid="alias-add-btn">Add</button>
            <button
              phx-click="alias_dialog_edit"
              disabled={@selected_alias == nil}
              data-testid="alias-edit-btn"
            >
              Edit
            </button>
            <button
              phx-click="alias_dialog_delete"
              disabled={@selected_alias == nil}
              data-testid="alias-delete-btn"
            >
              Remove
            </button>
            <button phx-click="close_alias_dialog">Close</button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp row_style(name, selected) when name == selected do
    "background: #000080; color: #ffffff; cursor: pointer;"
  end

  defp row_style(_name, _selected) do
    "cursor: pointer;"
  end

  defp raw_warning(msg), do: msg
end
