defmodule RetroHexChatWeb.Components.UI.ConversationsContextMenu do
  @moduledoc """
  Context menu for the conversations sidebar.

  Composed from ContextMenu primitives. Renders a positioned context menu with
  standard conversation actions (mark as read, mute/unmute, copy name) plus
  channel-only actions (leave, settings) and optional custom items.

  ## Usage

      <.conversations_context_menu
        visible={true}
        x={120}
        y={80}
        type={:channel}
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
  attr :type, :atom, default: :channel
  attr :channel, :string, default: nil
  attr :nick, :string, default: nil
  attr :is_muted, :boolean, default: false
  attr :has_unread, :boolean, default: false
  attr :custom_items, :list, default: []
  attr :on_action, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec conversations_context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def conversations_context_menu(assigns) do
    assigns =
      assigns
      |> assign(:is_pm, assigns.type == :pm)
      |> assign(:target, if(assigns.type == :pm, do: assigns.nick, else: assigns.channel))

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
        phx-value-nick={@nick}
        phx-value-type={@type}
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
        phx-value-nick={@nick}
        phx-value-type={@type}
        data-testid="ctx-mute-toggle"
      >
        <:icon>
          <Icons.icon_mute :if={@is_muted} class="w-[14px] h-[14px]" />
          <Icons.icon_dialog_sound :if={!@is_muted} class="w-[14px] h-[14px]" />
        </:icon>
        {mute_label(@is_pm, @is_muted)}
      </.context_menu_item>

      <.context_menu_separator />

      <%!-- Copy Channel Name --%>
      <.context_menu_item
        on_click={@on_action}
        action="ctx_conversations_copy_name"
        phx-value-channel={@channel}
        phx-value-nick={@nick}
        phx-value-type={@type}
        data-testid="ctx-copy-name"
      >
        <:icon><Icons.icon_copy class="w-[14px] h-[14px]" /></:icon>
        {if @is_pm, do: "Copy Nickname", else: "Copy Channel Name"}
      </.context_menu_item>

      <%!-- Channel Settings --%>
      <.context_menu_item
        :if={!@is_pm}
        on_click={@on_action}
        action="ctx_conversations_settings"
        phx-value-channel={@channel}
        data-testid="ctx-channel-settings"
      >
        <:icon><Icons.icon_btn_settings class="w-[14px] h-[14px]" /></:icon>
        Channel Settings
      </.context_menu_item>

      <.context_menu_separator :if={!@is_pm} />

      <%!-- Leave Channel --%>
      <.context_menu_item
        :if={!@is_pm}
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
        action={custom_item_action(item)}
        phx-value-target={@target}
        phx-value-command={custom_item_command(item)}
        phx-value-label={custom_item_label(item)}
      >
        <:icon><Icons.icon_btn_star class="w-[14px] h-[14px]" /></:icon>
        {custom_item_label(item)}
      </.context_menu_item>
    </.context_menu>
    """
  end

  defp mute_label(true = _is_pm, true = _is_muted), do: "Unmute PM"
  defp mute_label(true = _is_pm, false = _is_muted), do: "Mute PM"
  defp mute_label(false = _is_pm, true = _is_muted), do: "Unmute Channel"
  defp mute_label(false = _is_pm, false = _is_muted), do: "Mute Channel"

  defp custom_item_action(item), do: Map.get(item, :action) || "custom_menu_execute"
  defp custom_item_command(item), do: Map.get(item, :command) || ""
  defp custom_item_label(item), do: Map.get(item, :label) || ""
end
