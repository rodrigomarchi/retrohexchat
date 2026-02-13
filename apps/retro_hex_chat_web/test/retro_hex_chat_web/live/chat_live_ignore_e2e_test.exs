defmodule RetroHexChatWeb.ChatLiveIgnoreE2ETest do
  @moduledoc """
  End-to-end tests for the Ignore System feature (006).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ══════════════════════════════════════════════════════════════
  # US1 — Ignore and Unignore a User
  # ══════════════════════════════════════════════════════════════

  describe "US1: /ignore and /unignore" do
    test "/ignore adds user and confirms", %{conn: conn} do
      view = connect_user(conn, "E2EIg#{uid()}")
      submit_command(view, "/ignore SpamBot")

      html = render(view)
      assert html =~ "SpamBot is now ignored"
    end

    test "/unignore removes user and confirms", %{conn: conn} do
      view = connect_user(conn, "E2EUn#{uid()}")
      submit_command(view, "/ignore SpamBot")
      submit_command(view, "/unignore SpamBot")

      html = render(view)
      assert html =~ "SpamBot is no longer ignored"
    end

    test "/ignore bare shows empty list", %{conn: conn} do
      view = connect_user(conn, "E2ELst#{uid()}")
      submit_command(view, "/ignore")

      html = render(view)
      assert html =~ "Your ignore list is empty"
    end

    test "/ignore bare shows non-empty list", %{conn: conn} do
      view = connect_user(conn, "E2ELs2#{uid()}")
      submit_command(view, "/ignore SpamBot")
      submit_command(view, "/ignore")

      html = render(view)
      assert html =~ "SpamBot"
      assert html =~ "[all]"
    end

    test "self-ignore error", %{conn: conn} do
      nick = "E2ESelf#{uid()}"
      view = connect_user(conn, nick)
      submit_command(view, "/ignore #{nick}")

      html = render(view)
      assert html =~ "cannot ignore yourself"
    end

    test "channel messages from ignored user are hidden", %{conn: conn} do
      view = connect_user(conn, "E2EFlt#{uid()}")
      submit_command(view, "/ignore SpamBot")
      send_message(view, "SpamBot", "invisible spam", "#lobby")

      html = render(view)
      refute html =~ "invisible spam"
    end

    test "messages from non-ignored user are visible", %{conn: conn} do
      view = connect_user(conn, "E2EOk#{uid()}")
      submit_command(view, "/ignore SpamBot")
      send_message(view, "FriendlyUser", "hello friend", "#lobby")

      html = render(view)
      assert html =~ "hello friend"
    end

    test "system messages from ignored user remain visible", %{conn: conn} do
      view = connect_user(conn, "E2ESys#{uid()}")
      submit_command(view, "/ignore SpamBot")

      send(view.pid, %{
        event: "new_message",
        payload: %{
          id: "sys-#{uid()}",
          author: "System",
          content: "SpamBot has joined #lobby",
          type: :system,
          channel: "#lobby",
          timestamp: DateTime.utc_now()
        }
      })

      html = render(view)
      assert html =~ "SpamBot has joined #lobby"
    end

    test "nick rename tracking", %{conn: conn} do
      view = connect_user(conn, "E2ERen#{uid()}")
      ensure_channel("#lobby")
      submit_command(view, "/ignore OldNick")

      send(view.pid, {:nick_changed, %{old_nick: "OldNick", new_nick: "NewNick"}})
      send_message(view, "NewNick", "still hidden", "#lobby")

      html = render(view)
      refute html =~ "still hidden"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US2 — Per-Type Ignore
  # ══════════════════════════════════════════════════════════════

  describe "US2: type-specific ignore" do
    test "/ignore nick pms hides PMs but allows channel msgs", %{conn: conn} do
      view = connect_user(conn, "E2ETpm#{uid()}")
      submit_command(view, "/ignore SpamBot pms")

      send_message(view, "SpamBot", "visible channel", "#lobby")
      html = render(view)
      assert html =~ "visible channel"
    end

    test "/ignore nick actions hides actions", %{conn: conn} do
      view = connect_user(conn, "E2ETac#{uid()}")
      submit_command(view, "/ignore SpamBot actions")

      send_message(view, "SpamBot", "visible regular", "#lobby")
      html = render(view)
      assert html =~ "visible regular"

      send_action(view, "SpamBot", "dances", "#lobby")
      html = render(view)
      refute html =~ "dances"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US3 — Timed Ignore
  # ══════════════════════════════════════════════════════════════

  describe "US3: timed ignore" do
    test "timed ignore and expiry", %{conn: conn} do
      view = connect_user(conn, "E2ETim#{uid()}")
      submit_command(view, "/ignore SpamBot all 5m")

      html = render(view)
      assert html =~ "SpamBot is now ignored"

      # Simulate expiry
      send(view.pid, {:ignore_expired, "SpamBot"})
      html = render(view)
      assert html =~ "no longer ignored (timer expired)"

      # Messages now visible
      send_message(view, "SpamBot", "visible after expiry", "#lobby")
      html = render(view)
      assert html =~ "visible after expiry"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US4 — Dialog
  # ══════════════════════════════════════════════════════════════

  describe "US4: ignore list dialog" do
    test "Ctrl+Shift+G opens and close button closes", %{conn: conn} do
      view = connect_user(conn, "E2EDlg#{uid()}")

      render_keydown(view, "window_keydown", %{
        "key" => "g",
        "ctrlKey" => true,
        "shiftKey" => true
      })

      html = render(view)
      assert html =~ "ignore-list-dialog"

      render_click(view, "close_ignore_dialog")
      html = render(view)
      refute html =~ "ignore-list-dialog"
    end

    test "dialog shows entries and supports remove", %{conn: conn} do
      view = connect_user(conn, "E2EDe#{uid()}")
      submit_command(view, "/ignore SpamBot")

      render_click(view, "open_ignore_dialog")
      html = render(view)
      assert html =~ "SpamBot"
      assert html =~ "Permanent"

      render_click(view, "ignore_select", %{"nickname" => "SpamBot"})
      render_click(view, "ignore_dialog_remove")

      html = render(view)
      assert html =~ "SpamBot is no longer ignored"
    end

    test "add via dialog", %{conn: conn} do
      view = connect_user(conn, "E2EDad#{uid()}")

      render_click(view, "open_ignore_dialog")
      render_click(view, "ignore_dialog_add")

      html = render(view)
      assert html =~ "ignore-add-dialog"

      view
      |> element("[data-testid=ignore-add-dialog] form")
      |> render_submit(%{"nickname" => "Troll", "type" => "pms", "duration" => ""})

      html = render(view)
      assert html =~ "Troll is now ignored"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Context Menu
  # ══════════════════════════════════════════════════════════════

  describe "context menu ignore" do
    test "context_ignore adds and filters", %{conn: conn} do
      view = connect_user(conn, "E2ECx#{uid()}")

      render_click(view, "context_ignore", %{"nick" => "SpamBot"})
      html = render(view)
      assert html =~ "SpamBot is now ignored"

      send_message(view, "SpamBot", "invisible via ctx", "#lobby")
      html = render(view)
      refute html =~ "invisible via ctx"
    end

    test "context_unignore removes", %{conn: conn} do
      view = connect_user(conn, "E2ECxU#{uid()}")
      submit_command(view, "/ignore SpamBot")

      render_click(view, "context_unignore", %{"nick" => "SpamBot"})
      html = render(view)
      assert html =~ "SpamBot is no longer ignored"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Private Helpers
  # ══════════════════════════════════════════════════════════════

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")
    view
  end

  defp submit_command(view, command) do
    view |> element("form.chat-input-form") |> render_submit(%{"input" => command})
  end

  defp send_message(view, author, content, channel) do
    send(view.pid, %{
      event: "new_message",
      payload: %{
        id: "msg-#{uid()}",
        author: author,
        content: content,
        type: :message,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    })
  end

  defp send_action(view, author, content, channel) do
    send(view.pid, %{
      event: "new_message",
      payload: %{
        id: "act-#{uid()}",
        author: author,
        content: content,
        type: :action,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    })
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp uid do
    val = System.unique_integer([:positive])
    Process.put(:last_uid, val)
    val
  end
end
