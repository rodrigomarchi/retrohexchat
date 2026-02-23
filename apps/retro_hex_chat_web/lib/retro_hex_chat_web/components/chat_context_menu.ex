defmodule RetroHexChatWeb.Components.ChatContextMenu do
  @moduledoc """
  Right-click context menu for elements in the chat message area.

  Supports 4 variants based on `@menu.type`:
  - `:nick` — PM, Whois, Copy Nick, Ignore, Address Book, Nick Color, op actions
  - `:url` — Open Link, Copy URL, Save to URL List
  - `:channel` — Join Channel, Copy Channel Name, Channel Info
  - `:message` — Copy Message, Copy Selected Text, Quote/Reply, Ignore Sender
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.KeyBindings
  alias RetroHexChatWeb.Icons

  attr :menu, :map, required: true
  attr :viewer_nick, :string, required: true
  attr :viewer_is_identified, :boolean, default: false
  attr :viewer_is_op, :boolean, default: false
  attr :is_target_ignored, :boolean, default: false
  attr :is_target_registered, :boolean, default: false
  attr :is_target_self, :boolean, default: false
  attr :is_already_joined, :boolean, default: false
  attr :key_bindings, :map, default: %{}

  @spec chat_context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_context_menu(assigns) do
    ~H"""
    <div
      :if={@menu.visible}
      class="context-menu"
      style={"left: #{@menu.x}px; top: #{@menu.y}px;"}
      phx-hook="ContextMenuHook"
      id="chat-context-menu"
    >
      <div class="window u-p-2">
        <ul class="tree-view">
          <%= case @menu.type do %>
            <% :nick -> %>
              {nick_menu_items(assigns)}
            <% :url -> %>
              {url_menu_items(assigns)}
            <% :channel -> %>
              {channel_menu_items(assigns)}
            <% :message -> %>
              {message_menu_items(assigns)}
            <% _ -> %>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  defp nick_menu_items(assigns) do
    ~H"""
    <li data-testid="ctx-chat-pm" phx-click="ctx_chat_pm" phx-value-nick={@menu.target_nick}>
      <Icons.icon_tab_pm class="ctx-icon" /> Private Message
      <.shortcut_hint bindings={@key_bindings} action={:open_pm} />
    </li>
    <li data-testid="ctx-chat-whois" phx-click="ctx_chat_whois" phx-value-nick={@menu.target_nick}>
      <Icons.icon_btn_search class="ctx-icon" /> Whois
    </li>
    <li
      data-testid="ctx-chat-copy-nick"
      phx-click="ctx_chat_copy_nick"
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_copy class="ctx-icon" /> Copy Nick
    </li>
    <li class="separator"></li>
    <li
      :if={!@is_target_ignored && !@is_target_self}
      data-testid="ctx-chat-ignore"
      phx-click="ctx_chat_ignore"
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_btn_ignore class="ctx-icon" /> Ignore
    </li>
    <li
      :if={@is_target_ignored && !@is_target_self}
      data-testid="ctx-chat-unignore"
      phx-click="ctx_chat_ignore"
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_btn_ignore class="ctx-icon" /> Unignore
    </li>
    <li
      :if={@is_target_self}
      class="disabled"
      data-testid="ctx-chat-ignore-disabled"
    >
      <Icons.icon_btn_ignore class="ctx-icon" /> Ignore
    </li>
    <li
      data-testid="ctx-chat-add-contact"
      phx-click="ctx_chat_add_contact"
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_tab_contacts class="ctx-icon" /> Add to Address Book
    </li>
    <li
      data-testid="ctx-chat-set-color"
      phx-click="ctx_chat_set_color"
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_palette class="ctx-icon" /> Set Nick Color
    </li>
    <li :if={@viewer_is_identified} class="separator"></li>
    <li
      :if={@viewer_is_identified}
      class={if !@is_target_registered || @is_target_self, do: "disabled"}
      title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
      data-testid="ctx-chat-p2p"
      phx-click={if @is_target_registered && !@is_target_self, do: "ctx_chat_p2p"}
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_p2p class="ctx-icon" /> P2P Session
    </li>
    <li
      :if={@viewer_is_identified}
      class={if !@is_target_registered || @is_target_self, do: "disabled"}
      title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
      data-testid="ctx-chat-call"
      phx-click={if @is_target_registered && !@is_target_self, do: "ctx_chat_call"}
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_microphone class="ctx-icon" /> Audio Call
    </li>
    <li
      :if={@viewer_is_identified}
      class={if !@is_target_registered || @is_target_self, do: "disabled"}
      title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
      data-testid="ctx-chat-video-call"
      phx-click={if @is_target_registered && !@is_target_self, do: "ctx_chat_video_call"}
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_camera class="ctx-icon" /> Video Call
    </li>
    <li
      :if={@viewer_is_identified}
      class={if !@is_target_registered || @is_target_self, do: "disabled"}
      title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
      data-testid="ctx-chat-sendfile"
      phx-click={if @is_target_registered && !@is_target_self, do: "ctx_chat_sendfile"}
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_file_send class="ctx-icon" /> Send File
    </li>
    <li
      :if={@viewer_is_op}
      class="separator"
    >
    </li>
    <li
      :if={@viewer_is_op}
      class={if @is_target_self, do: "disabled", else: nil}
      data-testid="ctx-chat-kick"
      phx-click={unless @is_target_self, do: "ctx_chat_kick"}
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_dialog_kick class="ctx-icon" /> Kick
    </li>
    <li
      :if={@viewer_is_op}
      class={if @is_target_self, do: "disabled", else: nil}
      data-testid="ctx-chat-ban"
      phx-click={unless @is_target_self, do: "ctx_chat_ban"}
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_ban class="ctx-icon" /> Ban
    </li>
    <li
      :if={@viewer_is_op}
      data-testid="ctx-chat-voice"
      phx-click="ctx_chat_voice"
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_role_voiced class="ctx-icon" /> Give Voice (+v)
    </li>
    <li
      :if={@viewer_is_op}
      data-testid="ctx-chat-op"
      phx-click="ctx_chat_op"
      phx-value-nick={@menu.target_nick}
    >
      <Icons.icon_role_operator class="ctx-icon" /> Give Op (+o)
    </li>
    """
  end

  defp url_menu_items(assigns) do
    ~H"""
    <li
      data-testid="ctx-chat-open-url"
      phx-click="ctx_chat_open_url"
      phx-value-url={@menu.target_url}
    >
      <Icons.icon_link class="ctx-icon" /> Open Link
    </li>
    <li
      data-testid="ctx-chat-copy-url"
      phx-click="ctx_chat_copy_url"
      phx-value-url={@menu.target_url}
    >
      <Icons.icon_copy class="ctx-icon" /> Copy URL
    </li>
    <li
      data-testid="ctx-chat-save-url"
      phx-click="ctx_chat_save_url"
      phx-value-url={@menu.target_url}
      phx-value-author={@menu.target_message && @menu.target_message.author}
    >
      <Icons.icon_btn_save class="ctx-icon" /> Save to URL List
    </li>
    """
  end

  defp channel_menu_items(assigns) do
    ~H"""
    <li
      class={if @is_already_joined, do: "disabled", else: nil}
      data-testid="ctx-chat-join"
      phx-click={unless @is_already_joined, do: "ctx_chat_join"}
      phx-value-channel={@menu.target_channel}
    >
      <Icons.icon_btn_join class="ctx-icon" /> Join Channel
    </li>
    <li
      data-testid="ctx-chat-copy-channel"
      phx-click="ctx_chat_copy_channel"
      phx-value-channel={@menu.target_channel}
    >
      <Icons.icon_copy class="ctx-icon" /> Copy Channel Name
    </li>
    <li
      data-testid="ctx-chat-channel-info"
      phx-click="ctx_chat_channel_info"
      phx-value-channel={@menu.target_channel}
    >
      <Icons.icon_tab_channel class="ctx-icon" /> Channel Info
    </li>
    """
  end

  defp message_menu_items(assigns) do
    target_msg = assigns.menu.target_message
    is_system = target_msg && target_msg[:is_system]

    assigns =
      assigns
      |> assign(:is_system, is_system)
      |> assign(:has_urls, target_msg && target_msg[:urls] != nil && target_msg[:urls] != [])

    ~H"""
    <li
      data-testid="ctx-chat-copy-message"
      phx-click="ctx_chat_copy_message"
      phx-value-text={@menu.target_message && @menu.target_message[:text]}
    >
      <Icons.icon_copy class="ctx-icon" /> Copy Message
    </li>
    <li
      class={unless @menu.has_selection, do: "disabled"}
      data-testid="ctx-chat-copy-selection"
      phx-click={if @menu.has_selection, do: "ctx_chat_copy_selection"}
    >
      <Icons.icon_copy class="ctx-icon" /> Copy Selected Text
    </li>
    <li
      class={if @is_system, do: "disabled", else: nil}
      data-testid="ctx-chat-quote-reply"
      phx-click={unless @is_system, do: "reply_to_message"}
      phx-value-message_id={@menu.target_message && @menu.target_message[:message_id]}
    >
      <Icons.icon_chat class="ctx-icon" /> Reply
    </li>
    <li
      :if={!@is_system && @menu.target_message && @menu.target_message[:is_own]}
      data-testid="ctx-chat-delete"
      phx-click="ctx_chat_delete"
      phx-value-message_id={@menu.target_message && @menu.target_message[:message_id]}
    >
      <Icons.icon_trash class="ctx-icon" /> Delete message
    </li>
    <li class="separator"></li>
    <li
      :if={!@is_system}
      data-testid="ctx-chat-ignore-sender"
      phx-click="ctx_chat_ignore_sender"
      phx-value-nick={@menu.target_message && @menu.target_message[:author]}
    >
      <Icons.icon_btn_ignore class="ctx-icon" /> Ignore Sender
    </li>
    <li
      :if={@has_urls}
      class="separator"
    >
    </li>
    <li
      :if={@has_urls}
      data-testid="ctx-chat-msg-open-url"
      phx-click="ctx_chat_open_url"
      phx-value-url={@menu.target_url}
    >
      <Icons.icon_link class="ctx-icon" /> Open Link
    </li>
    <li
      :if={@has_urls}
      data-testid="ctx-chat-msg-copy-url"
      phx-click="ctx_chat_copy_url"
      phx-value-url={@menu.target_url}
    >
      <Icons.icon_copy class="ctx-icon" /> Copy URL
    </li>
    """
  end

  defp shortcut_hint(%{bindings: bindings, action: action} = assigns) do
    binding = Map.get(bindings, action)

    assigns = assign(assigns, :display, binding && KeyBindings.to_display_string(binding))

    ~H"""
    <span :if={@display} class="shortcut-hint">{@display}</span>
    """
  end
end
