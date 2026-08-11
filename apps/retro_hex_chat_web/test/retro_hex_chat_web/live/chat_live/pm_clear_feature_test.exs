defmodule RetroHexChatWeb.ChatLive.PmClearFeatureTest do
  @moduledoc """
  Clearing a private conversation has to survive leaving it.

  Clearing hides rather than deletes, so what keeps the messages off this
  reader's screen is a cutoff remembered per conversation. A channel has always
  had one. A private conversation emptied the window and remembered nothing, so
  the whole history returned the next time it was opened.

  These assert what the window shows. The stream belongs to a LiveComponent
  reached through `send_update/2`, but that update is a message the view sends
  to itself, so it is already in its own mailbox when the next `render/1` call
  arrives behind it — one round trip is enough, and no budget is being guessed.

  `loaded_message_count` looked like the synchronous signal and is not: nothing
  reads it, and the two loading paths disagree about whether it counts rows
  fetched or rows shown.
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

  defp shown(view), do: render(view)

  defp open_pm(view, peer) do
    render_click(view, "switch_pm", %{"nickname" => peer})
    view
  end

  test "a cleared private conversation stays cleared when reopened", %{conn: conn} do
    nick = "PmClr#{uid()}"
    peer = "Peer#{uid()}"
    elsewhere = "Else#{uid()}"

    write_pm(peer, nick, "zapzapone")
    write_pm(nick, peer, "zapzaptwo")

    view = connect_user(conn, nick)

    open_pm(view, peer)
    assert shown(view) =~ "zapzapone"
    assert shown(view) =~ "zapzaptwo"

    render_click(view, "toolbar_action", %{"action" => "clear_window"})

    # Leaving and coming back is the whole point: the window was already empty.
    open_pm(view, elsewhere)
    open_pm(view, peer)

    refute shown(view) =~ "zapzapone"
    refute shown(view) =~ "zapzaptwo"
  end

  test "a message written after the clear comes back", %{conn: conn} do
    nick = "PmClrA#{uid()}"
    peer = "Peer#{uid()}"
    elsewhere = "Else#{uid()}"

    write_pm(peer, nick, "zapbefore")

    view = connect_user(conn, nick)
    open_pm(view, peer)
    render_click(view, "toolbar_action", %{"action" => "clear_window"})

    write_pm(peer, nick, "zapafter")

    open_pm(view, elsewhere)
    open_pm(view, peer)

    assert shown(view) =~ "zapafter"
    refute shown(view) =~ "zapbefore"
  end

  # Filtering a page deliberately keeps `has_more` and the cursor, so reopening a
  # cleared conversation leaves a cursor pointing into the cleared region.
  # Scrolling back reads exactly that.
  test "scrolling back into a cleared conversation finds nothing there", %{conn: conn} do
    nick = "PmClrS#{uid()}"
    peer = "Peer#{uid()}"
    elsewhere = "Else#{uid()}"

    for i <- 1..55, do: write_pm(peer, nick, "zapold#{String.pad_leading(to_string(i), 3, "0")}")

    view = connect_user(conn, nick)
    open_pm(view, peer)
    assert shown(view) =~ "zapold055"

    render_click(view, "toolbar_action", %{"action" => "clear_window"})
    open_pm(view, elsewhere)
    open_pm(view, peer)

    refute shown(view) =~ "zapold055"
    assert :sys.get_state(view.pid).socket.assigns.has_more

    render_click(view, "load_more", %{})

    # The five the second page carries — the oldest, and the only ones this
    # click can bring back. Naming one of them is what makes this test about
    # scrolling rather than about the load that preceded it.
    refute shown(view) =~ "zapold003"
    refute shown(view) =~ "zapold001"
  end

  test "clearing one conversation leaves another's history alone", %{conn: conn} do
    nick = "PmClrB#{uid()}"
    peer = "Peer#{uid()}"
    other = "Other#{uid()}"

    write_pm(peer, nick, "zappeerhello")
    write_pm(other, nick, "zapotherhello")

    view = connect_user(conn, nick)

    open_pm(view, peer)
    render_click(view, "toolbar_action", %{"action" => "clear_window"})

    open_pm(view, other)

    assert shown(view) =~ "zapotherhello"
    refute shown(view) =~ "zappeerhello"
  end
end
