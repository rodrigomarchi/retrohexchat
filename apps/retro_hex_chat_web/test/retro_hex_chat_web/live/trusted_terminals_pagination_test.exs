defmodule RetroHexChatWeb.TrustedTerminalsPaginationTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.App.TrustedDeviceCookie
  alias RetroHexChatWeb.ChatLive.Components.TrustedTerminalsDialog

  # Both lists page at these sizes; the seed is one row past the larger of them
  # so a single fixture proves two pages exist for each.
  @sessions_page_size 25
  @events_page_size 20
  @seeded 26

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "the security lists page" do
    test "opens on the first page and offers the rest", %{conn: conn} do
      %{view: view} = open_window(conn)
      html = render(view)

      assert count_sessions(html) == @sessions_page_size
      assert count_events(html) == @events_page_size

      assert has_element?(view, load_more("sessions"))
      assert has_element?(view, load_more("events"))
    end

    test "the load-more button brings the next page and closes the list", %{conn: conn} do
      %{view: view} = open_window(conn)

      html = view |> element(load_more("events")) |> render_click()

      # 26 session.started events plus the grant event the fixture logs, so the
      # second page lands short of a full page and the list is exhausted.
      assert count_events(html) > @events_page_size
      refute has_element?(view, load_more("events"))
      assert has_element?(view, ~s([data-testid="trusted-events-end"]))
    end

    test "paging one list leaves the other where it was", %{conn: conn} do
      %{view: view} = open_window(conn)

      html = view |> element(load_more("events")) |> render_click()

      assert count_sessions(html) == @sessions_page_size,
             "the sessions list must not reload because the events list paged"
    end

    # The window refreshes its snapshot on open and after every mutation, and a
    # LiveComponent's update/2 runs on every parent render. Refreshing there
    # unconditionally would reset both streams, so a reader who loaded three
    # pages would silently drop back to one on the next unrelated parent render.
    test "a parent re-render does not discard the pages already loaded", %{conn: conn} do
      %{view: view} = open_window(conn)

      view |> element(load_more("events")) |> render_click()
      loaded = count_events(render(view))

      Phoenix.LiveView.send_update(view.pid, TrustedTerminalsDialog,
        id: TrustedTerminalsDialog.id(),
        timezone: "America/Sao_Paulo"
      )

      assert count_events(render(view)) == loaded
    end

    # The counterpart: a mutation genuinely changes the list, so it must reset.
    test "ending a session reloads the list from the first page", %{conn: conn} do
      %{view: view} = open_window(conn)

      view |> element(load_more("events")) |> render_click()
      assert count_events(render(view)) > @events_page_size

      view
      |> element(~s([data-testid="trusted-terminals-refresh"]))
      |> render_click()

      assert count_events(render(view)) == @events_page_size
    end
  end

  defp open_window(conn) do
    nick = "Page#{uid()}"
    NickServ.register(nick, "pass123")

    {:ok, %{device: device, cookie_value: cookie}} =
      TrustedDevices.remember_nick(nil, nick, label: "Desktop terminal", actor_nickname: nick)

    # Each session start also writes one security event, so one seed fills both
    # lists past their first page.
    for _ <- 1..@seeded do
      {:ok, _session} = TrustedDevices.record_session_start(nick, device.id, %{})
    end

    {:ok, view, _html} =
      conn
      |> put_req_cookie(TrustedDeviceCookie.name(), cookie)
      |> chat_conn(nick, pre_identified: true)
      |> live(~p"/chat")

    render_click(view, "toolbar_action", %{"action" => "open_trusted_terminals_dialog"})

    %{view: view, nick: nick, device: device}
  end

  defp load_more(list), do: ~s([data-testid="trusted-#{list}-load-more"])

  defp count_sessions(html), do: count_rows(html, ~r/data-testid="trusted-session-\d+"/)
  defp count_events(html), do: count_rows(html, ~r/data-testid="trusted-event-\d+"/)

  defp count_rows(html, regex), do: regex |> Regex.scan(html) |> length()

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
