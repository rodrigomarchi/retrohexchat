defmodule RetroHexChatWeb.Components.ChatContextMenu do
  @moduledoc """
  Right-click context menu for elements in the chat message area.

  Supports 4 variants based on `@menu.type`:
  - `:nick` — PM, Whois, Copy Nick, Ignore, Address Book, Nick Color, op actions
  - `:url` — Open Link, Copy URL, Save to URL List
  - `:channel` — Join Channel, Add to Favorites, Copy Channel Name, Channel Info
  - `:message` — Copy Message, Copy Selected Text, Quote/Reply, Ignore Sender
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.KeyBindings

  attr :menu, :map, required: true
  attr :viewer_nick, :string, required: true
  attr :viewer_is_op, :boolean, default: false
  attr :is_target_ignored, :boolean, default: false
  attr :is_target_self, :boolean, default: false
  attr :is_already_joined, :boolean, default: false
  attr :key_bindings, :map, default: %{}

  @spec chat_context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_context_menu(assigns) do
    ~H"""
    <div
      :if={@menu.visible}
      class="context-menu"
      style={"position: fixed; left: #{@menu.x}px; top: #{@menu.y}px; z-index: 300;"}
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
      Private Message <.shortcut_hint bindings={@key_bindings} action={:open_pm} />
    </li>
    <li data-testid="ctx-chat-whois" phx-click="ctx_chat_whois" phx-value-nick={@menu.target_nick}>
      Whois
    </li>
    <li
      data-testid="ctx-chat-copy-nick"
      phx-click="ctx_chat_copy_nick"
      phx-value-nick={@menu.target_nick}
    >
      Copy Nick
    </li>
    <li class="separator"></li>
    <li
      :if={!@is_target_ignored && !@is_target_self}
      data-testid="ctx-chat-ignore"
      phx-click="ctx_chat_ignore"
      phx-value-nick={@menu.target_nick}
    >
      Ignore
    </li>
    <li
      :if={@is_target_ignored && !@is_target_self}
      data-testid="ctx-chat-unignore"
      phx-click="ctx_chat_ignore"
      phx-value-nick={@menu.target_nick}
    >
      Unignore
    </li>
    <li
      :if={@is_target_self}
      class="disabled"
      data-testid="ctx-chat-ignore-disabled"
    >
      Ignore
    </li>
    <li
      data-testid="ctx-chat-add-contact"
      phx-click="ctx_chat_add_contact"
      phx-value-nick={@menu.target_nick}
    >
      Add to Address Book
    </li>
    <li
      data-testid="ctx-chat-set-color"
      phx-click="ctx_chat_set_color"
      phx-value-nick={@menu.target_nick}
    >
      Set Nick Color
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
      Kick
    </li>
    <li
      :if={@viewer_is_op}
      class={if @is_target_self, do: "disabled", else: nil}
      data-testid="ctx-chat-ban"
      phx-click={unless @is_target_self, do: "ctx_chat_ban"}
      phx-value-nick={@menu.target_nick}
    >
      Ban
    </li>
    <li
      :if={@viewer_is_op}
      data-testid="ctx-chat-voice"
      phx-click="ctx_chat_voice"
      phx-value-nick={@menu.target_nick}
    >
      Give Voice (+v)
    </li>
    <li
      :if={@viewer_is_op}
      data-testid="ctx-chat-op"
      phx-click="ctx_chat_op"
      phx-value-nick={@menu.target_nick}
    >
      Give Op (+o)
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
      Open Link
    </li>
    <li
      data-testid="ctx-chat-copy-url"
      phx-click="ctx_chat_copy_url"
      phx-value-url={@menu.target_url}
    >
      Copy URL
    </li>
    <li
      data-testid="ctx-chat-save-url"
      phx-click="ctx_chat_save_url"
      phx-value-url={@menu.target_url}
      phx-value-author={@menu.target_message && @menu.target_message.author}
    >
      Save to URL List
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
      Join Channel
    </li>
    <li
      data-testid="ctx-chat-fav"
      phx-click="ctx_chat_fav"
      phx-value-channel={@menu.target_channel}
    >
      Add to Favorites
    </li>
    <li
      data-testid="ctx-chat-copy-channel"
      phx-click="ctx_chat_copy_channel"
      phx-value-channel={@menu.target_channel}
    >
      Copy Channel Name
    </li>
    <li
      data-testid="ctx-chat-channel-info"
      phx-click="ctx_chat_channel_info"
      phx-value-channel={@menu.target_channel}
    >
      Channel Info
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
      Copy Message
    </li>
    <li
      class={unless @menu.has_selection, do: "disabled"}
      data-testid="ctx-chat-copy-selection"
      phx-click={if @menu.has_selection, do: "ctx_chat_copy_selection"}
    >
      Copy Selected Text
    </li>
    <li class="disabled" data-testid="ctx-chat-quote-reply">
      Quote/Reply
    </li>
    <li
      :if={!@is_system}
      data-testid="ctx-chat-ignore-sender"
      phx-click="ctx_chat_ignore_sender"
      phx-value-nick={@menu.target_message && @menu.target_message[:author]}
    >
      Ignore Sender
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
      Open Link
    </li>
    <li
      :if={@has_urls}
      data-testid="ctx-chat-msg-copy-url"
      phx-click="ctx_chat_copy_url"
      phx-value-url={@menu.target_url}
    >
      Copy URL
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
