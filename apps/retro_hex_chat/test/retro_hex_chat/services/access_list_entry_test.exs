defmodule RetroHexChat.Services.AccessListEntryTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Services.AccessListEntry

  @moduletag :unit

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      attrs = %{channel_name: "#elixir", nickname: "Rodrigo", level: "sop", added_by: "Admin"}
      changeset = AccessListEntry.changeset(%AccessListEntry{}, attrs)
      assert changeset.valid?
    end

    test "requires all fields" do
      changeset = AccessListEntry.changeset(%AccessListEntry{}, %{})
      refute changeset.valid?
      assert %{channel_name: _, nickname: _, level: _, added_by: _} = errors_on(changeset)
    end

    test "validates level inclusion" do
      for valid <- ~w(founder sop aop vop) do
        attrs = %{channel_name: "#elixir", nickname: "Rodrigo", level: valid, added_by: "Admin"}
        changeset = AccessListEntry.changeset(%AccessListEntry{}, attrs)
        assert changeset.valid?, "Expected #{valid} to be valid"
      end
    end

    test "rejects invalid level" do
      attrs = %{channel_name: "#elixir", nickname: "Rodrigo", level: "admin", added_by: "Admin"}
      changeset = AccessListEntry.changeset(%AccessListEntry{}, attrs)
      refute changeset.valid?
      assert %{level: [_]} = errors_on(changeset)
    end
  end
end
