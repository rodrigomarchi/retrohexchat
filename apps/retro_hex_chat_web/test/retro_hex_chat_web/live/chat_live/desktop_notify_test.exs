defmodule RetroHexChatWeb.ChatLive.DesktopNotifyTest do
  @moduledoc """
  When the server asks the browser to raise a desktop notification.

  The rule is not "something arrived": it is "something arrived that is about
  you, in a conversation you are not looking at, that you have not muted". Each
  of those three is a separate way for this to become noise, so each has a test.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.Service
  alias RetroHexChat.Chat.SoundSettings

  setup ctx do
    nick = "Notified#{uid()}"
    other = "Sender#{uid()}"
    {:ok, _} = register(nick)
    {:ok, _} = register(other)
    channel = "#notif#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(nick) |> live(~p"/chat")
    submit_command_sync(view, "/join #{channel}")
    # Somewhere else is where the reader is looking: a message in the channel
    # they have open is one they can already see.
    submit_command_sync(view, "/join #elsewhere#{uid()}")
    {:ok, _} = Server.join(channel, other)

    %{view: view, nick: nick, other: other, channel: channel}
  end

  test "a mention in a channel you are not looking at asks for a notification", ctx do
    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "hey #{ctx.nick} are you there")

    assert_push_event(ctx.view, "desktop_notify", %{conversation: conversation, body: body})
    assert conversation == ctx.channel
    assert body =~ "are you there"
  end

  test "a private message asks for one", ctx do
    {:ok, _} = Service.send_private_message(ctx.other, ctx.nick, "psst")

    assert_push_event(ctx.view, "desktop_notify", %{conversation: conversation})
    assert conversation == "pm:#{ctx.other}"
  end

  # An ordinary channel line is not about you, and notifying on it is how the
  # whole feature gets switched off on the first day.
  test "an ordinary channel line does not", ctx do
    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "just talking amongst ourselves")

    refute_push_event(ctx.view, "desktop_notify", %{})
  end

  test "a muted conversation does not", ctx do
    render_click(ctx.view, "ctx_conversations_mute", %{
      "channel" => ctx.channel,
      "type" => "channel"
    })

    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "hey #{ctx.nick} still muted?")

    refute_push_event(ctx.view, "desktop_notify", %{})
  end

  test "the conversation you are looking at does not", ctx do
    render_click(ctx.view, "switch_channel", %{"channel" => ctx.channel})

    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "hey #{ctx.nick} look here")

    refute_push_event(ctx.view, "desktop_notify", %{})
  end

  # Driven through what the session actually loads on mount, so it exercises the
  # persistence path as well as the gate.
  test "turning the preference off silences it", ctx do
    quiet = "Quiet#{uid()}"
    {:ok, _} = register(quiet)

    :ok =
      SoundSettings.save(
        quiet,
        SoundSettings.new()
        |> SoundSettings.set_notify(:highlight, false)
        |> SoundSettings.set_notify(:message, false)
      )

    # Preferences load on identify, so the session has to be one that has.
    {:ok, view, _html} =
      ctx.conn |> chat_conn(quiet, pre_identified: true) |> live(~p"/chat")

    submit_command_sync(view, "/join #{ctx.channel}")
    submit_command_sync(view, "/join #elsewhere#{uid()}")

    {:ok, _} = Server.send_message(ctx.channel, ctx.other, "hey #{quiet} silence please")

    refute_push_event(view, "desktop_notify", %{})
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
