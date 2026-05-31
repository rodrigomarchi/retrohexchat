defmodule RetroHexChat.Chat.HelpTopics.GettingStarted do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "welcome",
        title: gettext("Welcome to RetroHexChat"),
        category: gettext("Getting Started"),
        keywords: ["welcome", "introduction", "about", "overview"],
        icon: :icon_lightbulb,
        description:
          gettext(
            "Get started with RetroHexChat, a web-based IRC client with a faithful retro look and feel."
          )
      },
      %{
        id: "connecting",
        title: gettext("Connecting"),
        category: gettext("Getting Started"),
        keywords: ["connect", "login", "nickname", "join"],
        icon: :icon_connect,
        description:
          gettext(
            "Learn how to connect to the RetroHexChat server by choosing a nickname and joining channels."
          )
      },
      %{
        id: "channels",
        title: gettext("Channels"),
        category: gettext("Getting Started"),
        keywords: ["channel", "room", gettext("chat room"), gettext("join channel")],
        icon: :icon_channels,
        description:
          gettext(
            "Understand how chat channels work, including joining, leaving, and participating in conversations."
          )
      },
      %{
        id: "private-messages",
        title: gettext("Private Messages"),
        category: gettext("Getting Started"),
        keywords: ["pm", "private message", gettext("direct message"), "dm", "whisper", "query"],
        icon: :icon_p2p,
        description:
          gettext(
            "Send and receive private messages with other users using the /msg and /query commands."
          )
      },
      %{
        id: "connect-authentication",
        title: gettext("Connect Authentication"),
        category: gettext("Getting Started"),
        keywords: ["authentication", "login", "password", "registered", "identify"],
        icon: :icon_lock,
        description:
          gettext(
            "Authenticate with your registered nickname on connect to access your saved settings and channels."
          )
      }
    ]
  end
end
