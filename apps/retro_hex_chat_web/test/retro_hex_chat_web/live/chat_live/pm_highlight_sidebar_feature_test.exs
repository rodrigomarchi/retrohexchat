defmodule RetroHexChatWeb.ChatLive.PmHighlightSidebarFeatureTest do
  @moduledoc """
  A highlight in a conversation nobody is looking at leaves a mark.

  A channel has always done this: the row turns red in the sidebar and the
  conversation is pulled into the activity section, so the reader finds it after
  the fact. A private conversation played the sound and stopped there — the only
  record of the highlight was a noise the reader may not have been there for.

  These read `highlight_channels` rather than the rendered sidebar: the sidebar
  is rendered from that set, `ConversationsTest` covers that a set member is
  drawn as highlighted, and reading an assign is synchronous while the row
  travels through `send_update/2`.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp deliver_pm(view, peer, content) do
    send(view.pid, %{
      event: "new_pm",
      payload: %{
        id: System.unique_integer([:positive]),
        sender: peer,
        recipient: "irrelevant",
        content: content,
        type: :message,
        timestamp: DateTime.utc_now(),
        peer: peer,
        direction: :incoming
      }
    })

    render(view)
    view
  end

  defp highlighted(view) do
    %{socket: %{assigns: assigns}} = :sys.get_state(view.pid)
    assigns.highlight_channels
  end

  test "a highlight in a background conversation marks it", %{conn: conn} do
    nick = "PmMark#{uid()}"
    peer = "Peer#{uid()}"
    other = "Other#{uid()}"

    view = connect_user(conn, nick)
    # Somewhere else is on screen, so the peer's conversation is in the background.
    render_click(view, "switch_pm", %{"nickname" => other})

    deliver_pm(view, peer, "hey #{nick}, look at this")

    assert MapSet.member?(highlighted(view), "pm:#{peer}")
  end

  test "an ordinary message in a background conversation marks nothing", %{conn: conn} do
    nick = "PmPlain#{uid()}"
    peer = "Peer#{uid()}"
    other = "Other#{uid()}"

    view = connect_user(conn, nick)
    render_click(view, "switch_pm", %{"nickname" => other})

    deliver_pm(view, peer, "nothing to see")

    refute MapSet.member?(highlighted(view), "pm:#{peer}")
  end

  test "opening the conversation takes the mark away", %{conn: conn} do
    nick = "PmClear#{uid()}"
    peer = "Peer#{uid()}"
    other = "Other#{uid()}"

    view = connect_user(conn, nick)
    render_click(view, "switch_pm", %{"nickname" => other})
    deliver_pm(view, peer, "hey #{nick}, look at this")
    assert MapSet.member?(highlighted(view), "pm:#{peer}")

    render_click(view, "switch_pm", %{"nickname" => peer})

    refute MapSet.member?(highlighted(view), "pm:#{peer}")
  end

  test "the conversation on screen needs no mark", %{conn: conn} do
    nick = "PmActive#{uid()}"
    peer = "Peer#{uid()}"

    view = connect_user(conn, nick)
    render_click(view, "switch_pm", %{"nickname" => peer})

    deliver_pm(view, peer, "hey #{nick}, look at this")

    refute MapSet.member?(highlighted(view), "pm:#{peer}")
  end
end
