defmodule RetroHexChatWeb.ChatLive.Components.ChatTabs do
  @moduledoc """
  Pure function component for the IRC tab bar.

  The bar is a two-position switch: Status, and the conversation currently in
  focus. It never lists the other joined channels or open PMs — those live in
  the conversations sidebar, which owns the same unread, highlight, group-call
  and P2P signals and does not run out of horizontal room.

  This mirrors the state it renders. The socket carries a single
  `active_channel`/`active_pm` and a single message stream, so "one conversation
  on screen" was always the truth; a strip of N tabs only suggested otherwise.
  Leaving a conversation does not leave the channel — the PubSub subscription is
  bound to join/part, so a backgrounded conversation keeps arriving and keeps
  notifying in the sidebar.

  Space rides here as a third tab because it is what it always was: a second
  view of the focused conversation, rendered into the same region the messages
  occupy. It used to be a pair of toolbar buttons, one of which — "Chat" — the
  conversation tab already means.

  Function component (no local state). `switch_tab`/`close_tab` stay parent
  adapters (`navigation_events`), carried as attr defaults so the legacy event
  contract is preserved.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.IrcTabs

  attr :class, :any, default: nil, doc: "Extra classes for the tab bar container"
  attr :unread_counts, :map, default: %{}, doc: "Unread counts keyed by channel / \"pm:nick\""
  attr :status_unread, :boolean, default: false
  attr :show_status_tab, :boolean, default: false
  attr :active_channel, :string, default: nil
  attr :active_pm, :string, default: nil
  attr :channel_view, :atom, default: :chat, doc: "Which view of the conversation is on screen"

  attr :has_space, :boolean,
    default: false,
    doc: "Whether the focused conversation has a space to switch to"

  attr :nick_color_fn, :any, required: true, doc: "nick -> CSS color class (PM tab)"
  attr :on_switch, :any, default: "switch_tab"
  attr :on_close, :any, default: "close_tab"
  slot :actions

  attr :p2p_pm_sessions, :map,
    default: %{},
    doc: "P2P session read models keyed by downcased PM nick"

  attr :group_call_channels, :any,
    default: MapSet.new(),
    doc: "Channel names that currently have an active group call"

  attr :group_call_summaries, :map,
    default: %{},
    doc: "Channel conference summaries keyed by channel name"

  @spec chat_tabs(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_tabs(assigns) do
    assigns = assign(assigns, :tabs, build_tabs(assigns))

    ~H"""
    <.irc_tab_bar class={@class} data-testid="tab-bar">
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
        group_call_summary={tab.group_call_summary}
        p2p_state={tab.p2p_state}
        p2p_session={tab.p2p_session}
        on_click={@on_switch}
        on_close={@on_close}
      />
      <:actions :if={@actions != []}>{render_slot(@actions)}</:actions>
    </.irc_tab_bar>
    """
  end

  # Status, at most one conversation, and that conversation's space. A session
  # with nothing joined and no PM open renders the Status tab alone.
  @spec build_tabs(map()) :: [map()]
  defp build_tabs(assigns) do
    [status_tab(assigns) | focused_tab(assigns)] ++ space_tab(assigns)
  end

  # The space stays on the bar while Status is showing, exactly as the
  # conversation tab does: which tabs exist follows what is in focus, not which
  # of them you are currently looking at. A bar whose tabs come and go as you
  # glance at Status would be a moving target.
  defp space_tab(%{has_space: true} = assigns) do
    [
      %{
        type: "space",
        label: dgettext("chat", "Space"),
        active: !assigns.show_status_tab && assigns.channel_view == :space,
        unread: false,
        closeable: false,
        nick_color: nil,
        p2p: false,
        p2p_state: nil,
        p2p_session: nil,
        group_call: false,
        group_call_summary: nil
      }
    ]
  end

  defp space_tab(_assigns), do: []

  defp status_tab(assigns) do
    %{
      type: "status",
      label: dgettext("chat", "Status"),
      active: assigns.show_status_tab,
      unread: assigns.status_unread,
      closeable: false,
      nick_color: nil,
      p2p: false,
      p2p_state: nil,
      p2p_session: nil,
      group_call: false,
      group_call_summary: nil
    }
  end

  # The PM wins when both are set: opening a PM is what last took the screen,
  # and `active_channel` stays behind it so leaving the PM can fall back to it.
  defp focused_tab(%{active_pm: pm} = assigns) when is_binary(pm), do: [pm_tab(pm, assigns)]

  defp focused_tab(%{active_channel: channel} = assigns) when is_binary(channel),
    do: [channel_tab(channel, assigns)]

  defp focused_tab(_assigns), do: []

  defp channel_tab(channel, assigns) do
    %{
      type: "channel",
      label: channel,
      active: chat_view_active?(assigns),
      unread: Map.get(assigns.unread_counts, channel, 0) > 0,
      closeable: true,
      nick_color: nil,
      p2p: false,
      p2p_state: nil,
      p2p_session: nil,
      group_call: channel_group_call?(assigns.group_call_channels, channel),
      group_call_summary: Map.get(assigns.group_call_summaries || %{}, channel)
    }
  end

  defp pm_tab(pm, assigns) do
    pm_p2p_session = p2p_session_for_pm(assigns, pm)
    pm_p2p_state = p2p_tab_state(value(pm_p2p_session, :state))

    %{
      type: "pm",
      label: pm,
      active: chat_view_active?(assigns),
      unread: Map.get(assigns.unread_counts, "pm:#{pm}", 0) > 0,
      closeable: true,
      nick_color: assigns.nick_color_fn.(pm),
      p2p: pm_p2p_session != nil,
      p2p_state: pm_p2p_state,
      p2p_session: pm_p2p_session,
      group_call: false,
      group_call_summary: nil
    }
  end

  defp chat_view_active?(assigns) do
    !assigns.show_status_tab && assigns.channel_view != :space
  end

  # `focused_tab/1` only builds a tab for a binary name, so no nil clause here.
  defp channel_group_call?(channels, channel) do
    MapSet.member?(MapSet.new(channels || []), channel)
  end

  defp p2p_session_for_pm(%{p2p_pm_sessions: sessions}, pm) when is_map(sessions),
    do: Map.get(sessions, String.downcase(pm))

  defp p2p_session_for_pm(_assigns, _pm), do: nil

  defp p2p_tab_state(:idle), do: "idle"
  defp p2p_tab_state(:pending_received), do: "pending"
  defp p2p_tab_state(:invite_sent), do: "pending"
  defp p2p_tab_state(:connected), do: "connected"
  defp p2p_tab_state(nil), do: nil
  defp p2p_tab_state(_state), do: "connecting"

  # Nil-safe because the session it reads is absent more often than present.
  defp value(nil, _key), do: nil
  defp value(map, key) when is_map(map) and is_atom(key), do: Map.get(map, key)
end
