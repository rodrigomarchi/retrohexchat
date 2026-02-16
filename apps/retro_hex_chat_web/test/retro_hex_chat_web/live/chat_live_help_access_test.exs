defmodule RetroHexChatWeb.ChatLiveHelpAccessTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.HelpTopics

  @moduletag :liveview

  setup %{conn: conn} do
    {:ok, conn: conn}
  end

  describe "US11: Help menu quick access" do
    test "open_help_at_topic with keyboard-shortcuts opens help at that topic", %{conn: conn} do
      nick = "HA1#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "open_help_at_topic", %{"topic" => "keyboard-shortcuts"})

      assert html =~ "help-dialog"
      assert html =~ "Keyboard Shortcuts"
    end

    test "open_help_at_topic with commands-overview opens help at commands", %{conn: conn} do
      nick = "HA2#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "open_help_at_topic", %{"topic" => "commands-overview"})

      assert html =~ "help-dialog"
      assert html =~ "IRC Commands Reference"
    end

    test "commands-overview topic exists and has content" do
      topic = HelpTopics.get_topic("commands-overview")

      assert topic != nil
      assert topic.title == "IRC Commands Reference"
      assert topic.category == "Commands"
      assert topic.content =~ "/join"
      assert topic.content =~ "/quit"
      assert topic.content =~ "/msg"
    end

    test "menu bar has IRC Commands item", %{conn: conn} do
      nick = "HA3#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "data-testid=\"menu-help-commands\""
      assert html =~ "IRC Commands"
    end

    test "menu bar has Keyboard Shortcuts item", %{conn: conn} do
      nick = "HA4#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      assert html =~ "data-testid=\"menu-help-shortcuts\""
      assert html =~ "Keyboard Shortcuts"
    end
  end

  defp uid, do: System.unique_integer([:positive])
end
