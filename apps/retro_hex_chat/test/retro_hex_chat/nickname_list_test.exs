defmodule RetroHexChat.NicknameListTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.NicknameList

  defmodule Entry do
    @moduledoc false
    defstruct [:nick, :note]
  end

  @list NicknameList.new(field: :nick, max_entries: 3, max_note_length: 5)

  # A list is whatever holds the entries, and each one holds more beside them:
  # the notify list carries its settings there. Everything here goes through a
  # list with something else in it, so nothing may quietly drop that.
  defp kept(nicks) do
    %{entries: Enum.map(nicks, &%Entry{nick: &1, note: nil}), settings: :untouched}
  end

  defp nicks(list), do: Enum.map(list.entries, & &1.nick)

  describe "member?/3" do
    test "a nickname on the list is found however either side was typed" do
      assert NicknameList.member?(@list, kept(["Alice"]), "alice")
      assert NicknameList.member?(@list, kept(["Alice"]), "ALICE")
      assert NicknameList.member?(@list, kept(["alice"]), "Alice")
    end

    test "a nickname nobody added is not on the list" do
      refute NicknameList.member?(@list, kept(["Alice"]), "Bob")
    end

    test "nothing is on an empty list" do
      refute NicknameList.member?(@list, kept([]), "Alice")
    end
  end

  describe "full?/2" do
    test "there is room until the cap is reached" do
      refute NicknameList.full?(@list, kept(["a", "b"]))
      assert NicknameList.full?(@list, kept(["a", "b", "c"]))
    end

    test "a list somehow over the cap is still full" do
      assert NicknameList.full?(@list, kept(["a", "b", "c", "d"]))
    end
  end

  describe "sorted/2" do
    test "alphabetically, ignoring how each was typed" do
      sorted = NicknameList.sorted(@list, kept(["charlie", "Alice", "bob"]).entries)

      assert Enum.map(sorted, & &1.nick) == ["Alice", "bob", "charlie"]
    end

    test "orders part of a list too, which is how buddies are grouped" do
      sorted = NicknameList.sorted(@list, kept(["delta", "Bravo"]).entries)

      assert Enum.map(sorted, & &1.nick) == ["Bravo", "delta"]
    end
  end

  describe "remove/3" do
    test "takes the nickname off regardless of case" do
      assert {:ok, list} = NicknameList.remove(@list, kept(["Alice", "Bob"]), "alice")
      assert nicks(list) == ["Bob"]
    end

    test "removing someone who was never there says so" do
      assert NicknameList.remove(@list, kept(["Alice"]), "Bob") == {:error, :not_found}
    end

    test "the others keep their order" do
      assert {:ok, list} = NicknameList.remove(@list, kept(["Alice", "Bob", "Carol"]), "Bob")
      assert nicks(list) == ["Alice", "Carol"]
    end

    test "whatever else the list holds survives" do
      assert {:ok, list} = NicknameList.remove(@list, kept(["Alice"]), "Alice")
      assert list.settings == :untouched
    end
  end

  describe "update/4" do
    test "replaces only the matching entry, whatever the case" do
      assert {:ok, list} =
               NicknameList.update(@list, kept(["Alice", "Bob"]), "ALICE", &%{&1 | note: "hi"})

      assert Enum.map(list.entries, &{&1.nick, &1.note}) == [{"Alice", "hi"}, {"Bob", nil}]
    end

    test "keeps the order, so an update never reshuffles the list" do
      assert {:ok, list} =
               NicknameList.update(
                 @list,
                 kept(["Alice", "Bob", "Carol"]),
                 "Bob",
                 &%{&1 | note: "x"}
               )

      assert nicks(list) == ["Alice", "Bob", "Carol"]
    end

    test "updating someone who was never there says so" do
      assert NicknameList.update(@list, kept(["Alice"]), "Bob", & &1) == {:error, :not_found}
    end

    test "whatever else the list holds survives" do
      assert {:ok, list} = NicknameList.update(@list, kept(["Alice"]), "Alice", & &1)
      assert list.settings == :untouched
    end
  end

  describe "put_note/4" do
    test "cuts the note on the way in, so editing and adding agree" do
      assert {:ok, list} = NicknameList.put_note(@list, kept(["Alice"]), "Alice", "abcdefghij")

      assert hd(list.entries).note == "abcde"
    end

    test "clearing a note is setting it to nothing" do
      {:ok, with_note} = NicknameList.put_note(@list, kept(["Alice"]), "Alice", "hi")
      {:ok, cleared} = NicknameList.put_note(@list, with_note, "Alice", nil)

      assert hd(cleared.entries).note == nil
    end

    test "a nickname nobody added has no note to set" do
      assert NicknameList.put_note(@list, kept(["Alice"]), "Bob", "hi") == {:error, :not_found}
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
