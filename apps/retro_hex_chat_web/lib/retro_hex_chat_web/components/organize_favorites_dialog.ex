defmodule RetroHexChatWeb.Components.OrganizeFavoritesDialog do
  @moduledoc """
  Organize Favorites dialog with ordered list, selection, Up/Down/Edit/Remove buttons.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :favorites, :list, default: []
  attr :selected, :string, default: nil

  @spec organize_favorites_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def organize_favorites_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      data-testid="organize-favorites-dialog"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.3);"
    >
      <div class="window" style="width: 420px; min-height: 300px;">
        <div class="title-bar">
          <div class="title-bar-text">Organize Favorites</div>
          <div class="title-bar-controls">
            <button
              aria-label="Close"
              data-testid="organize-favorites-close"
              phx-click="close_organize_favorites"
            >
            </button>
          </div>
        </div>
        <div class="window-body" style="padding: 8px; display: flex; flex-direction: column;">
          <div class="sunken-panel" style="flex: 1; overflow-y: auto; min-height: 160px;">
            <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
              <thead>
                <tr style="background: #c0c0c0; position: sticky; top: 0;">
                  <th style="text-align: left; padding: 2px 4px;">Channel</th>
                  <th style="text-align: left; padding: 2px 4px;">Description</th>
                  <th style="text-align: left; padding: 2px 4px;">Password</th>
                  <th style="text-align: left; padding: 2px 4px;">Auto-Join</th>
                </tr>
              </thead>
              <tbody>
                <%= if @favorites == [] do %>
                  <tr>
                    <td
                      colspan="4"
                      style="text-align: center; padding: 16px; color: #808080;"
                      data-testid="organize-empty"
                    >
                      No favorites configured
                    </td>
                  </tr>
                <% else %>
                  <tr
                    :for={fav <- @favorites}
                    phx-click="favorite_select"
                    phx-value-channel={fav.channel_name}
                    data-testid={"organize-fav-#{fav.channel_name}"}
                    style={row_style(fav.channel_name, @selected)}
                  >
                    <td style="padding: 2px 4px;">{fav.channel_name}</td>
                    <td style="padding: 2px 4px;">{fav.description}</td>
                    <td style="padding: 2px 4px;">
                      {if fav.password != nil and fav.password != "", do: "Password set", else: ""}
                    </td>
                    <td style="padding: 2px 4px;">{if fav.auto_join, do: "Yes", else: ""}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
          <div style="margin-top: 8px; display: flex; gap: 4px; align-items: center;">
            <button
              type="button"
              data-testid="organize-edit-btn"
              phx-click="favorite_edit"
              disabled={is_nil(@selected)}
              style="font-size: 11px; padding: 1px 8px;"
            >
              Edit...
            </button>
            <button
              type="button"
              data-testid="organize-remove-btn"
              phx-click="favorite_remove"
              disabled={is_nil(@selected)}
              style="font-size: 11px; padding: 1px 8px;"
            >
              Remove
            </button>
            <div style="width: 1px; height: 16px; background: #808080; margin: 0 4px;"></div>
            <button
              type="button"
              data-testid="organize-move-up-btn"
              phx-click="favorite_move_up"
              disabled={is_nil(@selected) or first_entry?(@favorites, @selected)}
              style="font-size: 11px; padding: 1px 8px;"
            >
              Move Up
            </button>
            <button
              type="button"
              data-testid="organize-move-down-btn"
              phx-click="favorite_move_down"
              disabled={is_nil(@selected) or last_entry?(@favorites, @selected)}
              style="font-size: 11px; padding: 1px 8px;"
            >
              Move Down
            </button>
            <div style="flex: 1;"></div>
            <button
              type="button"
              data-testid="organize-close-btn"
              phx-click="close_organize_favorites"
              style="font-size: 11px; padding: 1px 8px;"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp row_style(channel, selected) when channel == selected do
    "background: #000080; color: #ffffff; cursor: pointer;"
  end

  defp row_style(_channel, _selected) do
    "cursor: pointer;"
  end

  defp first_entry?([], _selected), do: true

  defp first_entry?(favorites, selected) do
    case List.first(favorites) do
      nil -> true
      first -> first.channel_name == selected
    end
  end

  defp last_entry?([], _selected), do: true

  defp last_entry?(favorites, selected) do
    case List.last(favorites) do
      nil -> true
      last -> last.channel_name == selected
    end
  end
end
