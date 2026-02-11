defmodule RetroHexChatWeb.ChatLiveNotifyE2ETest do
  @moduledoc """
  End-to-end tests for the Notify List (Buddy List) feature.
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ── E2E: Notify List Window ──────────────────────────────────

  describe "Notify List Window" do
    test "open notify list window via toolbar", %{conn: conn} do
      nick = "E2ENotWin#{System.unique_integer([:positive])}"
      {:ok, view, html} = live(conn, "/chat?nickname=#{nick}")

      # Window should not be visible initially
      refute html =~ "notify-list-window"

      # Open the notify list window
      html = render_click(view, "toggle_notify_list")
      assert html =~ "notify-list-window"
      assert html =~ "Notify List"
    end

    test "close notify list window via toggle", %{conn: conn} do
      nick = "E2ENotCls#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "toggle_notify_list")
      html = render_click(view, "toggle_notify_list")
      refute html =~ "notify-list-window"
    end

    test "notify list window shows empty state", %{conn: conn} do
      nick = "E2ENotEmp#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      html = render_click(view, "toggle_notify_list")
      assert html =~ "notify-list-window"
    end
  end

  # ── E2E: Buddy CRUD Flow ─────────────────────────────────────

  describe "Buddy CRUD Flow" do
    test "add buddy appears in notify list", %{conn: conn} do
      nick = "E2EAdd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add buddy
      render_click(view, "notify_add", %{"nickname" => "E2EBuddy", "note" => "test buddy"})

      # Open window to verify
      html = render_click(view, "toggle_notify_list")
      assert html =~ "notify-entry-E2EBuddy"
      assert html =~ "test buddy"
    end

    test "remove buddy disappears from notify list", %{conn: conn} do
      nick = "E2ERm#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add then remove
      render_click(view, "notify_add", %{"nickname" => "RmBud", "note" => ""})
      render_click(view, "notify_remove", %{"nickname" => "RmBud"})

      # Open window to verify removal
      html = render_click(view, "toggle_notify_list")
      refute html =~ "notify-entry-RmBud"
    end

    test "edit buddy note updates in notify list", %{conn: conn} do
      nick = "E2EEdit#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add and then edit note
      render_click(view, "notify_add", %{"nickname" => "EditBud", "note" => "original"})
      render_click(view, "notify_edit", %{"nickname" => "EditBud", "note" => "updated"})

      # Verify
      html = render_click(view, "toggle_notify_list")
      assert html =~ "updated"
      refute html =~ "original"
    end

    test "select buddy highlights row", %{conn: conn} do
      nick = "E2ESel#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "notify_add", %{"nickname" => "SelBud", "note" => ""})
      render_click(view, "toggle_notify_list")

      html = render_click(view, "notify_select", %{"nickname" => "SelBud"})
      # Navy background for selected row
      assert html =~ "#000080"
    end
  end

  # ── E2E: /notify Commands ─────────────────────────────────────

  describe "/notify Commands" do
    test "/notify opens the notify list window", %{conn: conn} do
      nick = "E2ECmd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/notify"})

      Process.sleep(50)
      html = render(view)
      assert html =~ "notify-list-window"
    end

    test "/notify add creates entry visible in window", %{conn: conn} do
      nick = "E2ECmdAdd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify add CmdBud a note"})

      Process.sleep(50)

      html = render_click(view, "toggle_notify_list")
      assert html =~ "CmdBud"
    end

    test "/notify remove deletes entry", %{conn: conn} do
      nick = "E2ECmdRm#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add then remove via commands
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify add CmdRm"})

      Process.sleep(50)

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify remove CmdRm"})

      Process.sleep(50)

      html = render_click(view, "toggle_notify_list")
      refute html =~ "notify-entry-CmdRm"
    end

    test "/notify list displays entries in status window", %{conn: conn} do
      nick = "E2ECmdLst#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add entries
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify add Bud1"})

      Process.sleep(50)

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify add Bud2"})

      Process.sleep(50)

      # List them
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/notify list"})

      Process.sleep(50)
      html = render(view)
      assert html =~ "Bud1"
      assert html =~ "Bud2"
    end
  end

  # ── E2E: Presence Notifications ───────────────────────────────

  describe "Presence Notifications" do
    test "buddy online notification in status window", %{conn: conn} do
      nick = "E2EPres#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add buddy
      render_click(view, "notify_add", %{"nickname" => "PresBud", "note" => ""})

      # Manually fire debounce (simulates buddy coming online)
      send(view.pid, {:notify_debounce, "PresBud", :online})

      Process.sleep(50)
      html = render(view)
      assert html =~ "PresBud"
      assert html =~ "online"
    end

    test "buddy offline notification in status window", %{conn: conn} do
      nick = "E2EPresOff#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add buddy
      render_click(view, "notify_add", %{"nickname" => "OffPBud", "note" => ""})

      # Manually fire debounce (simulates buddy going offline)
      send(view.pid, {:notify_debounce, "OffPBud", :offline})

      Process.sleep(50)
      html = render(view)
      assert html =~ "OffPBud"
      assert html =~ "offline"
    end
  end

  # ── E2E: Status Tab ──────────────────────────────────────────

  describe "Status Tab" do
    test "status tab always present in tab bar", %{conn: conn} do
      nick = "E2EStat#{System.unique_integer([:positive])}"
      {:ok, _view, html} = live(conn, "/chat?nickname=#{nick}")

      assert html =~ "tab-status"
      assert html =~ "status-messages"
    end
  end

  # ── E2E: Auto-Whois ──────────────────────────────────────────

  describe "Auto-Whois" do
    test "toggle auto-whois and verify whois on buddy connect", %{conn: conn} do
      nick = "E2EAW#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Add buddy and enable auto-whois
      render_click(view, "notify_add", %{"nickname" => "AWBud", "note" => ""})
      render_click(view, "toggle_auto_whois")

      # Fire debounce for online
      send(view.pid, {:notify_debounce, "AWBud", :online})

      Process.sleep(50)
      html = render(view)
      assert html =~ "[Auto-Whois] AWBud"
    end
  end

  # ── E2E: Nick Rename Tracking ─────────────────────────────────

  describe "Nick Rename Tracking" do
    test "tracked buddy rename updates notify list entry", %{conn: conn} do
      nick = "E2ERen#{System.unique_integer([:positive])}"
      ch = "#e2e_ren_#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Join channel
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})

      # Add buddy
      render_click(view, "notify_add", %{"nickname" => "OldBud", "note" => "my pal"})

      # Simulate nick change on the channel
      Phoenix.PubSub.broadcast!(
        RetroHexChat.PubSub,
        "channel:#{ch}",
        {:nick_changed, %{old_nick: "OldBud", new_nick: "NewBud"}}
      )

      Process.sleep(50)

      # Open notify list to verify update
      html = render_click(view, "toggle_notify_list")
      assert html =~ "notify-entry-NewBud"
      assert html =~ "my pal"
      refute html =~ "notify-entry-OldBud"
    end
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
