defmodule RetroHexChat.Chat.HelpTopics.Commands do
  @moduledoc false

  @help_dir Path.join(:code.priv_dir(:retro_hex_chat), "help")

  @external_resource Path.join(@help_dir, "commands-overview.html")
  @external_resource Path.join(@help_dir, "cmd-alias.html")
  @external_resource Path.join(@help_dir, "cmd-autojoin.html")
  @external_resource Path.join(@help_dir, "cmd-autorespond.html")
  @external_resource Path.join(@help_dir, "cmd-away.html")
  @external_resource Path.join(@help_dir, "cmd-ban.html")
  @external_resource Path.join(@help_dir, "cmd-bio.html")
  @external_resource Path.join(@help_dir, "cmd-call.html")
  @external_resource Path.join(@help_dir, "cmd-clear.html")
  @external_resource Path.join(@help_dir, "cmd-cs.html")
  @external_resource Path.join(@help_dir, "cmd-ctcp.html")
  @external_resource Path.join(@help_dir, "cmd-help.html")
  @external_resource Path.join(@help_dir, "cmd-ignore.html")
  @external_resource Path.join(@help_dir, "cmd-invite.html")
  @external_resource Path.join(@help_dir, "cmd-join.html")
  @external_resource Path.join(@help_dir, "cmd-kick.html")
  @external_resource Path.join(@help_dir, "cmd-list.html")
  @external_resource Path.join(@help_dir, "cmd-me.html")
  @external_resource Path.join(@help_dir, "cmd-mode.html")
  @external_resource Path.join(@help_dir, "cmd-msg.html")
  @external_resource Path.join(@help_dir, "cmd-nick.html")
  @external_resource Path.join(@help_dir, "cmd-notice.html")
  @external_resource Path.join(@help_dir, "cmd-notice-routing.html")
  @external_resource Path.join(@help_dir, "cmd-notify.html")
  @external_resource Path.join(@help_dir, "cmd-ns.html")
  @external_resource Path.join(@help_dir, "cmd-p2p.html")
  @external_resource Path.join(@help_dir, "cmd-part.html")
  @external_resource Path.join(@help_dir, "cmd-perform.html")
  @external_resource Path.join(@help_dir, "cmd-popups.html")
  @external_resource Path.join(@help_dir, "cmd-query.html")
  @external_resource Path.join(@help_dir, "cmd-quit.html")
  @external_resource Path.join(@help_dir, "cmd-sendfile.html")
  @external_resource Path.join(@help_dir, "cmd-timer.html")
  @external_resource Path.join(@help_dir, "cmd-topic.html")
  @external_resource Path.join(@help_dir, "cmd-unban.html")
  @external_resource Path.join(@help_dir, "cmd-unignore.html")
  @external_resource Path.join(@help_dir, "cmd-whois.html")
  @external_resource Path.join(@help_dir, "cmd-whowas.html")

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "commands-overview",
        title: "IRC Commands Reference",
        category: "Commands",
        keywords: ["commands", "reference", "list", "help", "overview", "slash"],
        content: File.read!(Path.join(@help_dir, "commands-overview.html"))
      },
      %{
        id: "cmd-alias",
        title: "/alias",
        category: "Commands",
        keywords: ["alias", "shortcut", "macro", "expansion", "abbreviation"],
        content: File.read!(Path.join(@help_dir, "cmd-alias.html"))
      },
      %{
        id: "cmd-autojoin",
        title: "/autojoin",
        category: "Commands",
        keywords: ["autojoin", "auto join", "auto-join", "channel", "on connect"],
        content: File.read!(Path.join(@help_dir, "cmd-autojoin.html"))
      },
      %{
        id: "cmd-autorespond",
        title: "/autorespond",
        category: "Commands",
        keywords: ["autorespond", "auto", "respond", "trigger", "event", "greet"],
        content: File.read!(Path.join(@help_dir, "cmd-autorespond.html"))
      },
      %{
        id: "cmd-away",
        title: "/away",
        category: "Commands",
        keywords: ["away", "afk", "absent", "back"],
        content: File.read!(Path.join(@help_dir, "cmd-away.html"))
      },
      %{
        id: "cmd-ban",
        title: "/ban",
        category: "Commands",
        keywords: ["ban", "block", "prohibit"],
        content: File.read!(Path.join(@help_dir, "cmd-ban.html"))
      },
      %{
        id: "cmd-bio",
        title: "/bio",
        category: "Commands",
        keywords: ["bio", "profile", "about me", "description"],
        content: File.read!(Path.join(@help_dir, "cmd-bio.html"))
      },
      %{
        id: "cmd-call",
        title: "/call",
        category: "Commands",
        keywords: ["call", "audio", "voice", "voice call", "p2p"],
        content: File.read!(Path.join(@help_dir, "cmd-call.html"))
      },
      %{
        id: "cmd-clear",
        title: "/clear",
        category: "Commands",
        keywords: ["clear", "clean", "wipe", "reset"],
        content: File.read!(Path.join(@help_dir, "cmd-clear.html"))
      },
      %{
        id: "cmd-cs",
        title: "/cs",
        category: "Commands",
        keywords: ["cs", "chanserv", "channel service", "register channel"],
        content: File.read!(Path.join(@help_dir, "cmd-cs.html"))
      },
      %{
        id: "cmd-ctcp",
        title: "/ctcp",
        category: "Commands",
        keywords: ["ctcp", "ping", "version", "time", "finger", "client-to-client"],
        content: File.read!(Path.join(@help_dir, "cmd-ctcp.html"))
      },
      %{
        id: "cmd-help",
        title: "/help",
        category: "Commands",
        keywords: ["help", "commands", "usage"],
        content: File.read!(Path.join(@help_dir, "cmd-help.html"))
      },
      %{
        id: "cmd-ignore",
        title: "/ignore",
        category: "Commands",
        keywords: ["ignore", "block", "silence", "mute", "filter", "hide"],
        content: File.read!(Path.join(@help_dir, "cmd-ignore.html"))
      },
      %{
        id: "cmd-invite",
        title: "/invite",
        category: "Commands",
        keywords: ["invite", "invite user", "channel invite", "invite-only", "auto-join"],
        content: File.read!(Path.join(@help_dir, "cmd-invite.html"))
      },
      %{
        id: "cmd-join",
        title: "/join",
        category: "Commands",
        keywords: ["join", "enter", "channel"],
        content: File.read!(Path.join(@help_dir, "cmd-join.html"))
      },
      %{
        id: "cmd-kick",
        title: "/kick",
        category: "Commands",
        keywords: ["kick", "remove", "eject"],
        content: File.read!(Path.join(@help_dir, "cmd-kick.html"))
      },
      %{
        id: "cmd-list",
        title: "/list",
        category: "Commands",
        keywords: ["list", "channels", "channel list", "browse"],
        content: File.read!(Path.join(@help_dir, "cmd-list.html"))
      },
      %{
        id: "cmd-me",
        title: "/me",
        category: "Commands",
        keywords: ["me", "action", "emote", "roleplay"],
        content: File.read!(Path.join(@help_dir, "cmd-me.html"))
      },
      %{
        id: "cmd-mode",
        title: "/mode",
        category: "Commands",
        keywords: ["mode", "channel mode", "set mode", "operator"],
        content: File.read!(Path.join(@help_dir, "cmd-mode.html"))
      },
      %{
        id: "cmd-msg",
        title: "/msg",
        category: "Commands",
        keywords: ["msg", "message", "private", "whisper", "pm"],
        content: File.read!(Path.join(@help_dir, "cmd-msg.html"))
      },
      %{
        id: "cmd-nick",
        title: "/nick",
        category: "Commands",
        keywords: ["nick", "nickname", "rename", "change name"],
        content: File.read!(Path.join(@help_dir, "cmd-nick.html"))
      },
      %{
        id: "cmd-notice",
        title: "/notice",
        category: "Commands",
        keywords: ["notice", "notification", "announce"],
        content: File.read!(Path.join(@help_dir, "cmd-notice.html"))
      },
      %{
        id: "cmd-notice-routing",
        title: "/notice_routing",
        category: "Commands",
        keywords: ["notice", "routing", "preference", "setting"],
        content: File.read!(Path.join(@help_dir, "cmd-notice-routing.html"))
      },
      %{
        id: "cmd-notify",
        title: "/notify",
        category: "Commands",
        keywords: ["notify", "buddy", "friend", "watch"],
        content: File.read!(Path.join(@help_dir, "cmd-notify.html"))
      },
      %{
        id: "cmd-ns",
        title: "/ns",
        category: "Commands",
        keywords: ["ns", "nickserv", "register", "identify"],
        content: File.read!(Path.join(@help_dir, "cmd-ns.html"))
      },
      %{
        id: "cmd-p2p",
        title: "/p2p",
        category: "Commands",
        keywords: ["p2p", "peer", "session", "direct", "peer-to-peer"],
        content: File.read!(Path.join(@help_dir, "cmd-p2p.html"))
      },
      %{
        id: "cmd-part",
        title: "/part",
        category: "Commands",
        keywords: ["part", "leave", "exit", "channel"],
        content: File.read!(Path.join(@help_dir, "cmd-part.html"))
      },
      %{
        id: "cmd-perform",
        title: "/perform",
        category: "Commands",
        keywords: ["perform", "auto", "on connect", "execute", "autorun"],
        content: File.read!(Path.join(@help_dir, "cmd-perform.html"))
      },
      %{
        id: "cmd-popups",
        title: "/popups",
        category: "Commands",
        keywords: ["popups", "popup", "context menu", "custom menu", "right-click"],
        content: File.read!(Path.join(@help_dir, "cmd-popups.html"))
      },
      %{
        id: "cmd-query",
        title: "/query",
        category: "Commands",
        keywords: ["query", "pm", "private", "open conversation"],
        content: File.read!(Path.join(@help_dir, "cmd-query.html"))
      },
      %{
        id: "cmd-quit",
        title: "/quit",
        category: "Commands",
        keywords: ["quit", "disconnect", "exit", "logout"],
        content: File.read!(Path.join(@help_dir, "cmd-quit.html"))
      },
      %{
        id: "cmd-sendfile",
        title: "/sendfile",
        category: "Commands",
        keywords: ["sendfile", "send", "file", "transfer", "p2p"],
        content: File.read!(Path.join(@help_dir, "cmd-sendfile.html"))
      },
      %{
        id: "cmd-timer",
        title: "/timer",
        category: "Commands",
        keywords: ["timer", "schedule", "delay", "repeat", "interval", "cron"],
        content: File.read!(Path.join(@help_dir, "cmd-timer.html"))
      },
      %{
        id: "cmd-topic",
        title: "/topic",
        category: "Commands",
        keywords: ["topic", "channel topic", "set topic"],
        content: File.read!(Path.join(@help_dir, "cmd-topic.html"))
      },
      %{
        id: "cmd-unban",
        title: "/unban",
        category: "Commands",
        keywords: ["unban", "remove ban", "lift ban", "pardon"],
        content: File.read!(Path.join(@help_dir, "cmd-unban.html"))
      },
      %{
        id: "cmd-unignore",
        title: "/unignore",
        category: "Commands",
        keywords: ["unignore", "unblock", "unmute", "unsilence"],
        content: File.read!(Path.join(@help_dir, "cmd-unignore.html"))
      },
      %{
        id: "cmd-whois",
        title: "/whois",
        category: "Commands",
        keywords: ["whois", "info", "user info", "lookup", "profile", "idle", "bio"],
        content: File.read!(Path.join(@help_dir, "cmd-whois.html"))
      },
      %{
        id: "cmd-whowas",
        title: "/whowas",
        category: "Commands",
        keywords: ["whowas", "recently", "disconnected", "last seen", "offline"],
        content: File.read!(Path.join(@help_dir, "cmd-whowas.html"))
      }
    ]
  end
end
