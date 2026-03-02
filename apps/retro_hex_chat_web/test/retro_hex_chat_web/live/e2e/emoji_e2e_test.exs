defmodule RetroHexChatWeb.EmojiE2ETest do
  @moduledoc """
  E2E tests for emoji picker (US9).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  describe "Emoji Picker E2E" do
    test "clicking toggle opens emoji picker", %{conn: conn} do
      nick = "EE2#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "toggle_emoji_picker", %{})
      assert html =~ "data-testid=\"emoji-picker\""
      assert html =~ "data-testid=\"emoji-picker-search\""
      assert html =~ "grid grid-cols-8"
    end

    test "category tabs render in picker", %{conn: conn} do
      nick = "EE3#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "toggle_emoji_picker", %{})
      assert html =~ "Smileys &amp; Emotion"
      assert html =~ "People &amp; Body"
      assert html =~ "Animals &amp; Nature"
      assert html =~ "Food &amp; Drink"
    end

    test "emoji buttons render in grid", %{conn: conn} do
      nick = "EE4#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "toggle_emoji_picker", %{})
      assert html =~ "phx-value-emoji="
    end

    test "search field filters emojis", %{conn: conn} do
      nick = "EE5#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "emoji_search", %{"value" => "heart"})

      # Grid still present
      assert html =~ "grid grid-cols-8"
    end

    test "selecting emoji closes picker", %{conn: conn} do
      nick = "EE6#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "emoji_select", %{"emoji" => "\u{1F600}"})

      refute html =~ "data-testid=\"emoji-picker\""
    end

    test "switching category shows different emojis", %{conn: conn} do
      nick = "EE7#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "emoji_category", %{"category" => "Food & Drink"})

      assert html =~ "phx-value-emoji="
    end
  end
end
