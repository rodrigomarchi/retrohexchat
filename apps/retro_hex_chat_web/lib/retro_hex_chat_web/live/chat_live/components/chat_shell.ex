defmodule RetroHexChatWeb.ChatLive.Components.ChatShell do
  @moduledoc """
  Chat-layer glue for the chat window's menu bar.

  Derives what the menus need to know — admin?, arcade availability, whether a
  peer session exists and whether a relay is configured for it — from the
  `Session` struct and the host's call assigns, and delegates the markup to the
  design-system `menu_bar_app/1`.

  The menu bar hangs under the chat window's title bar, where Windows 98 put an
  application's menus, rather than in a strip across the top of the screen. The
  desk has no chrome of its own: what the app has to say about itself is in the
  window's title bar, the taskbar and the tray.

  Identity and the active conversation are not derived here: the chat window's
  title bar names both (see `ChatLive.ChatTitle`).

  Pure function component (the menu owns no draft/selection state). It holds the
  domain derivation only — no raw layout markup, which lives in `components/ui/`
  — keeping this lint-scanned glue free of raw Tailwind. Change-tracking
  memoizes it on the assigns it reads, so a plain chat message produces no menu
  diff.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.StatusBarApp

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.ChatContext

  attr :session, Session,
    required: true,
    doc: "Chat session struct (the menu is a function of it)"

  attr :p2p_session, :map,
    default: nil,
    doc: "The host's @p2p_session state-machine assign (nil when no session)"

  attr :mobile_viewport, :any,
    default: nil,
    doc: "The host's @mobile_viewport assign, threaded through to the menu bar"

  @spec chat_shell_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_shell_menu(assigns) do
    session = assigns.session

    assigns =
      assign(assigns,
        is_admin: ChatContext.admin?(session),
        arcade_available: session.identified == true,
        p2p_turn_available: (assigns.p2p_session || %{})[:turn_configured] == true
      )

    ~H"""
    <.menu_bar_app
      id="menubar"
      phx-hook="MenuBarHook"
      connected={true}
      is_admin={@is_admin}
      arcade_available={@arcade_available}
      p2p_active={@p2p_session != nil}
      p2p_turn_available={@p2p_turn_available}
      language_return_to="/chat"
      mobile_viewport={@mobile_viewport}
      on_action="toolbar_action"
    />
    """
  end

  attr :p2p_session, :map, default: nil, doc: "The host's @p2p_session assign"
  attr :group_call, :map, default: nil, doc: "The host's @group_call assign"

  @doc """
  The chat window's own status bar: what this session is doing right now.

  A Win98 application reported on itself along the bottom edge of its window,
  and that is where an active call or file transfer belongs — not in a strip
  across the whole screen, and not in the tray, which speaks for the machine
  (the clock, the volume, the connection) rather than for one window.
  """
  @spec chat_shell_status(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_shell_status(assigns) do
    assigns =
      assign(assigns,
        group_call_display: group_call_display(assigns.group_call),
        p2p: p2p_display(assigns.p2p_session)
      )

    ~H"""
    <.status_bar_zones
      group_call={@group_call_display}
      on_group_call_click="group_call_statusbar_click"
      on_group_call_stop="group_call_statusbar_stop"
      p2p={@p2p}
      on_p2p_click="p2p_statusbar_click"
      on_p2p_stop="p2p_statusbar_stop"
      show_clock={false}
      show_lag={false}
      show_mute={false}
    />
    """
  end

  @spec group_call_display(map() | nil) :: map() | nil
  defp group_call_display(nil), do: nil

  defp group_call_display(%{
         channel_name: channel_name,
         status: status,
         participants: participants
       }) do
    channel = channel_name || dgettext("group_call", "Group Call")
    count = length(participants || [])

    %{
      label: group_call_label(status, channel, count),
      title:
        dgettext("group_call", "Group call in %{channel} — click to focus", channel: channel),
      stop_title: dgettext("group_call", "Leave the group call")
    }
  end

  defp group_call_label(:connected, channel, count) when count > 0 do
    dgettext("group_call", "Call: %{channel} (%{count})", channel: channel, count: count)
  end

  defp group_call_label(:joining, channel, _count) do
    dgettext("group_call", "Call: joining %{channel}...", channel: channel)
  end

  defp group_call_label(:connecting, channel, _count) do
    dgettext("group_call", "Call: connecting %{channel}...", channel: channel)
  end

  defp group_call_label(:negotiating, channel, _count) do
    dgettext("group_call", "Call: negotiating %{channel}...", channel: channel)
  end

  defp group_call_label(:error, channel, _count) do
    dgettext("group_call", "Call: error in %{channel}", channel: channel)
  end

  defp group_call_label(_status, channel, count) when count > 0 do
    dgettext("group_call", "Call: %{channel} (%{count})", channel: channel, count: count)
  end

  defp group_call_label(_status, channel, _count) do
    dgettext("group_call", "Call: %{channel}", channel: channel)
  end

  # Derives the status-bar P2P zone strings from the host state machine —
  # the design-system component receives display text only.
  @spec p2p_display(map() | nil) :: map() | nil
  defp p2p_display(nil), do: nil

  defp p2p_display(%{state: state, peer_nick: peer_nick} = p2p) do
    peer = peer_nick || "?"

    case state do
      :invite_sent ->
        %{
          label: dgettext("chat", "P2P: waiting for %{peer}...", peer: peer),
          title: dgettext("chat", "P2P invite pending"),
          stop_title: dgettext("chat", "Cancel the P2P invite")
        }

      :connected ->
        %{
          label: connected_p2p_label(peer, p2p[:call_summary]),
          title: connected_p2p_title(peer, p2p),
          stop_title: dgettext("chat", "End the P2P session"),
          facets: p2p_facets(p2p),
          duration: get_in(p2p, [:call_summary, :duration]),
          quality: get_in(p2p, [:call_summary, :quality_label]),
          turn_only: p2p[:turn_only] == true and p2p[:turn_configured] == true
        }

      _joining_or_connecting ->
        %{
          label: dgettext("chat", "P2P: connecting to %{peer}...", peer: peer),
          title: dgettext("chat", "P2P session connecting"),
          stop_title: dgettext("chat", "End the P2P session")
        }
    end
  end

  defp connected_p2p_label(peer, %{duration: duration}) when is_binary(duration) do
    dgettext("chat", "P2P: %{peer} %{duration}", peer: peer, duration: duration)
  end

  defp connected_p2p_label(peer, _call_summary) do
    dgettext("chat", "P2P: %{peer}", peer: peer)
  end

  defp connected_p2p_title(peer, p2p) do
    facets = p2p_facets(p2p)

    suffix =
      case facets do
        [] -> dgettext("chat", "session ready")
        _ -> Enum.map_join(facets, ", ", &facet_title/1)
      end

    dgettext("chat", "P2P session with %{peer} — %{facets}. Click to focus",
      peer: peer,
      facets: suffix
    )
  end

  defp p2p_facets(p2p) do
    []
    |> maybe_add_facet(:call, p2p[:call_summary] != nil)
    |> maybe_add_facet(:file, p2p[:file_summary] != nil)
    |> maybe_add_facet(:game, get_in(p2p, [:game_summary, :active?]) == true)
  end

  defp maybe_add_facet(facets, facet, true), do: facets ++ [facet]
  defp maybe_add_facet(facets, _facet, _false), do: facets

  defp facet_title(:call), do: dgettext("chat", "call active")
  defp facet_title(:file), do: dgettext("chat", "file transfer active")
  defp facet_title(:game), do: dgettext("chat", "game active")

  @doc """
  How many buddies on the notify list are online right now.

  Public because the tray shows the badge: the taskbar is rendered from the
  chat template rather than from here, and the count is a property of the
  session either way.
  """
  @spec online_buddy_count(%{entries: list()} | nil) :: non_neg_integer()
  def online_buddy_count(%{entries: entries}) when is_list(entries) do
    Enum.count(entries, &(&1.online == true))
  end

  def online_buddy_count(_notify_list), do: 0
end
