defmodule RetroHexChat.Chat.HelpTopicsTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.HelpTopics

  @moduletag :unit

  describe "all_topics/0" do
    test "returns a non-empty list" do
      topics = HelpTopics.all_topics()
      assert is_list(topics)
      assert topics != []
    end

    test "every topic has required fields" do
      for topic <- HelpTopics.all_topics() do
        assert is_binary(topic.id) and topic.id != ""
        assert is_binary(topic.title) and topic.title != ""
        assert is_binary(topic.category) and topic.category != ""
        assert is_binary(topic.content) and topic.content != ""
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
    test "returns categories in display order" do
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
    end

    test "every category has at least one topic" do
      for {_name, topics} <- HelpTopics.topics_by_category() do
        assert topics != []
      end
    end

    test "categories cover all topics" do
      category_topics =
        HelpTopics.topics_by_category()
        |> Enum.flat_map(&elem(&1, 1))

      assert Enum.count(category_topics) == Enum.count(HelpTopics.all_topics())
    end
  end

  describe "search/1" do
    test "returns empty list for queries shorter than 2 chars" do
      assert HelpTopics.search("") == []
      assert HelpTopics.search("a") == []
    end

    test "finds topics by title" do
      results = HelpTopics.search("join")
      ids = Enum.map(results, & &1.id)
      assert "cmd-join" in ids
    end

    test "finds topics by keyword" do
      results = HelpTopics.search("buddy")
      ids = Enum.map(results, & &1.id)
      assert "feature-notify-list" in ids
    end

    test "finds topics by content" do
      results = HelpTopics.search("operator")
      assert results != []
    end

    test "search is case-insensitive" do
      lower = HelpTopics.search("join")
      upper = HelpTopics.search("JOIN")
      assert Enum.map(lower, & &1.id) == Enum.map(upper, & &1.id)
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
end
