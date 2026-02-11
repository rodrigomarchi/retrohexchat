defmodule RetroHexChatWeb.ChatLiveURLe2eTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  # ── E2E: Clickable URLs ──────────────────────────────────

  describe "E2E: clickable URLs in chat" do
    test "URL in channel message is clickable link", %{conn: conn} do
      nick = "E2EUrl#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_channel_msg(view, "Alice", "check https://example.com out", "#lobby")

      html = render(view)
      assert html =~ ~s(href="https://example.com")
      assert html =~ "chat-link"
      assert html =~ ~s(target="_blank")
    end

    test "URL with trailing period excludes period", %{conn: conn} do
      nick = "E2EDot#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_channel_msg(view, "Bob", "visit https://example.com.", "#lobby")

      html = render(view)
      assert html =~ ~s(href="https://example.com")
      refute html =~ ~s(href="https://example.com.")
    end

    test "multiple URLs in one message render independently", %{conn: conn} do
      nick = "E2EMulti#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_channel_msg(view, "Carol", "see https://a.com and https://b.com", "#lobby")

      html = render(view)
      assert html =~ ~s(href="https://a.com")
      assert html =~ ~s(href="https://b.com")
    end

    test "long URL is truncated in display", %{conn: conn} do
      nick = "E2ELong#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      long_path = String.duplicate("x", 90)
      url = "https://example.com/#{long_path}"
      send_channel_msg(view, "Dave", "see #{url}", "#lobby")

      html = render(view)
      assert html =~ long_path
      assert html =~ "..."
    end

    test "URL in PM is clickable", %{conn: conn} do
      nick = "E2EPmUrl#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Open PM
      render_click(view, "nick_right_click", %{"nick" => "Eve", "x" => 0, "y" => 0})
      render_click(view, "context_query", %{"nick" => "Eve"})

      send(view.pid, %{
        event: "new_pm",
        payload: %{
          id: "pm-#{System.unique_integer([:positive])}",
          author: "Eve",
          content: "link https://pm-link.com here",
          type: :message,
          sender: "Eve",
          recipient: nick,
          timestamp: DateTime.utc_now()
        }
      })

      html = render(view)
      assert html =~ ~s(href="https://pm-link.com")
    end

    test "bold-formatted URL is still clickable", %{conn: conn} do
      nick = "E2EBold#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_channel_msg(view, "Frank", "\x02https://bold-link.com\x02", "#lobby")

      html = render(view)
      assert html =~ ~s(href="https://bold-link.com")
    end
  end

  # ── E2E: URL Catcher Window ──────────────────────────────

  describe "E2E: URL Catcher window" do
    test "open via Alt+U, see captured URLs", %{conn: conn} do
      nick = "E2ECatcher#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_channel_msg(view, "Alice", "link https://catcher-test.com", "#lobby")
      html = render_keydown(view, "window_keydown", %{"key" => "u", "altKey" => true})

      assert html =~ "url-catcher-window"
      assert html =~ "catcher-test.com"
      assert html =~ "Alice"
      assert html =~ "#lobby"
    end

    test "sort by URL column", %{conn: conn} do
      nick = "E2ECSort#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_channel_msg(view, "Bob", "visit https://zebra.com", "#lobby")
      send_channel_msg(view, "Alice", "check https://apple.com", "#lobby")

      render_click(view, "toggle_url_catcher")
      html = render_click(view, "url_catcher_sort", %{"column" => "url"})

      apple_pos = :binary.match(html, ~s(data-url="https://apple.com")) |> elem(0)
      zebra_pos = :binary.match(html, ~s(data-url="https://zebra.com")) |> elem(0)
      assert apple_pos < zebra_pos
    end

    test "filter by channel", %{conn: conn} do
      nick = "E2ECFilter#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #e2e-filter"})
      send_channel_msg(view, "Alice", "https://lobby-link.com", "#lobby")
      send_channel_msg(view, "Bob", "https://filter-link.com", "#e2e-filter")

      render_click(view, "toggle_url_catcher")
      html = render_change(view, "url_catcher_filter", %{"channel" => "#lobby"})

      assert html =~ ~s(data-url="https://lobby-link.com")
      refute html =~ ~s(data-url="https://filter-link.com")
    end

    test "search by URL text", %{conn: conn} do
      nick = "E2ECSearch#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_channel_msg(view, "Alice", "https://elixir-search.com here", "#lobby")
      send_channel_msg(view, "Bob", "https://phoenix-search.com here", "#lobby")

      render_click(view, "toggle_url_catcher")
      html = render_change(view, "url_catcher_search", %{"query" => "elixir"})

      assert html =~ ~s(data-url="https://elixir-search.com")
      refute html =~ ~s(data-url="https://phoenix-search.com")
    end

    test "close and reopen preserves entries", %{conn: conn} do
      nick = "E2ECReopen#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_channel_msg(view, "Alice", "https://persist-test.com", "#lobby")
      render_click(view, "toggle_url_catcher")
      render_click(view, "toggle_url_catcher")
      html = render_click(view, "toggle_url_catcher")

      assert html =~ "persist-test.com"
    end

    test "real-time: new URL appears in open catcher", %{conn: conn} do
      nick = "E2ERT#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "toggle_url_catcher")
      send_channel_msg(view, "Bob", "https://realtime-e2e.com", "#lobby")

      html = render(view)
      assert html =~ "realtime-e2e.com"
    end

    test "open via menu bar", %{conn: conn} do
      nick = "E2ECMenu#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "toggle_url_catcher")
      assert html =~ "url-catcher-window"
    end
  end

  # ── E2E: Link Preview ──────────────────────────────────

  describe "E2E: link preview" do
    test "preview title appears via push event", %{conn: conn} do
      nick = "E2EPreview#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_channel_msg(view, "Alice", "see https://preview-e2e.com", "#lobby")
      send(view.pid, {:link_preview_result, "https://preview-e2e.com", {:ok, "Preview Page"}})

      assert_push_event(view, "link_preview", %{
        url: "https://preview-e2e.com",
        title: "Preview Page"
      })
    end

    test "no preview for error URL", %{conn: conn} do
      nick = "E2ENoPrv#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send(view.pid, {:link_preview_result, "https://broken-e2e.com", {:error, :fetch_failed}})
      render(view)

      refute_push_event(view, "link_preview", %{})
    end

    test "preview title escaped in URL Catcher", %{conn: conn} do
      nick = "E2EEscape#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      send_channel_msg(view, "Alice", "https://xss-test.com", "#lobby")

      send(
        view.pid,
        {:link_preview_result, "https://xss-test.com", {:ok, "Safe &amp; Sound"}}
      )

      html = render_click(view, "toggle_url_catcher")
      # Title is pre-escaped by HTTP fetcher, then HEEx auto-escapes again
      assert html =~ "Safe &amp;amp; Sound"
    end
  end

  # ── E2E: Session Reset ──────────────────────────────────

  describe "E2E: session behavior" do
    test "URL Catcher is empty on fresh connect", %{conn: conn} do
      nick = "E2EFresh#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "toggle_url_catcher")
      assert html =~ "No URLs captured"
    end
  end

  # ── Helpers ──────────────────────────────────────────────

  defp send_channel_msg(view, author, content, channel) do
    send(view.pid, %{
      event: "new_message",
      payload: %{
        id: "msg-#{System.unique_integer([:positive])}",
        author: author,
        content: content,
        type: :message,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    })
  end
end
