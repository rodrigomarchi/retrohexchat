defmodule RetroHexChatWeb.ChatLive.SystemMessageSpamFeatureTest do
  @moduledoc """
  Spam protection is about people, in a private conversation as in a channel.

  A system line repeats by nature — the same "P2P session connected" arrives
  every time a flaky link comes back — so it is neither counted towards a
  repeat nor dropped as one. The channel path always said so; the private one
  did not, and three identical `p2p_system` lines inside the ten-second window
  lost the third.

  These assert on the duplicate tracker rather than on the row that did or did
  not arrive: the tracker is the state the drop decision reads, and reading it
  is synchronous, while the row travels to a LiveComponent island through
  `send_update/2`.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Chat.DuplicateTracker

  @content "P2P session connected - call, files, games and stats are available."
  @window 10

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp deliver(view, peer, type) do
    send(view.pid, %{
      event: "new_pm",
      payload: %{
        id: System.unique_integer([:positive]),
        sender: peer,
        recipient: "irrelevant",
        content: @content,
        type: type,
        timestamp: DateTime.utc_now()
      }
    })

    # Forces the view to finish handling the message before its state is read.
    render(view)
    view
  end

  defp times_counted(view, peer) do
    %{socket: %{assigns: assigns}} = :sys.get_state(view.pid)

    DuplicateTracker.duplicate_count(
      assigns.duplicate_tracker,
      peer,
      {:pm, peer},
      @content,
      @window
    )
  end

  test "the system repeating itself in a private conversation is never spam", %{conn: conn} do
    nick = "SysSpam#{uid()}"
    peer = "Peer#{uid()}"

    view = connect_user(conn, nick)
    render_click(view, "switch_pm", %{"nickname" => peer})

    for _attempt <- 1..3, do: deliver(view, peer, :p2p_system)

    # Never counted, so never dropped: the third one is the one that says the
    # link finally came back.
    assert times_counted(view, peer) == 0
  end

  test "a person repeating themselves in a private conversation still is", %{conn: conn} do
    nick = "PmSpam#{uid()}"
    peer = "Peer#{uid()}"

    view = connect_user(conn, nick)
    render_click(view, "switch_pm", %{"nickname" => peer})

    for _attempt <- 1..3, do: deliver(view, peer, :message)

    # Three inside the window is the default spam threshold, which is what makes
    # the exemption above specific rather than a hole.
    assert times_counted(view, peer) == 3
  end

  test "a channel's system line is exempt the same way", %{conn: conn} do
    nick = "SysChan#{uid()}"
    channel = "#sysspam#{uid()}"

    view = connect_user(conn, nick)

    for _attempt <- 1..3 do
      send(view.pid, %{
        event: "new_message",
        payload: %{
          id: System.unique_integer([:positive]),
          channel: channel,
          author: "Server",
          content: @content,
          type: :system,
          timestamp: DateTime.utc_now()
        }
      })

      render(view)
    end

    %{socket: %{assigns: assigns}} = :sys.get_state(view.pid)

    assert DuplicateTracker.duplicate_count(
             assigns.duplicate_tracker,
             "Server",
             {:channel, channel},
             @content,
             @window
           ) == 0
  end
end
