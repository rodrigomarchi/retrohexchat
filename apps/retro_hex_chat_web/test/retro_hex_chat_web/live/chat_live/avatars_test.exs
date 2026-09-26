defmodule RetroHexChatWeb.ChatLive.AvatarsTest do
  @moduledoc """
  The chosen character, beside the nickname, in the chat.

  Two absences carry this feature and both are sabotage-tested: the reader who
  turned portraits off sees none, and the person who never chose a character
  gets no placeholder. Either failure puts a picture where the reader asked for
  text, which is the one thing the mIRC look cannot survive.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Accounts.Avatars
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.Roster
  alias RetroHexChat.Services.NickServ

  setup ctx do
    viewer = register("Vie")
    author = register("Aut")
    channel = "#ava#{uid()}"

    :ok = Avatars.remember(author, "knight")

    {:ok, view, _html} = ctx.conn |> chat_conn(viewer, pre_identified: true) |> live(~p"/chat")
    submit_command_sync(view, "/join #{channel}")
    {:ok, _state} = Server.join(channel, author)
    {:ok, _id} = Server.send_message(channel, author, "the wiki is up again")

    render_click(view, "switch_channel", %{"channel" => channel})

    %{view: view, viewer: viewer, author: author, channel: channel}
  end

  test "an author's character is drawn beside their line", ctx do
    assert render(ctx.view) =~ "rh-portrait--knight"
  end

  test "the nicklist draws it too", ctx do
    roster = Roster.of({:channel, ctx.channel})

    assert [%{avatar: "knight"}] = Enum.filter(roster.members, &(&1.nickname == ctx.author))
    assert render(ctx.view) =~ "nicklist-item-#{ctx.author}"
  end

  # Absence, sabotaged and reverted: turning it off has to turn it off.
  test "turning portraits off draws none", ctx do
    assert render(ctx.view) =~ "rh-portrait--knight"

    render_click(ctx.view, "toggle_show_avatars", %{})

    refute assigns(ctx.view).session.show_avatars
    refute render(ctx.view) =~ "rh-portrait--knight"
  end

  # Absence, sabotaged and reverted: nobody gets a stand-in face.
  test "somebody who never chose gets no portrait at all", ctx do
    stranger = register("Str")
    {:ok, _state} = Server.join(ctx.channel, stranger)
    {:ok, _id} = Server.send_message(ctx.channel, stranger, "hello from nowhere")

    html = render(ctx.view)

    assert html =~ "hello from nowhere"
    refute html =~ "nick-portrait-hero"
  end

  test "choosing in the space is what the chat reads", ctx do
    :ok = Avatars.remember(ctx.author, "sorceress")

    render_click(ctx.view, "switch_channel", %{"channel" => ctx.channel})

    assert render(ctx.view) =~ "rh-portrait--sorceress"
  end

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}"
    {:ok, _} = NickServ.register(nickname, "password123")
    nickname
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns
end
