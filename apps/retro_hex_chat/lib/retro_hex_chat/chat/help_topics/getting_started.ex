defmodule RetroHexChat.Chat.HelpTopics.GettingStarted do
  @moduledoc false

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "welcome",
        title: "Welcome to RetroHexChat",
        category: "Getting Started",
        keywords: ["welcome", "introduction", "about", "overview"],
        icon: :icon_lightbulb,
        description:
          "Get started with RetroHexChat, a web-based IRC client with an authentic Windows 98 look and feel."
      },
      %{
        id: "connecting",
        title: "Connecting",
        category: "Getting Started",
        keywords: ["connect", "login", "nickname", "join"],
        icon: :icon_connect,
        description:
          "Learn how to connect to the RetroHexChat server by choosing a nickname and joining channels."
      },
      %{
        id: "channels",
        title: "Channels",
        category: "Getting Started",
        keywords: ["channel", "room", "chat room", "join channel"],
        icon: :icon_channels,
        description:
          "Understand how chat channels work, including joining, leaving, and participating in conversations."
      },
      %{
        id: "private-messages",
        title: "Private Messages",
        category: "Getting Started",
        keywords: ["pm", "private message", "direct message", "dm", "whisper", "query"],
        icon: :icon_p2p,
        description:
          "Send and receive private messages with other users using the /msg and /query commands."
      },
      %{
        id: "connect-authentication",
        title: "Connect Authentication",
        category: "Getting Started",
        keywords: ["authentication", "login", "password", "registered", "identify"],
        icon: :icon_lock,
        description:
          "Authenticate with your registered nickname on connect to access your saved settings and channels."
      }
    ]
  end
end
