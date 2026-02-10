defmodule RetroHexChat.Services.BanTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Services.Ban

  @moduletag :unit

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      attrs = %{channel_name: "#elixir", banned_nickname: "Troll", banned_by: "Admin"}
      changeset = Ban.changeset(%Ban{}, attrs)
      assert changeset.valid?
    end

    test "requires channel_name, banned_nickname, banned_by" do
      changeset = Ban.changeset(%Ban{}, %{})
      refute changeset.valid?
      assert %{channel_name: _, banned_nickname: _, banned_by: _} = errors_on(changeset)
    end

    test "accepts optional reason" do
      attrs = %{
        channel_name: "#elixir",
        banned_nickname: "Troll",
        banned_by: "Admin",
        reason: "Spamming"
      }

      changeset = Ban.changeset(%Ban{}, attrs)
      assert changeset.valid?
    end

    test "validates reason max length 255" do
      attrs = %{
        channel_name: "#elixir",
        banned_nickname: "Troll",
        banned_by: "Admin",
        reason: String.duplicate("a", 256)
      }

      changeset = Ban.changeset(%Ban{}, attrs)
      refute changeset.valid?
    end
  end
end
