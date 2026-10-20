defmodule RetroHexChat.Services.AccessListEntryTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Services.AccessListEntry

  @moduletag :unit

  describe "changeset/2" do
    test "validates level inclusion" do
      for valid <- ~w(founder sop aop vop) do
        attrs = %{channel_name: "#elixir", nickname: "Alice", level: valid, added_by: "Admin"}
        changeset = AccessListEntry.changeset(%AccessListEntry{}, attrs)
        assert changeset.valid?, "Expected #{valid} to be valid"
      end
    end

    test "rejects invalid level" do
      attrs = %{channel_name: "#elixir", nickname: "Alice", level: "admin", added_by: "Admin"}
      changeset = AccessListEntry.changeset(%AccessListEntry{}, attrs)
      refute changeset.valid?
      assert %{level: [_]} = errors_on(changeset)
    end
  end
end
