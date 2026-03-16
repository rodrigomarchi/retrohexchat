defmodule RetroHexChatWeb.Components.UI.ChatContextMenu do
  @moduledoc """
  Reusable showcase version of the chat context menu component.

  Composed from ContextMenu primitives. Supports 4 menu types based on the
  `type` attribute:
  - `:nick` — PM, Whois, Copy Nick, Ignore, Address Book, P2P actions, Op actions
  - `:url` — Open Link, Copy URL, Save to URL List
  - `:channel` — Join Channel, Copy Channel Name, Channel Info
  - `:message` — Copy Message, Reply, Delete, Ignore Sender

  All actions are dispatched through a single `on_action` callback with
  `phx-value-action` identifying the specific action.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ContextMenu

  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, default: false
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :type, :atom, default: :nick, values: [:nick, :url, :channel, :message]
  attr :target_nick, :string, default: nil
  attr :target_url, :string, default: nil
  attr :target_channel, :string, default: nil
  attr :target_message, :map, default: nil
  attr :viewer_nick, :string, default: nil
  attr :viewer_is_op, :boolean, default: false
  attr :viewer_is_identified, :boolean, default: false
  attr :is_target_ignored, :boolean, default: false
  attr :is_target_self, :boolean, default: false
  attr :is_target_registered, :boolean, default: false
  attr :is_already_joined, :boolean, default: false
  attr :key_bindings, :map, default: %{}
  attr :custom_items, :list, default: []
  attr :on_action, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec chat_context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_context_menu(assigns) do
    ~H"""
    <.context_menu id="chat-context-menu" show={@visible} x={@x} y={@y} class={@class} {@rest}>
      <%= case @type do %>
        <% :nick -> %>
          {nick_menu_items(assigns)}
        <% :url -> %>
          {url_menu_items(assigns)}
        <% :channel -> %>
          {channel_menu_items(assigns)}
        <% :message -> %>
          {message_menu_items(assigns)}
      <% end %>
    </.context_menu>
    """
  end

  defp nick_menu_items(assigns) do
    ~H"""
    <.context_menu_item on_click={@on_action} action="ctx_chat_pm" phx-value-nick={@target_nick}>
      <:icon><Icons.icon_tab_pm class="w-[14px] h-[14px]" /></:icon>
      Private Message
    </.context_menu_item>
    <.context_menu_item on_click={@on_action} action="ctx_chat_whois" phx-value-nick={@target_nick}>
      <:icon><Icons.icon_btn_search class="w-[14px] h-[14px]" /></:icon>
      Whois
    </.context_menu_item>
    <.context_menu_separator />
    <.context_menu_item
      on_click={@on_action}
      action="ctx_chat_copy_nick"
      phx-value-nick={@target_nick}
    >
      <:icon><Icons.icon_copy class="w-[14px] h-[14px]" /></:icon>
      Copy Nick
    </.context_menu_item>
    <.context_menu_item
      :if={!@is_target_self}
      on_click={@on_action}
      action="ctx_chat_ignore"
      phx-value-nick={@target_nick}
    >
      <:icon><Icons.icon_btn_ignore class="w-[14px] h-[14px]" /></:icon>
      {if @is_target_ignored, do: "Unignore", else: "Ignore"}
    </.context_menu_item>
    <.context_menu_item :if={@is_target_self} disabled>
      <:icon><Icons.icon_btn_ignore class="w-[14px] h-[14px]" /></:icon>
      Ignore
    </.context_menu_item>
    <.context_menu_item
      on_click={@on_action}
      action="ctx_chat_add_contact"
      phx-value-nick={@target_nick}
    >
      <:icon><Icons.icon_tab_contacts class="w-[14px] h-[14px]" /></:icon>
      Address Book
    </.context_menu_item>
    <%!-- P2P items (only if viewer is identified) --%>
    <.context_menu_separator :if={@viewer_is_identified} />
    <.context_menu_item
      :if={@viewer_is_identified}
      on_click={if @is_target_registered && !@is_target_self, do: @on_action}
      action="ctx_chat_call"
      disabled={!@is_target_registered || @is_target_self}
      title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
      phx-value-nick={@target_nick}
    >
      <:icon><Icons.icon_microphone class="w-[14px] h-[14px]" /></:icon>
      Audio Call
    </.context_menu_item>
    <.context_menu_item
      :if={@viewer_is_identified}
      on_click={if @is_target_registered && !@is_target_self, do: @on_action}
      action="ctx_chat_video_call"
      disabled={!@is_target_registered || @is_target_self}
      title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
      phx-value-nick={@target_nick}
    >
      <:icon><Icons.icon_camera class="w-[14px] h-[14px]" /></:icon>
      Video Call
    </.context_menu_item>
    <.context_menu_item
      :if={@viewer_is_identified}
      on_click={if @is_target_registered && !@is_target_self, do: @on_action}
      action="ctx_chat_sendfile"
      disabled={!@is_target_registered || @is_target_self}
      title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
      phx-value-nick={@target_nick}
    >
      <:icon><Icons.icon_file_send class="w-[14px] h-[14px]" /></:icon>
      Send File
    </.context_menu_item>
    <.context_menu_item
      :if={@viewer_is_identified}
      on_click={if @is_target_registered && !@is_target_self, do: @on_action}
      action="ctx_chat_game"
      disabled={!@is_target_registered || @is_target_self}
      title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
      phx-value-nick={@target_nick}
    >
      <:icon><Icons.icon_star class="w-[14px] h-[14px]" /></:icon>
      Play Game
    </.context_menu_item>
    <%!-- Op actions (only if viewer is op and not targeting self) --%>
    <.context_menu_separator :if={@viewer_is_op && !@is_target_self} />
    <.context_menu_item
      :if={@viewer_is_op && !@is_target_self}
      on_click={@on_action}
      action="ctx_chat_kick"
      phx-value-nick={@target_nick}
    >
      <:icon><Icons.icon_dialog_kick class="w-[14px] h-[14px]" /></:icon>
      Kick
    </.context_menu_item>
    <.context_menu_item
      :if={@viewer_is_op && !@is_target_self}
      on_click={@on_action}
      action="ctx_chat_ban"
      phx-value-nick={@target_nick}
    >
      <:icon><Icons.icon_ban class="w-[14px] h-[14px]" /></:icon>
      Ban
    </.context_menu_item>
    <.context_menu_item
      :if={@viewer_is_op && !@is_target_self}
      on_click={@on_action}
      action="ctx_chat_voice"
      phx-value-nick={@target_nick}
    >
      <:icon><Icons.icon_role_voiced class="w-[14px] h-[14px]" /></:icon>
      Give Voice (+v)
    </.context_menu_item>
    <.context_menu_item
      :if={@viewer_is_op && !@is_target_self}
      on_click={@on_action}
      action="ctx_chat_op"
      phx-value-nick={@target_nick}
    >
      <:icon><Icons.icon_role_operator class="w-[14px] h-[14px]" /></:icon>
      Give Op (+o)
    </.context_menu_item>
    <%!-- Custom menu items --%>
    <.context_menu_separator :if={@custom_items != []} />
    <.context_menu_item
      :for={item <- @custom_items}
      on_click={@on_action}
      action="custom_menu_execute"
      phx-value-target={@target_nick}
      phx-value-command={item[:command]}
      phx-value-label={item[:label]}
    >
      <:icon><Icons.icon_btn_star class="w-[14px] h-[14px]" /></:icon>
      {item[:label]}
    </.context_menu_item>
    """
  end

  defp url_menu_items(assigns) do
    ~H"""
    <.context_menu_item on_click={@on_action} action="ctx_chat_open_url" phx-value-url={@target_url}>
      <:icon><Icons.icon_link class="w-[14px] h-[14px]" /></:icon>
      Open Link
    </.context_menu_item>
    <.context_menu_item on_click={@on_action} action="ctx_chat_copy_url" phx-value-url={@target_url}>
      <:icon><Icons.icon_copy class="w-[14px] h-[14px]" /></:icon>
      Copy URL
    </.context_menu_item>
    <.context_menu_item on_click={@on_action} action="ctx_chat_save_url" phx-value-url={@target_url}>
      <:icon><Icons.icon_btn_save class="w-[14px] h-[14px]" /></:icon>
      Save to URL List
    </.context_menu_item>
    """
  end

  defp channel_menu_items(assigns) do
    ~H"""
    <.context_menu_item
      on_click={unless @is_already_joined, do: @on_action}
      action="ctx_chat_join"
      disabled={@is_already_joined}
      phx-value-channel={@target_channel}
    >
      <:icon><Icons.icon_btn_join class="w-[14px] h-[14px]" /></:icon>
      Join Channel
    </.context_menu_item>
    <.context_menu_item
      on_click={@on_action}
      action="ctx_chat_copy_channel"
      phx-value-channel={@target_channel}
    >
      <:icon><Icons.icon_copy class="w-[14px] h-[14px]" /></:icon>
      Copy Channel Name
    </.context_menu_item>
    <.context_menu_item
      on_click={@on_action}
      action="ctx_chat_channel_info"
      phx-value-channel={@target_channel}
    >
      <:icon><Icons.icon_tab_channel class="w-[14px] h-[14px]" /></:icon>
      Channel Info
    </.context_menu_item>
    """
  end

  defp message_menu_items(assigns) do
    msg = assigns.target_message || %{}
    is_own = Map.get(msg, :is_own, false)

    assigns =
      assigns
      |> assign(:is_own, is_own)
      |> assign(:msg_text, Map.get(msg, :text))
      |> assign(:msg_id, Map.get(msg, :id))
      |> assign(:msg_nick, Map.get(msg, :nick))

    ~H"""
    <.context_menu_item
      on_click={@on_action}
      action="ctx_chat_copy_message"
      phx-value-text={@msg_text}
    >
      <:icon><Icons.icon_copy class="w-[14px] h-[14px]" /></:icon>
      Copy Message
    </.context_menu_item>
    <.context_menu_item on_click={@on_action} action="reply_to_message" phx-value-message_id={@msg_id}>
      <:icon><Icons.icon_chat class="w-[14px] h-[14px]" /></:icon>
      Reply
    </.context_menu_item>
    <.context_menu_separator />
    <.context_menu_item
      :if={@is_own}
      on_click={@on_action}
      action="ctx_chat_delete"
      phx-value-message_id={@msg_id}
    >
      <:icon><Icons.icon_trash class="w-[14px] h-[14px]" /></:icon>
      Delete
    </.context_menu_item>
    <.context_menu_item
      :if={!@is_target_self}
      on_click={@on_action}
      action="ctx_chat_ignore_sender"
      phx-value-nick={@msg_nick}
    >
      <:icon><Icons.icon_btn_ignore class="w-[14px] h-[14px]" /></:icon>
      Ignore Sender
    </.context_menu_item>
    """
  end
end
