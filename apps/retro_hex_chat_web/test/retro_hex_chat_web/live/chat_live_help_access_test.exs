defmodule RetroHexChatWeb.ChatLiveHelpAccessTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChat.Chat.HelpTopics

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "Help access in chat" do
    test "commands-overview topic exists and has content" do
      topic = HelpTopics.get_topic("commands-overview")

      assert topic != nil
      assert topic.title == "IRC Commands Reference"
      assert topic.category == "Commands"
      assert topic.content =~ "/join"
      assert topic.content =~ "/quit"
      assert topic.content =~ "/msg"
    end

    test "toolbar has Help Topics link", %{conn: conn} do
      nick = "HA5#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "data-testid=\"toolbar-help\""
      assert html =~ "/chat/help"
    end
  end

  defp uid, do: System.unique_integer([:positive])
end
