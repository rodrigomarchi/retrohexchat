defmodule RetroHexChat.Chat.HelpTopics.ChannelModes do
  @moduledoc false

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "channel-permissions",
        title: "Channel Permissions",
        category: "Channel Modes",
        keywords: [
          "permissions",
          "rank",
          "hierarchy",
          "owner",
          "operator",
          "half-operator",
          "voiced",
          "kick",
          "ban",
          "privileges",
          "access level",
          "chanserv",
          "auto-grant"
        ],
        icon: :icon_role_operator,
        description:
          "Understand the channel permission hierarchy from owner to regular user and what each rank can do."
      },
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
        icon: :icon_tab_modes,
        description:
          "Overview of all channel modes including moderation, access control, and privacy settings."
      },
      %{
        id: "mode-m",
        title: "+m Moderated",
        category: "Channel Modes",
        keywords: ["moderated", "mute", "silence"],
        icon: :icon_mute,
        description: "Restrict speaking to voiced users and above in a moderated channel."
      },
      %{
        id: "mode-i",
        title: "+i Invite Only",
        category: "Channel Modes",
        keywords: ["invite", "invite only", "restricted"],
        icon: :icon_dialog_invite,
        description: "Restrict channel access to users who have been explicitly invited."
      },
      %{
        id: "mode-t",
        title: "+t Topic Lock",
        category: "Channel Modes",
        keywords: ["topic lock", "topic", "restrict topic"],
        icon: :icon_btn_set_topic,
        description: "Restrict topic changes to half-operators and above."
      },
      %{
        id: "mode-k",
        title: "+k Channel Key",
        category: "Channel Modes",
        keywords: ["key", "password", "channel password"],
        icon: :icon_lock,
        description: "Require a password to join the channel."
      },
      %{
        id: "mode-l",
        title: "+l User Limit",
        category: "Channel Modes",
        keywords: ["limit", "user limit", "max users", "capacity"],
        icon: :icon_community,
        description: "Set a maximum number of users that can be in the channel at once."
      },
      %{
        id: "mode-q",
        title: "+q Owner",
        category: "Channel Modes",
        keywords: ["owner", "channel owner", "founder", "tilde"],
        icon: :icon_role_owner,
        description: "Grant owner status to a user, giving them full control over the channel."
      },
      %{
        id: "mode-o",
        title: "+o Operator",
        category: "Channel Modes",
        keywords: ["operator", "op", "admin", "channel operator"],
        icon: :icon_role_operator,
        description: "Grant operator status to a user, allowing them to manage the channel."
      },
      %{
        id: "mode-h",
        title: "+h Half-Operator",
        category: "Channel Modes",
        keywords: ["half-operator", "halfop", "half op", "helper"],
        icon: :icon_role_halfop,
        description: "Grant half-operator status with limited moderation privileges."
      },
      %{
        id: "mode-v",
        title: "+v Voice",
        category: "Channel Modes",
        keywords: ["voice", "speak", "moderated voice"],
        icon: :icon_role_voiced,
        description: "Grant voice status to allow speaking in moderated channels."
      },
      %{
        id: "mode-n",
        title: "+n No External Messages",
        category: "Channel Modes",
        keywords: ["no external", "external messages", "members only"],
        icon: :icon_globe_blocked,
        description: "Block messages from users who are not in the channel."
      },
      %{
        id: "mode-s",
        title: "+s Secret",
        category: "Channel Modes",
        keywords: ["secret", "hidden", "invisible"],
        icon: :icon_privacy,
        description: "Hide the channel from the channel list and whois results."
      },
      %{
        id: "mode-p",
        title: "+p Private",
        category: "Channel Modes",
        keywords: ["private", "prv", "hidden name"],
        icon: :icon_privacy,
        description: "Hide the channel name from whois while still appearing in the channel list."
      },
      %{
        id: "mode-c",
        title: "+c Strip Colors",
        category: "Channel Modes",
        keywords: ["strip colors", "no colors", "plain text", "formatting"],
        icon: :icon_palette,
        description: "Strip all color and formatting codes from messages sent to the channel."
      },
      %{
        id: "mode-R",
        title: "+R Registered Only",
        category: "Channel Modes",
        keywords: ["registered only", "identified", "nickserv", "auth"],
        icon: :icon_lock,
        description: "Restrict the channel to users who have identified with NickServ."
      },
      %{
        id: "mode-K",
        title: "+K No Knock",
        category: "Channel Modes",
        keywords: ["no knock", "disable knock", "block knock"],
        icon: :icon_ban,
        description: "Prevent users from sending knock requests to the channel."
      },
      %{
        id: "mode-j",
        title: "+j Join Throttle",
        category: "Channel Modes",
        keywords: ["join throttle", "rate limit", "flood", "join limit"],
        icon: :icon_dialog_flood,
        description: "Limit how quickly users can join the channel to prevent join flooding."
      },
      %{
        id: "cmd-knock",
        title: "/knock Command",
        category: "Commands",
        keywords: ["knock", "request invite", "join request"],
        icon: :icon_megaphone,
        description: "Request an invitation to join an invite-only channel."
      }
    ]
  end
end
