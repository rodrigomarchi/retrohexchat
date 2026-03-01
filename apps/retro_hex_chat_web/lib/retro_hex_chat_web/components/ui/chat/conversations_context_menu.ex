defmodule RetroHexChatWeb.Components.UI.ConversationsContextMenu do
  @moduledoc """
  Context menu for the conversations sidebar.

  Composed from ContextMenu primitives. Renders a positioned context menu with
  standard channel actions (mark as read, mute/unmute, copy name, leave,
  settings) plus optional custom items.

  ## Usage

      <.conversations_context_menu
        visible={true}
        x={120}
        y={80}
        channel="#lobby"
        has_unread={true}
        on_action="handle_ctx_action"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ContextMenu

  alias RetroHexChatWeb.Icons

  @doc "Renders the conversations context menu."
  attr :visible, :boolean, default: false
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :channel, :string, default: nil
  attr :is_muted, :boolean, default: false
  attr :has_unread, :boolean, default: false
  attr :custom_items, :list, default: []
  attr :on_action, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec conversations_context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def conversations_context_menu(assigns) do
    ~H"""
    <.context_menu
      id="conversations-context-menu"
      show={@visible}
      x={@x}
      y={@y}
      position="absolute"
      class={@class}
      {@rest}
    >
      <%!-- Mark as Read --%>
      <.context_menu_item
        on_click={@has_unread && @on_action}
        action="ctx_conversations_mark_read"
        disabled={!@has_unread}
        phx-value-channel={@channel}
        data-testid="ctx-mark-read"
      >
        <:icon><Icons.icon_checkmark class="w-[14px] h-[14px]" /></:icon>
        Mark as Read
      </.context_menu_item>

      <%!-- Mute / Unmute --%>
      <.context_menu_item
        on_click={@on_action}
        action="ctx_conversations_mute"
        phx-value-channel={@channel}
        data-testid="ctx-mute-toggle"
      >
        <:icon>
          <Icons.icon_mute :if={@is_muted} class="w-[14px] h-[14px]" />
          <Icons.icon_dialog_sound :if={!@is_muted} class="w-[14px] h-[14px]" />
        </:icon>
        {if @is_muted, do: "Unmute Channel", else: "Mute Channel"}
      </.context_menu_item>

      <.context_menu_separator />

      <%!-- Copy Channel Name --%>
      <.context_menu_item
        on_click={@on_action}
        action="ctx_conversations_copy_name"
        phx-value-channel={@channel}
        data-testid="ctx-copy-name"
      >
        <:icon><Icons.icon_copy class="w-[14px] h-[14px]" /></:icon>
        Copy Channel Name
      </.context_menu_item>

      <%!-- Channel Settings --%>
      <.context_menu_item
        on_click={@on_action}
        action="ctx_conversations_settings"
        phx-value-channel={@channel}
        data-testid="ctx-channel-settings"
      >
        <:icon><Icons.icon_btn_settings class="w-[14px] h-[14px]" /></:icon>
        Channel Settings
      </.context_menu_item>

      <.context_menu_separator />

      <%!-- Leave Channel --%>
      <.context_menu_item
        on_click={@on_action}
        action="ctx_conversations_leave"
        phx-value-channel={@channel}
        data-testid="ctx-leave"
      >
        <:icon><Icons.icon_btn_disconnect class="w-[14px] h-[14px]" /></:icon>
        Leave Channel
      </.context_menu_item>

      <%!-- Custom items --%>
      <.context_menu_separator :if={@custom_items != []} />
      <.context_menu_item
        :for={item <- @custom_items}
        on_click={@on_action}
        action="custom_menu_execute"
        phx-value-label={item[:action]}
        phx-value-channel={@channel}
      >
        <:icon><Icons.icon_btn_star class="w-[14px] h-[14px]" /></:icon>
        {item[:label]}
      </.context_menu_item>
    </.context_menu>
    """
  end
end
