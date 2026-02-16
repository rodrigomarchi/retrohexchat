defmodule RetroHexChatWeb.Live.SearchHighlightTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  describe "search_input triggers highlight push_event" do
    test "search_input pushes search_highlight event", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHL1"), "/chat")
      render_click(view, "toggle_search")

      html = render_change(view, "search_input", %{"query" => "hello"})
      assert html =~ "search-bar"
    end

    test "empty search_input clears highlights", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHL2"), "/chat")
      render_click(view, "toggle_search")
      render_change(view, "search_input", %{"query" => "hello"})

      html = render_change(view, "search_input", %{"query" => ""})
      assert html =~ "No results"
    end
  end

  describe "search_highlight_count updates assigns" do
    test "updates result count from JS hook", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHC1"), "/chat")
      render_click(view, "toggle_search")

      html = render_click(view, "search_highlight_count", %{"count" => 5})
      assert html =~ "1 of 5"
    end

    test "shows error when JS hook reports invalid regex", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHC2"), "/chat")
      render_click(view, "toggle_search")

      html =
        render_click(view, "search_highlight_count", %{
          "count" => 0,
          "error" => "Invalid regex"
        })

      assert html =~ "Invalid regex"
      assert html =~ "search-error"
    end
  end

  describe "search_next/search_prev navigation" do
    test "search_next wraps around", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchNW1"), "/chat")
      render_click(view, "toggle_search")
      # Simulate JS hook reporting 3 matches
      render_click(view, "search_highlight_count", %{"count" => 3})

      # Current index starts at 1, next goes to 2
      html = render_click(view, "search_next")
      assert html =~ "2 of 3"

      html = render_click(view, "search_next")
      assert html =~ "3 of 3"

      # Wrap to 1
      html = render_click(view, "search_next")
      assert html =~ "1 of 3"
    end

    test "search_prev wraps around", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchPW1"), "/chat")
      render_click(view, "toggle_search")
      render_click(view, "search_highlight_count", %{"count" => 3})

      # From 1, prev wraps to 3
      html = render_click(view, "search_prev")
      assert html =~ "3 of 3"

      html = render_click(view, "search_prev")
      assert html =~ "2 of 3"
    end
  end

  describe "search_navigate arrow keys" do
    test "ArrowDown triggers search_next", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchAD1"), "/chat")
      render_click(view, "toggle_search")
      render_click(view, "search_highlight_count", %{"count" => 3})

      html = render_click(view, "search_navigate", %{"key" => "ArrowDown"})
      assert html =~ "2 of 3"
    end

    test "ArrowUp triggers search_prev", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchAU1"), "/chat")
      render_click(view, "toggle_search")
      render_click(view, "search_highlight_count", %{"count" => 3})

      html = render_click(view, "search_navigate", %{"key" => "ArrowUp"})
      assert html =~ "3 of 3"
    end

    test "other keys in search_navigate are no-op", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchAN1"), "/chat")
      render_click(view, "toggle_search")

      html = render_click(view, "search_navigate", %{"key" => "a"})
      assert html =~ "search-bar"
    end
  end

  describe "search_toggle_filter" do
    test "toggling case_sensitive updates assigns", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchTF1"), "/chat")
      render_click(view, "toggle_search")

      html = render_click(view, "search_toggle_filter", %{"filter" => "case_sensitive"})
      assert html =~ "search-filters"
    end

    test "toggling regex with invalid query shows error", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchTF2"), "/chat")
      render_click(view, "toggle_search")
      render_change(view, "search_input", %{"query" => "[invalid"})

      html = render_click(view, "search_toggle_filter", %{"filter" => "regex"})
      assert html =~ "Invalid regex"
    end

    test "toggling regex with valid query does not show error", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchTF3"), "/chat")
      render_click(view, "toggle_search")
      render_change(view, "search_input", %{"query" => "error|warn"})

      html = render_click(view, "search_toggle_filter", %{"filter" => "regex"})
      refute html =~ "search-error"
    end

    test "toggling my_mentions updates assigns", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchTF4"), "/chat")
      render_click(view, "toggle_search")

      html = render_click(view, "search_toggle_filter", %{"filter" => "my_mentions"})
      assert html =~ "search-filters"
    end
  end

  describe "search_history toggle" do
    test "toggling history updates assigns", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHi1"), "/chat")
      render_click(view, "toggle_search")

      html = render_click(view, "search_toggle_filter", %{"filter" => "history"})
      assert html =~ "search-filters"
    end

    test "history checkbox renders in search bar", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHi2"), "/chat")
      html = render_click(view, "toggle_search")
      assert html =~ "History"
    end
  end

  describe "search_last_query persistence" do
    test "closing search saves query, reopening restores it", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchLQ1"), "/chat")
      render_click(view, "toggle_search")
      render_change(view, "search_input", %{"query" => "terraform"})

      # Close search
      render_click(view, "close_search")

      # Reopen — query should be restored
      html = render_click(view, "toggle_search")
      assert html =~ "terraform"
    end

    test "Escape saves query before closing", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchLQ2"), "/chat")
      render_click(view, "toggle_search")
      render_change(view, "search_input", %{"query" => "saved"})

      render_click(view, "window_keydown", %{"key" => "Escape"})

      html = render_click(view, "toggle_search")
      assert html =~ "saved"
    end
  end
end
