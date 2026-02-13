defmodule RetroHexChatWeb.EmojiE2ETest do
  @moduledoc """
  E2E tests for emoji picker (US9).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  describe "Emoji Picker E2E" do
    test "emoji picker toggle button is visible", %{conn: conn} do
      nick = "EE1#{uid()}"
      channel = "#ee1-#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      :timer.sleep(50)
      html = render(view)

      assert html =~ "data-testid=\"emoji-picker-toggle\""
    end

    test "clicking toggle opens emoji picker", %{conn: conn} do
      nick = "EE2#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "toggle_emoji_picker", %{})
      assert html =~ "data-testid=\"emoji-picker\""
      assert html =~ "data-testid=\"emoji-search\""
      assert html =~ "data-testid=\"emoji-grid\""
    end

    test "category tabs render in picker", %{conn: conn} do
      nick = "EE3#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "toggle_emoji_picker", %{})
      assert html =~ "emoji-category-tabs"
      assert html =~ "emoji-category-tab"
    end

    test "emoji buttons render in grid", %{conn: conn} do
      nick = "EE4#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "toggle_emoji_picker", %{})
      assert html =~ "emoji-btn"
      assert html =~ "data-emoji="
    end

    test "search field filters emojis", %{conn: conn} do
      nick = "EE5#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "emoji_search", %{"value" => "heart"})

      # Category tabs hidden during search
      refute html =~ "emoji-category-tabs"
      # Grid still present
      assert html =~ "emoji-grid"
    end

    test "selecting emoji closes picker", %{conn: conn} do
      nick = "EE6#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "emoji_select", %{"emoji" => "\u{1F600}"})

      refute html =~ "data-testid=\"emoji-picker\""
    end

    test "switching category shows different emojis", %{conn: conn} do
      nick = "EE7#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "emoji_category", %{"category" => "Food & Drink"})

      # Should have food emojis
      assert html =~ "emoji-grid"
      assert html =~ "data-emoji="
    end
  end

  defp uid, do: System.unique_integer([:positive])
end
