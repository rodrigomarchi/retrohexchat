defmodule RetroHexChat.Presence.NotifyListEntryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Presence.NotifyListEntry

  describe "changeset/2" do
    test "valid with required fields" do
      cs =
        NotifyListEntry.changeset(%NotifyListEntry{}, %{
          owner_nickname: "Alice",
          tracked_nickname: "Bob"
        })

      assert cs.valid?
    end

    test "valid with all fields" do
      cs =
        NotifyListEntry.changeset(%NotifyListEntry{}, %{
          owner_nickname: "Alice",
          tracked_nickname: "Bob",
          note: "A friend",
          last_seen_at: DateTime.utc_now()
        })

      assert cs.valid?
    end

    test "invalid without owner_nickname" do
      cs = NotifyListEntry.changeset(%NotifyListEntry{}, %{tracked_nickname: "Bob"})
      refute cs.valid?
      assert errors_on(cs)[:owner_nickname]
    end

    test "invalid without tracked_nickname" do
      cs = NotifyListEntry.changeset(%NotifyListEntry{}, %{owner_nickname: "Alice"})
      refute cs.valid?
      assert errors_on(cs)[:tracked_nickname]
    end

    test "validates owner_nickname max length 16" do
      cs =
        NotifyListEntry.changeset(%NotifyListEntry{}, %{
          owner_nickname: String.duplicate("a", 17),
          tracked_nickname: "Bob"
        })

      refute cs.valid?
      assert errors_on(cs)[:owner_nickname]
    end

    test "validates tracked_nickname max length 16" do
      cs =
        NotifyListEntry.changeset(%NotifyListEntry{}, %{
          owner_nickname: "Alice",
          tracked_nickname: String.duplicate("b", 17)
        })

      refute cs.valid?
      assert errors_on(cs)[:tracked_nickname]
    end

    test "validates note max length 200" do
      cs =
        NotifyListEntry.changeset(%NotifyListEntry{}, %{
          owner_nickname: "Alice",
          tracked_nickname: "Bob",
          note: String.duplicate("x", 201)
        })

      refute cs.valid?
      assert errors_on(cs)[:note]
    end

    test "accepts note at exactly 200 characters" do
      cs =
        NotifyListEntry.changeset(%NotifyListEntry{}, %{
          owner_nickname: "Alice",
          tracked_nickname: "Bob",
          note: String.duplicate("x", 200)
        })

      assert cs.valid?
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
