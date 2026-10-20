defmodule RetroHexChatWeb.EmojiFeatureTest do
  @moduledoc """
  E2E tests for emoji picker (US9).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  describe "Emoji Picker E2E" do
    test "clicking toggle opens emoji picker", %{conn: conn} do
      nick = "EE2#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/")

      html = render_click(view, "toggle_emoji_picker", %{})
      assert html =~ "data-testid=\"emoji-picker\""
      assert html =~ "data-testid=\"emoji-picker-search\""
      assert html =~ "grid grid-cols-8"
    end

    test "selecting emoji closes picker", %{conn: conn} do
      nick = "EE6#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/")

      render_click(view, "toggle_emoji_picker", %{})
      html = render_click(view, "emoji_select", %{"emoji" => "\u{1F600}"})

      refute html =~ "data-testid=\"emoji-picker\""
    end
  end
end
