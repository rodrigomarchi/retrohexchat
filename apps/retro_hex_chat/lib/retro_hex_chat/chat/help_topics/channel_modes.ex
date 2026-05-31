defmodule RetroHexChat.Chat.HelpTopics.ChannelModes do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "channel-permissions",
        title: gettext("Channel Permissions"),
        category: gettext("Channel Modes"),
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
          gettext("access level"),
          "chanserv",
          "auto-grant"
        ],
        icon: :icon_role_operator,
        description:
          gettext(
            "Understand the channel permission hierarchy from owner to regular user and what each rank can do."
          )
      },
      %{
        id: "channel-modes-overview",
        title: gettext("Channel Modes Overview"),
        category: gettext("Channel Modes"),
        keywords: [
          "mode",
          gettext("channel mode"),
          "moderated",
          "invite",
          gettext("topic lock"),
          "key",
          "limit",
          "owner",
          "half-op",
          "secret",
          "private",
          gettext("no external"),
          gettext("strip colors"),
          "registered",
          "knock",
          "throttle"
        ],
        icon: :icon_tab_modes,
        description:
          gettext(
            "Overview of all channel modes including moderation, access control, and privacy settings."
          )
      },
      %{
        id: "mode-m",
        title: gettext("+m Moderated"),
        category: gettext("Channel Modes"),
        keywords: ["moderated", "mute", "silence"],
        icon: :icon_mute,
        description:
          gettext("Restrict speaking to voiced users and above in a moderated channel.")
      },
      %{
        id: "mode-i",
        title: gettext("+i Invite Only"),
        category: gettext("Channel Modes"),
        keywords: ["invite", gettext("invite only"), "restricted"],
        icon: :icon_dialog_invite,
        description: gettext("Restrict channel access to users who have been explicitly invited.")
      },
      %{
        id: "mode-t",
        title: gettext("+t Topic Lock"),
        category: gettext("Channel Modes"),
        keywords: [gettext("topic lock"), "topic", gettext("restrict topic")],
        icon: :icon_btn_set_topic,
        description: gettext("Restrict topic changes to half-operators and above.")
      },
      %{
        id: "mode-k",
        title: gettext("+k Channel Key"),
        category: gettext("Channel Modes"),
        keywords: ["key", "password", gettext("channel password")],
        icon: :icon_lock,
        description: gettext("Require a password to join the channel.")
      },
      %{
        id: "mode-l",
        title: gettext("+l User Limit"),
        category: gettext("Channel Modes"),
        keywords: ["limit", gettext("user limit"), gettext("max users"), "capacity"],
        icon: :icon_community,
        description: gettext("Set a maximum number of users that can be in the channel at once.")
      },
      %{
        id: "mode-q",
        title: gettext("+q Owner"),
        category: gettext("Channel Modes"),
        keywords: ["owner", gettext("channel owner"), "founder", "tilde"],
        icon: :icon_role_owner,
        description:
          gettext("Grant owner status to a user, giving them full control over the channel.")
      },
      %{
        id: "mode-o",
        title: gettext("+o Operator"),
        category: gettext("Channel Modes"),
        keywords: ["operator", "op", "admin", gettext("channel operator")],
        icon: :icon_role_operator,
        description:
          gettext("Grant operator status to a user, allowing them to manage the channel.")
      },
      %{
        id: "mode-h",
        title: gettext("+h Half-Operator"),
        category: gettext("Channel Modes"),
        keywords: ["half-operator", "halfop", gettext("half op"), "helper"],
        icon: :icon_role_halfop,
        description: gettext("Grant half-operator status with limited moderation privileges.")
      },
      %{
        id: "mode-v",
        title: gettext("+v Voice"),
        category: gettext("Channel Modes"),
        keywords: ["voice", "speak", gettext("moderated voice")],
        icon: :icon_role_voiced,
        description: gettext("Grant voice status to allow speaking in moderated channels.")
      },
      %{
        id: "mode-n",
        title: gettext("+n No External Messages"),
        category: gettext("Channel Modes"),
        keywords: [gettext("no external"), gettext("external messages"), gettext("members only")],
        icon: :icon_globe_blocked,
        description: gettext("Block messages from users who are not in the channel.")
      },
      %{
        id: "mode-s",
        title: gettext("+s Secret"),
        category: gettext("Channel Modes"),
        keywords: ["secret", "hidden", "invisible"],
        icon: :icon_privacy,
        description: gettext("Hide the channel from the channel list and whois results.")
      },
      %{
        id: "mode-p",
        title: gettext("+p Private"),
        category: gettext("Channel Modes"),
        keywords: ["private", "prv", gettext("hidden name")],
        icon: :icon_privacy,
        description:
          gettext("Hide the channel name from whois while still appearing in the channel list.")
      },
      %{
        id: "mode-c",
        title: gettext("+c Strip Colors"),
        category: gettext("Channel Modes"),
        keywords: [gettext("strip colors"), gettext("no colors"), "plain text", "formatting"],
        icon: :icon_palette,
        description:
          gettext("Strip all color and formatting codes from messages sent to the channel.")
      },
      %{
        id: "mode-r",
        title: gettext("+R Registered Only"),
        category: gettext("Channel Modes"),
        keywords: [gettext("registered only"), "identified", "nickserv", "auth"],
        icon: :icon_lock,
        description: gettext("Restrict the channel to users who have identified with NickServ.")
      },
      %{
        id: "mode-nk",
        title: gettext("+K No Knock"),
        category: gettext("Channel Modes"),
        keywords: [gettext("no knock"), gettext("disable knock"), gettext("block knock")],
        icon: :icon_ban,
        description: gettext("Prevent users from sending knock requests to the channel.")
      },
      %{
        id: "mode-j",
        title: gettext("+j Join Throttle"),
        category: gettext("Channel Modes"),
        keywords: [
          gettext("join throttle"),
          gettext("rate limit"),
          "flood",
          gettext("join limit")
        ],
        icon: :icon_dialog_flood,
        description:
          gettext("Limit how quickly users can join the channel to prevent join flooding.")
      },
      %{
        id: "cmd-knock",
        title: gettext("/knock Command"),
        category: gettext("Channels"),
        keywords: ["knock", gettext("request invite"), gettext("join request")],
        icon: :icon_megaphone,
        description: gettext("Request an invitation to join an invite-only channel.")
      }
    ]
  end
end
