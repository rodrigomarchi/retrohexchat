defmodule RetroHexChat.Chat.SavedMessagesTest do
  @moduledoc """
  The pile a person keeps for themselves.

  Everything here is about two properties. It is **private**: what one person
  kept is invisible to everybody else, and there is no count, no badge and no
  event that leaks it. And it **outlives the scrollback without outliving the
  line** — a message that was deleted still has a row, because a saved item
  that silently disappears teaches the reader that saving does not work, but
  the row must not still be showing what was deleted.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.SavedMessages
  alias RetroHexChat.Services.RegisteredNick

  setup do
    %{ana: register("Ana"), bo: register("Bo"), message: channel_message(), pm: private_message()}
  end

  describe "save/3" do
    test "keeps a channel line, once", ctx do
      assert {:ok, _saved} = SavedMessages.save(ctx.ana, ctx.message)
      assert {:ok, _same} = SavedMessages.save(ctx.ana, ctx.message)

      assert SavedMessages.count(ctx.ana) == 1
    end

    test "keeps a private line the same way", ctx do
      assert {:ok, _saved} = SavedMessages.save(ctx.ana, ctx.pm)
      assert {:ok, _same} = SavedMessages.save(ctx.ana, ctx.pm)

      assert SavedMessages.count(ctx.ana) == 1
    end

    test "carries a note when one is given", ctx do
      {:ok, _saved} = SavedMessages.save(ctx.ana, ctx.message, "the address")

      assert [%{note: "the address"}] = SavedMessages.list(ctx.ana).items
    end

    test "refuses a line that was deleted", ctx do
      {:ok, deleted} = Queries.soft_delete(ctx.message, DateTime.utc_now())

      assert {:error, _reason} = SavedMessages.save(ctx.ana, deleted)
      assert SavedMessages.count(ctx.ana) == 0
    end

    # Absence assertion: the ceiling is the only thing standing between a
    # private list and a second unbounded scrollback.
    test "refuses one past the ceiling", ctx do
      for _ <- 1..SavedMessages.max_per_owner() do
        {:ok, _saved} = SavedMessages.save(ctx.ana, channel_message())
      end

      assert {:error, _reason} = SavedMessages.save(ctx.ana, channel_message())
      assert SavedMessages.count(ctx.ana) == SavedMessages.max_per_owner()
    end
  end

  describe "unsave/2" do
    test "removes it and is quiet about one that was never there", ctx do
      {:ok, _saved} = SavedMessages.save(ctx.ana, ctx.message)

      assert :ok = SavedMessages.unsave(ctx.ana, ctx.message)
      assert :ok = SavedMessages.unsave(ctx.ana, ctx.message)
      assert SavedMessages.count(ctx.ana) == 0
    end

    test "the window removes by row id, and only its owner's", ctx do
      {:ok, _hers} = SavedMessages.save(ctx.ana, ctx.message)
      [entry] = SavedMessages.list(ctx.ana).items

      assert {:error, _reason} = SavedMessages.unsave_id(ctx.bo, entry.id)
      assert SavedMessages.count(ctx.ana) == 1

      assert :ok = SavedMessages.unsave_id(ctx.ana, entry.id)
      assert SavedMessages.count(ctx.ana) == 0
    end

    test "leaves another person's copy of the same line alone", ctx do
      {:ok, _hers} = SavedMessages.save(ctx.ana, ctx.message)
      {:ok, _his} = SavedMessages.save(ctx.bo, ctx.message)

      assert :ok = SavedMessages.unsave(ctx.bo, ctx.message)
      assert SavedMessages.count(ctx.ana) == 1
    end
  end

  describe "the list is private" do
    # Absence assertion, sabotaged and reverted once: the whole feature rests
    # on nobody else being able to see what you kept.
    test "what one person saved does not appear for another", ctx do
      {:ok, _saved} = SavedMessages.save(ctx.ana, ctx.message)

      assert SavedMessages.list(ctx.bo).items == []
      assert SavedMessages.count(ctx.bo) == 0
      refute SavedMessages.saved?(ctx.bo, ctx.message)
      assert SavedMessages.saved?(ctx.ana, ctx.message)
    end
  end

  describe "list/2" do
    test "pages newest first, and says when there is more", ctx do
      for _ <- 1..4, do: {:ok, _} = SavedMessages.save(ctx.ana, channel_message())

      page = SavedMessages.list(ctx.ana, limit: 2)

      assert length(page.items) == 2
      assert page.has_more
      assert page.next_cursor

      rest = SavedMessages.list(ctx.ana, limit: 2, cursor: page.next_cursor)
      assert length(rest.items) == 2
      refute rest.has_more
    end

    test "carries the line itself, and where it was said", ctx do
      {:ok, _saved} = SavedMessages.save(ctx.ana, ctx.message)

      assert [entry] = SavedMessages.list(ctx.ana).items
      assert entry.message_id == ctx.message.id
      assert entry.content == ctx.message.content
      assert entry.author_nickname == ctx.message.author_nickname
      assert entry.channel_name == ctx.message.channel_name
      refute entry.deleted?
    end

    test "a private line carries both sides, so the window knows where to go", ctx do
      {:ok, _saved} = SavedMessages.save(ctx.ana, ctx.pm)

      assert [entry] = SavedMessages.list(ctx.ana).items
      assert entry.private_message_id == ctx.pm.id
      assert entry.author_nickname == ctx.pm.sender_nickname
      assert entry.pm_sender == ctx.pm.sender_nickname
      assert entry.pm_recipient == ctx.pm.recipient_nickname
      assert entry.channel_name == nil
    end

    test "channel and private lines come back in one list", ctx do
      {:ok, _first} = SavedMessages.save(ctx.ana, ctx.message)
      {:ok, _second} = SavedMessages.save(ctx.ana, ctx.pm)

      ids = Enum.map(SavedMessages.list(ctx.ana).items, & &1.id)

      assert length(ids) == 2
      assert ids == Enum.sort(ids, :desc)
    end

    # The row stays and says so. Vanishing would read as the save having
    # failed; still showing the text would undo the deletion.
    test "a deleted line keeps its row, marked, without its content", ctx do
      {:ok, _saved} = SavedMessages.save(ctx.ana, ctx.message)
      {:ok, _deleted} = Queries.soft_delete(ctx.message, DateTime.utc_now())

      assert [entry] = SavedMessages.list(ctx.ana).items
      assert entry.deleted?
      assert entry.content == nil
      assert entry.plain_content == nil
    end

    test "a person with nothing saved has an empty page", ctx do
      page = SavedMessages.list(ctx.ana)

      assert page.items == []
      refute page.has_more
    end
  end

  # The row points at a line. A line that is really gone has no row to point
  # at it, and that is the database's job rather than a sweep somebody
  # remembers to write.
  describe "the line going away" do
    test "destroying the channel message takes the saved row with it", ctx do
      {:ok, _saved} = SavedMessages.save(ctx.ana, ctx.message)

      Repo.delete!(Repo.get!(Message, ctx.message.id))

      assert SavedMessages.count(ctx.ana) == 0
    end

    test "destroying the private message does too", ctx do
      {:ok, _saved} = SavedMessages.save(ctx.ana, ctx.pm)

      Repo.delete!(ctx.pm)

      assert SavedMessages.count(ctx.ana) == 0
    end
  end

  defp channel_message do
    {:ok, message} =
      Queries.insert_message(%{
        channel_name: "#saved#{uid()}",
        author_nickname: "Writer",
        content: "something worth keeping #{uid()}",
        type: "message"
      })

    message
  end

  defp private_message do
    {:ok, pm} =
      Queries.insert_private_message(%{
        sender_nickname: "Writer",
        recipient_nickname: "Reader",
        content: "something worth keeping #{uid()}",
        type: "message"
      })

    pm
  end

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}" |> String.slice(0, 16)

    {:ok, _} =
      Repo.insert(%RegisteredNick{
        nickname: nickname,
        password_hash: "x",
        registered_at: DateTime.utc_now(),
        last_seen_at: DateTime.utc_now()
      })

    nickname
  end

  defp uid, do: rem(System.unique_integer([:positive]), 100_000)
end
