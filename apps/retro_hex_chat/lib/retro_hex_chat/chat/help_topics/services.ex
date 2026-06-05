defmodule RetroHexChat.Chat.HelpTopics.Services do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "nickserv",
        title: dgettext("help", "NickServ Overview"),
        category: dgettext("help", "Services & Protocols"),
        keywords: [
          "nickserv",
          "register",
          "identify",
          "account",
          "login",
          "ghost",
          "drop",
          "unregister",
          "away",
          "bio",
          "password",
          dgettext("help", "nickname protection")
        ],
        icon: :icon_lock,
        description:
          dgettext(
            "help",
            "Register and protect your nickname with NickServ to prevent others from using it."
          )
      },
      %{
        id: "chanserv",
        title: dgettext("help", "ChanServ Overview"),
        category: dgettext("help", "Services & Protocols"),
        keywords: [
          "chanserv",
          "cs register",
          "cs drop",
          "sop",
          "aop",
          "vop",
          "registration tab",
          dgettext("help", "channel service"),
          dgettext("help", "register channel"),
          dgettext("help", "access list"),
          dgettext("help", "channel expiration"),
          dgettext("help", "channel expiry")
        ],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "Register and manage channels with ChanServ, including access lists and channel settings."
          ),
        see_also: ["chanserv-register", "chanserv-access", "chanserv-ui", "cmd-cs"]
      },
      %{
        id: "chanserv-register",
        title: dgettext("help", "ChanServ Channel Registration"),
        category: dgettext("help", "Services & Protocols"),
        keywords: [
          "chanserv",
          "cs register",
          "cs drop",
          "cs info",
          "channel registration",
          "founder",
          "registration tab"
        ],
        icon: :icon_tab_registration,
        description:
          dgettext(
            "help",
            "Register, inspect, and drop the current channel through ChanServ commands or Channel Central."
          ),
        see_also: ["chanserv", "chanserv-access", "chanserv-ui", "cmd-cs"]
      },
      %{
        id: "chanserv-access",
        title: dgettext("help", "ChanServ Access Lists"),
        category: dgettext("help", "Services & Protocols"),
        keywords: [
          "chanserv",
          "access list",
          "sop",
          "aop",
          "vop",
          "auto operator",
          "auto voice",
          "registration tab"
        ],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "Manage SOP, AOP, and VOP access lists for registered channels."
          ),
        see_also: ["chanserv", "chanserv-register", "chanserv-ui", "cmd-cs"]
      },
      %{
        id: "chanserv-ui",
        title: dgettext("help", "ChanServ in Channel Central"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "chanserv",
          "registration tab",
          "channel central",
          "access lists",
          "sop",
          "aop",
          "vop"
        ],
        icon: :icon_dialog_channel_central,
        description:
          dgettext(
            "help",
            "Use Channel Central's Registration tab to register channels and manage access lists without typing commands."
          ),
        see_also: ["feature-channel-central", "chanserv", "chanserv-register", "chanserv-access"]
      }
    ]
  end
end
