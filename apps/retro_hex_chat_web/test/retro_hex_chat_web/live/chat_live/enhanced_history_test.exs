defmodule RetroHexChatWeb.ChatLive.EnhancedHistoryTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ── existing history behavior preserved ──────────────────

  describe "history_navigate event" do
    test "up/down navigates command history", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "HistUser"), "/chat")

      # Send a few messages to build history
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "first message"})
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "second message"})

      # Navigate up to see most recent
      render_click(view, "history_navigate", %{"direction" => "up"})
      html = render(view)
      assert html =~ "second message"

      # Navigate up again to see first
      render_click(view, "history_navigate", %{"direction" => "up"})
      html = render(view)
      assert html =~ "first message"

      # Navigate down back to most recent
      render_click(view, "history_navigate", %{"direction" => "down"})
      html = render(view)
      assert html =~ "second message"
    end

    test "down past newest clears input", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "HistDown"), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "some message"})

      render_click(view, "history_navigate", %{"direction" => "up"})
      render_click(view, "history_navigate", %{"direction" => "down"})

      # Input should be cleared (empty)
      html = render(view)
      # Textarea content should be empty
      assert html =~ ~r/<textarea[^>]*>\s*<\/textarea>/
    end
  end

  # ── history search component ─────────────────────────────

  describe "history search rendering" do
    test "history search bar is rendered but hidden by default", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "HistSearch"), "/chat")

      assert html =~ "hist-search-panel"
      assert html =~ ~s(style="display: none;")
    end

    test "history search bar contains search input and label", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "HistSearchDflt"), "/chat")

      assert html =~ "history-search-input"
      assert html =~ "Search history"
    end
  end

  # ── helpers ──────────────────────────────────────────────

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
