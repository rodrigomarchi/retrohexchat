defmodule RetroHexChat.Chat.HelpTopics.GettingStarted do
  @moduledoc false

  @help_dir Path.join(:code.priv_dir(:retro_hex_chat), "help")

  @external_resource Path.join(@help_dir, "welcome.html")
  @external_resource Path.join(@help_dir, "connecting.html")
  @external_resource Path.join(@help_dir, "channels.html")
  @external_resource Path.join(@help_dir, "private-messages.html")
  @external_resource Path.join(@help_dir, "connect-authentication.html")

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "welcome",
        title: "Welcome to RetroHexChat",
        category: "Getting Started",
        keywords: ["welcome", "introduction", "about", "overview"],
        content: File.read!(Path.join(@help_dir, "welcome.html"))
      },
      %{
        id: "connecting",
        title: "Connecting",
        category: "Getting Started",
        keywords: ["connect", "login", "nickname", "join"],
        content: File.read!(Path.join(@help_dir, "connecting.html"))
      },
      %{
        id: "channels",
        title: "Channels",
        category: "Getting Started",
        keywords: ["channel", "room", "chat room", "join channel"],
        content: File.read!(Path.join(@help_dir, "channels.html"))
      },
      %{
        id: "private-messages",
        title: "Private Messages",
        category: "Getting Started",
        keywords: ["pm", "private message", "direct message", "dm", "whisper", "query"],
        content: File.read!(Path.join(@help_dir, "private-messages.html"))
      },
      %{
        id: "connect-authentication",
        title: "Connect Authentication",
        category: "Getting Started",
        keywords: ["authentication", "login", "password", "registered", "identify"],
        content: File.read!(Path.join(@help_dir, "connect-authentication.html"))
      }
    ]
  end
end
