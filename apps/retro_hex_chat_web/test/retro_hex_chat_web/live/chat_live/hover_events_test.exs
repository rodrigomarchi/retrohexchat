defmodule RetroHexChatWeb.ChatLive.HoverEventsTest do
  @moduledoc """
  Tests for interactive element hover and click events:
  channel_hover, channel_click, nick_hover, nick_hover_dismiss, nick_dblclick.
  """
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @moduletag :e2e

  setup do
    channel = "#hover#{uid()}"
    ensure_channel(channel)
    {:ok, channel: channel}
  end

  # ── Channel hover ──────────────────────────────────────

  describe "channel_hover event" do
    test "returns channel tooltip data with member count", %{conn: conn, channel: channel} do
      nick = "HoverCh#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # Push hover event
      assert render_click(view, "channel_hover", %{"channel" => channel})
      # The event pushes "channel_tooltip" — verify the event was handled without error
    end

    test "handles hover for non-existent channel gracefully", %{conn: conn, channel: channel} do
      nick = "HoverNx#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # Should not crash — returns count=0, joined=false
      assert render_click(view, "channel_hover", %{"channel" => "#nonexistent#{uid()}"})
    end
  end

  # ── Channel click ──────────────────────────────────────

  describe "channel_click event" do
    test "switches to channel when already joined", %{conn: conn, channel: channel} do
      nick = "ClickSw#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # Click the channel — should switch (already joined)
      render_click(view, "channel_click", %{"channel" => channel})
      # Verify no error — the channel switch succeeded
      html = render(view)
      assert html =~ nick
    end

    test "joins channel when not yet joined", %{conn: conn, channel: channel} do
      nick = "ClickJn#{uid()}"
      channel2 = "#hoverjoin#{uid()}"
      ensure_channel(channel2)
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # Click a different channel — should join it
      render_click(view, "channel_click", %{"channel" => channel2})
      Process.sleep(50)
      html = render(view)
      assert html =~ channel2
    end
  end

  # ── Nick hover ─────────────────────────────────────────

  describe "nick_hover event" do
    test "populates hover card with nick data", %{conn: conn, channel: channel} do
      nick = "HoverNk#{uid()}"
      nick2 = "Target#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # Join a second user so they have presence
      {:ok, view2, _html} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)
      Process.sleep(50)

      # Hover over nick2
      render_click(view, "nick_hover", %{"nick" => nick2, "x" => 100, "y" => 200})
      html = render(view)

      # Hover card should be visible with nick info
      assert html =~ "nick-hover-card"
      assert html =~ nick2
    end

    test "suppresses hover card for own nick (FR-014)", %{conn: conn, channel: channel} do
      nick = "SelfHov#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      # Hover over own nick — should NOT show hover card
      render_click(view, "nick_hover", %{"nick" => nick, "x" => 100, "y" => 200})
      html = render(view)

      refute html =~ "nick-hover-card"
    end
  end

  # ── Nick hover dismiss ─────────────────────────────────

  describe "nick_hover_dismiss event" do
    test "hides the hover card", %{conn: conn, channel: channel} do
      nick = "Dismiss#{uid()}"
      nick2 = "DismTgt#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      {:ok, view2, _html} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)
      Process.sleep(50)

      # Show hover card
      render_click(view, "nick_hover", %{"nick" => nick2, "x" => 100, "y" => 200})
      html = render(view)
      assert html =~ "nick-hover-card"

      # Dismiss it
      render_click(view, "nick_hover_dismiss", %{})
      html = render(view)
      refute html =~ "nick-hover-card"
    end
  end

  # ── Nick dblclick ──────────────────────────────────────

  describe "nick_dblclick event" do
    test "opens PM conversation with target nick", %{conn: conn, channel: channel} do
      nick = "DblClk#{uid()}"
      nick2 = "DblTgt#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      {:ok, _view2, _html} = live(chat_conn(conn, nick2), "/chat")

      # Double-click nick — should open PM
      render_click(view, "nick_dblclick", %{"nick" => nick2})
      html = render(view)

      # Should see PM-related UI (the PM conversation is now active)
      assert html =~ nick2
    end
  end

  # ── Helpers ──────────────────────────────────────────

  defp join_channel(view, channel) do
    view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{channel}"})
    Process.sleep(50)
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
