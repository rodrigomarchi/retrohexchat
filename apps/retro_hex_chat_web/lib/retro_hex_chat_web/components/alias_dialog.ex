defmodule RetroHexChatWeb.Components.AliasDialog do
  @moduledoc """
  98.css dialog for managing user-defined command aliases.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

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
    >
      <div
        class="window u-flex-col dialog-window--alias"
        data-testid="alias-dialog"
      >
        <div class="title-bar">
          <Icons.icon_dialog_alias class="title-bar-icon" />
          <div class="title-bar-text">Alias Editor</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_alias_dialog"></button>
          </div>
        </div>
        <div class="window-body dialog-body--p8 u-flex-col u-gap-8 u-overflow-hidden">
          <fieldset class="u-flex-1 u-overflow-hidden u-flex-col">
            <legend>Aliases</legend>
            <div class="list-container crud-list">
              <table class="table-standard">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Expansion</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @aliases == [] do %>
                    <tr>
                      <td colspan="2" class="table-empty">
                        No aliases configured. Click "Add" to create one.
                      </td>
                    </tr>
                  <% else %>
                    <tr
                      :for={entry <- @aliases}
                      phx-click="alias_select"
                      phx-value-name={entry.name}
                      data-testid={"alias-entry-#{entry.name}"}
                      class={[
                        "table-row--selectable",
                        entry.name == @selected_alias && "table-row--selected"
                      ]}
                    >
                      <td>/{entry.name}</td>
                      <td class="table-cell--ellipsis alias-expansion-cell">
                        {entry.expansion}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </fieldset>

          <div :if={@warning_message} class="form-warning">
            {raw_warning(@warning_message)}
          </div>

          <div :if={@editing} class="edit-panel">
            <form phx-submit="alias_dialog_save" data-testid="alias-edit-form">
              <div class="u-flex-col u-gap-4">
                <div class="form-row form-row--gap-8">
                  <label class="form-label--w80">Name:</label>
                  <input
                    type="text"
                    name="name"
                    value={@draft_name}
                    maxlength="30"
                    placeholder="e.g. hi"
                    class="u-flex-1"
                    data-testid="alias-name-input"
                    disabled={@selected_alias != nil}
                  />
                </div>
                <div class="form-row form-row--gap-8">
                  <label class="form-label--w80">Expansion:</label>
                  <input
                    type="text"
                    name="expansion"
                    value={@draft_expansion}
                    maxlength="500"
                    placeholder="e.g. /me says hello!"
                    class="u-flex-1"
                    data-testid="alias-expansion-input"
                  />
                </div>
                <div class="form-hint form-hint--indented">
                  Variables: $1-$9 (args), $nick (your nick), $chan (channel)
                </div>
                <div
                  :if={@error_message}
                  class="form-error form-hint--indented"
                  data-testid="alias-error"
                >
                  {@error_message}
                </div>
                <div class="dialog-buttons u-mt-4">
                  <button type="submit" class="btn-icon" data-testid="alias-save-btn">
                    <Icons.icon_btn_save class="btn-icon__svg" /> Save
                  </button>
                  <button type="button" class="btn-icon" phx-click="alias_dialog_cancel_edit">
                    <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
                  </button>
                </div>
              </div>
            </form>
          </div>

          <div class="dialog-buttons">
            <button class="btn-icon" phx-click="alias_dialog_add" data-testid="alias-add-btn">
              <Icons.icon_btn_add class="btn-icon__svg" /> Add
            </button>
            <button
              class="btn-icon"
              phx-click="alias_dialog_edit"
              disabled={@selected_alias == nil}
              data-testid="alias-edit-btn"
            >
              <Icons.icon_btn_edit class="btn-icon__svg" /> Edit
            </button>
            <button
              class="btn-icon"
              phx-click="alias_dialog_delete"
              disabled={@selected_alias == nil}
              data-testid="alias-delete-btn"
            >
              <Icons.icon_btn_remove class="btn-icon__svg" /> Remove
            </button>
            <button class="btn-icon" phx-click="close_alias_dialog">
              <Icons.icon_btn_cancel class="btn-icon__svg" /> Close
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp raw_warning(msg), do: msg
end
