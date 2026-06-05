defmodule RetroHexChat.Chat.HelpTopics.ChannelModes do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "channel-permissions",
        title: dgettext("help", "Channel Permissions"),
        category: dgettext("help", "Channel Modes"),
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
          dgettext("help", "access level"),
          "chanserv",
          "auto-grant"
        ],
        icon: :icon_role_operator,
        description:
          dgettext(
            "help",
            "Understand the channel permission hierarchy from owner to regular user and what each rank can do."
          )
      },
      %{
        id: "channel-modes-overview",
        title: dgettext("help", "Channel Modes Overview"),
        category: dgettext("help", "Channel Modes"),
        keywords: [
          "mode",
          dgettext("help", "channel mode"),
          "moderated",
          "invite",
          dgettext("help", "topic lock"),
          "key",
          "limit",
          "owner",
          "half-op",
          "secret",
          "private",
          dgettext("help", "no external"),
          dgettext("help", "strip colors"),
          "registered",
          "knock",
          "throttle"
        ],
        icon: :icon_tab_modes,
        description:
          dgettext(
            "help",
            "Overview of all channel modes including moderation, access control, and privacy settings."
          )
      },
      %{
        id: "mode-m",
        title: dgettext("help", "+m Moderated"),
        category: dgettext("help", "Channel Modes"),
        keywords: ["moderated", "mute", "silence"],
        icon: :icon_mute,
        description:
          dgettext("help", "Restrict speaking to voiced users and above in a moderated channel.")
      },
      %{
        id: "mode-i",
        title: dgettext("help", "+i Invite Only"),
        category: dgettext("help", "Channel Modes"),
        keywords: [
          "invite",
          dgettext("help", "invite only"),
          "restricted",
          "knock",
          dgettext("help", "request access"),
          dgettext("help", "channel list")
        ],
        icon: :icon_dialog_invite,
        description:
          dgettext(
            "help",
            "Restrict channel access to invited users; non-members can request access from Channel List."
          )
      },
      %{
        id: "mode-t",
        title: dgettext("help", "+t Topic Lock"),
        category: dgettext("help", "Channel Modes"),
        keywords: [dgettext("help", "topic lock"), "topic", dgettext("help", "restrict topic")],
        icon: :icon_btn_set_topic,
        description: dgettext("help", "Restrict topic changes to half-operators and above.")
      },
      %{
        id: "mode-k",
        title: dgettext("help", "+k Channel Key"),
        category: dgettext("help", "Channel Modes"),
        keywords: ["key", "password", dgettext("help", "channel password")],
        icon: :icon_lock,
        description: dgettext("help", "Require a password to join the channel.")
      },
      %{
        id: "mode-l",
        title: dgettext("help", "+l User Limit"),
        category: dgettext("help", "Channel Modes"),
        keywords: [
          "limit",
          dgettext("help", "user limit"),
          dgettext("help", "max users"),
          "capacity"
        ],
        icon: :icon_community,
        description:
          dgettext("help", "Set a maximum number of users that can be in the channel at once.")
      },
      %{
        id: "mode-q",
        title: dgettext("help", "+q Owner"),
        category: dgettext("help", "Channel Modes"),
        keywords: ["owner", dgettext("help", "channel owner"), "founder", "tilde"],
        icon: :icon_role_owner,
        description:
          dgettext(
            "help",
            "Grant owner status to a user, giving them full control over the channel."
          )
      },
      %{
        id: "mode-o",
        title: dgettext("help", "+o Operator"),
        category: dgettext("help", "Channel Modes"),
        keywords: ["operator", "op", "admin", dgettext("help", "channel operator")],
        icon: :icon_role_operator,
        description:
          dgettext(
            "help",
            "Grant operator status to a user, allowing them to manage the channel."
          )
      },
      %{
        id: "mode-h",
        title: dgettext("help", "+h Half-Operator"),
        category: dgettext("help", "Channel Modes"),
        keywords: ["half-operator", "halfop", dgettext("help", "half op"), "helper"],
        icon: :icon_role_halfop,
        description:
          dgettext("help", "Grant half-operator status with limited moderation privileges.")
      },
      %{
        id: "mode-v",
        title: dgettext("help", "+v Voice"),
        category: dgettext("help", "Channel Modes"),
        keywords: ["voice", "speak", dgettext("help", "moderated voice")],
        icon: :icon_role_voiced,
        description:
          dgettext("help", "Grant voice status to allow speaking in moderated channels.")
      },
      %{
        id: "mode-n",
        title: dgettext("help", "+n No External Messages"),
        category: dgettext("help", "Channel Modes"),
        keywords: [
          dgettext("help", "no external"),
          dgettext("help", "external messages"),
          dgettext("help", "members only")
        ],
        icon: :icon_globe_blocked,
        description: dgettext("help", "Block messages from users who are not in the channel.")
      },
      %{
        id: "mode-s",
        title: dgettext("help", "+s Secret"),
        category: dgettext("help", "Channel Modes"),
        keywords: ["secret", "hidden", "invisible"],
        icon: :icon_privacy,
        description: dgettext("help", "Hide the channel from the channel list and whois results.")
      },
      %{
        id: "mode-p",
        title: dgettext("help", "+p Private"),
        category: dgettext("help", "Channel Modes"),
        keywords: ["private", "prv", dgettext("help", "hidden name")],
        icon: :icon_privacy,
        description:
          dgettext(
            "help",
            "Hide the channel name from whois while still appearing in the channel list."
          )
      },
      %{
        id: "mode-c",
        title: dgettext("help", "+c Strip Colors"),
        category: dgettext("help", "Channel Modes"),
        keywords: [
          dgettext("help", "strip colors"),
          dgettext("help", "no colors"),
          "plain text",
          "formatting"
        ],
        icon: :icon_palette,
        description:
          dgettext(
            "help",
            "Strip all color and formatting codes from messages sent to the channel."
          )
      },
      %{
        id: "mode-r",
        title: dgettext("help", "+R Registered Only"),
        category: dgettext("help", "Channel Modes"),
        keywords: [dgettext("help", "registered only"), "identified", "nickserv", "auth"],
        icon: :icon_lock,
        description:
          dgettext("help", "Restrict the channel to users who have identified with NickServ.")
      },
      %{
        id: "mode-nk",
        title: dgettext("help", "+K No Knock"),
        category: dgettext("help", "Channel Modes"),
        keywords: [
          dgettext("help", "no knock"),
          dgettext("help", "disable knock"),
          dgettext("help", "block knock")
        ],
        icon: :icon_ban,
        description: dgettext("help", "Prevent users from sending knock requests to the channel.")
      },
      %{
        id: "mode-j",
        title: dgettext("help", "+j Join Throttle"),
        category: dgettext("help", "Channel Modes"),
        keywords: [
          dgettext("help", "join throttle"),
          dgettext("help", "rate limit"),
          "flood",
          dgettext("help", "join limit")
        ],
        icon: :icon_dialog_flood,
        description:
          dgettext(
            "help",
            "Limit how quickly users can join the channel to prevent join flooding."
          )
      },
      %{
        id: "cmd-knock",
        title: dgettext("help", "/knock Command"),
        category: dgettext("help", "Channels"),
        keywords: [
          "knock",
          dgettext("help", "request invite"),
          dgettext("help", "join request"),
          dgettext("help", "request access"),
          dgettext("help", "channel list"),
          "invite-only",
          "+i"
        ],
        icon: :icon_megaphone,
        description: dgettext("help", "Request an invitation to join an invite-only channel.")
      }
    ]
  end
end
