defmodule RetroHexChatWeb.Components.ConversationsContextMenu do
  @moduledoc """
  Right-click context menu for channels in the conversations sidebar.

  Extended menu with: Mark as Read, Mute/Unmute Channel,
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

  @spec conversations_context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def conversations_context_menu(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="context-menu"
      data-testid="conversations-context-menu"
      style={"position: fixed; left: #{@x}px; top: #{@y}px; z-index: 300;"}
      phx-hook="ContextMenuHook"
      id="conversations-context-menu"
    >
      <div class="window u-p-2">
        <ul class="tree-view">
          <li
            class={unless @has_unread, do: "disabled"}
            data-testid="ctx-conversations-mark-read"
            phx-click={if @has_unread, do: "ctx_conversations_mark_read"}
            phx-value-channel={@channel}
          >
            Mark as Read
          </li>
          <li
            data-testid="ctx-conversations-mute"
            phx-click="ctx_conversations_mute"
            phx-value-channel={@channel}
          >
            {if @is_muted, do: "Unmute Channel", else: "Mute Channel"}
          </li>
          <li
            data-testid="ctx-conversations-copy-name"
            phx-click="ctx_conversations_copy_name"
            phx-value-channel={@channel}
          >
            Copy Name
          </li>
          <li class="separator"></li>
          <li
            data-testid="ctx-conversations-leave"
            phx-click="ctx_conversations_leave"
            phx-value-channel={@channel}
          >
            Leave Channel
          </li>
          <li
            data-testid="ctx-conversations-settings"
            phx-click="ctx_conversations_settings"
            phx-value-channel={@channel}
          >
            Channel Settings
          </li>
          <li
            :if={@custom_channel_items != []}
            class="separator"
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
