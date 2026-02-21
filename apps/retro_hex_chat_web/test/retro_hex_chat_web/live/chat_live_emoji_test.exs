defmodule RetroHexChatWeb.ChatLiveEmojiTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "US9: Emoji picker events" do
    test "toggle_emoji_picker shows picker", %{conn: conn} do
      nick = "EM1#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "toggle_emoji_picker", %{})
      assert html =~ "emoji-picker"
      assert html =~ "data-testid=\"emoji-picker\""
    end

    test "toggle_emoji_picker hides when already visible", %{conn: conn} do
      nick = "EM2#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "toggle_emoji_picker", %{})

      refute html =~ "data-testid=\"emoji-picker\""
    end

    test "emoji_category switches category", %{conn: conn} do
      nick = "EM3#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "emoji_category", %{"category" => "Food & Drink"})

      # The Food & Drink tab should be active
      assert html =~ "Food &amp; Drink"
    end

    test "emoji_search filters results", %{conn: conn} do
      nick = "EM4#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "emoji_search", %{"value" => "heart"})

      # Should show heart emojis, category tabs should be hidden
      refute html =~ "emoji-category-tabs"
      assert html =~ "emoji-grid"
    end

    test "emoji_select closes picker", %{conn: conn} do
      nick = "EM5#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "emoji_select", %{"emoji" => "\u{1F600}"})

      refute html =~ "data-testid=\"emoji-picker\""
    end

    test "emoji picker button visible in formatting toolbar", %{conn: conn} do
      nick = "EM6#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      channel = "#em-#{uid()}"
      render_submit(view, "send_input", %{"input" => "/join #{channel}"})
      :timer.sleep(50)
      html = render(view)

      assert html =~ "data-testid=\"emoji-picker-toggle\""
    end

    test "opening picker resets search", %{conn: conn} do
      nick = "EM7#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      # Open, search, close, reopen — search should be reset
      render_click(view, "toggle_emoji_picker", %{})
      render_click(view, "emoji_search", %{"value" => "heart"})
      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "toggle_emoji_picker", %{})

      # Category tabs should be visible (search cleared)
      assert html =~ "emoji-category-tabs"
    end
  end
end
