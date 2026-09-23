defmodule RetroHexChat.Chat.SearchMentionsTest do
  @moduledoc """
  "Who has said my name?" as a query.

  Deliberately a search rather than a table. A `mentions` table would have to be
  written at the moment each message is, which means loading every reader's
  highlight words on the hot path of every line. The question is asked rarely
  and answered from what is already stored — and this is the one place in the
  product where somebody arriving after two days away finds out what they
  missed.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.Search
  alias RetroHexChat.Page

  setup do
    %{channel: "#ment#{System.unique_integer([:positive])}", nick: "Ana"}
  end

  describe "list_mentions/3" do
    test "finds a line that names the nickname", ctx do
      say(ctx.channel, "Bo", "hey #{ctx.nick} are you there")

      assert %Page{items: [message]} = Search.list_mentions(ctx.nick, [ctx.channel])
      assert message.content =~ ctx.nick
    end

    test "ignores a line that does not", ctx do
      say(ctx.channel, "Bo", "just talking amongst ourselves")

      assert %Page{items: []} = Search.list_mentions(ctx.nick, [ctx.channel])
    end

    test "matches whatever case it was written in", ctx do
      say(ctx.channel, "Bo", "hey ANA look")

      assert %Page{items: [_]} = Search.list_mentions(ctx.nick, [ctx.channel])
    end

    # The list is what you were in, not what exists: a mention in a room you
    # have never opened is somebody else's conversation.
    test "looks only in the channels it was given", ctx do
      say("#elsewhere#{System.unique_integer([:positive])}", "Bo", "hey #{ctx.nick}")

      assert %Page{items: []} = Search.list_mentions(ctx.nick, [ctx.channel])
    end

    test "has nothing to say when given no channels", ctx do
      say(ctx.channel, "Bo", "hey #{ctx.nick}")

      assert %Page{items: [], has_more: false} = Search.list_mentions(ctx.nick, [])
    end

    test "spans every channel it was given", ctx do
      other = "#ment#{System.unique_integer([:positive])}"
      say(ctx.channel, "Bo", "hey #{ctx.nick} one")
      say(other, "Cy", "hey #{ctx.nick} two")

      assert %Page{items: items} = Search.list_mentions(ctx.nick, [ctx.channel, other])
      assert length(items) == 2
    end
  end

  describe "what never counts as a mention" do
    test "a line the room said about itself", ctx do
      say(ctx.channel, "System", "#{ctx.nick} has joined", "system")
      say(ctx.channel, "Service", "#{ctx.nick} is registered", "service")

      assert %Page{items: []} = Search.list_mentions(ctx.nick, [ctx.channel])
    end

    test "a deleted line", ctx do
      message = say(ctx.channel, "Bo", "hey #{ctx.nick}")
      {:ok, _} = Queries.soft_delete(message, DateTime.utc_now())

      assert %Page{items: []} = Search.list_mentions(ctx.nick, [ctx.channel])
    end

    test "your own line", ctx do
      say(ctx.channel, ctx.nick, "talking about #{ctx.nick} in the third person")

      assert %Page{items: []} = Search.list_mentions(ctx.nick, [ctx.channel])
    end

    test "an action still counts", ctx do
      say(ctx.channel, "Bo", "waves at #{ctx.nick}", "action")

      assert %Page{items: [_]} = Search.list_mentions(ctx.nick, [ctx.channel])
    end
  end

  describe "paging" do
    test "answers newest first", ctx do
      for i <- 1..3, do: say(ctx.channel, "Bo", "hey #{ctx.nick} #{i}")

      assert %Page{items: [newest | _]} = Search.list_mentions(ctx.nick, [ctx.channel])
      assert newest.content =~ "3"
    end

    # `has_more` comes from the row the database returned past the page, never
    # from the length of the list — a presentation filter must not be able to
    # end pagination early.
    test "says there is more when there is", ctx do
      for i <- 1..5, do: say(ctx.channel, "Bo", "hey #{ctx.nick} #{i}")

      assert %Page{items: items, has_more: true, next_cursor: cursor} =
               Search.list_mentions(ctx.nick, [ctx.channel], limit: 2)

      assert length(items) == 2
      assert cursor
    end

    test "says there is not when there is not", ctx do
      for i <- 1..2, do: say(ctx.channel, "Bo", "hey #{ctx.nick} #{i}")

      assert %Page{has_more: false, next_cursor: nil} =
               Search.list_mentions(ctx.nick, [ctx.channel], limit: 2)
    end

    test "the next page neither repeats nor skips", ctx do
      for i <- 1..5, do: say(ctx.channel, "Bo", "hey #{ctx.nick} #{i}")

      first = Search.list_mentions(ctx.nick, [ctx.channel], limit: 2)
      second = Search.list_mentions(ctx.nick, [ctx.channel], limit: 2, cursor: first.next_cursor)
      third = Search.list_mentions(ctx.nick, [ctx.channel], limit: 2, cursor: second.next_cursor)

      ids = Enum.map(first.items ++ second.items ++ third.items, & &1.id)

      assert length(ids) == 5
      assert ids == Enum.uniq(ids)
      assert ids == Enum.sort(ids, :desc)
    end
  end

  defp say(channel, author, content, type \\ "message") do
    {:ok, message} =
      Queries.insert_message(%{
        channel_name: channel,
        author_nickname: author,
        content: content,
        type: type
      })

    message
  end
end
