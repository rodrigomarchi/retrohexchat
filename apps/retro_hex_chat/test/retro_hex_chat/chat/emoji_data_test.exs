defmodule RetroHexChat.Chat.EmojiDataTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.EmojiData

  @moduletag :unit

  describe "categories/0" do
    test "returns 8 category strings" do
      cats = EmojiData.categories()
      assert length(cats) == 8
      assert Enum.all?(cats, &is_binary/1)
    end

    test "includes expected categories" do
      cats = EmojiData.categories()
      assert "Smileys & Emotion" in cats
      assert "People & Body" in cats
      assert "Animals & Nature" in cats
      assert "Food & Drink" in cats
      assert "Travel & Places" in cats
      assert "Activities" in cats
      assert "Objects" in cats
      assert "Symbols" in cats
    end
  end

  describe "all/0" do
    test "returns map with 8 categories" do
      all = EmojiData.all()
      assert map_size(all) == 8
    end

    test "total emoji count >= 200" do
      total =
        EmojiData.all()
        |> Map.values()
        |> List.flatten()
        |> length()

      assert total >= 200
    end

    test "each emoji has char, name, and keywords fields" do
      EmojiData.all()
      |> Map.values()
      |> List.flatten()
      |> Enum.each(fn emoji ->
        assert Map.has_key?(emoji, :char)
        assert Map.has_key?(emoji, :name)
        assert Map.has_key?(emoji, :keywords)
        assert is_binary(emoji.char)
        assert is_binary(emoji.name)
        assert is_list(emoji.keywords)
        assert Enum.all?(emoji.keywords, &is_binary/1)
      end)
    end
  end

  describe "by_category/1" do
    test "returns emojis for Smileys & Emotion" do
      emojis = EmojiData.by_category("Smileys & Emotion")
      assert emojis != []
      assert Enum.all?(emojis, &Map.has_key?(&1, :char))
    end

    test "returns empty list for unknown category" do
      assert EmojiData.by_category("Unknown") == []
    end

    test "every category has at least 20 emojis" do
      for cat <- EmojiData.categories() do
        emojis = EmojiData.by_category(cat)
        assert length(emojis) >= 20, "#{cat} has only #{length(emojis)} emojis"
      end
    end
  end

  describe "search/1" do
    test "searching 'smile' returns relevant results" do
      results = EmojiData.search("smile")
      assert results != []

      assert Enum.any?(results, fn e ->
               String.contains?(e.name, "smile") or "smile" in e.keywords
             end)
    end

    test "searching 'heart' returns results from keywords" do
      results = EmojiData.search("heart")
      assert results != []
    end

    test "search is case-insensitive" do
      lower = EmojiData.search("smile")
      upper = EmojiData.search("SMILE")
      assert lower == upper
    end

    test "empty string returns empty list" do
      assert EmojiData.search("") == []
    end

    test "single character returns empty list" do
      assert EmojiData.search("s") == []
    end

    test "no results for nonsense query" do
      assert EmojiData.search("xyzzzzzz") == []
    end
  end
end
