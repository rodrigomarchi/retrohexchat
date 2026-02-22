defmodule RetroHexChatWeb.ChatLiveHighlightTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @default_color RetroHexChat.Chat.Highlight.default_color()

  # ── US1: Own-nick highlighting ───────────────────────────────

  describe "US1: own-nick highlight in active channel" do
    test "message mentioning user's nick is highlighted", %{conn: conn} do
      nick = "HiLite#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "OtherUser", "hey #{nick}, check this out", "#lobby")

      html = render(view)
      assert html =~ "chat-message--highlighted"
      assert html =~ "hey #{nick}, check this out"
    end

    test "self-message is NOT highlighted", %{conn: conn} do
      nick = "SelfHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, nick, "I am #{nick} and I said my own name", "#lobby")

      html = render(view)
      assert html =~ "I am #{nick}"
      refute html =~ "chat-message--highlighted"
    end

    test "system message is NOT highlighted", %{conn: conn} do
      nick = "SysHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      msg = %{
        event: "new_message",
        payload: %{
          id: "sys-#{uid()}",
          author: "system",
          content: "#{nick} has joined #lobby",
          type: :system,
          channel: "#lobby",
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, msg)
      html = render(view)

      assert html =~ "chat-message--system"
      refute html =~ "chat-message--highlighted"
    end

    test "case-insensitive nick matching highlights", %{conn: conn} do
      nick = "CaseNick#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "OtherUser", "hey #{String.upcase(nick)}!", "#lobby")

      html = render(view)
      assert html =~ "chat-message--highlighted"
    end

    test "message NOT mentioning nick is NOT highlighted", %{conn: conn} do
      nick = "NoMatch#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "OtherUser", "hello world nothing special here", "#lobby")

      html = render(view)
      assert html =~ "hello world nothing special here"
      refute html =~ "chat-message--highlighted"
    end

    test "highlight applies inline background-color style", %{conn: conn} do
      nick = "StyleHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "OtherUser", "hey #{nick}!", "#lobby")

      html = render(view)
      assert html =~ "background-color: #{@default_color}"
    end

    test "action type (/me) mentioning nick is highlighted", %{conn: conn} do
      nick = "ActHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      msg = %{
        event: "new_message",
        payload: %{
          id: "act-#{uid()}",
          author: "OtherUser",
          content: "waves at #{nick}",
          type: :action,
          channel: "#lobby",
          timestamp: DateTime.utc_now()
        }
      }

      send(view.pid, msg)
      html = render(view)

      assert html =~ "chat-message--highlighted"
    end
  end

  # ── US2: Non-active channel conversations flash ─────────────────────

  describe "US2: conversations flash on non-active channel highlight" do
    test "highlight in non-active channel adds conversations-highlight class", %{conn: conn} do
      nick = "FlashHL#{uid()}"
      ch = "#hl_flash_#{uid()}"
      ensure_channel(ch)

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Join a second channel, then switch back to #lobby
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})

      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      # Now #lobby is active, ch is non-active — send highlight to ch
      send_new_message(view, "OtherUser", "hey #{nick}!", ch)

      html = render(view)
      assert html =~ "conversations-highlight"
    end

    test "highlight in active channel does NOT flash conversations", %{conn: conn} do
      nick = "NoFlash#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "OtherUser", "hey #{nick}!", "#lobby")

      html = render(view)
      assert html =~ "chat-message--highlighted"
      refute html =~ "conversations-highlight"
    end

    test "switching to highlighted channel clears flash", %{conn: conn} do
      nick = "ClearFlash#{uid()}"
      ch = "#hl_clear_#{uid()}"
      ensure_channel(ch)

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})

      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      # Send highlight to non-active channel
      send_new_message(view, "OtherUser", "hey #{nick}!", ch)
      html = render(view)
      assert html =~ "conversations-highlight"

      # Switch to that channel — flash should clear
      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#{ch}"]))
      |> render_click()

      html = render(view)
      refute html =~ "conversations-highlight"
    end

    test "non-highlight message in non-active channel does NOT flash", %{conn: conn} do
      nick = "NoFlash2#{uid()}"
      ch = "#hl_nofl_#{uid()}"
      ensure_channel(ch)

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})

      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      send_new_message(view, "OtherUser", "hello world", ch)

      html = render(view)
      refute html =~ "conversations-highlight"
    end
  end

  # ── US3: Notification sound ───────────────────────────────────

  describe "US3: notification sound on highlight" do
    test "push_event play_sound sent on highlight", %{conn: conn} do
      nick = "SndHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "OtherUser", "hey #{nick}!", "#lobby")

      assert_push_event(view, "play_sound", %{type: "alert"})
    end

    test "no push_event on non-highlight message", %{conn: conn} do
      nick = "NoSnd#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      send_new_message(view, "OtherUser", "hello world", "#lobby")

      # Render to process the message
      render(view)
      refute_push_event(view, "play_sound", %{type: "alert"})
    end

    test "push_event sent for highlight in non-active channel too", %{conn: conn} do
      nick = "SndBG#{uid()}"
      ch = "#hl_snd_#{uid()}"
      ensure_channel(ch)

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})

      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      send_new_message(view, "OtherUser", "hey #{nick}!", ch)

      assert_push_event(view, "play_sound", %{type: "alert"})
    end
  end

  # ── US4: Custom highlight words in LiveView ───────────────────

  describe "US4: custom highlight words" do
    test "message matching custom word is highlighted", %{conn: conn} do
      nick = "CustHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Add a custom highlight word
      render_click(view, "highlight_add", %{"word" => "phoenix", "bg_color" => ""})

      # Send a message with that word from another user
      send_new_message(view, "OtherUser", "I love phoenix framework", "#lobby")

      html = render(view)
      assert html =~ "chat-message--highlighted"
    end

    test "custom word with custom color applies that color", %{conn: conn} do
      nick = "ColorHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Add word with color index 4 (red)
      render_click(view, "highlight_add", %{"word" => "deploy", "bg_color" => "4"})

      send_new_message(view, "OtherUser", "we need to deploy now", "#lobby")

      html = render(view)
      assert html =~ "chat-message--highlighted"
      # Color 4 = #ff0000
      assert html =~ "background-color: #ff0000"
    end

    test "own nick takes priority over custom word", %{conn: conn} do
      nick = "PrioHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Add custom word with a different color
      render_click(view, "highlight_add", %{"word" => nick, "bg_color" => "4"})

      # The nick match should use default color, not custom word color
      send_new_message(view, "OtherUser", "hey #{nick}!", "#lobby")

      html = render(view)
      assert html =~ "chat-message--highlighted"
      assert html =~ "background-color: #{@default_color}"
    end

    test "removed highlight word no longer triggers", %{conn: conn} do
      nick = "RmHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "highlight_add", %{"word" => "deploy", "bg_color" => ""})
      render_click(view, "highlight_remove", %{"word" => "deploy"})

      send_new_message(view, "OtherUser", "we need to deploy now", "#lobby")

      html = render(view)
      refute html =~ "chat-message--highlighted"
    end
  end

  # ── US5: Configuration dialog ─────────────────────────────────

  describe "US5: highlight dialog" do
    test "opens and closes via event", %{conn: conn} do
      nick = "DlgHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "open_highlight_dialog")
      assert html =~ "Highlight Words"
      assert html =~ nick

      html = render_click(view, "close_highlight_dialog")
      refute html =~ "highlight-dialog"
    end

    test "add word via dialog", %{conn: conn} do
      nick = "AddWd#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "open_highlight_dialog")
      render_click(view, "open_highlight_add_dialog")

      html =
        view
        |> element(~s(form[phx-submit="highlight_add"]))
        |> render_submit(%{"word" => "phoenix", "bg_color" => ""})

      assert html =~ "phoenix"
      assert html =~ "highlight-word-phoenix"
    end

    test "remove word via dialog", %{conn: conn} do
      nick = "RmWd#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "highlight_add", %{"word" => "phoenix", "bg_color" => ""})
      render_click(view, "open_highlight_dialog")

      html = render(view)
      assert html =~ "highlight-word-phoenix"

      html = render_click(view, "highlight_remove", %{"word" => "phoenix"})
      refute html =~ "highlight-word-phoenix"
    end

    test "edit word color via dialog", %{conn: conn} do
      nick = "EdWd#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

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

    test "Ctrl+Shift+H toggles dialog", %{conn: conn} do
      nick = "AltH#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      html =
        render_keydown(view, "window_keydown", %{
          "key" => "h",
          "ctrlKey" => true,
          "shiftKey" => true
        })

      assert html =~ "Highlight Words"

      html =
        render_keydown(view, "window_keydown", %{
          "key" => "h",
          "ctrlKey" => true,
          "shiftKey" => true
        })

      refute html =~ "highlight-dialog"
    end

    test "Highlight Words menu item opens dialog", %{conn: conn} do
      nick = "MenuHL#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      html = render_click(view, "open_highlight_dialog")
      assert html =~ "Highlight Words"
    end
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp send_new_message(view, author, content, channel) do
    msg = %{
      event: "new_message",
      payload: %{
        id: "msg-#{uid()}",
        author: author,
        content: content,
        type: :message,
        channel: channel,
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
