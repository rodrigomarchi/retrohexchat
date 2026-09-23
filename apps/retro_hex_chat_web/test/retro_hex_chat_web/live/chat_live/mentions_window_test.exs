defmodule RetroHexChatWeb.ChatLive.MentionsWindowTest do
  @moduledoc """
  The window that answers "who has said my name?".

  The one thing it must not do is arrive empty and fill in a moment later: a
  list fetched after the window is on screen races the patch that put it there,
  and the reader watches it blink. So the assertion is that the first page is
  already in the markup the window opens with.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.Queries

  setup ctx do
    nick = "Ment#{uid()}"
    other = "Other#{uid()}"
    {:ok, _} = register(nick)
    {:ok, _} = register(other)
    channel = "#ment#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(nick) |> live(~p"/chat")
    submit_command_sync(view, "/join #{channel}")
    {:ok, _} = Server.join(channel, other)

    %{view: view, nick: nick, other: other, channel: channel}
  end

  test "opens with its first page already drawn", ctx do
    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "hey #{ctx.nick} are you there")
    message = last_message(ctx.channel)

    html = render_click(ctx.view, "open_mentions", %{})

    assert html =~ ~s(data-testid="mentions-window")
    # The row, not the chat line the row is about — the line is on screen too.
    assert html =~ ~s(data-testid="mention-row-#{message.id}")
  end

  test "says so when nobody has mentioned you", ctx do
    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "just talking amongst ourselves")

    html = render_click(ctx.view, "open_mentions", %{})

    assert html =~ ~s(data-testid="list-empty-state")
  end

  # The window is a list of doors. Following one has to reach the message, and a
  # mention from two days ago is exactly the case where the message is older
  # than the page currently loaded.
  test "following a row switches to the channel and points at the message", ctx do
    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "hey #{ctx.nick} over here")
    submit_command_sync(ctx.view, "/join #elsewhere#{uid()}")
    render_click(ctx.view, "open_mentions", %{})

    message = last_message(ctx.channel)
    send(ctx.view.pid, {:open_mention, ctx.channel, message.id})

    assert_push_event(ctx.view, "scroll_to_message", %{message_id: message_id})
    assert message_id == to_string(message.id)
    assert :sys.get_state(ctx.view.pid).socket.assigns.session.active_channel == ctx.channel
  end

  defp last_message(channel) do
    channel
    |> Queries.list_messages(limit: 1)
    |> Map.fetch!(:items)
    |> List.first()
  end

  defp register(nickname) do
    RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
      nickname: nickname,
      password_hash: "x",
      registered_at: DateTime.utc_now(),
      last_seen_at: DateTime.utc_now()
    })
  end
end
