defmodule RetroHexChatWeb.ChatLive.HighlightReachFeatureTest do
  @moduledoc """
  A highlight word reaches every conversation, not only the channels.

  Both kinds of conversation write into one stream and render through one row,
  which reads `:highlighted` without asking where the row came from. Only the
  producing side ever differed, so these two tests are deliberately the same
  assertion driven down two paths.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  test "a channel message naming the reader marks its row", %{conn: conn} do
    nick = "HiChan#{uid()}"
    channel = "#hichan#{uid()}"
    ensure_channel(channel)

    view = connect_user(conn, nick)
    render_click(view, "switch_channel", %{"channel" => channel})

    # `type` is an atom because `Service.broadcast_message/2` sends it as one;
    # the channel path decorates the payload as it arrives, so a string here
    # would test a message the server never broadcasts.
    send(view.pid, %{
      event: "new_message",
      payload: %{
        id: 1,
        channel: channel,
        author: "Poster",
        content: "hey #{nick}, look at this",
        type: :message,
        timestamp: DateTime.utc_now()
      }
    })

    assert render(view) =~ ~s(data-testid="highlighted-message")
  end

  test "a private message naming the reader marks its row", %{conn: conn} do
    nick = "HiPm#{uid()}"
    peer = "Peer#{uid()}"

    view = connect_user(conn, nick)
    render_click(view, "switch_pm", %{"nickname" => peer})

    send(view.pid, %{
      event: "new_pm",
      payload: %{
        id: 1,
        sender: peer,
        recipient: nick,
        content: "hey #{nick}, look at this",
        type: "message",
        timestamp: DateTime.utc_now()
      }
    })

    assert render(view) =~ ~s(data-testid="highlighted-message")
  end

  test "a private message not naming the reader leaves its row plain", %{conn: conn} do
    nick = "HiPmNo#{uid()}"
    peer = "Peer#{uid()}"

    view = connect_user(conn, nick)
    render_click(view, "switch_pm", %{"nickname" => peer})

    send(view.pid, %{
      event: "new_pm",
      payload: %{
        id: 1,
        sender: peer,
        recipient: nick,
        content: "nothing to see",
        type: "message",
        timestamp: DateTime.utc_now()
      }
    })

    html = render(view)

    assert html =~ "nothing to see"
    refute html =~ ~s(data-testid="highlighted-message")
  end
end
