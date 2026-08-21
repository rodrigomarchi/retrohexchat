defmodule RetroHexChatWeb.ChatLive.PmDeliveryFeatureTest do
  @moduledoc """
  A private message reaches the person it was addressed to.

  Whether the reader ever closed that tab, whether this is the conversation's
  first message, and whether the reader is the one who wrote it are all supposed
  to be irrelevant — a channel answers the same way in every one of those cases.

  What arrival does is asserted on the socket, never on the rendered page: the row
  travels to a component by `send_update/2`, so how many round trips it takes to
  appear depends on what else was queued, and a test that waits for it is
  measuring the queue. One test here did assert on the page, passed six runs, and
  failed the seventh under a partitioned suite.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Chat.Service

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp open_pm(view, peer) do
    render_click(view, "switch_pm", %{"nickname" => peer})
    view
  end

  defp close_pm(view, peer) do
    render_click(view, "close_pm_tab", %{"nickname" => peer})
    view
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  # Asserted on the socket and not on the page, and the reason is worth keeping:
  # the row travels to its component by `send_update/2`, which is a message the
  # view sends to itself *after* the one that asked it to render. Whether it has
  # been applied by the time the render replies depends on what else was queued,
  # so the page said "zapdelivered" on an idle machine and said nothing on a
  # loaded one. What is checked instead is the branch the message took: into the
  # conversation on screen, rather than onto its unread badge.
  test "a message arriving in the conversation on screen is not filed as unread", %{conn: conn} do
    nick = "PmDelA#{uid()}"
    peer = "Peer#{uid()}"

    view = connect_user(conn, nick)
    open_pm(view, peer)

    {:ok, _pm} = Service.send_private_message(peer, nick, "zapdelivered")

    # A second of grace: the default 100ms is the CI partition's, not this
    # machine's, and the push queues behind the mount's own event burst.
    assert_push_event(view, "tip_trigger", %{tip: "first_pm"}, 1_000)
    refute Map.has_key?(assigns(view).unread_counts, "pm:#{peer}")
  end

  # Closing a tab used to drop the conversation's subscription without telling
  # the set that remembered which subscriptions the connection held, so
  # reopening the tab believed it was already subscribed and never rejoined:
  # the window was open and the conversation was mute.
  test "a conversation reopened after being closed still receives", %{conn: conn} do
    nick = "PmDelB#{uid()}"
    peer = "Peer#{uid()}"
    elsewhere = "Else#{uid()}"

    view = connect_user(conn, nick)
    open_pm(view, peer)
    close_pm(view, peer)
    open_pm(view, peer)
    open_pm(view, elsewhere)

    {:ok, _pm} = Service.send_private_message(peer, nick, "zapreopened")

    assert assigns(view).unread_counts["pm:#{peer}"] == 1
  end

  # The one message a conversation's own topic could never carry: the reader
  # subscribes because of it.
  test "the first message of a conversation opens it and counts", %{conn: conn} do
    nick = "PmDelC#{uid()}"
    peer = "Peer#{uid()}"

    view = connect_user(conn, nick)

    {:ok, _pm} = Service.send_private_message(peer, nick, "zapfirstever")

    assert peer in assigns(view).open_pm_tabs
    assert assigns(view).unread_counts["pm:#{peer}"] == 1
  end

  # The failure that started all of this: a link pasted into a private
  # conversation was filed by the URL catcher only if the conversation already
  # existed, because the first message of one arrived by a route that did not
  # carry the body.
  test "a link in the first message of a conversation is captured, once", %{conn: conn} do
    nick = "PmDelD#{uid()}"
    peer = "Peer#{uid()}"

    view = connect_user(conn, nick)

    {:ok, _pm} = Service.send_private_message(peer, nick, "look at https://example.com/zapfirst")

    urls = Enum.map(assigns(view).url_catcher_entries, & &1.url)
    assert urls == ["https://example.com/zapfirst"]
  end

  # The writer's own copy: everything a broadcast drives — the URL catcher, the
  # link card — used to happen for the other person only, because the writer was
  # never on the conversation's topic at all.
  test "a link the reader wrote is captured too", %{conn: conn} do
    nick = "PmDelE#{uid()}"
    peer = "Peer#{uid()}"

    view = connect_user(conn, nick)
    open_pm(view, peer)

    {:ok, _pm} = Service.send_private_message(nick, peer, "mine https://example.com/zapmine")

    urls = Enum.map(assigns(view).url_catcher_entries, & &1.url)
    assert urls == ["https://example.com/zapmine"]
  end
end
