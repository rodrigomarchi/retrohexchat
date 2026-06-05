defmodule RetroHexChat.Chat.HelpTopics.GettingStarted do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "welcome",
        title: dgettext("help", "Welcome to RetroHexChat"),
        category: dgettext("help", "Getting Started"),
        keywords: ["welcome", "introduction", "about", "overview"],
        icon: :icon_lightbulb,
        description:
          dgettext(
            "help",
            "Get started with RetroHexChat, a web-based IRC client with a faithful retro look and feel."
          )
      },
      %{
        id: "connecting",
        title: dgettext("help", "Connecting"),
        category: dgettext("help", "Getting Started"),
        keywords: ["connect", "login", "nickname", "join"],
        icon: :icon_connect,
        description:
          dgettext(
            "help",
            "Learn how to connect to the RetroHexChat server by choosing a nickname and joining channels."
          )
      },
      %{
        id: "channels",
        title: dgettext("help", "Channels"),
        category: dgettext("help", "Getting Started"),
        keywords: [
          "channel",
          "room",
          dgettext("help", "chat room"),
          dgettext("help", "join channel")
        ],
        icon: :icon_channels,
        description:
          dgettext(
            "help",
            "Understand how chat channels work, including joining, leaving, and participating in conversations."
          )
      },
      %{
        id: "private-messages",
        title: dgettext("help", "Private Messages"),
        category: dgettext("help", "Getting Started"),
        keywords: [
          "pm",
          "private message",
          dgettext("help", "direct message"),
          "dm",
          "whisper",
          "query",
          "notice"
        ],
        icon: :icon_p2p,
        description:
          dgettext(
            "help",
            "Send and receive private messages with other users using the /msg and /query commands."
          )
      },
      %{
        id: "connect-authentication",
        title: dgettext("help", "Connect Authentication"),
        category: dgettext("help", "Getting Started"),
        keywords: ["authentication", "login", "password", "registered", "identify"],
        icon: :icon_lock,
        description:
          dgettext(
            "help",
            "Authenticate with your registered nickname on connect to access your saved settings and channels."
          )
      }
    ]
  end
end
