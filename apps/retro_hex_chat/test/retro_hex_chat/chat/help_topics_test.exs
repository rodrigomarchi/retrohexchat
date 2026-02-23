defmodule RetroHexChat.Chat.HelpTopicsTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.HelpTopics

  @moduletag :unit

  describe "all_topics/0" do
    test "returns a non-empty list" do
      assert [_ | _] = HelpTopics.all_topics()
    end

    test "every topic has required fields" do
      for topic <- HelpTopics.all_topics() do
        assert is_binary(topic.id) and topic.id != ""
        assert is_binary(topic.title) and topic.title != ""
        assert is_binary(topic.category) and topic.category != ""
        assert is_atom(topic.icon)
        assert is_binary(topic.description) and topic.description != ""
        assert is_list(topic.keywords) and topic.keywords != []
      end
    end

    test "topic ids are unique" do
      ids = Enum.map(HelpTopics.all_topics(), & &1.id)
      assert length(ids) == length(Enum.uniq(ids))
    end
  end

  describe "get_topic/1" do
    test "returns a topic by id" do
      topic = HelpTopics.get_topic("welcome")
      assert topic.id == "welcome"
      assert topic.title == "Welcome to RetroHexChat"
    end

    test "returns nil for unknown id" do
      assert HelpTopics.get_topic("nonexistent") == nil
    end
  end

  describe "topics_by_category/0" do
    test "returns categories in display order with icons" do
      categories = HelpTopics.topics_by_category()
      assert is_list(categories)

      names = Enum.map(categories, &elem(&1, 0))
      assert "Getting Started" in names
      assert "Commands" in names
      assert "Services" in names
      assert "Channel Modes" in names
      assert "Text Formatting" in names
      assert "Features" in names
      assert "User Interface" in names
      assert "Keyboard Shortcuts" in names

      # Each entry is a 3-tuple with category icon
      for {name, icon, topics} <- categories do
        assert is_binary(name)
        assert is_atom(icon)
        assert is_list(topics)
      end
    end

    test "every category has at least one topic" do
      for {_name, _icon, topics} <- HelpTopics.topics_by_category() do
        assert [_ | _] = topics
      end
    end

    test "categories cover all topics" do
      category_topics =
        HelpTopics.topics_by_category()
        |> Enum.flat_map(&elem(&1, 2))

      assert Enum.count(category_topics) == Enum.count(HelpTopics.all_topics())
    end
  end

  describe "category_icon/1" do
    test "returns icon atom for known category" do
      assert is_atom(HelpTopics.category_icon("Getting Started"))
      assert is_atom(HelpTopics.category_icon("Commands"))
    end
  end

  describe "feature-channel-central topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-channel-central")
      assert topic != nil
      assert topic.id == "feature-channel-central"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-channel-central")
      assert topic.title == "Channel Central"
    end

    test "has icon and description" do
      topic = HelpTopics.get_topic("feature-channel-central")
      assert is_atom(topic.icon)
      assert topic.description != ""
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("feature-channel-central")
      assert topic.keywords != []
    end
  end

  describe "feature-ban-exceptions topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-ban-exceptions")
      assert topic != nil
      assert topic.id == "feature-ban-exceptions"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-ban-exceptions")
      assert topic.title == "Ban Exceptions (+e)"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("feature-ban-exceptions")
      assert topic.keywords != []
    end
  end

  describe "feature-invite-exceptions topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-invite-exceptions")
      assert topic != nil
      assert topic.id == "feature-invite-exceptions"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-invite-exceptions")
      assert topic.title == "Invite Exceptions (+I)"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("feature-invite-exceptions")
      assert topic.keywords != []
    end
  end

  describe "cmd-perform topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("cmd-perform")
      assert topic != nil
      assert topic.id == "cmd-perform"
      assert topic.category == "Commands"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("cmd-perform")
      assert topic.title == "/perform"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("cmd-perform")
      assert topic.keywords != []
    end
  end

  describe "cmd-autojoin topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("cmd-autojoin")
      assert topic != nil
      assert topic.id == "cmd-autojoin"
      assert topic.category == "Commands"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("cmd-autojoin")
      assert topic.title == "/autojoin"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("cmd-autojoin")
      assert topic.keywords != []
    end
  end

  describe "feature-perform topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-perform")
      assert topic != nil
      assert topic.id == "feature-perform"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-perform")
      assert topic.title == "Perform / Auto-Commands"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("feature-perform")
      assert topic.keywords != []
    end
  end

  describe "feature-auto-reconnect topic" do
    test "exists with correct id and category" do
      topic = HelpTopics.get_topic("feature-auto-reconnect")
      assert topic != nil
      assert topic.id == "feature-auto-reconnect"
      assert topic.category == "Features"
    end

    test "has correct title" do
      topic = HelpTopics.get_topic("feature-auto-reconnect")
      assert topic.title == "Auto-Reconnect"
    end

    test "has non-empty keywords" do
      topic = HelpTopics.get_topic("feature-auto-reconnect")
      assert topic.keywords != []
    end
  end

  describe "all_keywords/0" do
    test "returns a sorted list of {keyword, topic_id}" do
      keywords = HelpTopics.all_keywords()
      assert is_list(keywords)
      assert keywords != []

      for {kw, id} <- keywords do
        assert is_binary(kw)
        assert is_binary(id)
      end
    end

    test "keywords are sorted alphabetically" do
      keywords = HelpTopics.all_keywords()
      kw_strings = Enum.map(keywords, &elem(&1, 0))
      assert kw_strings == Enum.sort(kw_strings)
    end

    test "every keyword points to a valid topic" do
      valid_ids = MapSet.new(HelpTopics.all_topics(), & &1.id)

      for {_kw, id} <- HelpTopics.all_keywords() do
        assert MapSet.member?(valid_ids, id), "keyword points to unknown topic: #{id}"
      end
    end
  end

  describe "status bar help topic" do
    test "topic exists" do
      topic = HelpTopics.get_topic("feature-status-bar")
      assert topic != nil
      assert topic.title == "Status Bar"
      assert topic.category == "Features"
    end
  end

  describe "lag indicator help topic" do
    test "topic exists" do
      topic = HelpTopics.get_topic("feature-lag-indicator")
      assert topic != nil
      assert topic.title == "Lag Indicator"
    end
  end

  describe "P2P help topics" do
    test "P2P Sessions topic exists with correct category" do
      topic = HelpTopics.get_topic("feature-p2p-sessions")
      assert topic != nil
      assert topic.category == "Features"
      assert topic.title == "P2P Sessions"
    end

    test "File Transfer topic exists with correct category" do
      topic = HelpTopics.get_topic("feature-file-transfer")
      assert topic != nil
      assert topic.category == "Features"
      assert topic.title == "File Transfer"
    end

    test "Privacy Settings topic exists with correct category" do
      topic = HelpTopics.get_topic("feature-privacy-settings")
      assert topic != nil
      assert topic.category == "Features"
      assert topic.title == "Privacy Settings"
    end

    test "command topics exist for P2P commands" do
      for id <- ~w(cmd-p2p cmd-call cmd-sendfile) do
        topic = HelpTopics.get_topic(id)
        assert topic != nil, "Missing help topic: #{id}"
        assert topic.category == "Commands"
      end
    end
  end

  describe "connection states help topic" do
    test "topic exists" do
      topic = HelpTopics.get_topic("feature-connection-states")
      assert topic != nil
      assert topic.title == "Connection States"
    end
  end

  describe "HEEx content template integrity" do
    # Navigate from this test file to the web app's help_content directory
    @content_dir __DIR__
                 |> Path.join("../../../../..")
                 |> Path.join(
                   "apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content"
                 )
                 |> Path.expand()

    test "every topic ID has a corresponding .html.heex file" do
      for topic <- HelpTopics.all_topics() do
        func_name = String.replace(topic.id, "-", "_")
        path = Path.join(@content_dir, "#{func_name}.html.heex")

        assert File.exists?(path),
               "Missing HEEx file for topic: #{topic.id} (expected #{path})"
      end
    end
  end
end
