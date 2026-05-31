defmodule RetroHexChat.Chat.HelpTopics.SpecialMessages do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "cmd-motd",
        title: "/motd",
        category: gettext("Server Messages"),
        keywords: ["motd", gettext("message of the day")],
        icon: :icon_notepad,
        description: gettext("View the server's Message of the Day.")
      },
      %{
        id: "cmd-setmotd",
        title: "/setmotd",
        category: gettext("Server Messages"),
        keywords: ["setmotd", "motd", gettext("set message of the day"), "admin"],
        icon: :icon_notepad,
        description:
          gettext("Set or update the server's Message of the Day. Requires admin privileges.")
      },
      %{
        id: "cmd-clearmotd",
        title: "/clearmotd",
        category: gettext("Server Messages"),
        keywords: ["clearmotd", "motd", gettext("clear message of the day"), "admin"],
        icon: :icon_trash,
        description: gettext("Remove the server's Message of the Day. Requires admin privileges.")
      },
      %{
        id: "cmd-setwelcome",
        title: "/setwelcome",
        category: gettext("Server Messages"),
        keywords: ["setwelcome", "welcome", gettext("channel welcome"), "greeting"],
        icon: :icon_megaphone,
        description:
          gettext("Set a welcome message displayed to users when they join your channel.")
      },
      %{
        id: "cmd-clearwelcome",
        title: "/clearwelcome",
        category: gettext("Server Messages"),
        keywords: ["clearwelcome", "welcome", gettext("clear welcome")],
        icon: :icon_trash,
        description: gettext("Remove the channel welcome message.")
      },
      %{
        id: "cmd-wallops",
        title: "/wallops",
        category: gettext("Server Messages"),
        keywords: ["wallops", gettext("operator broadcast"), gettext("server message")],
        icon: :icon_megaphone,
        description:
          gettext("Send a broadcast message to all users who have wallops mode enabled.")
      },
      %{
        id: "cmd-announce",
        title: "/announce",
        category: gettext("Server Messages"),
        keywords: ["announce", "announcement", "global", "broadcast", "admin"],
        icon: :icon_megaphone,
        description:
          gettext("Send a global announcement to all connected users. Requires admin privileges.")
      },
      %{
        id: "cmd-umode",
        title: "/umode",
        category: gettext("Channels"),
        keywords: ["umode", gettext("user mode"), "wallops", "mode"],
        icon: :icon_tab_modes,
        description:
          gettext("View or change your user modes, such as enabling wallops reception.")
      },
      %{
        id: "feature-special-messages",
        title: gettext("Special Messages"),
        category: gettext("Server Messages"),
        keywords: [
          "motd",
          "welcome",
          "wallops",
          "announce",
          "announcement",
          gettext("special messages"),
          gettext("server messages")
        ],
        icon: :icon_megaphone,
        description:
          gettext(
            "Overview of special message types including MOTD, welcome messages, wallops, and announcements."
          )
      }
    ]
  end
end
