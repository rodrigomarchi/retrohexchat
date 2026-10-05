defmodule RetroHexChat.Chat.ArchiveTest do
  @moduledoc """
  What a channel agrees to publish, and everything it does not.

  The centre of this feature is a refusal: nothing said before the switch was
  turned on is ever published. Whoever wrote it wrote it into a room, not onto
  the internet, and no later decision by somebody else can change what they
  agreed to. Every other rule here — deleted lines absent, system chatter out,
  visible text instead of the wire format — follows from the same idea, that a
  public page shows only what a person meant to say in public.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Chat.Attachment
  alias RetroHexChat.Chat.Attachments
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Services.RegisteredChannel

  setup do
    channel = "#arch#{uid()}"
    register(channel)
    %{channel: channel}
  end

  describe "publish/1 and unpublish/1" do
    test "publishing marks the instant, and it is not the registration's", ctx do
      before = DateTime.utc_now()
      assert {:ok, row} = Archive.publish(ctx.channel)

      assert row.public_archive
      assert DateTime.compare(row.archive_since, before) != :lt
    end

    test "publishing twice keeps the first instant", ctx do
      {:ok, first} = Archive.publish(ctx.channel)
      {:ok, again} = Archive.publish(ctx.channel)

      assert first.archive_since == again.archive_since
    end

    test "unpublishing clears the flag", ctx do
      {:ok, _} = Archive.publish(ctx.channel)

      assert {:ok, row} = Archive.unpublish(ctx.channel)
      refute row.public_archive
    end

    test "a channel nobody registered cannot be published" do
      assert {:error, _reason} = Archive.publish("#never#{uid()}")
    end

    test "published?/1 answers for the reader", ctx do
      refute Archive.published?(ctx.channel)
      {:ok, _} = Archive.publish(ctx.channel)
      assert Archive.published?(ctx.channel)
    end

    # A secret channel is not a candidate at all: the switch would publish the
    # existence of something whose whole mode is that it has none.
    test "a +s channel cannot be published", ctx do
      set_modes(ctx.channel, "+s")

      assert {:error, _reason} = Archive.publish(ctx.channel)
      refute Archive.published?(ctx.channel)
    end
  end

  describe "page_for/3" do
    setup ctx do
      old = message(ctx.channel, "said before anybody agreed to this")
      {:ok, _} = Archive.publish(ctx.channel)
      %{old: old}
    end

    # The absence that is the point of the whole item.
    test "nothing said before the switch is published", ctx do
      fresh = message(ctx.channel, "said after")

      texts = ctx.channel |> lines(day_of(fresh)) |> Enum.map(& &1.text)

      assert "said after" in texts
      refute "said before anybody agreed to this" in texts
      refute ctx.old.id in Enum.map(lines(ctx.channel, day_of(ctx.old)), & &1.id)
    end

    test "a deleted line is absent", ctx do
      kept = message(ctx.channel, "this one stays")
      gone = message(ctx.channel, "this one goes")
      {:ok, _} = Queries.soft_delete(gone, DateTime.utc_now())

      texts = ctx.channel |> lines(day_of(kept)) |> Enum.map(& &1.text)

      assert "this one stays" in texts
      refute "this one goes" in texts
    end

    test "system, service and notice lines are absent", ctx do
      said = message(ctx.channel, "a person said this")
      for type <- ~w(system service notice), do: message(ctx.channel, "#{type} noise", type)

      texts = ctx.channel |> lines(day_of(said)) |> Enum.map(& &1.text)

      assert texts == ["a person said this"]
    end

    # A message can be nothing but a file: the composer sends with an empty box
    # when something is attached, and a recorded voice message usually is
    # exactly that. The line still happened, and the archive publishes no
    # attachment — so it says an attachment was there rather than drawing an
    # author, a timestamp and a blank space on a page made for strangers.
    test "a message that is nothing but an attachment says so", ctx do
      said = message_with(ctx.channel, %{content: "", allow_blank_content: true})
      attach(said)

      [entry] = lines(ctx.channel, day_of(said))

      assert entry.attachment?
      assert entry.text == ""
    end

    test "a line with both its words and a file keeps the words and marks the file", ctx do
      said = message(ctx.channel, "look at this")
      attach(said)

      [entry] = lines(ctx.channel, day_of(said))

      assert entry.text == "look at this"
      assert entry.attachment?
    end

    # Absence, and the one this replaces: `attachment?` used to be a constant.
    test "an ordinary line carries no attachment mark", ctx do
      said = message(ctx.channel, "just talking")

      [entry] = lines(ctx.channel, day_of(said))

      refute entry.attachment?
    end

    test "an action is published, because somebody meant it", ctx do
      said = message(ctx.channel, "waves", "action")

      entries = lines(ctx.channel, day_of(said))

      assert [%{text: "waves", action?: true}] = entries
    end

    # Colour and bold are wire format. A page that printed them would show the
    # control bytes' digits as text.
    test "the visible text is published, never the source", ctx do
      said =
        message_with(ctx.channel, %{
          content: "\x0304red\x03 and \x02bold\x02",
          plain_content: "red and bold"
        })

      assert [%{text: "red and bold"}] = lines(ctx.channel, day_of(said))
    end

    test "an edited line says it was edited", ctx do
      said = message(ctx.channel, "first go")
      {:ok, _} = Queries.update_content(said, "second go", DateTime.utc_now())

      assert [%{edited?: true, text: "second go"}] =
               lines(ctx.channel, day_of(said))
    end

    test "chronological, oldest first", ctx do
      first = message(ctx.channel, "one")
      message(ctx.channel, "two")
      message(ctx.channel, "three")

      texts = ctx.channel |> lines(day_of(first)) |> Enum.map(& &1.text)

      assert texts == ["one", "two", "three"]
    end

    test "a channel that is not published has nothing to show", ctx do
      said = message(ctx.channel, "after the switch")
      {:ok, _} = Archive.unpublish(ctx.channel)

      assert lines(ctx.channel, day_of(said)) == []
    end
  end

  describe "days_for/1" do
    test "lists only days that have something publishable", ctx do
      {:ok, _} = Archive.publish(ctx.channel)
      said = message(ctx.channel, "a line")

      assert Archive.days_for(ctx.channel) == [day_of(said)]
    end

    test "a day whose only lines are system chatter is not a day", ctx do
      {:ok, _} = Archive.publish(ctx.channel)
      message(ctx.channel, "joined", "system")

      assert Archive.days_for(ctx.channel) == []
    end

    # Absence assertion, sabotaged and reverted once: turning the switch off has
    # to unpublish, not merely stop adding.
    test "unpublishing empties the index", ctx do
      {:ok, _} = Archive.publish(ctx.channel)
      message(ctx.channel, "a line")
      assert Archive.days_for(ctx.channel) != []

      {:ok, _} = Archive.unpublish(ctx.channel)

      assert Archive.days_for(ctx.channel) == []
    end

    test "a channel nobody published has no days", ctx do
      message(ctx.channel, "a line")

      assert Archive.days_for(ctx.channel) == []
    end
  end

  describe "published_channels/0" do
    test "lists what the sitemap has to offer", ctx do
      {:ok, _} = Archive.publish(ctx.channel)
      message(ctx.channel, "a line")

      assert ctx.channel in Archive.published_channels()
    end

    test "a published channel with nothing publishable is not offered", ctx do
      {:ok, _} = Archive.publish(ctx.channel)

      refute ctx.channel in Archive.published_channels()
    end
  end

  describe "page_for/3 across pages" do
    setup ctx do
      {:ok, _} = Archive.publish(ctx.channel)
      said = for n <- 1..5, do: message(ctx.channel, "line #{n}")
      %{said: said, day: day_of(hd(said))}
    end

    test "the first page has no way back and a cursor forward", ctx do
      %{page: page, previous: previous} = Archive.page_for(ctx.channel, ctx.day, limit: 2)

      assert Enum.map(page.items, & &1.text) == ["line 1", "line 2"]
      assert page.has_more
      assert page.next_cursor == Enum.at(ctx.said, 1).id
      assert previous == nil
    end

    test "a cursor opens the page after it, which points back to the start", ctx do
      %{page: page, previous: previous} =
        Archive.page_for(ctx.channel, ctx.day, limit: 2, after: Enum.at(ctx.said, 1).id)

      assert Enum.map(page.items, & &1.text) == ["line 3", "line 4"]
      assert previous == :start
    end

    test "the last page has nothing after it and a cursor back", ctx do
      %{page: page, previous: previous} =
        Archive.page_for(ctx.channel, ctx.day, limit: 2, after: Enum.at(ctx.said, 3).id)

      assert Enum.map(page.items, & &1.text) == ["line 5"]
      refute page.has_more
      assert previous == Enum.at(ctx.said, 1).id
    end

    # An id that is not a line of this day would otherwise answer the day's
    # first page under a second address.
    test "a cursor from outside the day is an empty page", ctx do
      %{page: page} = Archive.page_for(ctx.channel, ctx.day, after: 1)
      assert page.items == []

      other = message("#elsewhere#{uid()}", "not here")
      %{page: page} = Archive.page_for(ctx.channel, ctx.day, after: other.id)
      assert page.items == []
    end

    # The page after a line keeps its address when the line is withdrawn: the
    # line disappears from its own page, and the next page still opens after it.
    test "a deleted line still opens the page after it", ctx do
      gone = Enum.at(ctx.said, 2)
      {:ok, _} = Queries.soft_delete(gone, DateTime.utc_now())

      %{page: page} = Archive.page_for(ctx.channel, ctx.day, after: gone.id)

      assert Enum.map(page.items, & &1.text) == ["line 4", "line 5"]
    end

    test "only the canonical spelling of a day is a day", ctx do
      assert %{page: %{items: []}} = Archive.page_for(ctx.channel, "+" <> ctx.day)
      refute Archive.page_for(ctx.channel, ctx.day).page.items == []
    end
  end

  defp register(name) do
    {:ok, _} =
      Repo.insert(%RegisteredChannel{
        name: name,
        founder_nickname: "Founder",
        registered_at: DateTime.utc_now(),
        last_activity_at: DateTime.utc_now()
      })
  end

  defp set_modes(name, modes) do
    RegisteredChannel
    |> Repo.get_by!(name: name)
    |> Ecto.Changeset.change(modes: modes)
    |> Repo.update!()
  end

  defp message(channel, content, type \\ "message") do
    message_with(channel, %{content: content, plain_content: content, type: type})
  end

  defp attach(message) do
    {:ok, file, _meta} =
      Attachments.prepare_direct_upload("Speaker", %{
        filename: "voice-20260928-101500.weba",
        content_type: "audio/webm",
        byte_size: 9_112
      })

    {:ok, _} =
      Repo.insert(%Attachment{
        file_id: file.id,
        message_id: message.id,
        display_filename: "voice-20260928-101500.weba",
        position: 0
      })
  end

  defp message_with(channel, attrs) do
    {:ok, message} =
      Queries.insert_message(
        Map.merge(
          %{channel_name: channel, author_nickname: "Speaker", type: "message"},
          attrs
        )
      )

    message
  end

  defp lines(channel, day), do: Archive.page_for(channel, day).page.items

  defp day_of(message), do: message.inserted_at |> DateTime.to_date() |> Date.to_iso8601()

  defp uid, do: rem(System.unique_integer([:positive]), 100_000)
end
