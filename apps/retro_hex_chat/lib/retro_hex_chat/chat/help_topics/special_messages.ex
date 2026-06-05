defmodule RetroHexChat.Chat.HelpTopics.SpecialMessages do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "cmd-motd",
        title: "/motd",
        category: dgettext("help", "Server Messages"),
        keywords: ["motd", "Help menu", "show_motd", dgettext("help", "message of the day")],
        icon: :icon_notepad,
        description: dgettext("help", "View the server's Message of the Day."),
        see_also: ["ui-message-of-the-day", "feature-special-messages", "cmd-setmotd"]
      },
      %{
        id: "cmd-setmotd",
        title: "/setmotd",
        category: dgettext("help", "Server Messages"),
        keywords: ["setmotd", "motd", dgettext("help", "set message of the day"), "admin"],
        icon: :icon_notepad,
        description:
          dgettext(
            "help",
            "Set or update the server's Message of the Day. Requires admin privileges."
          ),
        see_also: ["cmd-motd", "cmd-clearmotd", "ui-message-of-the-day"]
      },
      %{
        id: "cmd-clearmotd",
        title: "/clearmotd",
        category: dgettext("help", "Server Messages"),
        keywords: ["clearmotd", "motd", dgettext("help", "clear message of the day"), "admin"],
        icon: :icon_trash,
        description:
          dgettext("help", "Remove the server's Message of the Day. Requires admin privileges."),
        see_also: ["cmd-motd", "cmd-setmotd", "ui-message-of-the-day"]
      },
      %{
        id: "cmd-setwelcome",
        title: "/setwelcome",
        category: dgettext("help", "Server Messages"),
        keywords: ["setwelcome", "welcome", dgettext("help", "channel welcome"), "greeting"],
        icon: :icon_megaphone,
        description:
          dgettext(
            "help",
            "Set a welcome message displayed to users when they join your channel."
          )
      },
      %{
        id: "cmd-clearwelcome",
        title: "/clearwelcome",
        category: dgettext("help", "Server Messages"),
        keywords: ["clearwelcome", "welcome", dgettext("help", "clear welcome")],
        icon: :icon_trash,
        description: dgettext("help", "Remove the channel welcome message.")
      },
      %{
        id: "cmd-wallops",
        title: "/wallops",
        category: dgettext("help", "Server Messages"),
        keywords: [
          "wallops",
          dgettext("help", "operator broadcast"),
          dgettext("help", "server message")
        ],
        icon: :icon_megaphone,
        description:
          dgettext("help", "Send a broadcast message to all users who have wallops mode enabled.")
      },
      %{
        id: "cmd-announce",
        title: "/announce",
        category: dgettext("help", "Server Messages"),
        keywords: ["announce", "announcement", "global", "broadcast", "admin"],
        icon: :icon_megaphone,
        description:
          dgettext(
            "help",
            "Send a global announcement to all connected users. Requires admin privileges."
          )
      },
      %{
        id: "cmd-umode",
        title: "/umode",
        category: dgettext("help", "Channels"),
        keywords: ["umode", dgettext("help", "user mode"), "wallops", "mode", "account"],
        icon: :icon_tab_modes,
        description:
          dgettext("help", "View or change your user modes, such as enabling wallops reception.")
      },
      %{
        id: "feature-special-messages",
        title: dgettext("help", "Special Messages"),
        category: dgettext("help", "Server Messages"),
        keywords: [
          "motd",
          "welcome",
          "wallops",
          "announce",
          "announcement",
          dgettext("help", "special messages"),
          dgettext("help", "server messages")
        ],
        icon: :icon_megaphone,
        description:
          dgettext(
            "help",
            "Overview of special message types including MOTD, welcome messages, wallops, and announcements."
          ),
        see_also: ["ui-message-of-the-day", "cmd-motd", "cmd-wallops", "cmd-announce"]
      }
    ]
  end
end
