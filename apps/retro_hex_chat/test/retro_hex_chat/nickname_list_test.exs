defmodule RetroHexChat.NicknameListTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.NicknameList

  defmodule Entry do
    @moduledoc false
    defstruct [:nick, :note]
  end

  @list NicknameList.new(field: :nick, max_entries: 3, max_note_length: 5)

  defp entries(nicks), do: Enum.map(nicks, &%Entry{nick: &1, note: nil})

  describe "member?/3" do
    test "a nickname on the list is found however either side was typed" do
      list = entries(["Alice"])

      assert NicknameList.member?(@list, list, "alice")
      assert NicknameList.member?(@list, list, "ALICE")
      assert NicknameList.member?(@list, entries(["alice"]), "Alice")
    end

    test "a nickname nobody added is not on the list" do
      refute NicknameList.member?(@list, entries(["Alice"]), "Bob")
    end

    test "nothing is on an empty list" do
      refute NicknameList.member?(@list, [], "Alice")
    end
  end

  describe "full?/2" do
    test "there is room until the cap is reached" do
      refute NicknameList.full?(@list, entries(["a", "b"]))
      assert NicknameList.full?(@list, entries(["a", "b", "c"]))
    end

    test "a list somehow over the cap is still full" do
      assert NicknameList.full?(@list, entries(["a", "b", "c", "d"]))
    end
  end

  describe "sorted/2" do
    test "alphabetically, ignoring how each was typed" do
      sorted = NicknameList.sorted(@list, entries(["charlie", "Alice", "bob"]))

      assert Enum.map(sorted, & &1.nick) == ["Alice", "bob", "charlie"]
    end
  end

  describe "remove/3" do
    test "takes the nickname off regardless of case" do
      assert {:ok, remaining} = NicknameList.remove(@list, entries(["Alice", "Bob"]), "alice")
      assert Enum.map(remaining, & &1.nick) == ["Bob"]
    end

    test "removing someone who was never there says so" do
      assert NicknameList.remove(@list, entries(["Alice"]), "Bob") == :not_found
    end

    test "the others keep their order" do
      assert {:ok, remaining} =
               NicknameList.remove(@list, entries(["Alice", "Bob", "Carol"]), "Bob")

      assert Enum.map(remaining, & &1.nick) == ["Alice", "Carol"]
    end
  end

  describe "update/4" do
    test "replaces only the matching entry, whatever the case" do
      assert {:ok, updated} =
               NicknameList.update(@list, entries(["Alice", "Bob"]), "ALICE", &%{&1 | note: "hi"})

      assert Enum.map(updated, &{&1.nick, &1.note}) == [{"Alice", "hi"}, {"Bob", nil}]
    end

    test "keeps the order, so an update never reshuffles the list" do
      assert {:ok, updated} =
               NicknameList.update(
                 @list,
                 entries(["Alice", "Bob", "Carol"]),
                 "Bob",
                 &%{&1 | note: "x"}
               )

      assert Enum.map(updated, & &1.nick) == ["Alice", "Bob", "Carol"]
    end

    test "updating someone who was never there says so" do
      assert NicknameList.update(@list, entries(["Alice"]), "Bob", & &1) == :not_found
    end
  end

  describe "truncate_note/2" do
    test "a long note is cut rather than refused" do
      assert NicknameList.truncate_note(@list, "abcdefghij") == "abcde"
    end

    test "a note that fits is left alone" do
      assert NicknameList.truncate_note(@list, "abc") == "abc"
    end

    test "no note stays no note" do
      assert NicknameList.truncate_note(@list, nil) == nil
    end

    test "cuts by characters, not bytes, so a note is never left broken" do
      spec = NicknameList.new(field: :nick, max_entries: 3, max_note_length: 2)

      assert NicknameList.truncate_note(spec, "áéí") == "áé"
    end
  end
end
