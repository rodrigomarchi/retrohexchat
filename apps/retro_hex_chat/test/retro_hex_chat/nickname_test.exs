defmodule RetroHexChat.NicknameTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :unit

  import Ecto.Query
  import RetroHexChat.Factory
  import RetroHexChat.Nickname, only: [matches: 2]

  alias RetroHexChat.Nickname
  alias RetroHexChat.Services.RegisteredNick

  describe "key/1" do
    test "case variants share one key" do
      assert Nickname.key("Alice") == Nickname.key("alice")
      assert Nickname.key("AlIcE") == "alice"
    end

    test "only ASCII letters fold, the way Postgres lower() does for this charset" do
      # RFC1459 would fold [ into {; the database indexes would not, so neither does this.
      refute Nickname.key("[bot]") == Nickname.key("{bot}")
      assert Nickname.key("Pix_[]") == "pix_[]"
    end
  end

  describe "equal?/2, member?/2 and find/3" do
    test "equal? ignores case only" do
      assert Nickname.equal?("Alice", "aLiCe")
      refute Nickname.equal?("Alice", "Alicia")
    end

    test "member? finds a case variant in any enumerable" do
      assert Nickname.member?(["Bob", "AlIcE"], "alice")
      assert Nickname.member?(MapSet.new(["Bob"]), "BOB")
      refute Nickname.member?(["Bob"], "alice")
    end

    test "find returns the element as stored, so the display spelling survives" do
      members = [{"Bob", :regular}, {"AlIcE", :operator}]

      assert Nickname.find(members, "alice", &elem(&1, 0)) == {"AlIcE", :operator}
      assert Nickname.find(members, "carol", &elem(&1, 0)) == nil
      assert Nickname.find(["AlIcE"], "ALICE") == "AlIcE"
    end
  end

  describe "matches/2 in a query" do
    test "a stored spelling is found by any case of it" do
      insert(:registered_nick, nickname: "MiXeD")

      found =
        Repo.one(
          from n in RegisteredNick, where: matches(n.nickname, "mixed"), select: n.nickname
        )

      assert found == "MiXeD"
    end
  end
end
