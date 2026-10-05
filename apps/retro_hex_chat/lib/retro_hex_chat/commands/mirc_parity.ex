defmodule RetroHexChat.Commands.MircParity do
  @moduledoc """
  What a command typed from mIRC habit does here.

  Each row names the thing a mIRC user reaches for — a command, or a dialog
  mIRC keeps under Options — and says whether it works the same, works
  differently, or does not exist, with the command to use instead and, when
  its shape differs from mIRC's, how it is typed here. The public
  "mIRC commands" page is drawn from this list.

  `here` is a name in `RetroHexChat.Commands.Registry`, never a free string, so
  a command that is renamed or removed fails this module's test instead of
  leaving the page pointing at a command nobody can type.
  """
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Chat.HelpTopics

  @type status :: :same | :different | :missing
  @type group :: :talking | :channels | :operators | :services | :automation | :elsewhere

  @type row :: %{
          mirc: String.t(),
          here: String.t() | nil,
          status: status(),
          group: group(),
          usage: String.t() | nil,
          note: String.t() | nil,
          help_topic: String.t() | nil
        }

  @groups [
    talking: dgettext_noop("commands", "Talking"),
    channels: dgettext_noop("commands", "Channels"),
    operators: dgettext_noop("commands", "Channel operators"),
    services: dgettext_noop("commands", "NickServ and ChanServ"),
    automation: dgettext_noop("commands", "Automation"),
    elsewhere: dgettext_noop("commands", "Files, servers and scripts")
  ]

  # `mirc` and `usage` are what the reader types — identifiers, so they are
  # never translated and never sit inside a translated note. Only `note` is
  # prose.
  @rows [
    {:talking, "/msg nick text", "msg", :same, nil, nil},
    {:talking, "/query nick", "query", :same, nil, nil},
    {:talking, "/me action", "me", :same, nil, nil},
    {:talking, "/notice nick text", "notice", :same, nil, nil},
    {:talking, "/nick newnick", "nick", :different, nil,
     dgettext_noop("commands", "Asks you to confirm before the change takes effect.")},
    {:talking, "/away message", "away", :same, nil, nil},
    {:talking, "/describe nick action", nil, :missing, nil,
     dgettext_noop("commands", "Open the private conversation and use /me there.")},
    {:talking, "/amsg text", nil, :missing, nil,
     dgettext_noop("commands", "Each chat room is its own conversation: say it in each one.")},
    {:talking, "/ctcp nick ping", nil, :missing, nil,
     dgettext_noop("commands", "There is no CTCP. /whois shows idle time and away status.")},
    {:channels, "/join #channel key", "join", :same, nil, nil},
    {:channels, "/part #channel message", "part", :same, nil, nil},
    {:channels, "/list", "list", :different, nil,
     dgettext_noop("commands", "Opens a channel list you can sort and filter.")},
    {:channels, "/topic #channel text", "topic", :different, "/topic text",
     dgettext_noop("commands", "Works on the channel you are in.")},
    {:channels, "/invite nick #channel", "invite", :same, nil, nil},
    {:channels, "/knock #channel", "knock", :same, nil, nil},
    {:channels, "/names #channel", nil, :missing, nil,
     dgettext_noop("commands", "The nick list beside every channel shows who is there.")},
    {:channels, "/whois nick", "whois", :same, nil, nil},
    {:channels, "/whowas nick", "whowas", :same, nil, nil},
    {:channels, "/clear", "clear", :same, nil, nil},
    {:channels, "/quit message", "quit", :same, nil, nil},
    {:operators, "/mode #channel +o nick", "mode", :different, "/mode +o nick",
     dgettext_noop("commands", "Works on the channel you are in.")},
    {:operators, "/op nick", "op", :same, nil, nil},
    {:operators, "/voice nick", "voice", :same, nil, nil},
    {:operators, "/kick #channel nick reason", "kick", :different, "/kick nick reason",
     dgettext_noop("commands", "Works on the channel you are in.")},
    {:operators, "/ban #channel nick", "ban", :different, "/ban nick",
     dgettext_noop(
       "commands",
       "Bans a nickname in the channel you are in. There are no host masks."
     )},
    {:operators, "/oper", nil, :missing, nil,
     dgettext_noop(
       "commands",
       "There is no operator login: the server's administrator appoints its staff."
     )},
    {:services, "/msg NickServ register", "ns", :different, "/ns register password",
     dgettext_noop("commands", "NickServ answers to its own command.")},
    {:services, "/msg ChanServ register #channel", "cs", :different, "/cs register",
     dgettext_noop("commands", "ChanServ answers to its own command, typed inside the channel.")},
    {:automation, "/alias", "alias", :different, "/alias add name expansion",
     dgettext_noop(
       "commands",
       "Takes $1 to $9, $nick and $chan. There is no scripting language behind it."
     )},
    {:automation, "Perform", "perform", :different, "/perform add command",
     dgettext_noop(
       "commands",
       "mIRC keeps it under Options; here it is a command, or the Perform dialog."
     )},
    {:automation, "Popups", "popups", :different, nil,
     dgettext_noop(
       "commands",
       "Your own right-click menu items for the nick list and channels."
     )},
    {:automation, "/timer", "timer", :different, "/timer name seconds command",
     dgettext_noop("commands", "Runs a command once after a delay, or again and again.")},
    {:automation, "/notify nick", "notify", :different, "/notify add nick",
     dgettext_noop("commands", "Takes a subcommand; on its own it opens the notify list.")},
    {:automation, "/ignore nick", "ignore", :different, "/ignore nick pms 1h",
     dgettext_noop("commands", "Takes a type and a duration.")},
    {:automation, "/autojoin", "autojoin", :different, "/autojoin add #channel",
     dgettext_noop("commands", "mIRC keeps it in the Favorites; here it is a command.")},
    {:elsewhere, "/dcc send nick", "p2p", :different, "/p2p nick",
     dgettext_noop(
       "commands",
       "Files go over a direct session between browsers. Both nicknames must be registered."
     )},
    {:elsewhere, "/server host", nil, :missing, nil,
     dgettext_noop(
       "commands",
       "This is one server, in the browser. There are no networks to switch to, and the mIRC program cannot connect to it."
     )},
    {:elsewhere, "mIRC scripts", "autorespond", :different, nil,
     dgettext_noop(
       "commands",
       "There are no .mrc scripts. /autorespond runs a command when someone joins, leaves or changes nickname."
     )}
  ]

  @doc "The groups, in page order, each with its label in the current locale."
  @spec groups() :: [{group(), String.t()}]
  def groups, do: Enum.map(@groups, fn {group, label} -> {group, t(label)} end)

  @doc """
  Every row, in page order, with its note in the current locale and the help
  topic that explains the command here, when there is one.
  """
  @spec rows() :: [row()]
  def rows do
    Enum.map(@rows, fn {group, mirc, here, status, usage, note} ->
      %{
        mirc: mirc,
        here: here,
        status: status,
        group: group,
        usage: usage,
        note: note && t(note),
        help_topic: help_topic(here)
      }
    end)
  end

  @doc "The rows of one group."
  @spec rows(group()) :: [row()]
  def rows(group), do: Enum.filter(rows(), &(&1.group == group))

  defp help_topic(nil), do: nil

  defp help_topic(command) do
    id = "cmd-" <> String.replace(command, "_", "-")
    if HelpTopics.get_topic(id), do: id
  end

  defp t(msgid), do: Gettext.dgettext(RetroHexChat.Gettext, "commands", msgid)
end
