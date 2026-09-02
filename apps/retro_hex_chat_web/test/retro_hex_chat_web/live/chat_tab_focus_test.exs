defmodule RetroHexChatWeb.ChatTabFocusTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  defp channel_activity(view, channel, author) do
    send(view.pid, %{
      event: "new_message",
      payload: %{
        id: "msg-#{uid()}",
        author: author,
        content: "background traffic",
        type: :message,
        channel: channel,
        timestamp: DateTime.utc_now()
      }
    })

    render(view)
  end

  defp pm_activity(view, peer) do
    send(view.pid, %{
      event: "new_pm",
      payload: %{
        id: System.unique_integer([:positive]),
        sender: peer,
        recipient: "irrelevant",
        content: "hello",
        type: :message,
        timestamp: DateTime.utc_now(),
        peer: peer,
        direction: :incoming
      }
    })

    render(view)
  end

  defp tab_labels(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(~s([data-testid="tab-bar"] [role="tab"]))
    |> Floki.attribute("phx-value-label")
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  test "the bar carries Status and the focused conversation, whatever else is joined", %{
    conn: conn
  } do
    channel_a = "#focus#{uid()}a"
    channel_b = "#focus#{uid()}b"
    {:ok, view, _html} = live(chat_conn(conn, "Focus#{uid()}"), "/chat")

    submit_command_sync(view, "/join #{channel_a}")
    html = submit_command_sync(view, "/join #{channel_b}")

    # Three channels joined, one conversation tab: joining activates the channel
    # it joined.
    assert assigns(view).session.channels == ["#lobby", channel_a, channel_b]
    assert tab_labels(html) == ["Status", channel_b]
  end

  test "switching replaces the focused tab instead of accumulating one", %{conn: conn} do
    channel_a = "#swap#{uid()}a"
    {:ok, view, _html} = live(chat_conn(conn, "Swap#{uid()}"), "/chat")

    submit_command_sync(view, "/join #{channel_a}")
    assert tab_labels(render(view)) == ["Status", channel_a]

    html = render_click(view, "switch_channel", %{"channel" => "#lobby"})

    assert tab_labels(html) == ["Status", "#lobby"]
    assert assigns(view).session.active_channel == "#lobby"
    # Still joined to both — leaving the screen is not leaving the channel.
    assert assigns(view).session.channels == ["#lobby", channel_a]
  end

  test "a backgrounded channel keeps notifying without taking a tab", %{conn: conn} do
    background = "#bg#{uid()}"
    {:ok, view, _html} = live(chat_conn(conn, "Bg#{uid()}"), "/chat")

    submit_command_sync(view, "/join #{background}")
    render_click(view, "switch_channel", %{"channel" => "#lobby"})

    html = channel_activity(view, background, "Someone")

    # Out of sight: no tab of its own.
    assert tab_labels(html) == ["Status", "#lobby"]
    # Still heard: the unread count the sidebar renders kept climbing.
    assert Map.get(assigns(view).unread_counts, background) == 1

    html = channel_activity(view, background, "Someone")

    assert tab_labels(html) == ["Status", "#lobby"]
    assert Map.get(assigns(view).unread_counts, background) == 2
  end

  test "an incoming PM notifies in the background and only tabs once focused", %{conn: conn} do
    {:ok, view, _html} = live(chat_conn(conn, "PmFocus#{uid()}"), "/chat")

    html = pm_activity(view, "Bob")

    assert tab_labels(html) == ["Status", "#lobby"]
    assert Map.get(assigns(view).unread_counts, "pm:Bob") == 1

    html = render_click(view, "switch_pm", %{"nickname" => "Bob"})

    assert tab_labels(html) == ["Status", "Bob"]
    # Focusing clears it: the tracker drops the key rather than zeroing it.
    assert Map.get(assigns(view).unread_counts, "pm:Bob", 0) == 0
  end

  test "the Status tab shares the bar with the conversation it covers", %{conn: conn} do
    {:ok, view, _html} = live(chat_conn(conn, "Stat#{uid()}"), "/chat")

    html = render_click(view, "switch_to_status", %{})

    # Status takes the screen; the conversation keeps its tab so it can come
    # back. The tab set does not move under the pointer.
    assert tab_labels(html) == ["Status", "#lobby"]
    assert assigns(view).show_status_tab
  end

  test "keyboard window navigation still reaches channels that have no tab", %{conn: conn} do
    channel_a = "#key#{uid()}a"
    {:ok, view, _html} = live(chat_conn(conn, "Key#{uid()}"), "/chat")

    submit_command_sync(view, "/join #{channel_a}")
    assert assigns(view).session.active_channel == channel_a

    html = render_click(view, "window_next")

    assert assigns(view).session.active_channel == "#lobby"
    assert tab_labels(html) == ["Status", "#lobby"]
  end
end
