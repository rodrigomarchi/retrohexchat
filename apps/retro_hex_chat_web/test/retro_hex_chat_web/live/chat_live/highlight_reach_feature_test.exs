defmodule RetroHexChatWeb.ChatLive.HighlightReachFeatureTest do
  @moduledoc """
  A highlight word reaches every conversation, not only the channels.

  Both kinds of conversation write into one stream and render through one row,
  which reads `:highlighted` without asking where the row came from. Only the
  producing side ever differed, so these tests are deliberately the same
  assertion driven down two paths.

  They assert on what the handler pushes rather than on the rendered row: the
  message stream is owned by a LiveComponent island reached through
  `send_update/2`, so the row's arrival is asynchronous and asserting on it
  measures scheduling. The tip is pushed from the same decorated map the row is
  built from, and `MessageRowTest` already covers that such a map renders as
  highlighted — between them the chain is covered, without a race.
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

  test "a channel message naming the reader is decorated as a highlight", %{conn: conn} do
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

    assert_push_event(view, "tip_trigger", %{tip: "first_highlight"})
  end

  test "a private message naming the reader is decorated as a highlight", %{conn: conn} do
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
        type: :message,
        timestamp: DateTime.utc_now(),
        peer: peer,
        direction: :incoming
      }
    })

    assert_push_event(view, "tip_trigger", %{tip: "first_highlight"})
  end

  test "a private message not naming the reader is left plain", %{conn: conn} do
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
        type: :message,
        timestamp: DateTime.utc_now(),
        peer: peer,
        direction: :incoming
      }
    })

    # The conversation still announces itself, which is what makes this a
    # refutation of the highlight rather than of the message arriving at all.
    assert_push_event(view, "tip_trigger", %{tip: "first_pm"})
    refute_push_event(view, "tip_trigger", %{tip: "first_highlight"})
  end
end
