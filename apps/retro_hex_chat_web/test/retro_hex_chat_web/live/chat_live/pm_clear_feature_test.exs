defmodule RetroHexChatWeb.ChatLive.PmClearFeatureTest do
  @moduledoc """
  Clearing a private conversation has to survive leaving it.

  Clearing hides rather than deletes, so what keeps the messages off this
  reader's screen is a cutoff remembered per conversation. A channel has always
  had one. A private conversation emptied the window and remembered nothing, so
  the whole history returned the next time it was opened.

  These assert `loaded_message_count`, which the loader sets synchronously from
  the page it has already filtered, rather than the stream it hands to an island
  through `send_update/2`.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Chat.Queries

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp write_pm(sender, recipient, content) do
    {:ok, _pm} =
      Queries.insert_private_message(%{
        sender_nickname: sender,
        recipient_nickname: recipient,
        content: content,
        content_format: "irc",
        type: "message"
      })
  end

  defp loaded_count(view) do
    :sys.get_state(view.pid).socket.assigns.loaded_message_count
  end

  defp open_pm(view, peer) do
    render_click(view, "switch_pm", %{"nickname" => peer})
    view
  end

  test "a cleared private conversation stays cleared when reopened", %{conn: conn} do
    nick = "PmClr#{uid()}"
    peer = "Peer#{uid()}"
    elsewhere = "Else#{uid()}"

    write_pm(peer, nick, "first")
    write_pm(nick, peer, "second")

    view = connect_user(conn, nick)

    open_pm(view, peer)
    assert loaded_count(view) == 2

    render_click(view, "toolbar_action", %{"action" => "clear_window"})

    # Leaving and coming back is the whole point: the window was already empty.
    open_pm(view, elsewhere)
    open_pm(view, peer)

    assert loaded_count(view) == 0
  end

  test "a message written after the clear comes back", %{conn: conn} do
    nick = "PmClrA#{uid()}"
    peer = "Peer#{uid()}"
    elsewhere = "Else#{uid()}"

    write_pm(peer, nick, "before the clear")

    view = connect_user(conn, nick)
    open_pm(view, peer)
    render_click(view, "toolbar_action", %{"action" => "clear_window"})

    write_pm(peer, nick, "after the clear")

    open_pm(view, elsewhere)
    open_pm(view, peer)

    assert loaded_count(view) == 1
  end

  test "clearing one conversation leaves another's history alone", %{conn: conn} do
    nick = "PmClrB#{uid()}"
    peer = "Peer#{uid()}"
    other = "Other#{uid()}"

    write_pm(peer, nick, "peer says hello")
    write_pm(other, nick, "other says hello")

    view = connect_user(conn, nick)

    open_pm(view, peer)
    render_click(view, "toolbar_action", %{"action" => "clear_window"})

    open_pm(view, other)

    assert loaded_count(view) == 1
  end
end
