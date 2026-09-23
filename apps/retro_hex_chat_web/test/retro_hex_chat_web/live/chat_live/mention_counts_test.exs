defmodule RetroHexChatWeb.ChatLive.MentionCountsTest do
  @moduledoc """
  Two numbers on a conversation, because there are two questions.

  The grey count says there is something new in there. The mention count says
  somebody is waiting on you. A reader who has to open the conversation to tell
  those apart has done exactly the work the badge existed to save, so the second
  number has to be counted — and cleared — separately.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.Service

  setup ctx do
    nick = "Ment#{uid()}"
    other = "Other#{uid()}"
    {:ok, _} = register(nick)
    {:ok, _} = register(other)
    background = "#back#{uid()}"
    onscreen = "#front#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(nick) |> live(~p"/chat")
    submit_command_sync(view, "/join #{background}")
    submit_command_sync(view, "/join #{onscreen}")
    {:ok, _} = Server.join(background, other)

    %{view: view, nick: nick, other: other, background: background}
  end

  test "a line naming you in a background channel counts twice over", ctx do
    {:ok, _} = Server.send_message(ctx.background, ctx.other, "hey #{ctx.nick} are you there")

    assert counts(ctx.view, :mention_counts)[ctx.background] == 1
    assert counts(ctx.view, :unread_counts)[ctx.background] == 1
  end

  # The whole point of the second number: an ordinary line must not raise it.
  test "a line naming nobody counts only as unread", ctx do
    {:ok, _} = Server.send_message(ctx.background, ctx.other, "just talking amongst ourselves")

    assert counts(ctx.view, :mention_counts) == %{}
    assert counts(ctx.view, :unread_counts)[ctx.background] == 1
  end

  test "two mentions count two", ctx do
    {:ok, _} = Server.send_message(ctx.background, ctx.other, "hey #{ctx.nick} one")
    {:ok, _} = Server.send_message(ctx.background, ctx.other, "hey #{ctx.nick} two")

    assert counts(ctx.view, :mention_counts)[ctx.background] == 2
  end

  test "opening the conversation clears both", ctx do
    {:ok, _} = Server.send_message(ctx.background, ctx.other, "hey #{ctx.nick} are you there")

    render_click(ctx.view, "switch_channel", %{"channel" => ctx.background})

    assert counts(ctx.view, :mention_counts) == %{}
    assert counts(ctx.view, :unread_counts) == %{}
  end

  test "a private message naming you counts as a mention", ctx do
    {:ok, _} = Service.send_private_message(ctx.other, ctx.nick, "hey #{ctx.nick} psst")

    assert counts(ctx.view, :mention_counts)["pm:#{ctx.other}"] == 1
  end

  # A line of your own arriving from another window of yours is not somebody
  # asking for you.
  test "your own message echoed back does not", ctx do
    {:ok, _} = Service.send_private_message(ctx.nick, ctx.other, "talking about #{ctx.nick}")

    assert counts(ctx.view, :mention_counts) == %{}
  end

  defp counts(view, key) do
    :sys.get_state(view.pid).socket.assigns[key]
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
