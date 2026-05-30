defmodule RetroHexChat.Chat.Schemas.IgnoreListEntryTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.Schemas.IgnoreListEntry

  describe "changeset/2" do
    test "valid changeset with all fields" do
      attrs = %{
        owner_nickname: "TestUser",
        ignored_nickname: "SpamBot",
        ignore_type: "all",
        expires_at: ~U[2026-03-01 00:00:00.000000Z]
      }

      changeset = IgnoreListEntry.changeset(%IgnoreListEntry{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset without expires_at (permanent)" do
      attrs = %{
        owner_nickname: "TestUser",
        ignored_nickname: "SpamBot",
        ignore_type: "all"
      }

      changeset = IgnoreListEntry.changeset(%IgnoreListEntry{}, attrs)
      assert changeset.valid?
    end

    test "requires owner_nickname" do
      attrs = %{ignored_nickname: "SpamBot", ignore_type: "all"}
      changeset = IgnoreListEntry.changeset(%IgnoreListEntry{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).owner_nickname
    end

    test "requires ignored_nickname" do
      attrs = %{owner_nickname: "TestUser", ignore_type: "all"}
      changeset = IgnoreListEntry.changeset(%IgnoreListEntry{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).ignored_nickname
    end

    test "requires ignore_type" do
      attrs = %{owner_nickname: "TestUser", ignored_nickname: "SpamBot"}
      changeset = IgnoreListEntry.changeset(%IgnoreListEntry{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).ignore_type
    end

    test "validates owner_nickname max length 16" do
      attrs = %{
        owner_nickname: String.duplicate("A", 17),
        ignored_nickname: "SpamBot",
        ignore_type: "all"
      }

      changeset = IgnoreListEntry.changeset(%IgnoreListEntry{}, attrs)
      refute changeset.valid?
    end

    test "validates ignored_nickname max length 16" do
      attrs = %{
        owner_nickname: "TestUser",
        ignored_nickname: String.duplicate("A", 17),
        ignore_type: "all"
      }

      changeset = IgnoreListEntry.changeset(%IgnoreListEntry{}, attrs)
      refute changeset.valid?
    end

    test "validates ignore_type inclusion" do
      for valid_type <- ~w(all messages pms invites actions notices) do
        attrs = %{
          owner_nickname: "TestUser",
          ignored_nickname: "SpamBot",
          ignore_type: valid_type
        }

        changeset = IgnoreListEntry.changeset(%IgnoreListEntry{}, attrs)
        assert changeset.valid?, "Expected type '#{valid_type}' to be valid"
      end
    end

    test "rejects invalid ignore_type" do
      attrs = %{
        owner_nickname: "TestUser",
        ignored_nickname: "SpamBot",
        ignore_type: "invalid"
      }

      changeset = IgnoreListEntry.changeset(%IgnoreListEntry{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).ignore_type
    end
  end
end
