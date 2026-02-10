defmodule RetroHexChatWeb.Components.StatusBarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.StatusBar

  describe "status_bar/1" do
    test "displays nickname" do
      html =
        render_component(&StatusBar.status_bar/1,
          nickname: "alice",
          channel: nil,
          user_count: 0,
          connected: true
        )

      assert html =~ "alice"
    end

    test "displays channel name" do
      html =
        render_component(&StatusBar.status_bar/1,
          nickname: "alice",
          channel: "#lobby",
          user_count: 0,
          connected: true
        )

      assert html =~ "#lobby"
    end

    test "displays user count" do
      html =
        render_component(&StatusBar.status_bar/1,
          nickname: "alice",
          channel: nil,
          user_count: 42,
          connected: true
        )

      assert html =~ "42"
    end

    test "shows connected status" do
      html =
        render_component(&StatusBar.status_bar/1,
          nickname: "alice",
          channel: nil,
          user_count: 0,
          connected: true
        )

      refute html =~ "Disconnected"
    end
  end
end
