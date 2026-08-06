defmodule RetroHexChat.TableTest do
  @moduledoc """
  The structured half of an admin listing reply.

  The property that matters most here is that adding it changed nothing about
  the text: `/admin` in chat still reads exactly what it read before, because
  the same code still produces it.
  """
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Commands.Handlers.Admin.User, as: AdminUser
  alias RetroHexChat.Page
  alias RetroHexChat.Services.Queries
  alias RetroHexChat.Table

  defp register_many(prefix, count) do
    for i <- 1..count do
      {:ok, nick} =
        Queries.insert_registered_nick(
          "#{prefix}#{String.pad_leading("#{i}", 3, "0")}",
          "password123"
        )

      nick
    end
  end

  defp run(args), do: AdminUser.execute(args, %{nickname: "root"})

  describe "the reply carries both halves" do
    test "the text is still the text, and the table travels beside it" do
      register_many("tbluser", 3)

      {:ok, :system, payload} = run(["list", "--search", "tbluser"])

      assert is_binary(payload.content)
      assert payload.content =~ "tbluser001"
      assert %Table{} = payload.table
    end

    test "the chat path can still match on content alone" do
      register_many("tblmatch", 2)

      # This is the shape every existing consumer pattern-matches. A map with an
      # extra key still matches it — that is what makes the addition safe.
      assert {:ok, :system, %{content: text}} = run(["list", "--search", "tblmatch"])
      assert text =~ "tblmatch001"
    end

    test "an empty listing still answers with the plain sentence, no rows" do
      {:ok, :system, payload} = run(["list", "--search", "tblnothingmatches"])

      assert payload.content =~ "No users found"
      assert payload.table.rows == []
    end
  end

  describe "rows" do
    test "one row per listed nick, keyed by something stable" do
      register_many("tblrows", 4)

      {:ok, :system, payload} = run(["list", "--search", "tblrows"])

      assert length(payload.table.rows) == 4
      assert Enum.all?(payload.table.rows, &is_binary(&1.id))
      assert Enum.map(payload.table.rows, & &1.nickname) == Enum.map(payload.table.rows, & &1.id)
    end

    test "rows carry the columns the window renders" do
      register_many("tblcols", 1)

      {:ok, :system, payload} = run(["list", "--search", "tblcols"])

      assert [row] = payload.table.rows
      assert Map.has_key?(row, :nickname)
      assert Map.has_key?(row, :online)
      assert Map.has_key?(row, :last_seen_at)
    end

    test "columns are declared with labels for the header" do
      register_many("tbllabels", 1)

      {:ok, :system, payload} = run(["list", "--search", "tbllabels"])

      assert Enum.all?(payload.table.columns, &(is_atom(&1.key) and is_binary(&1.label)))
    end
  end

  describe "pagination state travels with the table" do
    test "a truncated listing reports the real total and that more exist" do
      register_many("tbltrunc", 130)

      {:ok, :system, payload} = run(["list", "--search", "tbltrunc"])

      assert payload.table.total == 130
      assert Table.has_more?(payload.table)
      assert Table.next_cursor(payload.table)
    end

    test "a complete listing reports no more and no cursor" do
      register_many("tblwhole", 3)

      {:ok, :system, payload} = run(["list", "--search", "tblwhole"])

      refute Table.has_more?(payload.table)
      assert Table.next_cursor(payload.table) == nil
    end

    test "a bounded listing carries no pagination state at all" do
      table = Table.from_list([Table.column(:a, "A")], [%{a: 1}], &%{id: &1.a, a: &1.a})

      assert table.page == nil
      refute Table.has_more?(table)
      assert Table.next_cursor(table) == nil
    end
  end

  describe "from_page/3" do
    test "projects items without disturbing the page's accounting" do
      page = %Page{items: [%{n: 1}, %{n: 2}], has_more: true, next_cursor: 2, total: 99}

      table = Table.from_page([Table.column(:n, "N")], page, &%{id: &1.n, n: &1.n})

      assert Enum.map(table.rows, & &1.n) == [1, 2]
      assert table.total == 99
      assert Table.has_more?(table)
      assert Table.next_cursor(table) == 2
    end
  end

  # A window paginates by running the same command again with a cursor, so what
  # comes back describes only the new page. Appending is what turns those
  # separate replies into one growing listing.
  describe "append/2" do
    defp table_of(items, opts) do
      page = %Page{
        items: items,
        has_more: Keyword.get(opts, :has_more, false),
        next_cursor: Keyword.get(opts, :next_cursor),
        total: Keyword.get(opts, :total)
      }

      Table.from_page([Table.column(:n, "N")], page, &%{id: &1.n, n: &1.n})
    end

    test "puts the later rows under the earlier ones" do
      first = table_of([%{n: 1}, %{n: 2}], has_more: true, next_cursor: 2)
      second = table_of([%{n: 3}, %{n: 4}], has_more: true, next_cursor: 4)

      assert Enum.map(Table.append(first, second).rows, & &1.n) == [1, 2, 3, 4]
    end

    test "adopts the newer page's cursor, so the next request moves forward" do
      first = table_of([%{n: 1}], has_more: true, next_cursor: 1)
      second = table_of([%{n: 2}], has_more: true, next_cursor: 2)

      assert Table.next_cursor(Table.append(first, second)) == 2
    end

    test "a last page ends the listing rather than leaving it open" do
      first = table_of([%{n: 1}], has_more: true, next_cursor: 1)
      last = table_of([%{n: 2}], has_more: false)

      merged = Table.append(first, last)

      refute Table.has_more?(merged)
      assert Table.next_cursor(merged) == nil
    end

    test "keeps the total when a later page does not carry one" do
      first = table_of([%{n: 1}], has_more: true, next_cursor: 1, total: 500)
      second = table_of([%{n: 2}], has_more: false)

      assert Table.append(first, second).total == 500
    end

    test "keeps the columns already on screen" do
      # Otherwise a listing whose shape changed mid-scroll would reorder its
      # columns under the reader.
      first = table_of([%{n: 1}], has_more: true, next_cursor: 1)
      second = %Table{columns: [Table.column(:other, "Other")], rows: [], page: nil}

      assert Table.append(first, second).columns == first.columns
    end
  end
end
