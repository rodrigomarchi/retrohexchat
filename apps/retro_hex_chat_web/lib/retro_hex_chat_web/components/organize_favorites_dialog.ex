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
    >
      <div class="window dialog-window--md">
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
        <div class="window-body dialog-body--p8 u-flex-col">
          <div class="table-container favorites-list">
            <table class="table-standard">
              <thead>
                <tr class="u-sticky-top">
                  <th>Channel</th>
                  <th>Description</th>
                  <th>Password</th>
                  <th>Auto-Join</th>
                </tr>
              </thead>
              <tbody>
                <%= if @favorites == [] do %>
                  <tr>
                    <td colspan="4" class="table-empty u-p-16">
                      No favorites configured
                    </td>
                  </tr>
                <% else %>
                  <tr
                    :for={fav <- @favorites}
                    phx-click="favorite_select"
                    phx-value-channel={fav.channel_name}
                    data-testid={"organize-fav-#{fav.channel_name}"}
                    class={[
                      "table-row--selectable",
                      fav.channel_name == @selected && "table-row--selected"
                    ]}
                  >
                    <td>{fav.channel_name}</td>
                    <td>{fav.description}</td>
                    <td>
                      {if fav.password != nil and fav.password != "", do: "Password set", else: ""}
                    </td>
                    <td>{if fav.auto_join, do: "Yes", else: ""}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
          <div class="u-flex u-gap-4 u-items-center u-mt-8">
            <button
              type="button"
              class="btn-sm"
              data-testid="organize-edit-btn"
              phx-click="favorite_edit"
              disabled={is_nil(@selected)}
            >
              Edit...
            </button>
            <button
              type="button"
              class="btn-sm"
              data-testid="organize-remove-btn"
              phx-click="favorite_remove"
              disabled={is_nil(@selected)}
            >
              Remove
            </button>
            <div class="vertical-separator"></div>
            <button
              type="button"
              class="btn-sm"
              data-testid="organize-move-up-btn"
              phx-click="favorite_move_up"
              disabled={is_nil(@selected) or first_entry?(@favorites, @selected)}
            >
              Move Up
            </button>
            <button
              type="button"
              class="btn-sm"
              data-testid="organize-move-down-btn"
              phx-click="favorite_move_down"
              disabled={is_nil(@selected) or last_entry?(@favorites, @selected)}
            >
              Move Down
            </button>
            <div class="u-flex-1"></div>
            <button
              type="button"
              class="btn-sm"
              data-testid="organize-close-btn"
              phx-click="close_organize_favorites"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @spec first_entry?(list(), String.t() | nil) :: boolean()
  defp first_entry?([], _selected), do: true

  defp first_entry?(favorites, selected) do
    case List.first(favorites) do
      nil -> true
      first -> first.channel_name == selected
    end
  end

  @spec last_entry?(list(), String.t() | nil) :: boolean()
  defp last_entry?([], _selected), do: true

  defp last_entry?(favorites, selected) do
    case List.last(favorites) do
      nil -> true
      last -> last.channel_name == selected
    end
  end
end
