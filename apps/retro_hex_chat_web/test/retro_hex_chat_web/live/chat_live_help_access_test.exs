defmodule RetroHexChatWeb.ChatLiveHelpAccessTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChat.Chat.HelpTopics

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "Help menu items in chat" do
    test "commands-overview topic exists and has content" do
      topic = HelpTopics.get_topic("commands-overview")

      assert topic != nil
      assert topic.title == "IRC Commands Reference"
      assert topic.category == "Commands"
      assert topic.content =~ "/join"
      assert topic.content =~ "/quit"
      assert topic.content =~ "/msg"
    end

    test "menu bar has IRC Commands link", %{conn: conn} do
      nick = "HA3#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "data-testid=\"menu-help-commands\""
      assert html =~ "IRC Commands"
      assert html =~ "/chat/help?topic=commands-overview"
    end

    test "menu bar has Keyboard Shortcuts link", %{conn: conn} do
      nick = "HA4#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "data-testid=\"menu-help-shortcuts\""
      assert html =~ "Keyboard Shortcuts"
      assert html =~ "/chat/help?topic=keyboard-shortcuts"
    end

    test "menu bar has Help Topics link", %{conn: conn} do
      nick = "HA5#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "data-testid=\"menu-help-topics\""
      assert html =~ "/chat/help"
    end
  end

  defp uid, do: System.unique_integer([:positive])
end
