defmodule RetroHexChatWeb.Components.FavoriteDialog do
  @moduledoc """
  Add/Edit Favorite dialog with channel name, description, password, and auto-join fields.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :mode, :atom, default: :add
  attr :channel, :string, default: nil
  attr :data, :map, default: nil
  attr :is_duplicate, :boolean, default: false

  @spec favorite_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def favorite_dialog(assigns) do
    title =
      case assigns.mode do
        :edit -> "Edit Favorite"
        _ -> "Add Favorite"
      end

    data = assigns.data || %{}
    description = Map.get(data, :description, "")
    auto_join = Map.get(data, :auto_join, false)
    has_password = Map.get(data, :has_password, false)

    assigns =
      assigns
      |> assign(:title, title)
      |> assign(:description, description)
      |> assign(:auto_join_checked, auto_join)
      |> assign(:has_password, has_password)

    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      data-testid="favorite-dialog"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 210; background: rgba(0,0,0,0.2);"
    >
      <div class="window" style="width: 340px;">
        <div class="title-bar">
          <div class="title-bar-text">{@title}</div>
          <div class="title-bar-controls">
            <button
              aria-label="Close"
              data-testid="favorite-dialog-close"
              phx-click="close_favorite_dialog"
            >
            </button>
          </div>
        </div>
        <div class="window-body" style="padding: 8px;">
          <p
            :if={@is_duplicate}
            style="color: #800000; font-size: 11px; margin: 0 0 8px 0;"
            data-testid="favorite-duplicate-notice"
          >
            This channel is already in your favorites. Saving will update the existing entry.
          </p>
          <form phx-submit="save_favorite">
            <div class="field-row-stacked" style="margin-bottom: 8px;">
              <label for="favorite-channel-input">Channel:</label>
              <input
                type="text"
                id="favorite-channel-input"
                name="channel_name"
                data-testid="favorite-channel-input"
                maxlength="50"
                value={@channel}
                readonly={@mode == :edit}
                required
              />
            </div>
            <div class="field-row-stacked" style="margin-bottom: 8px;">
              <label for="favorite-description-input">Description:</label>
              <input
                type="text"
                id="favorite-description-input"
                name="description"
                data-testid="favorite-description-input"
                maxlength="200"
                value={@description}
                placeholder="Optional description"
              />
            </div>
            <div class="field-row-stacked" style="margin-bottom: 8px;">
              <label for="favorite-password-input">Password:</label>
              <input
                type="password"
                id="favorite-password-input"
                name="password"
                data-testid="favorite-password-input"
                maxlength="50"
                placeholder={if @has_password, do: "Password set", else: "Leave empty if no key"}
              />
            </div>
            <div style="margin-bottom: 8px;">
              <label style="display: flex; align-items: center; gap: 4px; font-size: 11px;">
                <input
                  type="checkbox"
                  name="auto_join"
                  value="true"
                  checked={@auto_join_checked}
                  data-testid="favorite-autojoin-checkbox"
                /> Auto-join on connect
              </label>
            </div>
            <div style="display: flex; gap: 4px; justify-content: flex-end;">
              <button type="submit" data-testid="favorite-save-btn">OK</button>
              <button
                type="button"
                phx-click="close_favorite_dialog"
                data-testid="favorite-cancel-btn"
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
end
