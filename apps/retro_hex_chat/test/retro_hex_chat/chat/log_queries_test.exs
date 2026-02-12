defmodule RetroHexChat.Chat.LogQueriesTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Chat.LogFilter
  alias RetroHexChat.Chat.LogQueries
  alias RetroHexChat.Chat.Queries

  defp insert_msg!(channel, nick, content, opts \\ []) do
    type = Keyword.get(opts, :type, "message")

    {:ok, msg} =
      Queries.insert_message(%{
        channel_name: channel,
        author_nickname: nick,
        content: content,
        type: type
      })

    case Keyword.get(opts, :inserted_at) do
      nil ->
        msg

      dt ->
        Repo.update_all(
          from(m in "messages", where: m.id == ^msg.id),
          set: [inserted_at: dt]
        )

        Repo.get!(RetroHexChat.Chat.Message, msg.id)
    end
  end

  defp insert_pm!(sender, recipient, content, opts \\ []) do
    {:ok, pm} =
      Queries.insert_private_message(%{
        sender_nickname: sender,
        recipient_nickname: recipient,
        content: content,
        type: Keyword.get(opts, :type, "message")
      })

    case Keyword.get(opts, :inserted_at) do
      nil ->
        pm

      dt ->
        Repo.update_all(
          from(m in "private_messages", where: m.id == ^pm.id),
          set: [inserted_at: dt]
        )

        Repo.get!(RetroHexChat.Chat.PrivateMessage, pm.id)
    end
  end

  describe "search_channel_log/1" do
    test "returns all messages when no filters applied" do
      channel = "#log-test-#{System.unique_integer([:positive])}"
      insert_msg!(channel, "Alice", "hello")
      insert_msg!(channel, "Bob", "world")

      filter = LogFilter.new(%{source: channel})
      page = LogQueries.search_channel_log(filter)

      assert page.total_count == 2
      assert length(page.entries) == 2
      assert page.page == 1
    end

    test "filters by channel source" do
      ch1 = "#src-a-#{System.unique_integer([:positive])}"
      ch2 = "#src-b-#{System.unique_integer([:positive])}"
      insert_msg!(ch1, "Alice", "in ch1")
      insert_msg!(ch2, "Alice", "in ch2")

      filter = LogFilter.new(%{source: ch1})
      page = LogQueries.search_channel_log(filter)

      assert page.total_count == 1
      assert hd(page.entries).content == "in ch1"
    end

    test "filters by date_from" do
      channel = "#df-#{System.unique_integer([:positive])}"
      old_dt = DateTime.new!(~D[2026-01-01], ~T[12:00:00], "Etc/UTC")
      new_dt = DateTime.new!(~D[2026-02-10], ~T[12:00:00], "Etc/UTC")

      insert_msg!(channel, "Alice", "old msg", inserted_at: old_dt)
      insert_msg!(channel, "Alice", "new msg", inserted_at: new_dt)

      filter = LogFilter.new(%{source: channel, date_from: ~D[2026-02-01]})
      page = LogQueries.search_channel_log(filter)

      assert page.total_count == 1
      assert hd(page.entries).content == "new msg"
    end

    test "filters by date_to (inclusive)" do
      channel = "#dt-#{System.unique_integer([:positive])}"
      old_dt = DateTime.new!(~D[2026-01-15], ~T[12:00:00], "Etc/UTC")
      new_dt = DateTime.new!(~D[2026-02-10], ~T[12:00:00], "Etc/UTC")

      insert_msg!(channel, "Alice", "old msg", inserted_at: old_dt)
      insert_msg!(channel, "Alice", "new msg", inserted_at: new_dt)

      filter = LogFilter.new(%{source: channel, date_to: ~D[2026-01-31]})
      page = LogQueries.search_channel_log(filter)

      assert page.total_count == 1
      assert hd(page.entries).content == "old msg"
    end

    test "filters by both date_from and date_to" do
      channel = "#dr-#{System.unique_integer([:positive])}"
      dt1 = DateTime.new!(~D[2026-01-01], ~T[12:00:00], "Etc/UTC")
      dt2 = DateTime.new!(~D[2026-01-15], ~T[12:00:00], "Etc/UTC")
      dt3 = DateTime.new!(~D[2026-02-10], ~T[12:00:00], "Etc/UTC")

      insert_msg!(channel, "Alice", "too early", inserted_at: dt1)
      insert_msg!(channel, "Alice", "in range", inserted_at: dt2)
      insert_msg!(channel, "Alice", "too late", inserted_at: dt3)

      filter =
        LogFilter.new(%{source: channel, date_from: ~D[2026-01-10], date_to: ~D[2026-01-20]})

      page = LogQueries.search_channel_log(filter)

      assert page.total_count == 1
      assert hd(page.entries).content == "in range"
    end

    test "filters by nickname (case-insensitive partial match)" do
      channel = "#nick-#{System.unique_integer([:positive])}"
      insert_msg!(channel, "Alice", "from alice")
      insert_msg!(channel, "Bob", "from bob")
      insert_msg!(channel, "Malice", "from malice")

      filter = LogFilter.new(%{source: channel, nickname: "ali"})
      page = LogQueries.search_channel_log(filter)

      assert page.total_count == 2
      nicks = Enum.map(page.entries, & &1.author_nickname)
      assert "Alice" in nicks
      assert "Malice" in nicks
    end

    test "filters by text (case-insensitive literal match)" do
      channel = "#txt-#{System.unique_integer([:positive])}"
      insert_msg!(channel, "Alice", "Let's discuss the meeting")
      insert_msg!(channel, "Bob", "hello world")

      filter = LogFilter.new(%{source: channel, text: "MEETING"})
      page = LogQueries.search_channel_log(filter)

      assert page.total_count == 1
      assert hd(page.entries).content =~ "meeting"
    end

    test "escapes special characters in text search" do
      channel = "#spec-#{System.unique_integer([:positive])}"
      insert_msg!(channel, "Alice", "I know C++ well")
      insert_msg!(channel, "Bob", "price is $100")

      filter = LogFilter.new(%{source: channel, text: "C++"})
      page = LogQueries.search_channel_log(filter)

      assert page.total_count == 1
      assert hd(page.entries).content =~ "C++"
    end

    test "paginates results" do
      channel = "#pag-#{System.unique_integer([:positive])}"

      for i <- 1..55 do
        dt = DateTime.new!(~D[2026-01-01], Time.new!(0, 0, i, 0), "Etc/UTC")
        insert_msg!(channel, "Alice", "msg #{i}", inserted_at: dt)
      end

      filter1 = LogFilter.new(%{source: channel, page: 1})
      page1 = LogQueries.search_channel_log(filter1)

      assert page1.total_count == 55
      assert page1.total_pages == 2
      assert length(page1.entries) == 50
      assert page1.page == 1

      filter2 = LogFilter.new(%{source: channel, page: 2})
      page2 = LogQueries.search_channel_log(filter2)

      assert length(page2.entries) == 5
      assert page2.page == 2
    end

    test "returns results in chronological order" do
      channel = "#order-#{System.unique_integer([:positive])}"
      dt1 = DateTime.new!(~D[2026-01-01], ~T[10:00:00], "Etc/UTC")
      dt2 = DateTime.new!(~D[2026-01-01], ~T[11:00:00], "Etc/UTC")
      dt3 = DateTime.new!(~D[2026-01-01], ~T[12:00:00], "Etc/UTC")

      insert_msg!(channel, "Alice", "third", inserted_at: dt3)
      insert_msg!(channel, "Alice", "first", inserted_at: dt1)
      insert_msg!(channel, "Alice", "second", inserted_at: dt2)

      filter = LogFilter.new(%{source: channel})
      page = LogQueries.search_channel_log(filter)

      contents = Enum.map(page.entries, & &1.content)
      assert contents == ["first", "second", "third"]
    end

    test "returns empty page when no matches" do
      channel = "#empty-#{System.unique_integer([:positive])}"
      filter = LogFilter.new(%{source: channel})
      page = LogQueries.search_channel_log(filter)

      assert page.total_count == 0
      assert page.total_pages == 0
      assert page.entries == []
    end

    test "combines all filters" do
      channel = "#combo-#{System.unique_integer([:positive])}"
      dt = DateTime.new!(~D[2026-01-15], ~T[12:00:00], "Etc/UTC")

      insert_msg!(channel, "Alice", "project meeting notes", inserted_at: dt)
      insert_msg!(channel, "Alice", "random chat", inserted_at: dt)
      insert_msg!(channel, "Bob", "project meeting notes", inserted_at: dt)

      old = DateTime.new!(~D[2025-12-01], ~T[12:00:00], "Etc/UTC")
      insert_msg!(channel, "Alice", "project meeting notes", inserted_at: old)

      filter =
        LogFilter.new(%{
          source: channel,
          date_from: ~D[2026-01-01],
          date_to: ~D[2026-01-31],
          nickname: "alice",
          text: "meeting"
        })

      page = LogQueries.search_channel_log(filter)

      assert page.total_count == 1
      entry = hd(page.entries)
      assert entry.author_nickname == "Alice"
      assert entry.content =~ "meeting"
    end
  end

  describe "search_pm_log/2" do
    test "finds messages bidirectionally" do
      suffix = System.unique_integer([:positive])
      alice = "PmA#{suffix}"
      bob = "PmB#{suffix}"

      insert_pm!(alice, bob, "from alice")
      insert_pm!(bob, alice, "from bob")

      filter = LogFilter.new(%{source: bob, source_type: :pm})
      page = LogQueries.search_pm_log(alice, filter)

      assert page.total_count == 2
    end

    test "filters by text in PM" do
      suffix = System.unique_integer([:positive])
      alice = "PtA#{suffix}"
      bob = "PtB#{suffix}"

      insert_pm!(alice, bob, "hello world")
      insert_pm!(bob, alice, "meeting notes")

      filter = LogFilter.new(%{source: bob, source_type: :pm, text: "meeting"})
      page = LogQueries.search_pm_log(alice, filter)

      assert page.total_count == 1
      assert hd(page.entries).content =~ "meeting"
    end

    test "filters by date range in PM" do
      suffix = System.unique_integer([:positive])
      alice = "PdA#{suffix}"
      bob = "PdB#{suffix}"

      old = DateTime.new!(~D[2026-01-01], ~T[12:00:00], "Etc/UTC")
      recent = DateTime.new!(~D[2026-02-05], ~T[12:00:00], "Etc/UTC")

      insert_pm!(alice, bob, "old pm", inserted_at: old)
      insert_pm!(bob, alice, "new pm", inserted_at: recent)

      filter =
        LogFilter.new(%{source: bob, source_type: :pm, date_from: ~D[2026-02-01]})

      page = LogQueries.search_pm_log(alice, filter)

      assert page.total_count == 1
      assert hd(page.entries).content == "new pm"
    end
  end

  describe "count_channel_log/1" do
    test "returns count matching filter" do
      channel = "#cnt-#{System.unique_integer([:positive])}"
      insert_msg!(channel, "Alice", "one")
      insert_msg!(channel, "Alice", "two")
      insert_msg!(channel, "Bob", "three")

      filter = LogFilter.new(%{source: channel, nickname: "Alice"})
      assert LogQueries.count_channel_log(filter) == 2
    end
  end

  describe "count_pm_log/2" do
    test "returns count matching filter" do
      suffix = System.unique_integer([:positive])
      alice = "CpA#{suffix}"
      bob = "CpB#{suffix}"

      insert_pm!(alice, bob, "one")
      insert_pm!(bob, alice, "two")

      filter = LogFilter.new(%{source: bob, source_type: :pm})
      assert LogQueries.count_pm_log(alice, filter) == 2
    end
  end

  describe "list_user_channels/1" do
    test "returns distinct channel names sorted" do
      suffix = System.unique_integer([:positive])
      nick = "Luc#{suffix}"
      ch_b = "#beta-#{suffix}"
      ch_a = "#alpha-#{suffix}"

      insert_msg!(ch_b, nick, "in beta")
      insert_msg!(ch_a, nick, "in alpha")
      insert_msg!(ch_b, nick, "again in beta")

      channels = LogQueries.list_user_channels(nick)
      assert channels == [ch_a, ch_b]
    end

    test "returns empty list for unknown user" do
      assert LogQueries.list_user_channels("NoSuchUser999") == []
    end
  end

  describe "list_user_pm_partners/1" do
    test "returns distinct partners from both sent and received" do
      suffix = System.unique_integer([:positive])
      me = "Me#{suffix}"
      alice = "Alice#{suffix}"
      bob = "Bob#{suffix}"

      insert_pm!(me, alice, "sent to alice")
      insert_pm!(bob, me, "from bob")

      partners = LogQueries.list_user_pm_partners(me)
      assert alice in partners
      assert bob in partners
    end

    test "returns sorted list without duplicates" do
      suffix = System.unique_integer([:positive])
      me = "Mx#{suffix}"
      zara = "Zara#{suffix}"
      anna = "Anna#{suffix}"

      insert_pm!(me, zara, "to zara")
      insert_pm!(anna, me, "from anna")
      insert_pm!(me, zara, "again to zara")

      partners = LogQueries.list_user_pm_partners(me)
      assert partners == Enum.sort(partners)
      assert length(partners) == length(Enum.uniq(partners))
    end

    test "returns empty list for unknown user" do
      assert LogQueries.list_user_pm_partners("NoSuchPmUser999") == []
    end
  end
end
