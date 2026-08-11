defmodule RetroHexChat.OwnedListTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Accounts.HighlightWordEntry
  alias RetroHexChat.OwnedList
  alias RetroHexChat.Services.Queries

  defmodule Word do
    @moduledoc false
    defstruct [:word, :position]
  end

  @schema HighlightWordEntry

  # The table points at a registered nickname, so an owner has to be one.
  defp owner do
    nickname = "own#{System.unique_integer([:positive]) |> rem(100_000)}"
    {:ok, _nick} = Queries.insert_registered_nick(nickname, "password123")

    nickname
  end

  defp words(list), do: Enum.map(list, &%Word{word: elem(&1, 0), position: elem(&1, 1)})

  defp to_attrs, do: fn entry -> %{word: entry.word, position: entry.position} end
  defp to_entry, do: fn row -> %Word{word: row.word, position: row.position} end

  defp save(who, list), do: OwnedList.replace(@schema, who, words(list), to_attrs())

  defp stored(who) do
    @schema
    |> where([r], r.owner_nickname == ^who)
    |> Repo.all()
    |> Enum.map(&{&1.word, &1.position})
    |> Enum.sort()
  end

  describe "replace/5" do
    test "writes every entry the list has" do
      who = owner()

      assert :ok = save(who, [{"alpha", 0}, {"beta", 1}])
      assert stored(who) == [{"alpha", 0}, {"beta", 1}]
    end

    test "the rows are exactly the list, so a removed entry is gone" do
      who = owner()
      :ok = save(who, [{"alpha", 0}, {"beta", 1}])

      assert :ok = save(who, [{"beta", 0}])
      assert stored(who) == [{"beta", 0}]
    end

    test "saving an empty list empties it" do
      who = owner()
      :ok = save(who, [{"alpha", 0}])

      assert :ok = save(who, [])
      assert stored(who) == []
    end

    test "the owner is filled in, so no caller repeats it" do
      who = owner()
      :ok = save(who, [{"alpha", 0}])

      assert [row] = Repo.all(where(@schema, [r], r.owner_nickname == ^who))
      assert row.owner_nickname == who
    end

    test "a row the column refuses takes the whole write down with it" do
      who = owner()
      :ok = save(who, [{"alpha", 0}, {"beta", 1}])

      too_long = String.duplicate("x", 51)

      assert_raise Ecto.InvalidChangesetError, fn ->
        save(who, [{"gamma", 0}, {too_long, 1}])
      end

      # Not the new list, not an empty one: what was there before.
      assert stored(who) == [{"alpha", 0}, {"beta", 1}]
    end

    test "the extra step runs, and runs inside the same write" do
      who = owner()
      test_pid = self()

      assert :ok =
               OwnedList.replace(@schema, who, words([{"alpha", 0}]), to_attrs(),
                 then: fn -> send(test_pid, :also_ran) end
               )

      assert_received :also_ran
    end

    test "an extra step that fails leaves the rows as they were" do
      who = owner()
      :ok = save(who, [{"alpha", 0}])

      assert_raise RuntimeError, fn ->
        OwnedList.replace(@schema, who, words([{"beta", 0}]), to_attrs(),
          then: fn -> raise "settings would not save" end
        )
      end

      assert stored(who) == [{"alpha", 0}]
    end

    test "one person's list is not another's" do
      mine = owner()
      theirs = owner()
      :ok = save(mine, [{"alpha", 0}])
      :ok = save(theirs, [{"beta", 0}])

      :ok = save(mine, [])

      assert stored(mine) == []
      assert stored(theirs) == [{"beta", 0}]
    end
  end

  describe "rows/4" do
    test "reads back what was written, as the domain sees it" do
      who = owner()
      :ok = save(who, [{"alpha", 0}])

      assert [%Word{word: "alpha", position: 0}] = OwnedList.rows(@schema, who, to_entry())
    end

    test "in the order named, not the order the database happened to return" do
      who = owner()
      :ok = save(who, [{"charlie", 2}, {"alpha", 0}, {"bravo", 1}])

      entries = OwnedList.rows(@schema, who, to_entry(), order_by: :position)

      assert Enum.map(entries, & &1.word) == ["alpha", "bravo", "charlie"]
    end

    test "keeps only what the domain still counts" do
      who = owner()
      :ok = save(who, [{"keep", 0}, {"drop", 1}])

      entries = OwnedList.rows(@schema, who, to_entry(), keep: &(&1.word != "drop"))

      assert Enum.map(entries, & &1.word) == ["keep"]
    end

    test "somebody with no list has no entries" do
      assert OwnedList.rows(@schema, owner(), to_entry()) == []
    end
  end

  describe "load/4" do
    test "a person who never saved one gets no list, not an empty list" do
      assert OwnedList.load(@schema, owner(), to_entry()) == {:error, :not_found}
    end

    test "a person who saved one gets it back" do
      who = owner()
      :ok = save(who, [{"alpha", 0}])

      assert {:ok, %{entries: [%Word{word: "alpha"}]}} =
               OwnedList.load(@schema, who, to_entry())
    end

    test "a list saved empty reads back as none, which is what starts a person over" do
      who = owner()
      :ok = save(who, [{"alpha", 0}])
      :ok = save(who, [])

      assert OwnedList.load(@schema, who, to_entry()) == {:error, :not_found}
    end
  end
end
