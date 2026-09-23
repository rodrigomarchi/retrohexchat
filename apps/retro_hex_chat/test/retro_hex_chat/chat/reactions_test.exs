defmodule RetroHexChat.Chat.ReactionsTest do
  @moduledoc """
  The cheapest thing a person can say, and the rules that keep it cheap.

  A reaction costs one click and answers a message without writing one, which
  is the whole reason it belongs here: the only way to respond to somebody in
  this product today is to type, and somebody who just arrived does not type.

  Everything asserted below is about not letting that get expensive — one
  reaction per person per emoji, a ceiling on how many distinct ones a message
  can carry, and nothing outside the catalog the picker already offers.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.Reactions
  alias RetroHexChat.Services.RegisteredNick

  @thumbs "\u{1F44D}"
  @heart "\u{2764}\u{FE0F}"

  setup do
    %{message: channel_message(), pm: private_message(), ana: register("Ana"), bo: register("Bo")}
  end

  describe "toggle/3 on a channel message" do
    test "adds a reaction that was not there", ctx do
      assert {:ok, %{emoji: @thumbs, count: 1, actors: [actor]}} =
               Reactions.toggle(ctx.message, ctx.ana, @thumbs)

      assert actor == ctx.ana
    end

    test "takes it away again", ctx do
      {:ok, _} = Reactions.toggle(ctx.message, ctx.ana, @thumbs)

      assert {:ok, %{emoji: @thumbs, count: 0, actors: []}} =
               Reactions.toggle(ctx.message, ctx.ana, @thumbs)

      assert Reactions.summary_for(ctx.message) == %{}
    end

    test "two people on the same emoji count two", ctx do
      {:ok, _} = Reactions.toggle(ctx.message, ctx.ana, @thumbs)

      assert {:ok, %{count: 2, actors: actors}} =
               Reactions.toggle(ctx.message, ctx.bo, @thumbs)

      assert Enum.sort(actors) == Enum.sort([ctx.ana, ctx.bo])
    end

    test "one person on two emoji keeps both", ctx do
      {:ok, _} = Reactions.toggle(ctx.message, ctx.ana, @thumbs)
      {:ok, _} = Reactions.toggle(ctx.message, ctx.ana, @heart)

      summary = Reactions.summary_for(ctx.message)

      assert summary[@thumbs].count == 1
      assert summary[@heart].count == 1
    end
  end

  describe "toggle/3 on a private message" do
    test "works the same way", ctx do
      assert {:ok, %{count: 1}} = Reactions.toggle(ctx.pm, ctx.ana, @thumbs)
      assert {:ok, %{count: 0}} = Reactions.toggle(ctx.pm, ctx.ana, @thumbs)
    end

    test "is kept apart from a channel message with the same id", ctx do
      {:ok, _} = Reactions.toggle(ctx.message, ctx.ana, @thumbs)

      assert Reactions.summary_for(ctx.pm) == %{}
    end
  end

  describe "what is refused" do
    # An arbitrary string here would be unmoderatable content hidden inside a
    # counter, and nothing in the product would ever show it to a moderator.
    test "an emoji the picker does not offer", ctx do
      assert {:error, _reason} = Reactions.toggle(ctx.message, ctx.ana, "not-an-emoji")
      assert {:error, _reason} = Reactions.toggle(ctx.message, ctx.ana, "\u{1F4A9}\u{1F4A9}")
    end

    test "a message that was deleted", ctx do
      {:ok, deleted} = Queries.soft_delete(ctx.message, DateTime.utc_now())

      assert {:error, _reason} = Reactions.toggle(deleted, ctx.ana, @thumbs)
    end

    # The ceiling is on distinct emoji, not on people: twenty faces under one
    # line is already a wall, and there is no reading of the twenty-first.
    test "the twenty-first distinct emoji", ctx do
      for emoji <- Enum.take(Reactions.catalog_emoji(), Reactions.max_distinct()) do
        assert {:ok, _} = Reactions.toggle(ctx.message, ctx.ana, emoji)
      end

      twenty_first = Enum.at(Reactions.catalog_emoji(), Reactions.max_distinct())

      assert {:error, _reason} = Reactions.toggle(ctx.message, ctx.bo, twenty_first)
    end

    test "but joining an emoji already there is still allowed at the ceiling", ctx do
      [first | _] = existing = Enum.take(Reactions.catalog_emoji(), Reactions.max_distinct())

      for emoji <- existing do
        assert {:ok, _} = Reactions.toggle(ctx.message, ctx.ana, emoji)
      end

      assert {:ok, %{count: 2}} = Reactions.toggle(ctx.message, ctx.bo, first)
    end
  end

  describe "summary_for_many/2" do
    test "answers for a whole page in one query", ctx do
      messages = for _i <- 1..50, do: channel_message()
      {:ok, _} = Reactions.toggle(hd(messages), ctx.ana, @thumbs)
      ids = Enum.map(messages, & &1.id)

      {count, summaries} =
        count_queries(fn -> Reactions.summary_for_many(:message, ids) end)

      assert count == 1
      assert summaries[hd(ids)][@thumbs].count == 1
    end

    test "says nothing about a message nobody reacted to", ctx do
      assert Reactions.summary_for_many(:message, [ctx.message.id]) == %{}
    end

    test "keeps the two kinds of message apart", ctx do
      {:ok, _} = Reactions.toggle(ctx.pm, ctx.ana, @thumbs)

      assert Reactions.summary_for_many(:message, [ctx.pm.id]) == %{}
      assert Reactions.summary_for_many(:private_message, [ctx.pm.id])[ctx.pm.id][@thumbs]
    end
  end

  # A reaction has no meaning without the line it is under, so it must not
  # outlive one.
  describe "when the message goes" do
    test "a channel message takes its reactions with it", ctx do
      {:ok, _} = Reactions.toggle(ctx.message, ctx.ana, @thumbs)
      Repo.delete!(ctx.message)

      assert Reactions.summary_for_many(:message, [ctx.message.id]) == %{}
    end

    test "a private message does too", ctx do
      {:ok, _} = Reactions.toggle(ctx.pm, ctx.ana, @thumbs)
      Repo.delete!(ctx.pm)

      assert Reactions.summary_for_many(:private_message, [ctx.pm.id]) == %{}
    end
  end

  defp channel_message do
    {:ok, message} =
      Queries.insert_message(%{
        channel_name: "#react",
        author_nickname: "Writer",
        content: "something worth reacting to",
        type: "message"
      })

    message
  end

  defp private_message do
    {:ok, pm} =
      Queries.insert_private_message(%{
        sender_nickname: "Writer",
        recipient_nickname: "Reader",
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

  defp count_queries(fun) do
    ref = make_ref()
    parent = self()
    handler = "reactions-query-count-#{inspect(ref)}"

    :telemetry.attach(
      handler,
      [:retro_hex_chat, :repo, :query],
      fn _event, _measurements, _metadata, _config -> send(parent, {ref, :query}) end,
      nil
    )

    try do
      result = fun.()
      {drain(ref, 0), result}
    after
      :telemetry.detach(handler)
    end
  end

  defp drain(ref, count) do
    receive do
      {^ref, :query} -> drain(ref, count + 1)
    after
      0 -> count
    end
  end
end
