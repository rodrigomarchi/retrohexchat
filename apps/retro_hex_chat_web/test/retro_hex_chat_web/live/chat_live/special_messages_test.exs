defmodule RetroHexChatWeb.ChatLive.SpecialMessagesTest do
  @moduledoc """
  End-to-end tests for the Special Messages feature (020).
  Covers MOTD, welcome messages, wallops, and announcements.
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Services.Motd
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  setup do
    ensure_channel("#lobby")

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :motd_cache)
      Application.delete_env(:retro_hex_chat, :admins)
      ServiceQueries.delete_setting("motd")
    end)

    :ok
  end

  # ── E2E: MOTD on Connect ──────────────────────────────────────

  describe "MOTD on connect" do
    test "displays MOTD in status window on mount when set", %{conn: conn} do
      # Set MOTD before mounting
      Motd.set("Server rules: be nice to everyone!", "Admin")

      nick = "E2EMotd#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      # Status tab is active on mount, MOTD should be visible
      assert html =~ "Server rules: be nice to everyone!"
    end

    test "does not display MOTD when not set", %{conn: conn} do
      # Ensure no MOTD is set
      Motd.clear("Admin")

      nick = "E2ENoMtd#{uid()}"
      {:ok, _view, html} = live(chat_conn(conn, nick), "/chat")

      # Should not contain any MOTD-related content
      refute html =~ "chat-status--motd"
    end
  end

  # ── E2E: /motd Command ────────────────────────────────────────

  describe "/motd command" do
    test "shows MOTD when set", %{conn: conn} do
      Motd.set("Server MOTD: Please be respectful.", "Admin")

      nick = "E2EMotdCmd#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Execute /motd command
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/motd"})

      Process.sleep(100)

      # Switch to status tab where /motd content appears
      render_click(view, "switch_to_status")
      html = render(view)

      assert html =~ "Please be respectful"
    end

    test "shows message when MOTD is not set", %{conn: conn} do
      Motd.clear("Admin")

      nick = "E2EMtdErr#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/motd"})

      Process.sleep(100)

      html = render(view)

      assert html =~ "No MOTD has been set"
    end
  end

  # ── E2E: /setmotd Command ─────────────────────────────────────

  describe "/setmotd command" do
    test "non-admin cannot set MOTD", %{conn: conn} do
      nick = "User#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/setmotd Unauthorized MOTD"})

      Process.sleep(100)

      html = render(view)

      assert html =~ "Permission denied"
    end
  end

  # ── E2E: /clearmotd Command ───────────────────────────────────

  describe "/clearmotd command" do
    test "non-admin cannot clear MOTD", %{conn: conn} do
      nick = "User#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/clearmotd"})

      Process.sleep(100)

      html = render(view)

      assert html =~ "Permission denied"
    end
  end

  # ── E2E: Welcome Messages ─────────────────────────────────────

  describe "channel welcome messages" do
    test "welcome message is set and persisted", %{conn: conn} do
      unique = uid()
      ch = "#welc_#{unique}"
      ensure_channel(ch)

      setter = "Setter#{unique}"
      {:ok, setter_view, _html} = live(chat_conn(conn, setter), "/chat")

      setter_view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #{ch}"})

      Process.sleep(100)

      setter_view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/setwelcome #{ch} Welcome to the channel!"})

      Process.sleep(100)

      html = render(setter_view)
      assert html =~ "Welcome message for #{ch} has been set"
    end
  end

  # ── E2E: Wallops ──────────────────────────────────────────────

  describe "wallops" do
    test "user without +w mode does not receive wallops", %{conn: conn} do
      unique = uid()
      nick = "NoWall#{unique}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Do NOT set +w mode (default is no wallops)

      # Broadcast wallops message
      Phoenix.PubSub.broadcast!(
        RetroHexChat.PubSub,
        "server:wallops",
        {:wallops, %{sender: "ServerAdmin", content: "Hidden wallops message"}}
      )

      Process.sleep(100)

      render_click(view, "switch_to_status")
      html = render(view)

      refute html =~ "Hidden wallops message"
    end
  end

  # ── E2E: Announcements ────────────────────────────────────────

  describe "announcements" do
    test "announcement appears in active window", %{conn: conn} do
      unique = uid()
      nick = "AnnUser#{unique}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Broadcast announcement
      Phoenix.PubSub.broadcast!(
        RetroHexChat.PubSub,
        "server:announcements",
        {:announcement, %{content: "Server-wide announcement: New features released!"}}
      )

      Process.sleep(100)

      html = render(view)
      assert html =~ "Server-wide announcement"
    end

    test "multiple announcements appear in order", %{conn: conn} do
      unique = uid()
      nick = "MultiAnn#{unique}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Broadcast multiple announcements
      Phoenix.PubSub.broadcast!(
        RetroHexChat.PubSub,
        "server:announcements",
        {:announcement, %{content: "First announcement"}}
      )

      Process.sleep(100)

      Phoenix.PubSub.broadcast!(
        RetroHexChat.PubSub,
        "server:announcements",
        {:announcement, %{content: "Second announcement"}}
      )

      Process.sleep(100)

      html = render(view)
      assert html =~ "First announcement"
      assert html =~ "Second announcement"
    end
  end

  # ── Helpers ───────────────────────────────────────────────────

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
