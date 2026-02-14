defmodule RetroHexChatWeb.ChatLiveURLCatcherTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  # ── US2: URL Catcher Window ────────────────────────────────

  describe "US2: URL Catcher window basics" do
    test "toggle_url_catcher opens the window", %{conn: conn} do
      nick = "UCOpen#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "toggle_url_catcher")
      assert html =~ "url-catcher-window"
      assert html =~ "URL Catcher"
    end

    test "toggle_url_catcher closes the window", %{conn: conn} do
      nick = "UCClose#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "toggle_url_catcher")
      html = render_click(view, "toggle_url_catcher")
      refute html =~ "url-catcher-window"
    end

    test "window shows table with column headers", %{conn: conn} do
      nick = "UCHeaders#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "toggle_url_catcher")
      assert html =~ "url-catcher-sort-url"
      assert html =~ "url-catcher-sort-channel"
      assert html =~ "url-catcher-sort-posted-by"
      assert html =~ "url-catcher-sort-time"
    end

    test "empty window shows no URLs message", %{conn: conn} do
      nick = "UCEmpty#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "toggle_url_catcher")
      assert html =~ "No URLs captured"
    end

    test "Ctrl+Shift+S opens URL Catcher window", %{conn: conn} do
      nick = "UCAltU#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      html =
        render_keydown(view, "window_keydown", %{
          "key" => "s",
          "ctrlKey" => true,
          "shiftKey" => true
        })

      assert html =~ "url-catcher-window"
    end

    test "Ctrl+Shift+S toggles URL Catcher window", %{conn: conn} do
      nick = "UCToggle#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_keydown(view, "window_keydown", %{
        "key" => "s",
        "ctrlKey" => true,
        "shiftKey" => true
      })

      html =
        render_keydown(view, "window_keydown", %{
          "key" => "s",
          "ctrlKey" => true,
          "shiftKey" => true
        })

      refute html =~ "url-catcher-window"
    end

    test "menu bar URL Catcher item opens window", %{conn: conn} do
      nick = "UCMenu#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      assert render(view) =~ "menu-url-catcher"
      html = render_click(view, "toggle_url_catcher")
      assert html =~ "url-catcher-window"
    end
  end

  describe "US2: URL capture and display" do
    test "new message with URL appears in URL Catcher", %{conn: conn} do
      nick = "UCCapture#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_new_message(view, "Alice", "check https://example.com out", "#lobby")
      html = render_click(view, "toggle_url_catcher")

      assert html =~ "example.com"
      assert html =~ "#lobby"
      assert html =~ "Alice"
      assert html =~ "1 URL captured"
    end

    test "message with multiple URLs creates multiple entries", %{conn: conn} do
      nick = "UCMulti#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_new_message(view, "Bob", "visit https://a.com and https://b.com", "#lobby")
      html = render_click(view, "toggle_url_catcher")

      assert html =~ "a.com"
      assert html =~ "b.com"
      assert html =~ "2 URLs captured"
    end

    test "PM with URL is captured with PM source", %{conn: conn} do
      nick = "UCPm#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Open PM conversation first
      render_click(view, "nick_right_click", %{"nick" => "Carol", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "Carol"})

      msg = %{
        event: "new_pm",
        payload: %{
          id: "pm-#{System.unique_integer([:positive])}",
          author: "Carol",
          content: "see https://pm-example.com",
          type: :message,
          sender: "Carol",
          recipient: nick,
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, msg)
      html = render_click(view, "toggle_url_catcher")

      assert html =~ "pm-example.com"
      assert html =~ "Carol"
    end

    test "real-time update: new URL appears in open window", %{conn: conn} do
      nick = "UCRealtime#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "toggle_url_catcher")
      send_new_message(view, "Dave", "look at https://realtime.com", "#lobby")

      html = render(view)
      assert html =~ "realtime.com"
      assert html =~ "1 URL captured"
    end

    test "message without URL does not add entry", %{conn: conn} do
      nick = "UCNoUrl#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_new_message(view, "Eve", "just some text", "#lobby")
      html = render_click(view, "toggle_url_catcher")

      assert html =~ "No URLs captured"
    end
  end

  describe "US2: sorting" do
    test "clicking column header sorts entries", %{conn: conn} do
      nick = "UCSort#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_new_message(view, "Bob", "visit https://banana.com", "#lobby")
      send_new_message(view, "Alice", "check https://apple.com", "#lobby")

      render_click(view, "toggle_url_catcher")
      html = render_click(view, "url_catcher_sort", %{"column" => "url"})

      # Extract URL catcher table section and check order within it
      table_html = extract_url_catcher_table(html)
      apple_pos = :binary.match(table_html, "apple.com") |> elem(0)
      banana_pos = :binary.match(table_html, "banana.com") |> elem(0)
      assert apple_pos < banana_pos
    end

    test "clicking same column header toggles direction", %{conn: conn} do
      nick = "UCSortDir#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_new_message(view, "Bob", "visit https://banana.com", "#lobby")
      send_new_message(view, "Alice", "check https://apple.com", "#lobby")

      render_click(view, "toggle_url_catcher")

      # First click on URL: ascending
      render_click(view, "url_catcher_sort", %{"column" => "url"})
      # Second click: descending
      html = render_click(view, "url_catcher_sort", %{"column" => "url"})

      # In descending order, banana should come before apple
      table_html = extract_url_catcher_table(html)
      banana_pos = :binary.match(table_html, "banana.com") |> elem(0)
      apple_pos = :binary.match(table_html, "apple.com") |> elem(0)
      assert banana_pos < apple_pos
    end

    test "sort indicator shows on active column", %{conn: conn} do
      nick = "UCSortInd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "toggle_url_catcher")
      # Default sort is timestamp desc, so Time column should show ▼
      assert html =~ "\u25BC"
    end
  end

  describe "US2: filtering" do
    setup %{conn: conn} do
      nick = "UCFilter#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Join a second channel
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #filter-ch"})

      send_new_message(view, "Alice", "lobby link https://lobby-url.com", "#lobby")
      send_new_message(view, "Bob", "filter link https://filter-url.com", "#filter-ch")

      render_click(view, "toggle_url_catcher")
      %{view: view}
    end

    test "filter by channel shows only that channel's URLs", %{view: view} do
      html = render_change(view, "url_catcher_filter", %{"channel" => "#lobby"})

      # Use url-catcher-entry testid to check URL catcher table specifically (not chat links)
      assert html =~ "lobby-url.com"
      assert url_catcher_has_url?(html, "lobby-url.com")
      refute url_catcher_has_url?(html, "filter-url.com")
    end

    test "filter All Channels shows all URLs", %{view: view} do
      render_change(view, "url_catcher_filter", %{"channel" => "#lobby"})
      html = render_change(view, "url_catcher_filter", %{"channel" => ""})

      assert html =~ ~s(data-url="https://lobby-url.com")
      assert html =~ ~s(data-url="https://filter-url.com")
    end
  end

  describe "US2: search" do
    test "search filters by URL text", %{conn: conn} do
      nick = "UCSearch#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_new_message(view, "Alice", "https://elixir-lang.org here", "#lobby")
      send_new_message(view, "Bob", "https://phoenixframework.org here", "#lobby")

      render_click(view, "toggle_url_catcher")
      html = render_change(view, "url_catcher_search", %{"query" => "elixir"})

      # Check URL catcher table entries specifically (not chat area links)
      assert url_catcher_has_url?(html, "elixir-lang.org")
      refute url_catcher_has_url?(html, "phoenixframework.org")
    end

    test "empty search shows all URLs", %{conn: conn} do
      nick = "UCSrchAll#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_new_message(view, "Alice", "https://elixir-lang.org here", "#lobby")
      send_new_message(view, "Bob", "https://phoenixframework.org here", "#lobby")

      render_click(view, "toggle_url_catcher")
      render_change(view, "url_catcher_search", %{"query" => "elixir"})
      html = render_change(view, "url_catcher_search", %{"query" => ""})

      assert html =~ ~s(data-url="https://elixir-lang.org")
      assert html =~ ~s(data-url="https://phoenixframework.org")
    end
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp send_new_message(view, author, content, channel) do
    msg = %{
      event: "new_message",
      payload: %{
        id: "msg-#{System.unique_integer([:positive])}",
        author: author,
        content: content,
        type: :message,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    }

    send(view.pid, msg)
  end

  defp url_catcher_has_url?(html, url_fragment) do
    # Match data-url on <tr> rows in URL catcher table (data-testid="url-catcher-entry-*")
    Regex.match?(
      ~r/data-testid="url-catcher-entry-[^"]*"[^>]*data-url="[^"]*#{Regex.escape(url_fragment)}/,
      html
    ) or
      Regex.match?(
        ~r/data-url="[^"]*#{Regex.escape(url_fragment)}[^"]*"[^>]*data-testid="url-catcher-entry-/,
        html
      )
  end

  defp extract_url_catcher_table(html) do
    case Regex.run(~r/data-testid="url-catcher-window".*$/s, html) do
      [match] -> match
      nil -> html
    end
  end
end
