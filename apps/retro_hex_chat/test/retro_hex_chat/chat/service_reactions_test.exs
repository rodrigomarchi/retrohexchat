defmodule RetroHexChat.Chat.ServiceReactionsTest do
  @moduledoc """
  Who learns that a reaction changed.

  A reaction is a change to a message that already exists, so it travels the
  same way an edit does: published on the conversation the message was written
  in, saying which conversation that was. A channel names itself; a private
  conversation names a participant, and reaches both inboxes because it has no
  topic of its own.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.Service
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.Topics

  @thumbs "\u{1F44D}"

  setup do
    %{
      channel: "#react#{System.unique_integer([:positive])}",
      ana: register("Ana"),
      bo: register("Bo")
    }
  end

  describe "toggle_reaction/3" do
    test "tells the channel what the emoji looks like now", ctx do
      message = channel_message(ctx.channel)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(ctx.channel))

      assert {:ok, %{count: 1}} = Service.toggle_reaction(message.id, ctx.ana, @thumbs)

      assert_receive %{
        event: "reaction_changed",
        payload: %{id: id, channel: channel, emoji: @thumbs, count: 1, actors: actors}
      }

      assert id == message.id
      assert channel == ctx.channel
      assert actors == [ctx.ana]
    end

    test "says count zero when the last person takes it back", ctx do
      message = channel_message(ctx.channel)
      {:ok, _} = Service.toggle_reaction(message.id, ctx.ana, @thumbs)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(ctx.channel))

      assert {:ok, %{count: 0}} = Service.toggle_reaction(message.id, ctx.ana, @thumbs)

      assert_receive %{event: "reaction_changed", payload: %{count: 0, actors: []}}
    end

    test "refuses an emoji outside the catalog and publishes nothing", ctx do
      message = channel_message(ctx.channel)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(ctx.channel))

      assert {:error, _reason} = Service.toggle_reaction(message.id, ctx.ana, "nope")

      refute_receive %{event: "reaction_changed"}
    end

    test "refuses a message that is not there", ctx do
      assert {:error, _reason} = Service.toggle_reaction(-1, ctx.ana, @thumbs)
    end
  end

  describe "toggle_private_reaction/3" do
    test "reaches both people's inboxes", ctx do
      pm = private_message(ctx.ana, ctx.bo)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(ctx.ana))
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(ctx.bo))

      assert {:ok, %{count: 1}} = Service.toggle_private_reaction(pm.id, ctx.bo, @thumbs)

      assert_receive %{event: "reaction_changed", payload: %{sender: sender, emoji: @thumbs}}
      assert sender == ctx.ana
      assert_receive %{event: "reaction_changed", payload: %{sender: ^sender}}
    end
  end

  defp channel_message(channel) do
    {:ok, message} =
      Queries.insert_message(%{
        channel_name: channel,
        author_nickname: "Writer",
        content: "something worth reacting to",
        type: "message"
      })

    message
  end

  defp private_message(sender, recipient) do
    {:ok, pm} =
      Queries.insert_private_message(%{
        sender_nickname: sender,
        recipient_nickname: recipient,
        content: "something worth reacting to",
        type: "message"
      })

    pm
  end

  defp register(prefix) do
    nickname = "#{prefix}#{System.unique_integer([:positive])}" |> String.slice(0, 16)

    {:ok, _} =
      Repo.insert(%RegisteredNick{
        nickname: nickname,
        password_hash: "x",
        registered_at: DateTime.utc_now(),
        last_seen_at: DateTime.utc_now()
      })

    nickname
  end
end
