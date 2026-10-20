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

  # Each mount carries one sequence of events, checked after every step: the
  # counter's whole life — the hook's count, next/prev and the arrow keys with
  # their wrap-around, an empty query — is one conversation with one search bar,
  # and the regex error's is another. A count reported again puts the cursor
  # back on the first match, which is what lets each step start from 1/3.
  describe "counter and navigation" do
    test "the hook's count drives the counter, and next/prev/arrows wrap around",
         %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHC1"), "/")
      render_click(view, "toggle_search")

      # The JS hook reports the DOM match count.
      render_click(view, "search_highlight_count", %{"count" => 5})
      assert render(view) =~ "1/5"

      # search_next: current index starts at 1, next goes to 2, then wraps.
      render_click(view, "search_highlight_count", %{"count" => 3})
      render_click(view, "search_next")
      assert render(view) =~ "2/3"

      render_click(view, "search_next")
      assert render(view) =~ "3/3"

      render_click(view, "search_next")
      assert render(view) =~ "1/3"

      # search_prev: from 1, prev wraps to 3.
      render_click(view, "search_prev")
      assert render(view) =~ "3/3"

      render_click(view, "search_prev")
      assert render(view) =~ "2/3"

      # ArrowDown is search_next, ArrowUp is search_prev.
      render_click(view, "search_highlight_count", %{"count" => 3})
      render_click(view, "search_navigate", %{"key" => "ArrowDown"})
      assert render(view) =~ "2/3"

      render_click(view, "search_highlight_count", %{"count" => 3})
      render_click(view, "search_navigate", %{"key" => "ArrowUp"})
      assert render(view) =~ "3/3"

      # An empty search_input clears the highlights and the counter.
      render_change(view, "search_input", %{"query" => "hello"})
      render_change(view, "search_input", %{"query" => ""})
      assert render(view) =~ "0/0"
    end

    test "an invalid regex is reported by the hook and by the regex toggle", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchHC2"), "/")
      render_click(view, "toggle_search")

      # The JS hook reports an invalid regex.
      render_click(view, "search_highlight_count", %{
        "count" => 0,
        "error" => "Invalid regex"
      })

      html = render(view)
      assert html =~ "Invalid regex"
      assert html =~ "text-error"

      # A new query clears it; toggling regex on over a valid query shows none.
      render_change(view, "search_input", %{"query" => "error|warn"})
      render_click(view, "search_toggle_filter", %{"filter" => "regex"})
      refute render(view) =~ "text-error"

      # Toggling regex on over an invalid query shows the error.
      render_click(view, "search_toggle_filter", %{"filter" => "regex"})
      render_change(view, "search_input", %{"query" => "[invalid"})
      refute render(view) =~ "Invalid regex"

      render_click(view, "search_toggle_filter", %{"filter" => "regex"})
      assert render(view) =~ "Invalid regex"
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

      {:ok, view, _html} = live(chat_conn(conn, "SrchAsync1"), "/")
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

      {:ok, view, _html} = live(chat_conn(conn, "SrchAsync2"), "/")
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
    test "closing search, by its button or by Escape, saves the query reopening restores",
         %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SrchLQ1"), "/")
      render_click(view, "toggle_search")
      render_change(view, "search_input", %{"query" => "terraform"})

      # Close search
      render_click(view, "close_search")

      # Reopen — query should be restored
      render_click(view, "toggle_search")
      assert render(view) =~ "terraform"

      # Escape saves the query before closing.
      render_change(view, "search_input", %{"query" => "saved"})
      render_click(view, "window_keydown", %{"key" => "Escape"})

      render_click(view, "toggle_search")
      assert render(view) =~ "saved"
    end
  end
end
