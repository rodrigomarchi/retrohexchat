defmodule RetroHexChatWeb.ChatLive.ReactionsTest do
  @moduledoc """
  Reacting from the screen, and seeing somebody else's reaction arrive.

  Asserted on what the server actually stored rather than on the stream: the
  row is server-authoritative on purpose, so the stored reaction is the fact
  and the row is a picture of it.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.Reactions
  alias RetroHexChatWeb.ChatLive.PubsubHandlers

  @thumbs "\u{1F44D}"

  setup ctx do
    nick = "Reactor#{uid()}"
    other = "Writer#{uid()}"
    {:ok, _} = register(nick)
    {:ok, _} = register(other)
    channel = "#react#{uid()}"

    {:ok, view, _html} = ctx.conn |> chat_conn(nick) |> live("/")
    submit_command_sync(view, "/join #{channel}")
    {:ok, _} = Server.join(channel, other)
    {:ok, message} = Server.send_message(channel, other, "worth reacting to")

    %{view: view, nick: nick, other: other, channel: channel, message_id: message}
  end

  test "clicking a quick pick stores the reaction", ctx do
    message = last_message(ctx.channel)

    render_click(ctx.view, "toggle_reaction", %{
      "message_id" => to_string(message.id),
      "emoji" => @thumbs
    })

    assert %{@thumbs => %{count: 1, actors: [actor]}} = Reactions.summary_for(message)
    assert actor == ctx.nick
  end

  # The line's menu carries the quick picks: on a phone a long press is the way
  # to react, since the line draws no smiley at rest.
  test "a quick pick from the line's menu stores the reaction", ctx do
    message = last_message(ctx.channel)

    render_click(ctx.view, "chat_context_action", %{
      "action" => "ctx_chat_react_pick",
      "message_id" => to_string(message.id),
      "emoji" => @thumbs
    })

    assert %{@thumbs => %{count: 1, actors: [actor]}} = Reactions.summary_for(message)
    assert actor == ctx.nick
  end

  test "clicking it again takes the reaction away", ctx do
    message = last_message(ctx.channel)
    params = %{"message_id" => to_string(message.id), "emoji" => @thumbs}

    render_click(ctx.view, "toggle_reaction", params)
    render_click(ctx.view, "toggle_reaction", params)

    assert Reactions.summary_for(message) == %{}
  end

  # A reaction somebody else made has to reach this screen, and the row it
  # lands on is applied through `send_update` — which is asynchronous, so the
  # stream is the wrong place to ask. What can be asked synchronously is the
  # thing that was actually missing: whether the event is routed at all. It was
  # not, and every unit test underneath it was green.
  test "a reaction from elsewhere is a routed event, not a dropped one" do
    message = %{event: "reaction_changed", payload: %{channel: "#somewhere-else", id: 1}}

    assert {:halt, _socket} = PubsubHandlers.handle_info(message, inactive_socket())
  end

  # The thread window can hold a channel line while a private conversation is
  # the one on screen; the pick says which kind of line it is, so it is not
  # filed against an unrelated private message that shares the number.
  test "a pick names its line's kind, whatever conversation is on screen", ctx do
    message = last_message(ctx.channel)
    submit_command_sync(ctx.view, "/query #{ctx.other}")

    render_click(ctx.view, "toggle_reaction", %{
      "message_id" => to_string(message.id),
      "source" => "channel",
      "emoji" => @thumbs
    })

    assert %{@thumbs => %{count: 1}} = Reactions.summary_for(message)
  end

  # A row that failed to send keeps a client placeholder for its id. Reaching
  # the database with it would raise and take the whole chat down.
  test "a placeholder id is refused, not cast", ctx do
    render_click(ctx.view, "toggle_reaction", %{"message_id" => "pending_3", "emoji" => @thumbs})

    assert Process.alive?(ctx.view.pid)
    assert render(ctx.view) =~ "chat-desktop"
  end

  test "an emoji outside the catalog changes nothing", ctx do
    message = last_message(ctx.channel)

    render_click(ctx.view, "toggle_reaction", %{
      "message_id" => to_string(message.id),
      "emoji" => "not-an-emoji"
    })

    assert Reactions.summary_for(message) == %{}
  end

  # The picker is shared with the composer, so which of the two a pick belongs
  # to is the one thing that can go wrong.
  describe "through the emoji picker" do
    test "an emoji picked for a message becomes a reaction", ctx do
      message = last_message(ctx.channel)

      render_click(ctx.view, "ctx_chat_react", %{"message_id" => to_string(message.id)})
      render_click(ctx.view, "emoji_select", %{"emoji" => @thumbs})

      assert %{@thumbs => %{count: 1}} = Reactions.summary_for(message)
    end

    test "an emoji picked for the composer does not", ctx do
      message = last_message(ctx.channel)

      render_click(ctx.view, "emoji_select", %{"emoji" => @thumbs})

      assert Reactions.summary_for(message) == %{}
    end

    # Closing the picker without picking must not leave the next composer emoji
    # pointing at a line the reader has scrolled past.
    test "closing the picker forgets the message it was opened for", ctx do
      message = last_message(ctx.channel)

      render_click(ctx.view, "ctx_chat_react", %{"message_id" => to_string(message.id)})
      render_click(ctx.view, "toggle_emoji_picker", %{})
      render_click(ctx.view, "emoji_select", %{"emoji" => @thumbs})

      assert Reactions.summary_for(message) == %{}
    end
  end

  # A conversation this session is not looking at: the handler consumes the
  # event and does nothing, which is exactly the half that proves routing.
  defp inactive_socket do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        session: %Session{nickname: "Nobody", active_channel: "#elsewhere", active_pm: nil}
      }
    }
  end

  defp last_message(channel) do
    channel |> Queries.list_messages(limit: 1) |> Map.fetch!(:items) |> List.first()
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
