defmodule RetroHexChatWeb.HelpLive.HelpContentCoverageTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.HelpLive.HelpHelpers

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

  # Icons and other components inside a page are called by name at render
  # time, so a misspelt one compiles and only fails when somebody opens the
  # topic. Rendering every page here turns that 500 into a red test.
  test "every topic's content renders" do
    failures =
      for topic <- HelpTopics.all_topics(),
          reason = render_failure(topic.id),
          do: {topic.id, reason}

    assert failures == []
  end

  defp render_failure(id) do
    %{id: id}
    |> HelpHelpers.render_topic_content()
    |> rendered_to_string()

    nil
  rescue
    error -> Exception.message(error)
  end
end
