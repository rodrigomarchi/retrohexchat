defmodule RetroHexChat.Chat.HelpTopics.SpecialMessages do
  @moduledoc false

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "cmd-motd",
        title: "/motd",
        category: "Commands",
        keywords: ["motd", "message of the day"],
        icon: :icon_notepad,
        description: "View the server's Message of the Day."
      },
      %{
        id: "cmd-setmotd",
        title: "/setmotd",
        category: "Commands",
        keywords: ["setmotd", "motd", "set message of the day", "admin"],
        icon: :icon_notepad,
        description: "Set or update the server's Message of the Day. Requires admin privileges."
      },
      %{
        id: "cmd-clearmotd",
        title: "/clearmotd",
        category: "Commands",
        keywords: ["clearmotd", "motd", "clear message of the day", "admin"],
        icon: :icon_trash,
        description: "Remove the server's Message of the Day. Requires admin privileges."
      },
      %{
        id: "cmd-setwelcome",
        title: "/setwelcome",
        category: "Commands",
        keywords: ["setwelcome", "welcome", "channel welcome", "greeting"],
        icon: :icon_megaphone,
        description: "Set a welcome message displayed to users when they join your channel."
      },
      %{
        id: "cmd-clearwelcome",
        title: "/clearwelcome",
        category: "Commands",
        keywords: ["clearwelcome", "welcome", "clear welcome"],
        icon: :icon_trash,
        description: "Remove the channel welcome message."
      },
      %{
        id: "cmd-wallops",
        title: "/wallops",
        category: "Commands",
        keywords: ["wallops", "operator broadcast", "server message"],
        icon: :icon_megaphone,
        description: "Send a broadcast message to all users who have wallops mode enabled."
      },
      %{
        id: "cmd-announce",
        title: "/announce",
        category: "Commands",
        keywords: ["announce", "announcement", "global", "broadcast", "admin"],
        icon: :icon_megaphone,
        description:
          "Send a global announcement to all connected users. Requires admin privileges."
      },
      %{
        id: "cmd-umode",
        title: "/umode",
        category: "Commands",
        keywords: ["umode", "user mode", "wallops", "mode"],
        icon: :icon_tab_modes,
        description: "View or change your user modes, such as enabling wallops reception."
      },
      %{
        id: "feature-special-messages",
        title: "Special Messages",
        category: "Features",
        keywords: [
          "motd",
          "welcome",
          "wallops",
          "announce",
          "announcement",
          "special messages",
          "server messages"
        ],
        icon: :icon_megaphone,
        description:
          "Overview of special message types including MOTD, welcome messages, wallops, and announcements."
      }
    ]
  end
end
