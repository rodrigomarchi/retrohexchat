defmodule RetroHexChatWeb.VisualNotificationsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @moduletag :liveview

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
    :timer.sleep(5)
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
    :timer.sleep(5)
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  # ── Treebar flash for channels ──────────────────────────────

  describe "treebar flash for channels" do
    test "title_flash_start pushed for PM with flash enabled", %{conn: conn} do
      nick = "VNot#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      # Consume connect sound
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      # PM flash is enabled by default
      send_new_pm(view, "Alice", nick, "flash me")

      # Title flash should be triggered for background PM
      assert_push_event(view, "title_flash_start", %{message: "* New activity"})
    end

    test "flash cleared on channel switch", %{conn: conn} do
      nick = "VClr#{System.unique_integer([:positive])}"
      ch = "#vn_clr_#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Join second channel
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})

      # Switch to background channel
      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#lobby"]))
      |> render_click()

      # Send a highlight to background channel (highlight flash is enabled by default)
      send_new_message(view, "Other", "hey #{nick}!", ch)

      html = render(view)
      assert html =~ "tree-highlight"

      # Switch to that channel — flash should clear
      view
      |> element(~s(li[phx-click="switch_channel"][phx-value-channel="#{ch}"]))
      |> render_click()

      html = render(view)
      # The flash class should be gone for the switched-to channel
      refute html =~ ~r/data-testid="channel-#{Regex.escape(ch)}"[^>]*tree-highlight/
    end
  end

  # ── Title flash events ─────────────────────────────────────

  describe "title flash events" do
    test "title_flash_start pushed on flash-enabled activity", %{conn: conn} do
      nick = "VTitle#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      # Consume connect sound
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      # PM flash is enabled by default — send a background PM
      send_new_pm(view, "Bob", nick, "title flash test")

      assert_push_event(view, "title_flash_start", %{message: "* New activity"})
    end

    test "title_flash_stop pushed on tab_focused", %{conn: conn} do
      nick = "VStop#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_hook(view, "tab_focused", %{})

      assert_push_event(view, "title_flash_stop", %{})
    end
  end
end
