defmodule RetroHexChatWeb.Site.AddressBridgeTest do
  @moduledoc """
  The address bar and the desktop say the same thing: the page in front has
  the address, a window brought forward hands it its page's, closing a page's
  last window hands it to what is behind, and a channel switched in front of
  the reader gets its own `/c/` address — never while a page of the site is in
  front. A visitor's home is the chat, the home's windows one icon away.
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
             ~s([data-testid="site-windows"][data-window-group-focus="true"] [data-testid="site-window-intro"])
           )
  end

  test "bringing a window forward hands it the address, without a new history entry", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, "/features")

    render_hook(view, "window_focused", %{"id" => "chat"})
    assert_patch(view, "/c/lobby")

    render_hook(view, "window_focused", %{"id" => "site-channels", "slot" => "site"})
    assert_patch(view, "/features")
  end

  # The reader clicked one of the page's own windows: the page is already
  # there, so it is neither loaded again nor laid out again.
  test "a window of the page in front keeps the address and the page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/features")
    loaded = assigns(view).docs[:site]

    render_hook(view, "window_focused", %{"id" => "site-bots", "slot" => "site"})

    assert assigns(view).current_address == "/features"
    assert assigns(view).docs[:site] == loaded
  end

  test "a slot the desktop never named is not a page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/features")
    before = assigns(view)

    render_hook(view, "document_closed", %{"slot" => "no-such-slot"})

    assert assigns(view).docs == before.docs
    assert assigns(view).focused_doc == :site
    assert assigns(view).current_address == "/features"
  end

  test "a bridge event without what it names asks the visitor gate for nothing", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/features")
    before = assigns(view)

    for event <- ~w(window_focused document_closed open_page) do
      render_hook(view, event, %{})
    end

    assert assigns(view).docs == before.docs
    assert assigns(view).current_address == "/features"
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

    render_hook(view, "document_closed", %{"slot" => "help"})
    assert_patch(view, "/faq")
    refute has_element?(view, ~s([data-testid="document-window-help"]))
  end

  test "closing the last page goes back to the conversation in front", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/faq")

    render_hook(view, "document_closed", %{"slot" => "site"})

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

  describe "a visitor's home" do
    test "is the chat in front, the home's windows closed behind it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert assigns(view).focused_doc == nil
      assert %{open?: false} = assigns(view).docs[:site]

      assert has_element?(
               view,
               ~s([data-testid="site-windows"][data-window-group-open="false"])
             )
    end

    test "keeps its address while the chat shows the conversation it opened with", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/")

      render_hook(view, "window_focused", %{"id" => "chat"})

      _ = render(view)
      assert assigns(view).current_address == "/"
    end

    test "opens its windows where they are when the Welcome icon asks", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      render_hook(view, "open_page", %{"id" => "home"})

      assert %{open?: true} = assigns(view).docs[:site]
      assert assigns(view).focused_doc == :site
      assert_push_event(view, "window_command", %{action: "open_group", id: "site"})
    end

    # Only arriving at the home leaves its windows closed. Coming to it from
    # within the desktop — the Start menu's Home, a move back from another
    # page — is asking for it.
    test "opens its windows when the reader comes back to it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      render_patch(view, "/features")

      render_patch(view, "/")

      assert %{open?: true, page: RetroHexChatWeb.Site.Pages.Index} = assigns(view).docs[:site]
      assert assigns(view).focused_doc == :site
    end

    test "opens its windows from the Start menu's Home, already at the home", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element(~s(#chat-start-menu a[href="/"]))
      |> render_click()

      assert %{open?: true} = assigns(view).docs[:site]
      assert assigns(view).focused_doc == :site
    end

    test "in another language, opens in that language", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/pt-BR")
      assert %{open?: false} = assigns(view).docs[:site]

      render_hook(view, "open_page", %{"id" => "home"})

      assert_patch(view, "/pt-BR")
      assert %{open?: true, address: "/pt-BR"} = assigns(view).docs[:site]
    end

    test "puts its windows away when the last one closes, keeping their words", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      render_hook(view, "open_page", %{"id" => "home"})

      render_hook(view, "document_closed", %{"slot" => "site"})

      assert %{open?: false} = assigns(view).docs[:site]
      assert assigns(view).focused_doc == nil
      assert render(view) =~ "Your community isn’t yours."
    end
  end

  describe "a desktop icon" do
    test "opens its page at the page's address", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/c/lobby")

      render_hook(view, "open_page", %{"id" => "faq"})

      assert_patch(view, "/faq")
      assert assigns(view).focused_doc == :site
    end

    test "for the home, from another page, opens the home's windows", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/faq")

      render_hook(view, "open_page", %{"id" => "home"})

      assert_patch(view, "/")
      assert %{open?: true, page: RetroHexChatWeb.Site.Pages.Index} = assigns(view).docs[:site]
    end

    test "naming no page of the site does nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/faq")

      render_hook(view, "open_page", %{"id" => "no-such-page"})

      assert assigns(view).current_address == "/faq"
    end
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
