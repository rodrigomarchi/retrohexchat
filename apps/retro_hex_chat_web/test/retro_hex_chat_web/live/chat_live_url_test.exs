defmodule RetroHexChatWeb.ChatLiveURLTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  # ── US1: Clickable URLs in chat messages ────────────────────

  describe "US1: clickable URL rendering" do
    test "message with URL renders anchor tag with correct attributes", %{conn: conn} do
      nick = "URLUser#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "Alice", "check https://example.com out", "#lobby")

      html = render(view)
      assert html =~ ~s(href="https://example.com")
      assert html =~ "chat-link"
      assert html =~ ~s(target="_blank")
      assert html =~ ~s(rel="noopener noreferrer")
    end

    test "surrounding text renders normally alongside URL", %{conn: conn} do
      nick = "URLSurr#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "Alice", "visit https://example.com now", "#lobby")

      html = render(view)
      assert html =~ "visit"
      assert html =~ "now"
      assert html =~ ~s(href="https://example.com")
    end

    test "URL with trailing period excludes the period from link", %{conn: conn} do
      nick = "URLDot#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "Alice", "see https://example.com.", "#lobby")

      html = render(view)
      assert html =~ ~s(href="https://example.com")
      # The period should NOT be inside the href
      refute html =~ ~s(href="https://example.com.")
    end

    test "URL with query params and fragment is fully clickable", %{conn: conn} do
      nick = "URLQuery#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(
        view,
        "Alice",
        "link https://example.com/path?q=test&page=2#section here",
        "#lobby"
      )

      html = render(view)
      # The href should contain the full URL (with HTML-escaped ampersand)
      assert html =~ "example.com/path"
      assert html =~ "chat-link"
    end

    test "message with multiple URLs has multiple independent links", %{conn: conn} do
      nick = "URLMulti#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(
        view,
        "Alice",
        "links: https://a.com and https://b.com here",
        "#lobby"
      )

      html = render(view)
      assert html =~ ~s(href="https://a.com")
      assert html =~ ~s(href="https://b.com")
    end

    test "PM message with URL also renders as clickable link", %{conn: conn} do
      nick = "URLPM#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open PM conversation with Bob and stay on it
      render_click(view, "nick_right_click", %{"nick" => "Bob", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "Bob"})

      # Send a PM with a URL — needs sender/recipient for pm_other_nick/2
      msg = %{
        event: "new_pm",
        payload: %{
          id: "pm-#{uid()}",
          author: "Bob",
          content: "check https://example.com/pm",
          type: :message,
          sender: "Bob",
          recipient: nick,
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, msg)
      html = render(view)

      assert html =~ ~s(href="https://example.com/pm")
      assert html =~ "chat-link"
    end
  end

  describe "US1: long URL truncation" do
    test "URL over 100 chars has truncated display with full href", %{conn: conn} do
      nick = "URLLong#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      long_path = String.duplicate("a", 90)
      url = "https://example.com/#{long_path}"

      send_new_message(view, "Alice", "see #{url}", "#lobby")

      html = render(view)
      # href should contain the full URL
      assert html =~ long_path
      assert html =~ "chat-link"
      # Display text should be truncated
      assert html =~ "..."
    end

    test "URL exactly 100 chars is NOT truncated", %{conn: conn} do
      nick = "URLExact#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      base = "https://example.com/"
      padding = String.duplicate("x", 100 - String.length(base))
      url = base <> padding

      send_new_message(view, "Alice", url, "#lobby")

      html = render(view)
      assert html =~ "chat-link"
      # The link display text should NOT be truncated (no ellipsis in the link)
      refute html =~ ~s(class="chat-link">#{String.slice(url, 0, 97)}...)
    end
  end

  describe "US1: URL + IRC formatting interaction" do
    test "bold-wrapped URL renders as clickable link", %{conn: conn} do
      nick = "URLBold#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Bold control code (0x02) around URL
      send_new_message(view, "Alice", "\x02https://example.com\x02", "#lobby")

      html = render(view)
      assert html =~ ~s(href="https://example.com")
      assert html =~ "chat-link"
    end

    test "URL in strip_formatting mode renders as plain clickable link", %{conn: conn} do
      nick = "URLStrip#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Toggle strip formatting
      view |> element("[data-testid=\"strip-formatting-toggle\"]") |> render_click()

      send_new_message(view, "Alice", "see \x02https://example.com\x02 here", "#lobby")

      html = render(view)
      assert html =~ ~s(href="https://example.com")
      assert html =~ "chat-link"
      # Should not have irc-bold spans (formatting stripped)
      refute html =~ "irc-bold"
    end

    test "action message with URL renders URL as clickable", %{conn: conn} do
      nick = "URLAction#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      msg = %{
        event: "new_message",
        payload: %{
          id: "msg-#{uid()}",
          author: "Alice",
          content: "shares https://example.com/action with everyone",
          type: :action,
          channel: "#lobby",
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, msg)

      html = render(view)
      assert html =~ ~s(href="https://example.com/action")
      assert html =~ "chat-link"
    end
  end

  # ── US3: Inline Link Preview ────────────────────────────────

  describe "US3: async link preview" do
    test "message renders immediately without preview", %{conn: conn} do
      nick = "LPNoBlock#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "Alice", "check https://example.com out", "#lobby")

      html = render(view)
      assert html =~ ~s(href="https://example.com")
      # No preview yet (fetch is async)
      refute html =~ "chat-link-preview"
    end

    test "preview result pushes event to client", %{conn: conn} do
      nick = "LPPush#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send(view.pid, {:link_preview_result, "https://example.com", {:ok, "Example Domain"}})

      assert_push_event(view, "link_preview", %{
        url: "https://example.com",
        title: "Example Domain"
      })
    end

    test "error result does not push event", %{conn: conn} do
      nick = "LPError#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send(view.pid, {:link_preview_result, "https://broken.com", {:error, :fetch_failed}})
      render(view)

      refute_push_event(view, "link_preview", %{})
    end

    test "preview updates URL Catcher entry", %{conn: conn} do
      nick = "LPCatcher#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "Alice", "see https://example.com/page", "#lobby")
      render(view)

      send(view.pid, {:link_preview_result, "https://example.com/page", {:ok, "My Page"}})
      html = render_click(view, "toggle_url_catcher")

      assert html =~ "My Page"
    end
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp send_new_message(view, author, content, channel) do
    msg = %{
      event: "new_message",
      payload: %{
        id: "msg-#{uid()}",
        author: author,
        content: content,
        type: :message,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    }

    send(view.pid, msg)
  end
end
