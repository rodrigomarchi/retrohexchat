defmodule RetroHexChatWeb.WindowTitleFeatureTest do
  @moduledoc """
  E2E tests for the chat window, taskbar and browser tab titles.
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  describe "Chat window title" do
    test "the active conversation names the window, the taskbar and the tab alike",
         %{conn: conn} do
      nick = "WT1#{uid()}"
      {:ok, view, html} = live(chat_conn(conn, nick), "/")

      # Connecting auto-joins #lobby.
      title = "#lobby[#{nick}]"

      # Window title bar.
      assert has_element?(view, ~s([data-window-id="chat"] [data-window-titlebar]), title)
      # Browser tab, handed to the hook that owns document.title.
      assert html =~ ~s(phx-hook="DocumentTitleHook")
      assert html =~ ~s(data-title="#{title}")
      assert html =~ ~s(data-window-taskbar="chat")
    end

    test "switching to a joined channel renames all three", %{conn: conn} do
      nick = "WT2#{uid()}"
      channel = "#wt#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/")

      html = submit_command_sync(view, "/join #{channel}")

      title = "#{channel}[#{nick}]"

      assert has_element?(view, ~s([data-window-id="chat"] [data-window-titlebar]), title)
      assert html =~ ~s(data-title="#{title}")
      refute html =~ ~s(data-title="#lobby[#{nick}]")
    end
  end
end
