defmodule RetroHexChatWeb.Site.AddressBridgeTest do
  @moduledoc """
  The address bar and the desktop say the same thing: the window in front
  has the address, a window brought forward takes it, closing one hands it
  to what is behind, and a channel switched in front of the reader gets its
  own `/c/` address — never while a page of the site is in front.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Admin.BanCache
  alias RetroHexChat.Channels.{Server, Supervisor}

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  defp open_channel do
    channel = "#bridge-#{uid()}"
    {:ok, pid} = Supervisor.start_child(channel)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    {:ok, _} = Server.join(channel, "Host#{uid()}")
    channel
  end

  test "a page opens in front of the chat and owns the address", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/features")

    assert assigns(view).focused_doc == :site

    assert has_element?(
             view,
             ~s([data-testid="document-window-site"][data-window-initial-focus="true"])
           )
  end

  test "bringing a window forward hands it the address, without a new history entry", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, "/features")

    render_hook(view, "window_focused", %{"id" => "chat"})
    assert_patch(view, "/c/lobby")

    render_hook(view, "window_focused", %{"id" => "doc-site"})
    assert_patch(view, "/features")
  end

  test "moving to another page reuses the page's window", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/features")

    render_patch(view, "/faq")

    assert assigns(view).docs[:site].address == "/faq"
    assert has_element?(view, "#faq-heading")
    refute has_element?(view, "#features-heading")
  end

  test "help opens beside the page, and closing it goes back to the page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/faq")

    render_patch(view, "/chat/help/cmd-join")
    assert assigns(view).doc_order == [:help, :site]

    render_hook(view, "window_closed", %{"id" => "doc-help"})
    assert_patch(view, "/faq")
    refute has_element?(view, ~s([data-testid="document-window-help"]))
  end

  test "closing the last page goes back to the conversation in front", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/faq")

    render_hook(view, "window_closed", %{"id" => "doc-site"})

    assert_patch(view, "/c/lobby")
    assert assigns(view).docs == %{}
  end

  test "a channel switched in front of the reader takes its address", %{conn: conn} do
    channel = open_channel()
    {:ok, view, _html} = live(conn, "/c/lobby")

    render_hook(view, "switch_channel", %{"channel" => channel})

    assert_patch(view, "/c/" <> String.trim_leading(channel, "#"))
  end

  test "a channel switched behind a page leaves the page's address alone", %{conn: conn} do
    channel = open_channel()
    {:ok, view, _html} = live(conn, "/features")

    render_hook(view, "switch_channel", %{"channel" => channel})

    _ = render(view)
    assert assigns(view).session.active_channel == channel
    # A patch would have run `handle_params`, which records every address.
    assert assigns(view).current_address == "/features"
  end

  test "an address in another language is the same window in that language", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/pt-BR/features")

    assert html =~ ~s(lang="pt-BR")
  end

  # The View menu sits in the window's menu bar, outside the viewer component
  # it drives; for a visitor it is reading, never something to sign in for.
  test "the help viewer's View menu switches its tab, for a visitor too", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chat/help")

    refute render(view) =~ "Type in the search box to find topics."

    view
    |> element(~s(.app-menu-bar__desktop-menu [data-testid="help-menu-search"]))
    |> render_click()

    assert assigns(view).focused_doc == :help
    assert render(view) =~ "Type in the search box to find topics."
  end

  # A visitor whose chat has no channel in front has the home as the chat's
  # address: closing the Welcome there must not reopen it.
  test "closing the home's Welcome when the chat's address is the home", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "switch_to_status", %{})

    render_hook(view, "window_closed", %{"id" => "doc-site"})

    assert assigns(view).docs == %{}
    assert assigns(view).focused_doc == nil
    refute has_element?(view, ~s([data-testid="document-window-site"]))
  end

  describe "a banned nickname" do
    setup do
      nick = "Banned#{uid()}"
      BanCache.add(nick)
      on_exit(fn -> BanCache.remove(nick) end)
      %{nick: nick}
    end

    test "still reads the site", %{conn: conn, nick: nick} do
      conn = Plug.Test.init_test_session(conn, %{"chat_nickname" => nick})

      assert {:ok, _view, html} = live(conn, "/faq")
      assert html =~ ~s(id="faq-heading")
    end

    test "is sent to the sign-in window from a channel's address", %{conn: conn, nick: nick} do
      conn = Plug.Test.init_test_session(conn, %{"chat_nickname" => nick})

      assert {:error, {:redirect, %{to: "/connect?reason=banned"}}} = live(conn, "/c/lobby")
    end
  end
end
