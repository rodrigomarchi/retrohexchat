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
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      # Connecting auto-joins #lobby.
      title = "#lobby[#{nick}]"

      # Window title bar (it carries the taskbar button's label too — the
      # button reads the same string).
      assert html =~ title
      # Browser tab, handed to the hook that owns document.title.
      assert html =~ ~s(phx-hook="DocumentTitleHook")
      assert html =~ ~s(data-title="#{title}")
      assert html =~ ~s(data-window-taskbar="chat")
    end

    test "switching to a joined channel renames all three", %{conn: conn} do
      nick = "WT2#{uid()}"
      channel = "#wt#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      html = submit_command_sync(view, "/join #{channel}")

      title = "#{channel}[#{nick}]"

      assert html =~ title
      assert html =~ ~s(data-title="#{title}")
      refute html =~ ~s(data-title="#lobby[#{nick}]")
    end

    test "the status tab names the window after itself", %{conn: conn} do
      nick = "WT3#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "switch_tab", %{"type" => "status", "label" => "Status"})

      assert html =~ ~s(data-title="Status[#{nick}]")
    end

    test "the title bar meta zone carries the identity state", %{conn: conn} do
      nick = "WT4#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "window-title-meta"
      assert html =~ "Guest"
    end

    test "the app name no longer titles the window", %{conn: conn} do
      nick = "WT5#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      refute html =~ ~s(data-title="RetroHexChat")
    end
  end
end
