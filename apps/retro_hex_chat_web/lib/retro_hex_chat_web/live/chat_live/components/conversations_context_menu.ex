defmodule RetroHexChatWeb.ChatLive.Components.ConversationsContextMenu do
  @moduledoc """
  Stateful island for the conversations-sidebar right-click context menu.

  Owns the menu's own state (`visible`/`x`/`y`/`type`/`channel`/`nick`) — one map
  lifted out of the parent `assign_defaults` — and stops the menu from
  re-rendering on every parent hot-path re-render (chat message, typing, lag),
  the same change-tracking isolation as the nicklist island.

  The action events (`ctx_conversations_*`) stay parent adapters: they read their
  target from the menu item's `phx-value` params, never from the parent assigns,
  so the menu state moves cleanly with zero parent read-model. Open
  (`channel_right_click`/`pm_right_click`) and close are adapters that drive this
  component via `send_update` (the events module's `put_conv_menu/2`). The mute/
  unread read-model maps (`muted_channels`/`unread_counts`) and the session stay
  parent-owned and arrive here as passthrough; the menu derives `is_muted`/
  `has_unread`/`custom_items` in `render/1` (helpers moved here from the parent).
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ConversationsContextMenu

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{CustomMenus, UnreadTracker}

  @id "conversations-context-menu"

  @spec id() :: String.t()
  def id, do: @id

  @closed %{visible: false, x: 0, y: 0, type: :channel, channel: nil, nick: nil}

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(@closed)
     |> assign(muted_channels: MapSet.new(), unread_counts: %{}, session: nil)}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    key = context_key(assigns)

    assigns =
      assign(assigns,
        is_muted: MapSet.member?(assigns.muted_channels, key),
        has_unread: UnreadTracker.unread?(assigns.unread_counts, key),
        custom_items: custom_items(assigns.session, assigns.type)
      )

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.conversations_context_menu
        visible={@visible}
        x={@x}
        y={@y}
        type={@type}
        channel={@channel}
        nick={@nick}
        is_muted={@is_muted}
        has_unread={@has_unread}
        custom_items={@custom_items}
        on_action="conversations_context_action"
      />
    </div>
    """
  end

  @spec context_key(map()) :: String.t() | nil
  defp context_key(%{type: type, nick: nick}) when type in [:pm, "pm"] and is_binary(nick),
    do: "pm:#{nick}"

  defp context_key(%{channel: channel}) when is_binary(channel), do: channel
  defp context_key(_assigns), do: nil

  @spec custom_items(Session.t() | nil, atom() | String.t()) :: list()
  defp custom_items(_session, type) when type in [:pm, "pm"], do: []
  defp custom_items(nil, _type), do: []
  defp custom_items(session, _type), do: CustomMenus.entries_for(session.custom_menus, :channel)
end
