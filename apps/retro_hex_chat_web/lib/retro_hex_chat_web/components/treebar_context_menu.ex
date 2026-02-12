defmodule RetroHexChatWeb.Components.TreebarContextMenu do
  @moduledoc """
  Right-click context menu for channels in the treebar.
  Shows "Add to Favorites" option for channel items.
  """
  use Phoenix.Component

  attr :custom_channel_items, :list, default: []
  attr :visible, :boolean, default: false
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :channel, :string, default: nil

  @spec treebar_context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def treebar_context_menu(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="context-menu"
      data-testid="treebar-context-menu"
      style={"position: fixed; left: #{@x}px; top: #{@y}px; z-index: 300;"}
    >
      <div class="window" style="padding: 2px;">
        <ul class="tree-view" style="margin: 0; padding: 2px;">
          <li
            data-testid="ctx-add-to-favorites"
            phx-click="add_to_favorites"
            phx-value-channel={@channel}
          >
            Add to Favorites
          </li>
          <li
            :if={@custom_channel_items != []}
            class="separator"
            style="border-top: 1px solid #666; margin: 2px 0;"
          >
          </li>
          <li
            :for={item <- @custom_channel_items}
            data-testid={"ctx-custom-#{item.label}"}
            phx-click="custom_menu_execute"
            phx-value-command={item.command}
            phx-value-target={@channel}
          >
            {item.label}
          </li>
        </ul>
      </div>
    </div>
    """
  end
end
