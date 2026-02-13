defmodule RetroHexChatWeb.Components.EmojiPickerTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.EmojiData
  alias RetroHexChatWeb.Components.EmojiPicker

  @moduletag :unit

  describe "emoji_picker/1" do
    test "renders when visible" do
      html =
        render_component(&EmojiPicker.emoji_picker/1,
          visible: true,
          categories: EmojiData.categories(),
          active_category: "Smileys & Emotion",
          emojis: EmojiData.by_category("Smileys & Emotion"),
          search_query: ""
        )

      assert html =~ "emoji-picker"
      assert html =~ "data-testid=\"emoji-picker\""
    end

    test "does not render when not visible" do
      html =
        render_component(&EmojiPicker.emoji_picker/1,
          visible: false,
          categories: EmojiData.categories(),
          active_category: "Smileys & Emotion",
          emojis: EmojiData.by_category("Smileys & Emotion"),
          search_query: ""
        )

      refute html =~ "emoji-picker"
    end

    test "renders category tabs" do
      html =
        render_component(&EmojiPicker.emoji_picker/1,
          visible: true,
          categories: EmojiData.categories(),
          active_category: "Smileys & Emotion",
          emojis: EmojiData.by_category("Smileys & Emotion"),
          search_query: ""
        )

      assert html =~ "emoji-category-tabs"
      assert html =~ "emoji-category-tab"
      # 8 category tab buttons (match class="emoji-category-tab" not the container)
      assert length(Regex.scan(~r/emoji-category-tab /, html)) == 8
    end

    test "renders emoji grid with buttons" do
      html =
        render_component(&EmojiPicker.emoji_picker/1,
          visible: true,
          categories: EmojiData.categories(),
          active_category: "Smileys & Emotion",
          emojis: EmojiData.by_category("Smileys & Emotion"),
          search_query: ""
        )

      assert html =~ "emoji-grid"
      assert html =~ "data-testid=\"emoji-grid\""
      assert html =~ "emoji-btn"
      assert html =~ "data-emoji="
    end

    test "search input is present" do
      html =
        render_component(&EmojiPicker.emoji_picker/1,
          visible: true,
          categories: EmojiData.categories(),
          active_category: "Smileys & Emotion",
          emojis: EmojiData.by_category("Smileys & Emotion"),
          search_query: ""
        )

      assert html =~ "data-testid=\"emoji-search\""
      assert html =~ "Search emoji"
    end

    test "hides category tabs during search" do
      html =
        render_component(&EmojiPicker.emoji_picker/1,
          visible: true,
          categories: EmojiData.categories(),
          active_category: "Smileys & Emotion",
          emojis: EmojiData.search("heart"),
          search_query: "heart"
        )

      refute html =~ "emoji-category-tabs"
    end

    test "emoji buttons have phx-click and phx-value-emoji" do
      html =
        render_component(&EmojiPicker.emoji_picker/1,
          visible: true,
          categories: EmojiData.categories(),
          active_category: "Smileys & Emotion",
          emojis: EmojiData.by_category("Smileys & Emotion"),
          search_query: ""
        )

      assert html =~ "phx-click=\"emoji_select\""
      assert html =~ "phx-value-emoji="
    end
  end
end
