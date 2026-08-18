defmodule RetroHexChatWeb.VisualNotificationsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @moduletag :liveview

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
    :timer.sleep(5)
    # Flush the async send_update from the message stream island so any
    # push_event from this handler is delivered before the caller asserts.
    render(view)
  end

  defp send_pm_activity(view, sender, recipient, content) do
    send(
      view.pid,
      %{
        event: "new_pm",
        payload: %{
          id: System.unique_integer([:positive]),
          sender: sender,
          recipient: recipient,
          content: content,
          type: :message,
          timestamp: DateTime.utc_now(),
          peer: sender,
          direction: :incoming
        }
      }
    )

    :timer.sleep(5)
    # Flush the async send_update from the message stream island so any
    # push_event from this handler is delivered before the caller asserts.
    render(view)
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp row_pos(html, testid) do
    html
    |> :binary.match(~s(data-testid="#{testid}"))
    |> elem(0)
  end

  # ── Conversations flash for channels ────────────────────────

  describe "conversations flash for channels" do
    test "title_flash_start pushed for PM with flash enabled", %{conn: conn} do
      nick = "VNot#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      # Consume connect sound
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      # PM flash is enabled by default
      send_pm_activity(view, "Alice", nick, "flash me")

      # Title flash should be triggered for background PM
      assert_push_event(view, "title_flash_start", %{message: "* New activity"})
    end

    test "flash cleared on channel switch", %{conn: conn} do
      nick = "VClr#{uid()}"
      ch = "#vn_clr_#{uid()}"
      ensure_channel(ch)

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Join second channel
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/join #{ch}"})

      # Switch to background channel
      view
      |> element(~s([data-testid="channel-#lobby"]))
      |> render_click()

      # Send a highlight to background channel (highlight flash is enabled by default)
      send_new_message(view, "Other", "hey #{nick}!", ch)

      html = render(view)
      assert html =~ "text-error"

      # Switch to that channel — flash should clear
      view
      |> element(~s([data-testid="channel-#{ch}"]))
      |> render_click()

      html = render(view)
      # The highlight class should be gone for the switched-to channel
      refute html =~ ~r/data-testid="channel-#{Regex.escape(ch)}"[^>]*text-error/
    end

    test "channel activity reorders the single open-channel list", %{conn: conn} do
      nick = "VOrd#{uid()}"
      first = "#vn_ord_a_#{uid()}"
      second = "#vn_ord_b_#{uid()}"
      ensure_channel(first)
      ensure_channel(second)

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/join #{first}"})

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/join #{second}"})

      html = render(view)
      assert row_pos(html, "channel-#{second}") < row_pos(html, "channel-#{first}")

      send_new_message(view, "Other", "background message", first)

      html = render(view)
      assert row_pos(html, "channel-#{first}") < row_pos(html, "channel-#{second}")
      refute html =~ "ACTIVITY"
    end
  end

  # ── Title flash events ─────────────────────────────────────

  describe "title flash events" do
    test "title_flash_start pushed on flash-enabled activity", %{conn: conn} do
      nick = "VTitle#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      # Consume connect sound
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      # PM flash is enabled by default — send a background PM
      send_pm_activity(view, "Bob", nick, "title flash test")

      assert_push_event(view, "title_flash_start", %{message: "* New activity"})
    end

    test "title_flash_stop pushed on tab_focused", %{conn: conn} do
      nick = "VStop#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_hook(view, "tab_focused", %{})

      assert_push_event(view, "title_flash_stop", %{})
    end
  end
end
