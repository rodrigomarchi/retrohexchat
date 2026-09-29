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

  alias RetroHexChatWeb.Components.UI.Chat.CustomMenuItem
  alias RetroHexChatWeb.Icons

  @doc "Renders the conversations context menu."
  attr :visible, :boolean, default: false
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :type, :atom, default: :channel
  attr :channel, :string, default: nil
  attr :nick, :string, default: nil
  attr :is_muted, :boolean, default: false

  attr :is_autojoin, :boolean,
    default: false,
    doc: "The channel is on the account's auto-join list"

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
      reposition
      sheet
      sheet_title={@target}
      class={@class}
      on_close="close_conversations_context_menu"
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
        testid="ctx-mark-read"
      >
        <:icon><Icons.icon_checkmark class="w-[14px] h-[14px]" /></:icon>
        {dgettext("chat", "Mark as Read")}
      </.context_menu_item>

      <%!-- Mute / Unmute --%>
      <.context_menu_item
        on_click={@on_action}
        action="ctx_conversations_mute"
        phx-value-channel={@channel}
        phx-value-nick={@nick}
        phx-value-type={@type}
        testid="ctx-mute-toggle"
      >
        <:icon>
          <Icons.icon_mute :if={@is_muted} class="w-[14px] h-[14px]" />
          <Icons.icon_dialog_sound :if={!@is_muted} class="w-[14px] h-[14px]" />
        </:icon>
        {mute_label(@is_pm, @is_muted)}
      </.context_menu_item>

      <.context_menu_separator />

      <%!-- Auto-join, as an attribute of the room rather than a list of its own.
            It is the canonical way to set it: a pin on the row is 16 pixels and
            exists only where there is a pointer, and a menu item is the same
            size on every input. --%>
      <.context_menu_item
        :if={@type == :channel}
        on_click={@on_action}
        action="ctx_conversations_toggle_autojoin"
        phx-value-channel={@channel}
        role="menuitemcheckbox"
        aria-checked={to_string(@is_autojoin)}
        testid="ctx-toggle-autojoin"
      >
        <:icon>
          <Icons.icon_checkmark :if={@is_autojoin} class="w-[14px] h-[14px]" />
          <Icons.icon_dialog_autojoin :if={!@is_autojoin} class="w-[14px] h-[14px]" />
        </:icon>
        {dgettext("chat", "Join on connect")}
      </.context_menu_item>

      <%!-- Channel Settings --%>
      <.context_menu_item
        :if={!@is_pm}
        on_click={@on_action}
        action="ctx_conversations_settings"
        phx-value-channel={@channel}
        testid="ctx-channel-settings"
      >
        <:icon><Icons.icon_btn_settings class="w-[14px] h-[14px]" /></:icon>
        {dgettext("chat", "Channel Settings")}
      </.context_menu_item>

      <.context_menu_separator :if={!@is_pm} />

      <%!-- Copy Invite Link: the address that leaves the product, so it is only
            offered for a channel and never for a private conversation. --%>
      <.context_menu_item
        :if={@type == :channel}
        on_click={@on_action}
        action="ctx_conversations_copy_invite"
        phx-value-channel={@channel}
      >
        <:icon><Icons.icon_btn_link class="w-[14px] h-[14px]" /></:icon>
        {dgettext("chat", "Copy Invite Link")}
      </.context_menu_item>

      <%!-- Copy Channel Name --%>
      <.context_menu_item
        on_click={@on_action}
        action="ctx_conversations_copy_name"
        phx-value-channel={@channel}
        phx-value-nick={@nick}
        phx-value-type={@type}
        testid="ctx-copy-name"
      >
        <:icon><Icons.icon_copy class="w-[14px] h-[14px]" /></:icon>
        {copy_name_label(@is_pm)}
      </.context_menu_item>

      <.context_menu_separator />

      <%!-- Close Conversation — the private half of Leave Channel. A channel is
            left; a private conversation is only put away, and the next line
            from that nickname brings it back. --%>
      <.context_menu_item
        :if={@is_pm}
        on_click={@on_action}
        action="ctx_conversations_close_pm"
        phx-value-nick={@nick}
        testid="ctx-close-pm"
      >
        <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
        {dgettext("chat", "Close Conversation")}
      </.context_menu_item>

      <%!-- Leave Channel --%>
      <.context_menu_item
        :if={!@is_pm}
        on_click={@on_action}
        action="ctx_conversations_leave"
        phx-value-channel={@channel}
        testid="ctx-leave"
      >
        <:icon><Icons.icon_btn_disconnect class="w-[14px] h-[14px]" /></:icon>
        {dgettext("chat", "Leave Channel")}
      </.context_menu_item>

      <%!-- Custom items --%>
      <.context_menu_separator :if={@custom_items != []} />
      <.context_menu_item
        :for={item <- @custom_items}
        on_click={@on_action}
        action={CustomMenuItem.action(item)}
        phx-value-target={@target}
        phx-value-command={CustomMenuItem.command(item)}
        phx-value-label={CustomMenuItem.label(item)}
      >
        <:icon><Icons.icon_btn_star class="w-[14px] h-[14px]" /></:icon>
        {CustomMenuItem.label(item)}
      </.context_menu_item>
    </.context_menu>
    """
  end

  defp mute_label(true = _is_pm, true = _is_muted), do: dgettext("chat", "Unmute PM")
  defp mute_label(true = _is_pm, false = _is_muted), do: dgettext("chat", "Mute PM")
  defp mute_label(false = _is_pm, true = _is_muted), do: dgettext("chat", "Unmute Channel")
  defp mute_label(false = _is_pm, false = _is_muted), do: dgettext("chat", "Mute Channel")

  defp copy_name_label(true = _is_pm), do: dgettext("chat", "Copy Nickname")
  defp copy_name_label(false = _is_pm), do: dgettext("chat", "Copy Channel Name")
end
