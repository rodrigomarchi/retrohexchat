defmodule RetroHexChatWeb.ChatTabOrderTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  defp pm_activity(peer) do
    {:pm_activity,
     %{
       peer: peer,
       message_id: System.unique_integer([:positive]),
       type: :message,
       timestamp: DateTime.utc_now(),
       direction: :incoming
     }}
  end

  defp tab_labels(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(~s([data-testid="tab-bar"] [role="tab"]))
    |> Floki.attribute("phx-value-label")
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  test "clicking a channel tab moves it to the front of conversation tabs", %{conn: conn} do
    channel_a = "#tab#{uid()}a"
    channel_b = "#tab#{uid()}b"
    {:ok, view, _html} = live(chat_conn(conn, "TabOrd#{uid()}"), "/chat")

    submit_command_sync(view, "/join #{channel_a}")
    html = submit_command_sync(view, "/join #{channel_b}")
    assert tab_labels(html) == ["Status", "#lobby", channel_a, channel_b]

    html = render_click(view, "switch_tab", %{"type" => "channel", "label" => channel_a})

    assert tab_labels(html) == ["Status", channel_a, "#lobby", channel_b]
    assert assigns(view).session.channels == ["#lobby", channel_a, channel_b]
  end

  test "clicking a PM tab can move it ahead of channel tabs", %{conn: conn} do
    {:ok, view, _html} = live(chat_conn(conn, "TabPm#{uid()}"), "/chat")

    send(view.pid, pm_activity("Bob"))
    send(view.pid, pm_activity("Alice"))
    html = render(view)
    assert tab_labels(html) == ["Status", "#lobby", "Bob", "Alice"]

    html = render_click(view, "switch_tab", %{"type" => "pm", "label" => "Alice"})

    assert tab_labels(html) == ["Status", "Alice", "#lobby", "Bob"]
  end

  test "keyboard window navigation follows the clicked tab order without reordering it", %{
    conn: conn
  } do
    channel_a = "#key#{uid()}a"
    channel_b = "#key#{uid()}b"
    {:ok, view, _html} = live(chat_conn(conn, "TabKey#{uid()}"), "/chat")

    submit_command_sync(view, "/join #{channel_a}")
    submit_command_sync(view, "/join #{channel_b}")
    html = render_click(view, "switch_tab", %{"type" => "channel", "label" => channel_a})
    assert tab_labels(html) == ["Status", channel_a, "#lobby", channel_b]

    html = render_click(view, "window_next")

    assert assigns(view).session.active_channel == "#lobby"
    assert tab_labels(html) == ["Status", channel_a, "#lobby", channel_b]
  end
end
