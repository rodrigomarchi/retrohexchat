defmodule RetroHexChat.Services.RegisteredNicksPageTest do
  @moduledoc """
  The registered-nick listing and the counter the admin user list prints.

  The regression: the header used `length(entries)` over a list capped at 100,
  so a server with thousands of nicks reported "100 results" as if that were the
  total.
  """
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Commands.Handlers.Admin.User, as: AdminUser
  alias RetroHexChat.Page
  alias RetroHexChat.Services.Queries

  defp register(nickname) do
    {:ok, nick} = Queries.insert_registered_nick(nickname, "password123")
    nick
  end

  defp register_many(prefix, count) do
    for i <- 1..count, do: register("#{prefix}#{String.pad_leading("#{i}", 3, "0")}")
  end

  describe "list_registered_nicks/1" do
    test "returns a page carrying the total that matches the filter" do
      register_many("pgtotal", 12)

      page = Queries.list_registered_nicks(search: "pgtotal", limit: 5)

      assert %Page{} = page
      assert length(page.items) == 5
      assert page.has_more
      assert page.total == 12
    end

    test "the total ignores the page size, not the filter" do
      register_many("pgfiltera", 7)
      register_many("pgfilterb", 3)

      page = Queries.list_registered_nicks(search: "pgfilterb", limit: 2)

      assert page.total == 3, "the total counts what matches, not everything in the table"
    end

    test "the alphabetical cursor walks every match exactly once" do
      expected = "pgwalk" |> register_many(11) |> Enum.map(& &1.nickname) |> Enum.sort()

      collected =
        Stream.unfold({nil, true}, fn
          {_cursor, false} ->
            nil

          {cursor, true} ->
            opts = [search: "pgwalk", limit: 4]
            opts = if cursor, do: Keyword.put(opts, :cursor, cursor), else: opts
            page = Queries.list_registered_nicks(opts)
            {Enum.map(page.items, & &1.nickname), {page.next_cursor, page.has_more}}
        end)
        |> Enum.to_list()
        |> List.flatten()

      assert collected == expected
    end
  end

  describe "admin user list header" do
    test "discloses truncation instead of reporting the page size as the total" do
      register_many("pghdr", 130)

      {:ok, :system, %{content: text}} =
        AdminUser.execute(["list", "--search", "pghdr"], %{nickname: "root"})

      [header | _] = String.split(text, "\n")

      assert header =~ "130", "the header must report how many exist"
      refute header =~ "(100 results)", "the page size must never be presented as the total"
    end

    test "reports a plain count when everything fits" do
      register_many("pgsmall", 4)

      {:ok, :system, %{content: text}} =
        AdminUser.execute(["list", "--search", "pgsmall"], %{nickname: "root"})

      [header | _] = String.split(text, "\n")

      assert header =~ "4 results"
    end
  end

  # The Users window reaches page two by running this same command with the last
  # nickname it holds. Without the flag the window can only ever draw the first
  # page, however many rows the database has.
  describe "admin user list --after" do
    test "returns only the nicknames that sort after the cursor" do
      register_many("pgcur", 4)

      {:ok, :system, %{table: table}} =
        AdminUser.execute(["list", "--search", "pgcur"], %{nickname: "root"})

      [first | _] = names = Enum.map(table.rows, & &1.nickname)

      {:ok, :system, %{table: after_table}} =
        AdminUser.execute(["list", "--search", "pgcur", "--after", first], %{nickname: "root"})

      assert Enum.map(after_table.rows, & &1.nickname) == tl(names)
    end

    test "an unknown cursor is not an error, it is simply the end" do
      register_many("pgend", 2)

      {:ok, :system, %{table: table}} =
        AdminUser.execute(["list", "--search", "pgend", "--after", "zzzzzzzz"], %{
          nickname: "root"
        })

      assert table.rows == []
    end
  end
end
