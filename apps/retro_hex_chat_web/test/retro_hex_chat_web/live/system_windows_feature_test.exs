defmodule RetroHexChatWeb.SystemWindowsFeatureTest do
  @moduledoc """
  Behaviour contract for the runtime inspection windows.

  These windows read the node the suite itself is running on, so the assertions
  target facts that are true of any BEAM running this application — the
  emulator banner, a process that is always registered, this application being
  loaded — rather than fixed numbers that would differ per machine.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  describe "System Overview window" do
    test "shows the node's banner, versions, limits and memory split", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "system_home")

      html = render(view)

      assert html =~ "Erlang/OTP"
      assert html =~ "System limits"
      assert html =~ "Run queues"
      assert html =~ "Total usage:"
      assert html =~ "elixir"
    end

    test "refreshing re-reads the vitals without reopening the window", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "system_home")

      assert view |> element("[data-testid='system-home-refresh']") |> render_click() =~
               "System limits"
    end
  end

  describe "runtime listings" do
    test "the processes window lists processes and can be filtered", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "system_processes")

      assert render(view) =~ "code_server"

      html =
        view
        |> form("#system-processes-dialog-search", %{"search" => "zzz_no_such_process_zzz"})
        |> render_change()

      assert html =~ "No processes matched"
    end

    test "the applications window finds this very application", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "system_applications")

      html =
        view
        |> form("#system-applications-dialog-search", %{"search" => "retro_hex_chat"})
        |> render_change()

      assert html =~ "retro_hex_chat"
    end

    test "the ETS window reports table memory in bytes", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "system_ets")

      html = render(view)

      assert html =~ "ETS tables"
      assert html =~ ~r/\d+(\.\d+)? (B|KB|MB)/
    end

    test "clicking a sortable heading reorders without losing the filter", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "system_processes")

      view
      |> form("#system-processes-dialog-search", %{"search" => "gen_server"})
      |> render_change()

      html =
        view
        |> element("#system-processes-dialog-browser [phx-value-column='memory']")
        |> render_click()

      assert html =~ "gen_server"
    end

    test "every listing window opens", %{conn: conn} do
      view = connect_admin(conn)

      for source <- ~w(processes ports sockets ets applications) do
        open(view, "system_#{source}")

        assert has_element?(view, "[data-testid='system-#{source}-window']"),
               "the #{source} window did not open"
      end
    end
  end

  describe "Oban Health window" do
    test "opens with grouped tabs for every Oban contract", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "system_oban")

      html = render(view)

      assert html =~ "Oban health"
      assert html =~ "Overview"
      assert html =~ "Queues"
      assert html =~ "Bots"
      assert html =~ "Maintenance"
      assert html =~ "Previews"
      assert html =~ "Persistence"
      assert html =~ "Queues by state"
      assert html =~ "Recent jobs"
      assert html =~ "RSS feed coverage"
      assert html =~ "Bot schedule coverage"
      assert html =~ "Bot event log jobs"
      assert html =~ "Attachment orphan cleanup"
      assert html =~ "Trusted device expiry"
      assert html =~ "Chat device session cleanup"
      assert html =~ "Runtime stale cleanup"
      assert html =~ "Channel mute expiry"
      assert html =~ "Global mute expiry"
      assert html =~ "Ignore expired cleanup"
      assert html =~ "Link preview cache"
      assert html =~ "Retrying"
      assert html =~ "Final failures"
      assert html =~ "Preference persistence"
      assert has_element?(view, "[data-testid='system-oban-window']")
      assert has_element?(view, "#system-oban-dialog-tabs[data-active-tab='overview']")
      assert has_element?(view, "[data-testid='system-oban-tab-overview'][aria-selected='true']")
      refute has_element?(view, "[data-testid='system-oban-tabpanel-overview'].hidden")
      assert has_element?(view, "[data-testid='system-oban-tabpanel-queues'].hidden")
    end

    test "switches Oban sections with tabs", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "system_oban")

      html =
        view
        |> element("[data-testid='system-oban-tab-queues']")
        |> render_click()

      assert html =~ "Queues by state"
      assert html =~ "Recent jobs"
      assert has_element?(view, "#system-oban-dialog-tabs[data-active-tab='queues']")
      assert has_element?(view, "[data-testid='system-oban-tab-queues'][aria-selected='true']")
      assert has_element?(view, "[data-testid='system-oban-tabpanel-overview'].hidden")
      refute has_element?(view, "[data-testid='system-oban-tabpanel-queues'].hidden")

      html =
        view
        |> element("[data-testid='system-oban-tab-bots']")
        |> render_click()

      assert html =~ "RSS feed coverage"
      assert html =~ "Bot schedule coverage"
      assert html =~ "Bot event log jobs"
      assert has_element?(view, "#system-oban-dialog-tabs[data-active-tab='bots']")

      html =
        view
        |> element("[data-testid='system-oban-tab-maintenance']")
        |> render_click()

      assert html =~ "Maintenance sweeps"
      assert html =~ "Attachment orphan cleanup"
      assert html =~ "Trusted device expiry"
      assert html =~ "Chat device session cleanup"
      assert html =~ "Runtime stale cleanup"
      assert html =~ "Channel mute expiry"
      assert html =~ "Global mute expiry"
      assert html =~ "Ignore expired cleanup"
      assert has_element?(view, "#system-oban-dialog-tabs[data-active-tab='maintenance']")

      html =
        view
        |> element("[data-testid='system-oban-tab-previews']")
        |> render_click()

      assert html =~ "Link preview cache"
      assert html =~ "Retrying"
      assert html =~ "Final failures"
      assert has_element?(view, "#system-oban-dialog-tabs[data-active-tab='previews']")

      html =
        view
        |> element("[data-testid='system-oban-tab-persistence']")
        |> render_click()

      assert html =~ "Preference persistence"
      assert has_element?(view, "#system-oban-dialog-tabs[data-active-tab='persistence']")
    end

    test "refreshing re-reads the Oban snapshot", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "system_oban")

      assert view |> element("[data-testid='system-oban-refresh']") |> render_click() =~
               "Oban health"
    end

    test "recent Oban jobs can be filtered by state, queue and worker", %{conn: conn} do
      view = connect_admin(conn)
      open(view, "system_oban")

      view
      |> element("[data-testid='system-oban-tab-queues']")
      |> render_click()

      view
      |> form("#system-oban-dialog-filter", %{
        "filter" => "all",
        "queue" => "queue-that-does-not-exist",
        "worker" => "WorkerThatDoesNotExist"
      })
      |> render_change()

      html = render_async(view)

      assert html =~ "No jobs matched this filter"
    end
  end

  describe "authorization" do
    test "a non-admin cannot open a runtime window", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PlainUser", pre_identified: true), "/chat")

      render_click(view, "toolbar_action", %{"action" => "open_system_processes"})

      refute has_element?(view, "[data-testid='system-processes-window']")
    end
  end

  defp connect_admin(conn) do
    {:ok, view, _html} = live(chat_conn(conn, "TestAdmin", pre_identified: true), "/chat")
    view
  end

  defp open(view, action) do
    render_click(view, "toolbar_action", %{"action" => "open_#{action}"})
    render_async(view)
  end
end
