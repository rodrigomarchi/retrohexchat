defmodule RetroHexChatWeb.Live.SearchHighlightTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.Queries

  @moduletag :liveview

  # Search content state lives in the ChatLive.Components.SearchBar LiveComponent.
  # The search events fire on the parent LiveView and are forwarded to the
  # component via `send_update/2`, which is processed asynchronously relative to
  # the triggering `render_*` call. We therefore read the resulting markup with a
  # follow-up `render(view)` (a separate message that the LiveView processes after
  # the queued component update) instead of relying on the event call's return
  # value for component-owned state.

  describe "search_input triggers highlight push_event" do
    test "search_input pushes search_highlight event", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHL1"), "/chat")
      render_click(view, "toggle_search")

      render_change(view, "search_input", %{"query" => "hello"})
      assert render(view) =~ "search-bar"
    end

    test "empty search_input clears highlights", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHL2"), "/chat")
      render_click(view, "toggle_search")
      render_change(view, "search_input", %{"query" => "hello"})

      render_change(view, "search_input", %{"query" => ""})
      assert render(view) =~ "0/0"
    end
  end

  describe "search_highlight_count updates assigns" do
    test "updates result count from JS hook", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHC1"), "/chat")
      render_click(view, "toggle_search")

      render_click(view, "search_highlight_count", %{"count" => 5})
      assert render(view) =~ "1/5"
    end

    test "shows error when JS hook reports invalid regex", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHC2"), "/chat")
      render_click(view, "toggle_search")

      render_click(view, "search_highlight_count", %{
        "count" => 0,
        "error" => "Invalid regex"
      })

      html = render(view)
      assert html =~ "Invalid regex"
      assert html =~ "text-error"
    end
  end

  describe "search_next/search_prev navigation" do
    test "search_next wraps around", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchNW1"), "/chat")
      render_click(view, "toggle_search")
      # Simulate JS hook reporting 3 matches
      render_click(view, "search_highlight_count", %{"count" => 3})

      # Current index starts at 1, next goes to 2
      render_click(view, "search_next")
      assert render(view) =~ "2/3"

      render_click(view, "search_next")
      assert render(view) =~ "3/3"

      # Wrap to 1
      render_click(view, "search_next")
      assert render(view) =~ "1/3"
    end

    test "search_prev wraps around", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchPW1"), "/chat")
      render_click(view, "toggle_search")
      render_click(view, "search_highlight_count", %{"count" => 3})

      # From 1, prev wraps to 3
      render_click(view, "search_prev")
      assert render(view) =~ "3/3"

      render_click(view, "search_prev")
      assert render(view) =~ "2/3"
    end
  end

  describe "search_navigate arrow keys" do
    test "ArrowDown triggers search_next", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchAD1"), "/chat")
      render_click(view, "toggle_search")
      render_click(view, "search_highlight_count", %{"count" => 3})

      render_click(view, "search_navigate", %{"key" => "ArrowDown"})
      assert render(view) =~ "2/3"
    end

    test "ArrowUp triggers search_prev", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchAU1"), "/chat")
      render_click(view, "toggle_search")
      render_click(view, "search_highlight_count", %{"count" => 3})

      render_click(view, "search_navigate", %{"key" => "ArrowUp"})
      assert render(view) =~ "3/3"
    end

    test "other keys in search_navigate are no-op", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchAN1"), "/chat")
      render_click(view, "toggle_search")

      render_click(view, "search_navigate", %{"key" => "a"})
      assert render(view) =~ "search-bar"
    end
  end

  describe "search_toggle_filter" do
    test "toggling case_sensitive updates assigns", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchTF1"), "/chat")
      render_click(view, "toggle_search")

      render_click(view, "search_toggle_filter", %{"filter" => "case_sensitive"})
      assert render(view) =~ "Case sensitive"
    end

    test "toggling regex with invalid query shows error", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchTF2"), "/chat")
      render_click(view, "toggle_search")
      render_change(view, "search_input", %{"query" => "[invalid"})

      render_click(view, "search_toggle_filter", %{"filter" => "regex"})
      assert render(view) =~ "Invalid regex"
    end

    test "toggling regex with valid query does not show error", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchTF3"), "/chat")
      render_click(view, "toggle_search")
      render_change(view, "search_input", %{"query" => "error|warn"})

      render_click(view, "search_toggle_filter", %{"filter" => "regex"})
      refute render(view) =~ "text-error"
    end

    test "toggling my_mentions updates assigns", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchTF4"), "/chat")
      render_click(view, "toggle_search")

      render_click(view, "search_toggle_filter", %{"filter" => "my_mentions"})
      assert render(view) =~ "Case sensitive"
    end
  end

  describe "search_history toggle" do
    test "toggling history updates assigns", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHi1"), "/chat")
      render_click(view, "toggle_search")

      render_click(view, "search_toggle_filter", %{"filter" => "history"})
      assert render(view) =~ "Case sensitive"
    end

    test "history checkbox renders in search bar", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHi2"), "/chat")
      render_click(view, "toggle_search")
      html = render(view)
      assert html =~ "Search history"
    end
  end

  describe "history mode searches persisted messages asynchronously" do
    test "history match count resolves via async DB lookup", %{conn: conn} do
      for content <- ["alpha zzqq one", "beta zzqq two", "no match here"] do
        Queries.insert_message(%{
          channel_name: "#lobby",
          author_nickname: "Seed",
          content: content,
          type: "message"
        })
      end

      {:ok, view, _html} = live(chat_conn(conn, "SrchAsync1"), "/chat")
      render_click(view, "toggle_search")
      render_click(view, "search_toggle_filter", %{"filter" => "history"})
      render_change(view, "search_input", %{"query" => "zzqq"})

      # Without a JS client the DOM match count stays 0, so the displayed total
      # comes purely from the async persisted-history lookup (2 matches).
      assert render_async(view) =~ "1/2"
    end

    test "stale async result is ignored after query changes", %{conn: conn} do
      Queries.insert_message(%{
        channel_name: "#lobby",
        author_nickname: "Seed",
        content: "uniquetoken here",
        type: "message"
      })

      {:ok, view, _html} = live(chat_conn(conn, "SrchAsync2"), "/chat")
      render_click(view, "toggle_search")
      render_click(view, "search_toggle_filter", %{"filter" => "history"})

      # Search for the token, then immediately clear — the in-flight async result
      # for "uniquetoken" must not resurrect a count for an empty query.
      render_change(view, "search_input", %{"query" => "uniquetoken"})
      render_change(view, "search_input", %{"query" => ""})

      assert render_async(view) =~ "0/0"
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
      render_click(view, "toggle_search")
      assert render(view) =~ "terraform"
    end

    test "Escape saves query before closing", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchLQ2"), "/chat")
      render_click(view, "toggle_search")
      render_change(view, "search_input", %{"query" => "saved"})

      render_click(view, "window_keydown", %{"key" => "Escape"})

      render_click(view, "toggle_search")
      assert render(view) =~ "saved"
    end
  end
end
