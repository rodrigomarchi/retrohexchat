defmodule RetroHexChat.Chat.HelpTopics.SpecialMessages do
  @moduledoc false

  @help_dir Path.join(:code.priv_dir(:retro_hex_chat), "help")

  @external_resource Path.join(@help_dir, "cmd-motd.html")
  @external_resource Path.join(@help_dir, "cmd-setmotd.html")
  @external_resource Path.join(@help_dir, "cmd-clearmotd.html")
  @external_resource Path.join(@help_dir, "cmd-setwelcome.html")
  @external_resource Path.join(@help_dir, "cmd-clearwelcome.html")
  @external_resource Path.join(@help_dir, "cmd-wallops.html")
  @external_resource Path.join(@help_dir, "cmd-announce.html")
  @external_resource Path.join(@help_dir, "cmd-umode.html")
  @external_resource Path.join(@help_dir, "feature-special-messages.html")

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "cmd-motd",
        title: "/motd",
        category: "Commands",
        keywords: ["motd", "message of the day"],
        content: File.read!(Path.join(@help_dir, "cmd-motd.html"))
      },
      %{
        id: "cmd-setmotd",
        title: "/setmotd",
        category: "Commands",
        keywords: ["setmotd", "motd", "set message of the day", "admin"],
        content: File.read!(Path.join(@help_dir, "cmd-setmotd.html"))
      },
      %{
        id: "cmd-clearmotd",
        title: "/clearmotd",
        category: "Commands",
        keywords: ["clearmotd", "motd", "clear message of the day", "admin"],
        content: File.read!(Path.join(@help_dir, "cmd-clearmotd.html"))
      },
      %{
        id: "cmd-setwelcome",
        title: "/setwelcome",
        category: "Commands",
        keywords: ["setwelcome", "welcome", "channel welcome", "greeting"],
        content: File.read!(Path.join(@help_dir, "cmd-setwelcome.html"))
      },
      %{
        id: "cmd-clearwelcome",
        title: "/clearwelcome",
        category: "Commands",
        keywords: ["clearwelcome", "welcome", "clear welcome"],
        content: File.read!(Path.join(@help_dir, "cmd-clearwelcome.html"))
      },
      %{
        id: "cmd-wallops",
        title: "/wallops",
        category: "Commands",
        keywords: ["wallops", "operator broadcast", "server message"],
        content: File.read!(Path.join(@help_dir, "cmd-wallops.html"))
      },
      %{
        id: "cmd-announce",
        title: "/announce",
        category: "Commands",
        keywords: ["announce", "announcement", "global", "broadcast", "admin"],
        content: File.read!(Path.join(@help_dir, "cmd-announce.html"))
      },
      %{
        id: "cmd-umode",
        title: "/umode",
        category: "Commands",
        keywords: ["umode", "user mode", "wallops", "mode"],
        content: File.read!(Path.join(@help_dir, "cmd-umode.html"))
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
        content: File.read!(Path.join(@help_dir, "feature-special-messages.html"))
      }
    ]
  end
end
