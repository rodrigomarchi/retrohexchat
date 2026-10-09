defmodule RetroHexChat.Nickname.UniquenessTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  import RetroHexChat.Factory

  alias RetroHexChat.Nickname.Uniqueness

  test "rows that differ by nickname case alone are listed with every spelling" do
    Repo.query!("CREATE TEMP TABLE casemap_probe (channel_name text, nickname text)")

    Repo.query!("""
    INSERT INTO casemap_probe VALUES
      ('#a', 'Alice'), ('#a', 'alice'), ('#b', 'Alice'), ('#a', 'Bob')
    """)

    index = %{table: "casemap_probe", scope: ["channel_name"], nickname: "nickname", where: nil}

    assert %{rows: [["#a", ["Alice", "alice"]]]} =
             Repo.query!(Uniqueness.duplicates_sql(index))
  end

  test "the schema refuses a case variant of a registered nickname" do
    insert(:registered_nick, nickname: "Casey")

    assert_raise Ecto.ConstraintError, fn -> insert(:registered_nick, nickname: "CASEY") end
  end

  test "a clean database has nothing to resolve" do
    assert Uniqueness.duplicates(Repo) == []
  end
end
