defmodule RetroHexChatWeb.ChatLive.Components.ChatShell do
  @moduledoc """
  Chat-layer glue for the chat window's menu bar.

  Derives what the menus need to know — whether a peer session exists and
  whether a relay is configured for it — from the host's call assigns, and
  delegates the markup to the design-system `menu_bar_app/1`.

  The menus act on this window and nothing else. Launching another program —
  the arcade, the retro games, an admin or a runtime window — is the Start
  menu's job, which is why none of them are reached from here and why this no
  longer reads the session at all.

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

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.ChatLive.ChatContext

  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.StatusBarApp

  attr :session, Session,
    required: true,
    doc: "Chat session struct — read only for the admin gate on Bot Management"

  attr :p2p_session, :map,
    default: nil,
    doc: "The host's @p2p_session state-machine assign (nil when no session)"

  attr :mobile_viewport, :any,
    default: nil,
    doc: "The host's @mobile_viewport assign, threaded through to the menu bar"

  @spec chat_shell_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_shell_menu(assigns) do
    assigns =
      assign(assigns,
        is_admin: ChatContext.admin?(assigns.session),
        p2p_turn_available: (assigns.p2p_session || %{})[:turn_configured] == true
      )

    ~H"""
    <.menu_bar_app
      id="menubar"
      phx-hook="MenuBarHook"
      connected={true}
      is_admin={@is_admin}
      p2p_active={@p2p_session != nil}
      p2p_turn_available={@p2p_turn_available}
      language_return_to="/chat"
      mobile_viewport={@mobile_viewport}
      on_action="toolbar_action"
    />
    """
  end

  attr :p2p_session, :map, default: nil, doc: "The host's @p2p_session assign"

  attr :group_call_elsewhere, :map,
    default: nil,
    doc: """
    `%{channel_name, path}` when the reader has a live call open at its own
    address — from `GroupCallReadModel.elsewhere/3`. It is the only shape this
    zone has: a conference is never on this screen.
    """

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
        group_call_display: group_call_elsewhere_display(assigns.group_call_elsewhere),
        p2p: p2p_display(assigns.p2p_session)
      )

    ~H"""
    <.status_bar_zones
      group_call={@group_call_display}
      p2p={@p2p}
      on_p2p_click="p2p_statusbar_click"
      on_p2p_stop="p2p_statusbar_stop"
      show_clock={false}
      show_lag={false}
      show_mute={false}
    />
    """
  end

  # The only shape the zone has: the call is running and this reader is in it,
  # on a screen that is not this one. There is nothing to focus here and nothing
  # to leave from here — only a way over to it.
  @spec group_call_elsewhere_display(map() | nil) :: map() | nil
  defp group_call_elsewhere_display(%{channel_name: channel_name, path: path})
       when is_binary(channel_name) and is_binary(path) do
    %{
      label: dgettext("group_call", "Call: %{channel} — in another tab", channel: channel_name),
      title:
        dgettext(
          "group_call",
          "The call in %{channel} is open in another tab of yours — click to go to it",
          channel: channel_name
        ),
      path: path
    }
  end

  defp group_call_elsewhere_display(_elsewhere), do: nil

  # Derives the status-bar P2P zone strings from the host state machine —
  # the design-system component receives display text only.
  @spec p2p_display(map() | nil) :: map() | nil
  defp p2p_display(nil), do: nil

  # The session is running in another page of this person's, so this zone is a
  # way over to it and not a control over it. Same shape the conference zone
  # takes, and for the same reason: you end a session from the screen that is
  # holding it.
  defp p2p_display(%{displaced: true, token: token} = p2p) when is_binary(token) do
    peer = p2p[:peer_nick] || "?"

    %{
      label: dgettext("chat", "P2P: %{peer} — in another tab", peer: peer),
      title:
        dgettext("chat", "This P2P session is open in another tab of yours — click to go to it"),
      path: Paths.p2p_path(token)
    }
  end

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
