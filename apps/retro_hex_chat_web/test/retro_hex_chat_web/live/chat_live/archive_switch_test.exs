defmodule RetroHexChatWeb.ChatLive.ArchiveSwitchTest do
  @moduledoc """
  Opening a channel's archive from Channel Central.

  Two things have to hold no matter what the screen draws. The decision is the
  founder's — an operator moderates the room, but deciding that what is said in
  it becomes readable from outside is a different kind of decision. And the
  room is told: nobody should learn from a search engine that what they say is
  being published.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Topics

  setup ctx do
    founder = register("Fnd")
    other = register("Oth")
    channel = "#arcsw#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(founder, pre_identified: true) |> live(~p"/chat")
    submit_command_sync(view, "/join #{channel}")
    submit_command_sync(view, "/cs register #{channel}")
    open_cc(view, channel)

    %{view: view, founder: founder, other: other, channel: channel}
  end

  # The room being told is asserted on the broadcast rather than on the DOM:
  # the system line reaches the conversation through the same component insert
  # every other channel event uses, and that path is asynchronous.
  test "the founder opens the archive, and the channel is told", ctx do
    refute Archive.published?(ctx.channel)
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(ctx.channel))

    toggle(ctx.view)

    assert Archive.published?(ctx.channel)
    assert_receive {:public_archive_changed, %{enabled: true, nickname: nickname}}
    assert nickname == ctx.founder
  end

  test "and closes it again", ctx do
    toggle(ctx.view)
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(ctx.channel))

    toggle(ctx.view)

    refute Archive.published?(ctx.channel)
    assert_receive {:public_archive_changed, %{enabled: false}}
  end

  # Absence assertion: the switch is drawn for the founder, and the refusal is
  # the channel's — somebody who sends the event anyway is turned down where
  # the membership lives.
  test "an operator who is not the founder is refused", ctx do
    {:ok, other_view, _html} =
      build_conn() |> chat_conn(ctx.other, pre_identified: true) |> live(~p"/chat")

    submit_command_sync(other_view, "/join #{ctx.channel}")
    open_cc(other_view, ctx.channel)

    # The switch is not even drawn for them, which is the first refusal.
    refute render(other_view) =~ "cc-archive-toggle"

    # And the second is the channel's, when the event is sent anyway.
    send_toggle(other_view, ctx.channel, ctx.other)

    refute Archive.published?(ctx.channel)
  end

  defp open_cc(view, channel) do
    render_click(view, "open_channel_central", %{"cc_channel" => channel})
    render(view)
  end

  defp toggle(view) do
    view |> element("[data-testid='cc-archive-toggle']") |> render_click()
  end

  # The event a viewer could send without the control being drawn for them.
  defp send_toggle(view, channel, nickname) do
    Server.set_public_archive(channel, nickname, true)
    render(view)
  end

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}"
    {:ok, _} = NickServ.register(nickname, "password123")
    nickname
  end
end
