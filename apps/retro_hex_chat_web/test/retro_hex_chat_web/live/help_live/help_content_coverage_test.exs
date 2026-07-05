defmodule RetroHexChatWeb.HelpLive.HelpContentCoverageTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.HelpTopics

  @moduletag :unit

  # A HEEx file alone is not enough: it must be picked up by an
  # embed_templates glob in a HelpContent module, or render_topic_content/1
  # raises at runtime when the topic is opened.
  @help_content_modules [
    RetroHexChatWeb.HelpContent.CommandsAdmin,
    RetroHexChatWeb.HelpContent.CommandsAtoM,
    RetroHexChatWeb.HelpContent.CommandsNtoZ,
    RetroHexChatWeb.HelpContent.Bots,
    RetroHexChatWeb.HelpContent.Channels,
    RetroHexChatWeb.HelpContent.Arcade,
    RetroHexChatWeb.HelpContent.Games,
    RetroHexChatWeb.HelpContent.P2P,
    RetroHexChatWeb.HelpContent.UI,
    RetroHexChatWeb.HelpContent.ChatFeatures,
    RetroHexChatWeb.HelpContent.ChatStatusFeatures
  ]

  test "every topic id has an exported content component" do
    missing =
      for topic <- HelpTopics.all_topics(),
          func = topic.id |> String.replace("-", "_") |> String.to_atom(),
          not Enum.any?(@help_content_modules, fn module ->
            Code.ensure_loaded?(module) and function_exported?(module, func, 1)
          end),
          do: topic.id

    assert missing == []
  end
end
