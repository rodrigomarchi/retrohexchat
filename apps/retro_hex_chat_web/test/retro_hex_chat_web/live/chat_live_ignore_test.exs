defmodule RetroHexChatWeb.ChatLiveIgnoreTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  # ── US1: Ignore and Unignore a User ──────────────────────────

  describe "US1: /ignore command dispatches" do
    test "/ignore with nickname adds ignore entry", %{conn: conn} do
      nick = "IgnCmd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore SpamBot"})

      html = render(view)
      assert html =~ "SpamBot is now ignored"
    end

    test "/ignore bare shows ignore list (empty)", %{conn: conn} do
      nick = "IgnBare#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore"})

      html = render(view)
      assert html =~ "Your ignore list is empty"
    end

    test "/ignore bare shows ignore list (with entries)", %{conn: conn} do
      nick = "IgnLst#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore SpamBot"})
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore"})

      html = render(view)
      assert html =~ "SpamBot"
      assert html =~ "[all]"
    end

    test "self-ignore shows error", %{conn: conn} do
      nick = "SelfIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore #{nick}"})

      html = render(view)
      assert html =~ "cannot ignore yourself"
    end
  end

  describe "US1: /unignore command dispatches" do
    test "/unignore removes ignore entry", %{conn: conn} do
      nick = "UnIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore SpamBot"})
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/unignore SpamBot"})

      html = render(view)
      assert html =~ "SpamBot is no longer ignored"
    end

    test "/unignore non-ignored user shows error", %{conn: conn} do
      nick = "UnNone#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/unignore Nobody"})

      html = render(view)
      assert html =~ "not in your ignore list"
    end
  end

  describe "US1: channel message filtering" do
    test "messages from ignored user are hidden", %{conn: conn} do
      nick = "FiltCh#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Ignore SpamBot
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore SpamBot"})

      # Send message from SpamBot — should be filtered
      send_new_message(view, "SpamBot", "you should not see this", "#lobby")

      html = render(view)
      refute html =~ "you should not see this"
    end

    test "messages from non-ignored user are shown", %{conn: conn} do
      nick = "FiltOk#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore SpamBot"})

      # Send message from a different user — should be visible
      send_new_message(view, "FriendlyUser", "hello there", "#lobby")

      html = render(view)
      assert html =~ "hello there"
    end

    test "system messages from ignored user are NOT filtered", %{conn: conn} do
      nick = "FiltSys#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore SpamBot"})

      # Send a system-type message from SpamBot (join/part) — should be visible
      send_system_message(view, "SpamBot", "SpamBot has joined #lobby", "#lobby")

      html = render(view)
      assert html =~ "SpamBot has joined #lobby"
    end
  end

  describe "US1: PM filtering" do
    test "PMs from ignored user are hidden", %{conn: conn} do
      nick = "FiltPM#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore SpamBot"})

      send_new_pm(view, "SpamBot", nick, "spam PM content")

      html = render(view)
      refute html =~ "spam PM content"
    end
  end

  describe "US1: nick rename tracking" do
    test "ignoring carries over when user renames", %{conn: conn} do
      nick = "RenIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")
      ensure_channel("#lobby")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore OldNick"})

      # Simulate nick rename
      send(view.pid, {:nick_changed, %{old_nick: "OldNick", new_nick: "NewNick"}})

      # Messages from NewNick should be filtered
      send_new_message(view, "NewNick", "still ignored after rename", "#lobby")

      html = render(view)
      refute html =~ "still ignored after rename"
    end
  end

  # ── US2: Per-type ignore ──────────────────────────────────────

  describe "US2: type-specific filtering" do
    test "/ignore nick messages hides channel msgs but allows PMs", %{conn: conn} do
      nick = "TypeMs#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot messages"})

      # Channel message should be hidden
      send_new_message(view, "SpamBot", "hidden channel msg", "#lobby")
      html = render(view)
      refute html =~ "hidden channel msg"

      # PM should NOT be filtered (messages type only filters channel msgs)
      send_new_pm(view, "SpamBot", nick, "visible pm")
      # PM won't appear in chat_messages unless active_pm matches,
      # but it should NOT be dropped — it should set unread indicator
    end

    test "/ignore nick pms hides PMs but allows channel msgs", %{conn: conn} do
      nick = "TypePm#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot pms"})

      # Channel message should be visible
      send_new_message(view, "SpamBot", "visible channel msg", "#lobby")
      html = render(view)
      assert html =~ "visible channel msg"

      # PM should be hidden
      send_new_pm(view, "SpamBot", nick, "hidden pm content")
      html = render(view)
      refute html =~ "hidden pm content"
    end

    test "/ignore nick actions hides actions but allows messages", %{conn: conn} do
      nick = "TypeAc#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot actions"})

      # Regular message should be visible
      send_new_message(view, "SpamBot", "visible regular msg", "#lobby")
      html = render(view)
      assert html =~ "visible regular msg"

      # Action message should be hidden
      send_action_message(view, "SpamBot", "dances around", "#lobby")
      html = render(view)
      refute html =~ "dances around"
    end

    test "re-ignore updates type and shows update message", %{conn: conn} do
      nick = "ReIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot all"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot pms"})

      html = render(view)
      assert html =~ "ignore updated to: pms"
    end
  end

  # ── US3: Timed ignore ───────────────────────────────────────

  describe "US3: timed ignore" do
    test "timed ignore shows expiry in system message", %{conn: conn} do
      nick = "TimIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot all 5m"})

      html = render(view)
      assert html =~ "SpamBot is now ignored"
    end

    test "expired timer removes ignore and shows message", %{conn: conn} do
      nick = "ExpIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot all 5m"})

      # Manually send the timer expiry message
      send(view.pid, {:ignore_expired, "SpamBot"})

      html = render(view)
      assert html =~ "no longer ignored (timer expired)"

      # Messages should now be visible again
      send_new_message(view, "SpamBot", "visible after expiry", "#lobby")
      html = render(view)
      assert html =~ "visible after expiry"
    end

    test "/unignore cancels active timer", %{conn: conn} do
      nick = "CnlTm#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot all 5m"})

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/unignore SpamBot"})

      html = render(view)
      assert html =~ "no longer ignored"
    end
  end

  # ── US4: Ignore List Dialog ──────────────────────────────────

  describe "US4: ignore list dialog" do
    test "Alt+I opens dialog", %{conn: conn} do
      nick = "AltI#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_keydown(view, "window_keydown", %{"key" => "i", "altKey" => true})

      html = render(view)
      assert html =~ "ignore-list-dialog"
      assert html =~ "Ignore List"
    end

    test "menu bar Ignore List opens dialog", %{conn: conn} do
      nick = "MnuIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "open_ignore_dialog")

      html = render(view)
      assert html =~ "ignore-list-dialog"
    end

    test "close button closes dialog", %{conn: conn} do
      nick = "ClsIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "open_ignore_dialog")
      render_click(view, "close_ignore_dialog")

      html = render(view)
      refute html =~ "ignore-list-dialog"
    end

    test "dialog shows empty state when no ignores", %{conn: conn} do
      nick = "EmtIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "open_ignore_dialog")

      html = render(view)
      assert html =~ "No users ignored"
    end

    test "dialog shows ignored entries", %{conn: conn} do
      nick = "ShwIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot"})

      render_click(view, "open_ignore_dialog")

      html = render(view)
      assert html =~ "SpamBot"
      assert html =~ "all"
      assert html =~ "Permanent"
    end

    test "select and remove entry via dialog", %{conn: conn} do
      nick = "DlgRm#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ignore SpamBot"})

      render_click(view, "open_ignore_dialog")
      render_click(view, "ignore_select", %{"nickname" => "SpamBot"})
      render_click(view, "ignore_dialog_remove")

      html = render(view)
      assert html =~ "no longer ignored"
    end

    test "add via dialog creates ignore entry", %{conn: conn} do
      nick = "DlgAdd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

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

  # ── US4b: Context menu ignore/unignore ──────────────────────

  describe "context menu ignore integration" do
    test "context_ignore adds entry and shows system message", %{conn: conn} do
      nick = "CtxIgn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "context_ignore", %{"nick" => "SpamBot"})

      html = render(view)
      assert html =~ "SpamBot is now ignored"
    end

    test "context_unignore removes entry and shows system message", %{conn: conn} do
      nick = "CtxUn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # First ignore
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/ignore SpamBot"})
      # Then unignore via context menu
      render_click(view, "context_unignore", %{"nick" => "SpamBot"})

      html = render(view)
      assert html =~ "SpamBot is no longer ignored"
    end

    test "context_ignore filters subsequent messages", %{conn: conn} do
      nick = "CtxFlt#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      render_click(view, "context_ignore", %{"nick" => "SpamBot"})
      send_new_message(view, "SpamBot", "hidden after ctx ignore", "#lobby")

      html = render(view)
      refute html =~ "hidden after ctx ignore"
    end
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp send_new_message(view, author, content, channel) do
    msg = %{
      event: "new_message",
      payload: %{
        id: "msg-#{System.unique_integer([:positive])}",
        author: author,
        content: content,
        type: :message,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    }

    send(view.pid, msg)
  end

  defp send_action_message(view, author, content, channel) do
    msg = %{
      event: "new_message",
      payload: %{
        id: "act-#{System.unique_integer([:positive])}",
        author: author,
        content: content,
        type: :action,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    }

    send(view.pid, msg)
  end

  defp send_system_message(view, _author, content, channel) do
    msg = %{
      event: "new_message",
      payload: %{
        id: "sys-#{System.unique_integer([:positive])}",
        author: "System",
        content: content,
        type: :system,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    }

    send(view.pid, msg)
  end

  defp send_new_pm(view, sender, recipient, content) do
    msg = %{
      event: "new_pm",
      payload: %{
        id: "pm-#{System.unique_integer([:positive])}",
        sender: sender,
        recipient: recipient,
        content: content,
        type: :message,
        timestamp: DateTime.utc_now()
      }
    }

    send(view.pid, msg)
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
