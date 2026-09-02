defmodule RetroHexChatWeb.ChatLive.Components.ChatShell do
  @moduledoc """
  Chat-layer glue for the chat window's menu bar.

  Derives what the menus need to know from the host's session assigns and
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
  alias RetroHexChatWeb.ChatLive.ChatContext

  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.StatusBarApp

  attr :session, Session,
    required: true,
    doc: "Chat session struct — read only for the admin gate on Bot Management"

  attr :mobile_viewport, :any,
    default: nil,
    doc: "The host's @mobile_viewport assign, threaded through to the menu bar"

  @spec chat_shell_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_shell_menu(assigns) do
    assigns = assign(assigns, is_admin: ChatContext.admin?(assigns.session))

    ~H"""
    <.menu_bar_app
      id="menubar"
      phx-hook="MenuBarHook"
      connected={true}
      is_admin={@is_admin}
      language_return_to="/chat"
      mobile_viewport={@mobile_viewport}
      on_action="toolbar_action"
    />
    """
  end

  attr :p2p_elsewhere, :map,
    default: nil,
    doc: """
    `%{peer_nick, path}` when the reader has a live P2P session open at its own
    address — from `P2PReadModel.elsewhere/2`. It is the only shape this zone
    has: a session is never on this screen.
    """

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
        p2p: p2p_elsewhere_display(assigns.p2p_elsewhere)
      )

    ~H"""
    <.status_bar_zones
      group_call={@group_call_display}
      p2p={@p2p}
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

  # The only shape this zone has: the session is running in a page of this
  # person's that is not this one. There is nothing to focus here and nothing to
  # end from here — you end a session on the screen that is holding it — so what
  # is left is a way over to the tab that does.
  @spec p2p_elsewhere_display(map() | nil) :: map() | nil
  defp p2p_elsewhere_display(%{peer_nick: peer_nick, path: path})
       when is_binary(peer_nick) and is_binary(path) do
    %{
      label: dgettext("chat", "P2P: %{peer} — in another tab", peer: peer_nick),
      title:
        dgettext("chat", "This P2P session is open in another tab of yours — click to go to it"),
      path: path
    }
  end

  defp p2p_elsewhere_display(_elsewhere), do: nil

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
