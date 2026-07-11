defmodule RetroHexChatWeb.ChatLive.Components.ChatTabs do
  @moduledoc """
  Pure function component for the IRC tab bar (status + channels + PMs).

  Normalizes the channel/PM/unread data into a single tab list BEFORE rendering
  (instead of three inline `:for` comprehensions with `Map.get(@unread_counts, …)`
  in the main template) and renders it through the design-system `irc_tab_bar`/
  `irc_tab_item` components.

  Function component (no local state): there is no drag/reorder/overflow/pin yet.
  `switch_tab`/`close_tab` stay parent adapters (`navigation_events`), carried as
  attr defaults so the legacy event contract is preserved; change-tracking
  memoizes the bar on the few inputs it reads, so a message in the active channel
  that does not change unread no longer re-renders the whole tab strip.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.IrcTabs

  attr :channels, :list, default: [], doc: "Joined channel names, in order"
  attr :pm_conversations, :list, default: [], doc: "Open PM nicks, in order"
  attr :unread_counts, :map, default: %{}, doc: "Unread counts keyed by channel / \"pm:nick\""
  attr :status_unread, :boolean, default: false
  attr :show_status_tab, :boolean, default: false
  attr :active_channel, :string, default: nil
  attr :active_pm, :string, default: nil
  attr :nick_color_fn, :any, required: true, doc: "nick -> CSS color class (PM tabs)"
  attr :on_switch, :any, default: "switch_tab"
  attr :on_close, :any, default: "close_tab"

  attr :p2p_peer, :string,
    default: nil,
    doc: "Peer of the active P2P session — that PM tab gets the session glyph"

  attr :group_call_channels, :any,
    default: MapSet.new(),
    doc: "Channel names that currently have an active group call"

  @spec chat_tabs(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_tabs(assigns) do
    assigns = assign(assigns, :tabs, build_tabs(assigns))

    ~H"""
    <.irc_tab_bar>
      <.irc_tab_item
        :for={tab <- @tabs}
        type={tab.type}
        label={tab.label}
        active={tab.active}
        unread={tab.unread}
        closeable={tab.closeable}
        nick_color={tab.nick_color}
        p2p={tab.p2p}
        group_call={tab.group_call}
        on_click={@on_switch}
        on_close={@on_close}
      />
    </.irc_tab_bar>
    """
  end

  # Build the normalized `%{type, label, active, unread, closeable, nick_color}`
  # list outside the HEEx so the template carries no per-tab data shaping.
  @spec build_tabs(map()) :: [map()]
  defp build_tabs(assigns) do
    status_tab = %{
      type: "status",
      label: dgettext("chat", "Status"),
      active: assigns.show_status_tab,
      unread: assigns.status_unread,
      closeable: false,
      nick_color: nil,
      p2p: false,
      group_call: false
    }

    channel_tabs =
      for channel <- assigns.channels do
        %{
          type: "channel",
          label: channel,
          active: assigns.active_channel == channel && !assigns.show_status_tab,
          unread: Map.get(assigns.unread_counts, channel, 0) > 0,
          closeable: true,
          nick_color: nil,
          p2p: false,
          group_call: channel_group_call?(assigns.group_call_channels, channel)
        }
      end

    p2p_peer = assigns.p2p_peer && String.downcase(assigns.p2p_peer)

    pm_tabs =
      for pm <- assigns.pm_conversations do
        %{
          type: "pm",
          label: pm,
          active: assigns.active_pm == pm && !assigns.show_status_tab,
          unread: Map.get(assigns.unread_counts, "pm:#{pm}", 0) > 0,
          closeable: true,
          nick_color: assigns.nick_color_fn.(pm),
          p2p: p2p_peer == String.downcase(pm),
          group_call: false
        }
      end

    [status_tab | channel_tabs ++ pm_tabs]
  end

  defp channel_group_call?(channels, channel) when is_binary(channel) do
    MapSet.member?(MapSet.new(channels || []), channel)
  end

  defp channel_group_call?(_channels, _channel), do: false
end
