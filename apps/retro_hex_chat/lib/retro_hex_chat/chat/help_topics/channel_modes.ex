defmodule RetroHexChat.Chat.HelpTopics.ChannelModes do
  @moduledoc false

  @help_dir Path.join(:code.priv_dir(:retro_hex_chat), "help")

  @external_resource Path.join(@help_dir, "channel-modes-overview.html")
  @external_resource Path.join(@help_dir, "mode-m.html")
  @external_resource Path.join(@help_dir, "mode-i.html")
  @external_resource Path.join(@help_dir, "mode-t.html")
  @external_resource Path.join(@help_dir, "mode-k.html")
  @external_resource Path.join(@help_dir, "mode-l.html")
  @external_resource Path.join(@help_dir, "mode-q.html")
  @external_resource Path.join(@help_dir, "mode-o.html")
  @external_resource Path.join(@help_dir, "mode-h.html")
  @external_resource Path.join(@help_dir, "mode-v.html")
  @external_resource Path.join(@help_dir, "mode-n.html")
  @external_resource Path.join(@help_dir, "mode-s.html")
  @external_resource Path.join(@help_dir, "mode-p.html")
  @external_resource Path.join(@help_dir, "mode-c.html")
  @external_resource Path.join(@help_dir, "mode-R.html")
  @external_resource Path.join(@help_dir, "mode-K.html")
  @external_resource Path.join(@help_dir, "mode-j.html")
  @external_resource Path.join(@help_dir, "cmd-knock.html")

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "channel-modes-overview",
        title: "Channel Modes Overview",
        category: "Channel Modes",
        keywords: [
          "mode",
          "channel mode",
          "moderated",
          "invite",
          "topic lock",
          "key",
          "limit",
          "owner",
          "half-op",
          "secret",
          "private",
          "no external",
          "strip colors",
          "registered",
          "knock",
          "throttle"
        ],
        content: File.read!(Path.join(@help_dir, "channel-modes-overview.html"))
      },
      %{
        id: "mode-m",
        title: "+m Moderated",
        category: "Channel Modes",
        keywords: ["moderated", "mute", "silence"],
        content: File.read!(Path.join(@help_dir, "mode-m.html"))
      },
      %{
        id: "mode-i",
        title: "+i Invite Only",
        category: "Channel Modes",
        keywords: ["invite", "invite only", "restricted"],
        content: File.read!(Path.join(@help_dir, "mode-i.html"))
      },
      %{
        id: "mode-t",
        title: "+t Topic Lock",
        category: "Channel Modes",
        keywords: ["topic lock", "topic", "restrict topic"],
        content: File.read!(Path.join(@help_dir, "mode-t.html"))
      },
      %{
        id: "mode-k",
        title: "+k Channel Key",
        category: "Channel Modes",
        keywords: ["key", "password", "channel password"],
        content: File.read!(Path.join(@help_dir, "mode-k.html"))
      },
      %{
        id: "mode-l",
        title: "+l User Limit",
        category: "Channel Modes",
        keywords: ["limit", "user limit", "max users", "capacity"],
        content: File.read!(Path.join(@help_dir, "mode-l.html"))
      },
      %{
        id: "mode-q",
        title: "+q Owner",
        category: "Channel Modes",
        keywords: ["owner", "channel owner", "founder", "tilde"],
        content: File.read!(Path.join(@help_dir, "mode-q.html"))
      },
      %{
        id: "mode-o",
        title: "+o Operator",
        category: "Channel Modes",
        keywords: ["operator", "op", "admin", "channel operator"],
        content: File.read!(Path.join(@help_dir, "mode-o.html"))
      },
      %{
        id: "mode-h",
        title: "+h Half-Operator",
        category: "Channel Modes",
        keywords: ["half-operator", "halfop", "half op", "helper"],
        content: File.read!(Path.join(@help_dir, "mode-h.html"))
      },
      %{
        id: "mode-v",
        title: "+v Voice",
        category: "Channel Modes",
        keywords: ["voice", "speak", "moderated voice"],
        content: File.read!(Path.join(@help_dir, "mode-v.html"))
      },
      %{
        id: "mode-n",
        title: "+n No External Messages",
        category: "Channel Modes",
        keywords: ["no external", "external messages", "members only"],
        content: File.read!(Path.join(@help_dir, "mode-n.html"))
      },
      %{
        id: "mode-s",
        title: "+s Secret",
        category: "Channel Modes",
        keywords: ["secret", "hidden", "invisible"],
        content: File.read!(Path.join(@help_dir, "mode-s.html"))
      },
      %{
        id: "mode-p",
        title: "+p Private",
        category: "Channel Modes",
        keywords: ["private", "prv", "hidden name"],
        content: File.read!(Path.join(@help_dir, "mode-p.html"))
      },
      %{
        id: "mode-c",
        title: "+c Strip Colors",
        category: "Channel Modes",
        keywords: ["strip colors", "no colors", "plain text", "formatting"],
        content: File.read!(Path.join(@help_dir, "mode-c.html"))
      },
      %{
        id: "mode-R",
        title: "+R Registered Only",
        category: "Channel Modes",
        keywords: ["registered only", "identified", "nickserv", "auth"],
        content: File.read!(Path.join(@help_dir, "mode-R.html"))
      },
      %{
        id: "mode-K",
        title: "+K No Knock",
        category: "Channel Modes",
        keywords: ["no knock", "disable knock", "block knock"],
        content: File.read!(Path.join(@help_dir, "mode-K.html"))
      },
      %{
        id: "mode-j",
        title: "+j Join Throttle",
        category: "Channel Modes",
        keywords: ["join throttle", "rate limit", "flood", "join limit"],
        content: File.read!(Path.join(@help_dir, "mode-j.html"))
      },
      %{
        id: "cmd-knock",
        title: "/knock Command",
        category: "Commands",
        keywords: ["knock", "request invite", "join request"],
        content: File.read!(Path.join(@help_dir, "cmd-knock.html"))
      }
    ]
  end
end
