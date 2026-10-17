defmodule RetroHexChatWeb.ChatLive.Arrival do
  @moduledoc """
  What the chat says to someone arriving, signed in or visiting.

  Everybody reads the same server text in the Status window: the message of
  the day, the server's welcome and the welcome message an admin set
  (`/admin server set welcome_message`). What follows depends on what they
  can do:

    * a member gets the commands to start with and the ChanServ and NickServ
      quick starts;
    * a visitor, who can type none of them, is greeted in the channel on
      screen instead — a System line carrying the card that names what an
      account opens (`Components.UI.VisitorGreetingCard`), for their eyes only.

  A member's reconnect restores silently; a visitor has nothing to restore,
  so every arrival is greeted.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Admin
  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChat.Services.{ChanExpiry, Motd, NickExpiry}
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Helpers.Messages

  @doc "Greets a member who has just signed in."
  @spec member(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def member(socket) do
    socket
    |> server_text()
    |> status_lines(:system, commands())
    |> status_lines(:service, chanserv())
    |> status_lines(:service, nickserv())
  end

  @doc "Greets a visitor in the channel on screen, after the server's own text."
  @spec visitor(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def visitor(socket) do
    socket
    |> server_text()
    |> greet_visitor()
  end

  defp server_text(socket) do
    socket
    |> status_lines(:motd, List.wrap(Motd.get()))
    |> status_lines(:system, [
      dgettext("chat", "Welcome to %{server_name}!", server_name: Admin.server_name()),
      dgettext("chat", "A real-time chat platform with a retro look and feel.")
    ])
    |> status_lines(:system, admin_welcome())
  end

  defp admin_welcome do
    case Admin.server_setting("welcome_message") do
      "" -> []
      message -> [message]
    end
  end

  # A visitor the server refused the channel they came for has the error in
  # front of them instead, and no channel to be greeted in.
  defp greet_visitor(
         %{assigns: %{session: %{active_channel: channel}, visitor_nick: guest}} = socket
       )
       when is_binary(channel) do
    MessageViewport.insert(
      socket,
      Messages.visitor_greeting_message(guest, channel, Admin.server_name())
    )
  end

  defp greet_visitor(socket), do: socket

  defp status_lines(socket, type, lines) do
    Enum.reduce(lines, socket, &Messages.push_status_message(&2, &1, type))
  end

  defp commands do
    [
      "",
      dgettext("chat", "Useful commands:"),
      dgettext("chat", "  /join #channel   — Join a channel"),
      dgettext("chat", "  /msg nick text   — Send a private message"),
      dgettext("chat", "  /nick new_nick   — Change your nickname"),
      dgettext("chat", "  /help            — View full help"),
      dgettext("chat", "  /help commands   — List all commands"),
      "",
      dgettext("chat", "Tip: Go to Help > Help Topics for the full documentation.") <>
        " " <> dgettext("chat", "Open /chat/help in a new tab.")
    ]
  end

  # The command is typed, never translated: only its description goes through Gettext, and
  # every ChanServ command acts on the channel you are in, so none of them takes one.
  defp chanserv_line(command, description),
    do: "  " <> String.pad_trailing(command, 21) <> " — " <> description

  defp chanserv do
    [
      "",
      dgettext("chat", "[ChanServ] Channel Services Online"),
      dgettext("chat", "ChanServ manages channel registration and access control."),
      dgettext("chat", "Register your channel to protect it when no operators are online."),
      "",
      dgettext("chat", "Quick start:"),
      chanserv_line("/cs register", dgettext("chat", "Register the channel you are in")),
      chanserv_line("/cs sop add <nick>", dgettext("chat", "Add a Super Operator")),
      chanserv_line("/cs aop add <nick>", dgettext("chat", "Add an Auto Operator")),
      chanserv_line("/cs vop add <nick>", dgettext("chat", "Add an Auto Voice user")),
      chanserv_line("/cs info", dgettext("chat", "See who founded the channel")),
      "",
      dgettext("chat", "Access hierarchy: Owner > SOP > AOP > VOP"),
      "",
      dgettext("chat", "Rules:"),
      dgettext("chat", "  • Channels expire after %{window} of inactivity",
        window: TimeFormatter.days(ChanExpiry.configured_expiration_days())
      ),
      dgettext("chat", "  • If a founder's nick expires, the next ranked user is promoted"),
      "",
      dgettext("chat", "Type /help chanserv or /help channel-permissions for full details.")
    ]
  end

  defp nickserv do
    [
      "",
      dgettext("chat", "[NickServ] Nickname Services Online"),
      dgettext(
        "chat",
        "NickServ protects your nickname with a password so nobody else can use it."
      ),
      "",
      dgettext("chat", "Quick start:"),
      dgettext("chat", "  /ns register <password>   — Register your current nickname"),
      dgettext("chat", "  /ns identify <password>   — Identify (log in) for this session"),
      dgettext("chat", "  /ns info [nickname]       — Look up registration info"),
      dgettext("chat", "  /ns ghost <nick> <pass>   — Disconnect a ghost session"),
      dgettext("chat", "  /ns drop <password>       — Permanently unregister your nickname"),
      "",
      dgettext("chat", "Rules:"),
      dgettext(
        "chat",
        "  • Capital letters do not matter: \"Alice\" and \"alice\" are the same nick"
      ),
      dgettext("chat", "  • Nicks expire after %{window} of inactivity",
        window: TimeFormatter.days(NickExpiry.configured_expiration_days())
      ),
      dgettext("chat", "  • Switching to a registered nick gives you 60s to identify"),
      "",
      dgettext("chat", "Type /help nickserv for full details.")
    ]
  end
end
