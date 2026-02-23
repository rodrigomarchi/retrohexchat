defmodule RetroHexChatWeb.ChatLive.AdminConsoleEventsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  setup do
    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :admins)
    end)

    :ok
  end

  alias RetroHexChat.Services.NickServ

  defp make_admin(nick) do
    current = Application.get_env(:retro_hex_chat, :admins, [])
    Application.put_env(:retro_hex_chat, :admins, [nick | current])
  end

  describe "admin gate" do
    test "non-admin cannot open admin console", %{conn: conn} do
      nick = "AcNa#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_admin_console")
      html = render(view)
      refute html =~ "admin-console-dialog"
      assert html =~ "restricted to server administrators"
    end

    test "admin can open admin console", %{conn: conn} do
      nick = "AcAdm#{uid()}"
      make_admin(nick)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_admin_console")
      html = render(view)
      assert html =~ "admin-console-dialog"
      assert html =~ "Admin Console"
    end
  end

  describe "dialog lifecycle" do
    test "close_admin_console hides dialog", %{conn: conn} do
      nick = "AcCls#{uid()}"
      make_admin(nick)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_admin_console")
      render_click(view, "close_admin_console")
      html = render(view)
      refute html =~ "admin-console-dialog"
    end
  end

  describe "command execution" do
    test "executes valid commands and shows results", %{conn: conn} do
      nick = "AcExe#{uid()}"
      make_admin(nick)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_admin_console")
      render_submit(view, "execute_admin_console", %{"input" => "/help\n/help nick"})
      html = render(view)
      assert html =~ "admin-console-results"
      assert html =~ "[OK]"
    end

    test "shows error for unknown commands", %{conn: conn} do
      nick = "AcUnk#{uid()}"
      make_admin(nick)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_admin_console")
      render_submit(view, "execute_admin_console", %{"input" => "/xyznotexist"})
      html = render(view)
      assert html =~ "[ERR]"
    end

    test "skips comments and empty lines", %{conn: conn} do
      nick = "AcCmt#{uid()}"
      make_admin(nick)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_admin_console")

      render_submit(view, "execute_admin_console", %{
        "input" => "# this is a comment\n\n/help"
      })

      html = render(view)
      # Only 1 result (the /help command), comments and blanks are skipped
      assert html =~ "1 commands"
      assert html =~ "[OK]"
      refute html =~ "this is a comment"
    end

    test "rejects non-command lines", %{conn: conn} do
      nick = "AcMsg#{uid()}"
      make_admin(nick)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_admin_console")
      render_submit(view, "execute_admin_console", %{"input" => "just a message"})
      html = render(view)
      assert html =~ "[ERR]"
      assert html =~ "Not a command"
    end
  end

  describe "context tracking" do
    test "join updates active_channel for subsequent commands", %{conn: conn} do
      nick = "AcCtx#{uid()}"
      make_admin(nick)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      channel = "#acctx#{uid()}"

      render_click(view, "open_admin_console")

      # /topic and /mode depend on active_channel being set by /join
      render_submit(view, "execute_admin_console", %{
        "input" => "/join #{channel}\n/topic Test topic\n/mode +tn"
      })

      html = render(view)
      refute html =~ "[ERR]"
      assert html =~ "Joined #{channel}"
      assert html =~ "Topic set:"
      assert html =~ "Mode set:"
    end

    test "chanserv register works after join with identified user", %{conn: conn} do
      nick = "AcCsR#{uid()}"
      make_admin(nick)
      NickServ.register(nick, "pass123")
      NickServ.identify(nick, "pass123")

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      channel = "#accsr#{uid()}"

      render_click(view, "open_admin_console")

      render_submit(view, "execute_admin_console", %{
        "input" => "/join #{channel}\n/cs register"
      })

      html = render(view)
      refute html =~ "[ERR]"
      assert html =~ "Joined #{channel}"
      assert html =~ "registered"
    end
  end

  describe "clear results" do
    test "clear_admin_console removes results", %{conn: conn} do
      nick = "AcClr#{uid()}"
      make_admin(nick)
      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_admin_console")
      render_submit(view, "execute_admin_console", %{"input" => "/help"})
      html = render(view)
      assert html =~ "admin-console-results"

      render_click(view, "clear_admin_console")
      html = render(view)
      refute html =~ "admin-console-results"
    end
  end
end
