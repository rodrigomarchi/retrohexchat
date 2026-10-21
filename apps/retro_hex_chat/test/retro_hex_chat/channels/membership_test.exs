defmodule RetroHexChat.Channels.MembershipTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Channels.Membership

  describe "add/3" do
    test "adds a member with default :regular role" do
      m = Membership.new() |> Membership.add("alice")
      assert Membership.member?(m, "alice")
      assert {:ok, :regular} = Membership.role(m, "alice")
    end

    test "adds a member with :operator role" do
      m = Membership.new() |> Membership.add("bob", :operator)
      assert Membership.member?(m, "bob")
      assert {:ok, :operator} = Membership.role(m, "bob")
    end

    test "adds a member with :voiced role" do
      m = Membership.new() |> Membership.add("carol", :voiced)
      assert Membership.member?(m, "carol")
      assert {:ok, :voiced} = Membership.role(m, "carol")
    end

    test "adding multiple members increases count" do
      m =
        Membership.new()
        |> Membership.add("alice")
        |> Membership.add("bob")
        |> Membership.add("carol")

      assert Membership.count(m) == 3
    end

    test "adding the same nickname again overwrites the previous entry" do
      m =
        Membership.new()
        |> Membership.add("alice", :regular)
        |> Membership.add("alice", :operator)

      assert Membership.count(m) == 1
      assert {:ok, :operator} = Membership.role(m, "alice")
    end
  end

  describe "remove/2" do
    test "removes an existing member" do
      m =
        Membership.new()
        |> Membership.add("alice")
        |> Membership.remove("alice")

      refute Membership.member?(m, "alice")
      assert Membership.count(m) == 0
    end

    test "removing a non-existent member is a no-op" do
      m = Membership.new() |> Membership.remove("ghost")
      assert Membership.count(m) == 0
    end

    test "does not affect other members" do
      m =
        Membership.new()
        |> Membership.add("alice")
        |> Membership.add("bob")
        |> Membership.remove("alice")

      refute Membership.member?(m, "alice")
      assert Membership.member?(m, "bob")
      assert Membership.count(m) == 1
    end
  end

  describe "member?/2" do
    test "returns false for non-existent member" do
      m = Membership.new()
      refute Membership.member?(m, "nobody")
    end

    test "any case of a member's nickname finds them, shown as they spell it" do
      m = Membership.new() |> Membership.add("AlIcE", :operator)

      assert Membership.member?(m, "alice")
      assert {:ok, :operator} = Membership.role(m, "ALICE")
      assert {:ok, "AlIcE"} = Membership.display(m, "alice")
      assert Membership.to_list(m) == [{"AlIcE", :operator}]
    end

    test "a case variant is the same member, not a second one" do
      m = Membership.new() |> Membership.add("Alice") |> Membership.add("alice")
      assert Membership.count(m) == 1
    end

    test "a change of case keeps the member and shows the new spelling" do
      m =
        Membership.new()
        |> Membership.add("Alice", :voiced)
        |> Membership.rename("alice", "ALICE")

      assert Membership.to_list(m) == [{"ALICE", :voiced}]
    end
  end

  describe "role/2" do
    test "returns {:error, :not_member} for non-existent member" do
      m = Membership.new()
      assert {:error, :not_member} = Membership.role(m, "nobody")
    end
  end

  describe "set_role/3" do
    test "changes role from :regular to :operator" do
      m =
        Membership.new()
        |> Membership.add("alice", :regular)
        |> Membership.set_role("alice", :operator)

      assert {:ok, :operator} = Membership.role(m, "alice")
    end

    test "changes role from :operator to :voiced" do
      m =
        Membership.new()
        |> Membership.add("alice", :operator)
        |> Membership.set_role("alice", :voiced)

      assert {:ok, :voiced} = Membership.role(m, "alice")
    end

    test "changes role from :voiced to :regular" do
      m =
        Membership.new()
        |> Membership.add("alice", :voiced)
        |> Membership.set_role("alice", :regular)

      assert {:ok, :regular} = Membership.role(m, "alice")
    end

    test "is a no-op for non-existent member" do
      m = Membership.new() |> Membership.set_role("nobody", :operator)
      assert Membership.count(m) == 0
    end
  end

  describe "operators/1" do
    test "returns empty list when no operators" do
      m = Membership.new() |> Membership.add("alice", :regular)
      assert Membership.operators(m) == []
    end

    test "returns list of operators sorted alphabetically" do
      m =
        Membership.new()
        |> Membership.add("charlie", :operator)
        |> Membership.add("alice", :operator)
        |> Membership.add("bob", :regular)

      assert Membership.operators(m) == ["alice", "charlie"]
    end

    test "does not include voiced or regular members" do
      m =
        Membership.new()
        |> Membership.add("alice", :operator)
        |> Membership.add("bob", :voiced)
        |> Membership.add("carol", :regular)

      assert Membership.operators(m) == ["alice"]
    end
  end

  describe "voiced/1" do
    test "returns empty list when no voiced members" do
      m = Membership.new() |> Membership.add("alice", :regular)
      assert Membership.voiced(m) == []
    end

    test "returns list of voiced members sorted alphabetically" do
      m =
        Membership.new()
        |> Membership.add("charlie", :voiced)
        |> Membership.add("alice", :voiced)
        |> Membership.add("bob", :operator)

      assert Membership.voiced(m) == ["alice", "charlie"]
    end

    test "does not include operators or regular members" do
      m =
        Membership.new()
        |> Membership.add("alice", :operator)
        |> Membership.add("bob", :voiced)
        |> Membership.add("carol", :regular)

      assert Membership.voiced(m) == ["bob"]
    end
  end

  describe "count/2" do
    test "counts the bots unless asked to leave them out" do
      m =
        Membership.new()
        |> Membership.add("alice")
        |> Membership.add("Scoreboard", :bot)

      assert Membership.count(m) == 2
      assert Membership.count(m, exclude_bots: true) == 1
    end
  end

  describe "count/1" do
    test "returns 0 for empty membership" do
      assert Membership.count(Membership.new()) == 0
    end
  end

  describe "rename/3" do
    test "transfers membership preserving role" do
      m =
        Membership.new()
        |> Membership.add("alice", :operator)
        |> Membership.add("bob", :regular)

      m = Membership.rename(m, "alice", "alice_new")

      assert Membership.member?(m, "alice_new")
      refute Membership.member?(m, "alice")
      assert {:ok, :operator} = Membership.role(m, "alice_new")
      assert Membership.count(m) == 2
    end

    test "with non-existent user returns unchanged" do
      m = Membership.new() |> Membership.add("alice")

      m2 = Membership.rename(m, "ghost", "new_ghost")

      assert m == m2
      assert Membership.member?(m2, "alice")
      refute Membership.member?(m2, "new_ghost")
    end
  end

  describe "to_list/1" do
    test "returns empty list for empty membership" do
      assert Membership.to_list(Membership.new()) == []
    end

    test "returns sorted list of {nickname, role} tuples" do
      m =
        Membership.new()
        |> Membership.add("charlie", :regular)
        |> Membership.add("alice", :operator)
        |> Membership.add("bob", :voiced)

      assert Membership.to_list(m) == [
               {"alice", :operator},
               {"bob", :voiced},
               {"charlie", :regular}
             ]
    end

    test "reflects role changes" do
      m =
        Membership.new()
        |> Membership.add("alice", :regular)
        |> Membership.set_role("alice", :operator)

      assert Membership.to_list(m) == [{"alice", :operator}]
    end

    test "does not include removed members" do
      m =
        Membership.new()
        |> Membership.add("alice")
        |> Membership.add("bob")
        |> Membership.remove("alice")

      assert Membership.to_list(m) == [{"bob", :regular}]
    end
  end

  describe "owner role" do
    test "add member as owner" do
      m = Membership.new() |> Membership.add("alice", :owner)
      assert {:ok, :owner} = Membership.role(m, "alice")
    end

    test "owners/1 returns sorted list of owners" do
      m =
        Membership.new()
        |> Membership.add("charlie", :owner)
        |> Membership.add("alice", :owner)
        |> Membership.add("bob", :operator)

      assert Membership.owners(m) == ["alice", "charlie"]
    end
  end

  describe "half_operator role" do
    test "add member as half_operator" do
      m = Membership.new() |> Membership.add("alice", :half_operator)
      assert {:ok, :half_operator} = Membership.role(m, "alice")
    end

    test "half_operators/1 returns sorted list of half-operators" do
      m =
        Membership.new()
        |> Membership.add("charlie", :half_operator)
        |> Membership.add("alice", :half_operator)
        |> Membership.add("bob", :operator)

      assert Membership.half_operators(m) == ["alice", "charlie"]
    end
  end

  describe "rank/1" do
    test "rank ordering is strictly hierarchical" do
      assert Membership.rank(:owner) > Membership.rank(:operator)
      assert Membership.rank(:operator) > Membership.rank(:half_operator)
      assert Membership.rank(:half_operator) > Membership.rank(:voiced)
      assert Membership.rank(:voiced) > Membership.rank(:regular)
    end
  end

  describe "outranks?/3" do
    test "owner outranks operator" do
      m =
        Membership.new()
        |> Membership.add("owner", :owner)
        |> Membership.add("op", :operator)

      assert Membership.outranks?(m, "owner", "op")
    end

    test "operator does not outrank owner" do
      m =
        Membership.new()
        |> Membership.add("owner", :owner)
        |> Membership.add("op", :operator)

      refute Membership.outranks?(m, "op", "owner")
    end

    test "half_operator outranks regular" do
      m =
        Membership.new()
        |> Membership.add("halfop", :half_operator)
        |> Membership.add("user", :regular)

      assert Membership.outranks?(m, "halfop", "user")
    end

    test "equal rank does not outrank" do
      m =
        Membership.new()
        |> Membership.add("op1", :operator)
        |> Membership.add("op2", :operator)

      refute Membership.outranks?(m, "op1", "op2")
    end

    test "returns false for non-member" do
      m = Membership.new() |> Membership.add("alice", :operator)
      refute Membership.outranks?(m, "alice", "ghost")
    end
  end
end
