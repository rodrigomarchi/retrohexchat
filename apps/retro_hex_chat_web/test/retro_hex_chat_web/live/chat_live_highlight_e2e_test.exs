defmodule RetroHexChatWeb.ChatLiveHighlightE2ETest do
  @moduledoc """
  End-to-end tests for the Highlight / Mentions feature (004).
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
  # US1 — Own-Nick Highlighting
  # ══════════════════════════════════════════════════════════════

  describe "US1: Own-nick highlighting" do
    test "message mentioning user's nick is highlighted", %{conn: conn} do
      view = connect_user(conn, "E2EHL#{uid()}")
      nick = "E2EHL" <> last_uid()

      send_message(view, "OtherUser", "hey #{nick}, look at this!", "#lobby")

      html = render(view)
      assert html =~ "chat-message--highlighted"
      assert html =~ "highlighted-message"
    end

    test "own message is not highlighted", %{conn: conn} do
      nick = "E2ESelf#{uid()}"
      view = connect_user(conn, nick)

      send_message(view, nick, "I said my own name #{nick}", "#lobby")

      html = render(view)
      refute html =~ "chat-message--highlighted"
    end

    test "system message is not highlighted", %{conn: conn} do
      nick = "E2ESys#{uid()}"
      view = connect_user(conn, nick)

      send(view.pid, %{
        event: "new_message",
        payload: %{
          id: "sys-#{uid()}",
          author: "system",
          content: "#{nick} has joined #lobby",
          type: :system,
          channel: "#lobby",
          timestamp: DateTime.utc_now()
        }
      })

      html = render(view)
      refute html =~ "chat-message--highlighted"
    end

    test "case-insensitive nick matching highlights", %{conn: conn} do
      nick = "E2ECase#{uid()}"
      view = connect_user(conn, nick)

      send_message(view, "OtherUser", "hey #{String.upcase(nick)}!", "#lobby")

      html = render(view)
      assert html =~ "chat-message--highlighted"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US2 — TreeBar Flash
  # ══════════════════════════════════════════════════════════════

  describe "US2: TreeBar flash on non-active channel highlight" do
    test "highlight in non-active channel adds tree-highlight class", %{conn: conn} do
      nick = "E2EFlash#{uid()}"
      ch = "#e2e_flash_#{uid()}"
      ensure_channel(ch)

      view = connect_user(conn, nick)

      # Join second channel, switch back to #lobby
      submit_command(view, "/join #{ch}")
      click_channel(view, "#lobby")

      # Trigger highlight in non-active channel
      send_message(view, "OtherUser", "hey #{nick}!", ch)

      html = render(view)
      assert html =~ "tree-highlight"
    end

    test "switching to highlighted channel clears flash", %{conn: conn} do
      nick = "E2EClear#{uid()}"
      ch = "#e2e_clear_#{uid()}"
      ensure_channel(ch)

      view = connect_user(conn, nick)

      submit_command(view, "/join #{ch}")
      click_channel(view, "#lobby")

      send_message(view, "OtherUser", "hey #{nick}!", ch)
      assert render(view) =~ "tree-highlight"

      # Switch to the highlighted channel — flash should clear
      click_channel(view, ch)
      refute render(view) =~ "tree-highlight"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US3 — Notification Sound
  # ══════════════════════════════════════════════════════════════

  describe "US3: Notification sound" do
    test "push_event play_sound sent on highlight", %{conn: conn} do
      nick = "E2ESnd#{uid()}"
      view = connect_user(conn, nick)

      send_message(view, "OtherUser", "hey #{nick}!", "#lobby")

      assert_push_event(view, "play_sound", %{type: "alert"})
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US4 — Custom Highlight Words
  # ══════════════════════════════════════════════════════════════

  describe "US4: Custom highlight words" do
    test "custom word triggers highlighting", %{conn: conn} do
      nick = "E2ECust#{uid()}"
      view = connect_user(conn, nick)

      # Add custom highlight word
      render_click(view, "highlight_add", %{"word" => "phoenix", "bg_color" => ""})

      send_message(view, "OtherUser", "I love phoenix framework", "#lobby")

      html = render(view)
      assert html =~ "chat-message--highlighted"
    end

    test "custom word with custom color applies that color", %{conn: conn} do
      nick = "E2EColor#{uid()}"
      view = connect_user(conn, nick)

      # Add word with color index 4 (red = #ff0000)
      render_click(view, "highlight_add", %{"word" => "deploy", "bg_color" => "4"})

      send_message(view, "OtherUser", "we need to deploy now", "#lobby")

      html = render(view)
      assert html =~ "chat-message--highlighted"
      assert html =~ "background-color: #ff0000"
    end

    test "removed word no longer triggers highlighting", %{conn: conn} do
      nick = "E2ERm#{uid()}"
      view = connect_user(conn, nick)

      render_click(view, "highlight_add", %{"word" => "deploy", "bg_color" => ""})
      render_click(view, "highlight_remove", %{"word" => "deploy"})

      send_message(view, "OtherUser", "we need to deploy now", "#lobby")

      html = render(view)
      refute html =~ "chat-message--highlighted"
    end
  end

  # ══════════════════════════════════════════════════════════════
  # US5 — Configuration Dialog
  # ══════════════════════════════════════════════════════════════

  describe "US5: Highlight dialog" do
    test "opens and closes via event", %{conn: conn} do
      view = connect_user(conn, "E2EDlg#{uid()}")

      html = render_click(view, "open_highlight_dialog")
      assert html =~ "highlight-dialog"
      assert html =~ "Highlight Words"

      html = render_click(view, "close_highlight_dialog")
      refute html =~ "highlight-dialog"
    end

    test "Ctrl+Shift+H toggles dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAltH#{uid()}")

      html =
        render_keydown(view, "window_keydown", %{
          "key" => "h",
          "ctrlKey" => true,
          "shiftKey" => true
        })

      assert html =~ "highlight-dialog"

      html =
        render_keydown(view, "window_keydown", %{
          "key" => "h",
          "ctrlKey" => true,
          "shiftKey" => true
        })

      refute html =~ "highlight-dialog"
    end

    test "add word via dialog", %{conn: conn} do
      view = connect_user(conn, "E2EAdd#{uid()}")

      render_click(view, "open_highlight_dialog")
      render_click(view, "open_highlight_add_dialog")

      html =
        view
        |> element(~s(form[phx-submit="highlight_add"]))
        |> render_submit(%{"word" => "elixir", "bg_color" => ""})

      assert html =~ "highlight-word-elixir"
    end

    test "remove word via dialog", %{conn: conn} do
      view = connect_user(conn, "E2ERmDlg#{uid()}")

      render_click(view, "highlight_add", %{"word" => "elixir", "bg_color" => ""})
      render_click(view, "open_highlight_dialog")

      assert render(view) =~ "highlight-word-elixir"

      html = render_click(view, "highlight_remove", %{"word" => "elixir"})
      refute html =~ "highlight-word-elixir"
    end

    test "edit word color via dialog", %{conn: conn} do
      view = connect_user(conn, "E2EEdit#{uid()}")

      render_click(view, "highlight_add", %{"word" => "deploy", "bg_color" => ""})
      render_click(view, "open_highlight_dialog")
      render_click(view, "highlight_select", %{"word" => "deploy"})
      render_click(view, "open_highlight_edit_dialog")

      view
      |> element(~s(form[phx-submit="highlight_edit"]))
      |> render_submit(%{"word" => "deploy", "bg_color" => "4"})

      # Edit dialog should close
      refute render(view) =~ "highlight-edit-dialog"
    end

    test "own nick shown in dialog as non-removable", %{conn: conn} do
      nick = "E2EOwn#{uid()}"
      view = connect_user(conn, nick)

      html = render_click(view, "open_highlight_dialog")
      assert html =~ nick
      assert html =~ "highlight-own-nick"
      assert html =~ "(default)"
    end

    test "full flow: add word, verify highlight, remove, verify no highlight", %{conn: conn} do
      nick = "E2EFull#{uid()}"
      view = connect_user(conn, nick)

      # Add custom word via dialog
      render_click(view, "open_highlight_dialog")
      render_click(view, "open_highlight_add_dialog")

      view
      |> element(~s(form[phx-submit="highlight_add"]))
      |> render_submit(%{"word" => "liveview", "bg_color" => "3"})

      # Close dialog
      render_click(view, "close_highlight_dialog")

      # Send message with custom word — should be highlighted
      send_message(view, "OtherUser", "liveview is great", "#lobby")
      html = render(view)
      assert html =~ "chat-message--highlighted"

      # Remove the word
      render_click(view, "open_highlight_dialog")
      render_click(view, "highlight_select", %{"word" => "liveview"})
      render_click(view, "highlight_remove", %{"word" => "liveview"})
      render_click(view, "close_highlight_dialog")

      # Send another message with same word — should NOT be highlighted
      send_message(view, "SomeoneElse", "liveview is really great", "#lobby")
      html = render(view)

      # The new message should not be highlighted (old one still is in the stream)
      # Count occurrences of highlighted-message to verify only 1 (old one)
      count = length(Regex.scan(~r/highlighted-message/, html))
      assert count == 1
    end
  end

  # ══════════════════════════════════════════════════════════════
  # Private Helpers
  # ══════════════════════════════════════════════════════════════

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")
    view
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

  defp submit_command(view, cmd) do
    view |> element("form.chat-input-form") |> render_submit(%{"input" => cmd})
  end

  defp click_channel(view, channel) do
    view
    |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#{channel}"]))
    |> render_click()
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

  defp last_uid, do: to_string(Process.get(:last_uid))
end
