defmodule RetroHexChatWeb.Components.UI.ChatContextMenu do
  @moduledoc """
  Reusable showcase version of the chat context menu component.

  Supports 4 menu types based on the `type` attribute:
  - `:nick` — PM, Whois, Copy Nick, Ignore, Address Book, P2P actions, Op actions
  - `:url` — Open Link, Copy URL, Save to URL List
  - `:channel` — Join Channel, Copy Channel Name, Channel Info
  - `:message` — Copy Message, Reply, Delete, Ignore Sender

  All actions are dispatched through a single `on_action` callback with
  `phx-value-action` identifying the specific action.
  """
  use RetroHexChatWeb.Component

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
  attr :is_already_joined, :boolean, default: false
  attr :on_action, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec chat_context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_context_menu(assigns) do
    ~H"""
    <div
      :if={@visible}
      class={
        classes([
          "fixed z-50 shadow-retro-window bg-surface p-[3px] min-w-[180px]",
          @class
        ])
      }
      style={position_style(@x, @y)}
      {@rest}
    >
      <div class="shadow-retro-field bg-white p-[2px]">
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
      </div>
    </div>
    """
  end

  defp nick_menu_items(assigns) do
    ~H"""
    <ul class="list-none m-0 p-[2px] text-xs">
      <li>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="pm"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_tab_pm class="w-[16px] h-[16px] shrink-0" />
          <span>Private Message</span>
        </button>
      </li>
      <li>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="whois"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_btn_search class="w-[16px] h-[16px] shrink-0" />
          <span>Whois</span>
        </button>
      </li>
      <li class="border-t border-separator my-[2px]"></li>
      <li>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="copy_nick"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_copy class="w-[16px] h-[16px] shrink-0" />
          <span>Copy Nick</span>
        </button>
      </li>
      <li :if={!@is_target_self}>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action={if @is_target_ignored, do: "unignore", else: "ignore"}
          phx-value-nick={@target_nick}
        >
          <Icons.icon_btn_ignore class="w-[16px] h-[16px] shrink-0" />
          <span>{if @is_target_ignored, do: "Unignore", else: "Ignore"}</span>
        </button>
      </li>
      <li :if={@is_target_self}>
        <span class="flex items-center gap-1.5 w-full px-4 py-1 text-left opacity-50 cursor-default">
          <Icons.icon_btn_ignore class="w-[16px] h-[16px] shrink-0" />
          <span>Ignore</span>
        </span>
      </li>
      <li>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="address_book"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_tab_contacts class="w-[16px] h-[16px] shrink-0" />
          <span>Address Book</span>
        </button>
      </li>
      <%!-- P2P items (only if viewer is identified) --%>
      <li :if={@viewer_is_identified} class="border-t border-separator my-[2px]"></li>
      <li :if={@viewer_is_identified}>
        <button
          class={[
            "flex items-center gap-1.5 w-full px-4 py-1 text-left",
            if(@is_target_self,
              do: "opacity-50 cursor-default pointer-events-none",
              else: "hover:bg-primary hover:text-white"
            )
          ]}
          phx-click={unless @is_target_self, do: @on_action}
          phx-value-action="audio_call"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_microphone class="w-[16px] h-[16px] shrink-0" />
          <span>Audio Call</span>
        </button>
      </li>
      <li :if={@viewer_is_identified}>
        <button
          class={[
            "flex items-center gap-1.5 w-full px-4 py-1 text-left",
            if(@is_target_self,
              do: "opacity-50 cursor-default pointer-events-none",
              else: "hover:bg-primary hover:text-white"
            )
          ]}
          phx-click={unless @is_target_self, do: @on_action}
          phx-value-action="video_call"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_camera class="w-[16px] h-[16px] shrink-0" />
          <span>Video Call</span>
        </button>
      </li>
      <li :if={@viewer_is_identified}>
        <button
          class={[
            "flex items-center gap-1.5 w-full px-4 py-1 text-left",
            if(@is_target_self,
              do: "opacity-50 cursor-default pointer-events-none",
              else: "hover:bg-primary hover:text-white"
            )
          ]}
          phx-click={unless @is_target_self, do: @on_action}
          phx-value-action="send_file"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_file_send class="w-[16px] h-[16px] shrink-0" />
          <span>Send File</span>
        </button>
      </li>
      <li :if={@viewer_is_identified}>
        <button
          class={[
            "flex items-center gap-1.5 w-full px-4 py-1 text-left",
            if(@is_target_self,
              do: "opacity-50 cursor-default pointer-events-none",
              else: "hover:bg-primary hover:text-white"
            )
          ]}
          phx-click={unless @is_target_self, do: @on_action}
          phx-value-action="play_game"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_star class="w-[16px] h-[16px] shrink-0" />
          <span>Play Game</span>
        </button>
      </li>
      <%!-- Op actions (only if viewer is op and not targeting self) --%>
      <li :if={@viewer_is_op && !@is_target_self} class="border-t border-separator my-[2px]"></li>
      <li :if={@viewer_is_op && !@is_target_self}>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="kick"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_dialog_kick class="w-[16px] h-[16px] shrink-0" />
          <span>Kick</span>
        </button>
      </li>
      <li :if={@viewer_is_op && !@is_target_self}>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="ban"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_ban class="w-[16px] h-[16px] shrink-0" />
          <span>Ban</span>
        </button>
      </li>
      <li :if={@viewer_is_op && !@is_target_self}>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="voice"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_role_voiced class="w-[16px] h-[16px] shrink-0" />
          <span>Give Voice (+v)</span>
        </button>
      </li>
      <li :if={@viewer_is_op && !@is_target_self}>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="op"
          phx-value-nick={@target_nick}
        >
          <Icons.icon_role_operator class="w-[16px] h-[16px] shrink-0" />
          <span>Give Op (+o)</span>
        </button>
      </li>
    </ul>
    """
  end

  defp url_menu_items(assigns) do
    ~H"""
    <ul class="list-none m-0 p-[2px] text-xs">
      <li>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="open_link"
          phx-value-url={@target_url}
        >
          <Icons.icon_link class="w-[16px] h-[16px] shrink-0" />
          <span>Open Link</span>
        </button>
      </li>
      <li>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="copy_url"
          phx-value-url={@target_url}
        >
          <Icons.icon_copy class="w-[16px] h-[16px] shrink-0" />
          <span>Copy URL</span>
        </button>
      </li>
      <li>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="save_url"
          phx-value-url={@target_url}
        >
          <Icons.icon_btn_save class="w-[16px] h-[16px] shrink-0" />
          <span>Save to URL List</span>
        </button>
      </li>
    </ul>
    """
  end

  defp channel_menu_items(assigns) do
    ~H"""
    <ul class="list-none m-0 p-[2px] text-xs">
      <li>
        <button
          class={[
            "flex items-center gap-1.5 w-full px-4 py-1 text-left",
            if(@is_already_joined,
              do: "opacity-50 cursor-default pointer-events-none",
              else: "hover:bg-primary hover:text-white"
            )
          ]}
          phx-click={unless @is_already_joined, do: @on_action}
          phx-value-action="join_channel"
          phx-value-channel={@target_channel}
        >
          <Icons.icon_btn_join class="w-[16px] h-[16px] shrink-0" />
          <span>Join Channel</span>
        </button>
      </li>
      <li>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="copy_channel"
          phx-value-channel={@target_channel}
        >
          <Icons.icon_copy class="w-[16px] h-[16px] shrink-0" />
          <span>Copy Channel Name</span>
        </button>
      </li>
      <li>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="channel_info"
          phx-value-channel={@target_channel}
        >
          <Icons.icon_tab_channel class="w-[16px] h-[16px] shrink-0" />
          <span>Channel Info</span>
        </button>
      </li>
    </ul>
    """
  end

  defp message_menu_items(assigns) do
    msg = assigns.target_message || %{}
    is_own = Map.get(msg, :is_own, false)
    has_urls = Map.get(msg, :has_urls, false)

    assigns =
      assigns
      |> assign(:is_own, is_own)
      |> assign(:has_urls, has_urls)
      |> assign(:msg_text, Map.get(msg, :text))
      |> assign(:msg_id, Map.get(msg, :id))
      |> assign(:msg_nick, Map.get(msg, :nick))

    ~H"""
    <ul class="list-none m-0 p-[2px] text-xs">
      <li>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="copy_message"
          phx-value-text={@msg_text}
        >
          <Icons.icon_copy class="w-[16px] h-[16px] shrink-0" />
          <span>Copy Message</span>
        </button>
      </li>
      <li>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="reply"
          phx-value-message_id={@msg_id}
        >
          <Icons.icon_chat class="w-[16px] h-[16px] shrink-0" />
          <span>Reply</span>
        </button>
      </li>
      <li class="border-t border-separator my-[2px]"></li>
      <li :if={@is_own}>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="delete"
          phx-value-message_id={@msg_id}
        >
          <Icons.icon_trash class="w-[16px] h-[16px] shrink-0" />
          <span>Delete</span>
        </button>
      </li>
      <li :if={!@is_target_self}>
        <button
          class="flex items-center gap-1.5 w-full px-4 py-1 text-left hover:bg-primary hover:text-white"
          phx-click={@on_action}
          phx-value-action="ignore_sender"
          phx-value-nick={@msg_nick}
        >
          <Icons.icon_btn_ignore class="w-[16px] h-[16px] shrink-0" />
          <span>Ignore Sender</span>
        </button>
      </li>
    </ul>
    """
  end

  defp position_style(x, y), do: "left: #{x}px; top: #{y}px;"
end
