defmodule RetroHexChatWeb.Components.TreebarContextMenu do
  @moduledoc """
  Right-click context menu for channels in the treebar.

  Extended menu with: Mark as Read, Mute/Unmute Channel, Add to Favorites,
  Copy Name, separator, Leave Channel, Channel Settings.
  """
  use Phoenix.Component

  attr :custom_channel_items, :list, default: []
  attr :visible, :boolean, default: false
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :channel, :string, default: nil
  attr :is_muted, :boolean, default: false
  attr :has_unread, :boolean, default: false

  @spec treebar_context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def treebar_context_menu(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="context-menu"
      data-testid="treebar-context-menu"
      style={"position: fixed; left: #{@x}px; top: #{@y}px; z-index: 300;"}
      phx-hook="ContextMenuHook"
      id="treebar-context-menu"
    >
      <div class="window" style="padding: 2px;">
        <ul class="tree-view" style="margin: 0; padding: 2px;">
          <li
            class={unless @has_unread, do: "disabled"}
            data-testid="ctx-treebar-mark-read"
            phx-click={if @has_unread, do: "ctx_treebar_mark_read"}
            phx-value-channel={@channel}
          >
            Mark as Read
          </li>
          <li
            data-testid="ctx-treebar-mute"
            phx-click="ctx_treebar_mute"
            phx-value-channel={@channel}
          >
            {if @is_muted, do: "Unmute Channel", else: "Mute Channel"}
          </li>
          <li
            data-testid="ctx-add-to-favorites"
            phx-click="add_to_favorites"
            phx-value-channel={@channel}
          >
            Add to Favorites
          </li>
          <li
            data-testid="ctx-treebar-copy-name"
            phx-click="ctx_treebar_copy_name"
            phx-value-channel={@channel}
          >
            Copy Name
          </li>
          <li class="separator" style="border-top: 1px solid #666; margin: 2px 0;"></li>
          <li
            data-testid="ctx-treebar-leave"
            phx-click="ctx_treebar_leave"
            phx-value-channel={@channel}
          >
            Leave Channel
          </li>
          <li
            data-testid="ctx-treebar-settings"
            phx-click="ctx_treebar_settings"
            phx-value-channel={@channel}
          >
            Channel Settings
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
