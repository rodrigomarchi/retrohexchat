defmodule RetroHexChat.Channels.PolicyTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Channels.{Membership, Modes, Policy}

  describe "can_join?/5" do
    test "allows join with no restrictions" do
      modes = Modes.new()
      membership = Membership.new()
      assert :ok = Policy.can_join?(modes, membership)
    end

    test "rejects when channel is full (+l)" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+l", ["1"])
      membership = Membership.new() |> Membership.add("existing_user")
      assert {:error, msg} = Policy.can_join?(modes, membership)
      assert msg =~ "full"
    end

    test "rejects invite-only channel (+i)" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+i", [])
      membership = Membership.new()
      assert {:error, msg} = Policy.can_join?(modes, membership)
      assert msg =~ "invite-only"
    end

    test "rejects wrong key (+k)" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+k", ["secret"])
      membership = Membership.new()
      assert {:error, msg} = Policy.can_join?(modes, membership, "wrong")
      assert msg =~ "key"
    end

    test "allows join with correct key" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+k", ["secret"])
      membership = Membership.new()
      assert :ok = Policy.can_join?(modes, membership, "secret")
    end
  end

  describe "can_join? with invite exceptions (T041)" do
    test "invite-only rejects user not in invite_exceptions" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+i", [])
      membership = Membership.new()
      exceptions = MapSet.new()
      assert {:error, msg} = Policy.can_join?(modes, membership, nil, "alice", exceptions)
      assert msg =~ "invite-only"
    end

    test "invite-only allows user in invite_exceptions" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+i", [])
      membership = Membership.new()
      exceptions = MapSet.new(["alice"])
      assert :ok = Policy.can_join?(modes, membership, nil, "alice", exceptions)
    end

    test "non-invite-only channel unaffected by invite_exceptions" do
      modes = Modes.new()
      membership = Membership.new()
      exceptions = MapSet.new()
      assert :ok = Policy.can_join?(modes, membership, nil, "alice", exceptions)
    end
  end

  describe "can_speak?/3" do
    test "allows speaking in non-moderated channel" do
      modes = Modes.new()
      membership = Membership.new() |> Membership.add("alice")
      assert :ok = Policy.can_speak?(modes, membership, "alice")
    end

    test "allows operator to speak in moderated channel" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+m", [])
      membership = Membership.new() |> Membership.add("alice", :operator)
      assert :ok = Policy.can_speak?(modes, membership, "alice")
    end

    test "rejects regular user in moderated channel (+m)" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+m", [])
      membership = Membership.new() |> Membership.add("alice", :regular)
      assert {:error, msg} = Policy.can_speak?(modes, membership, "alice")
      assert msg =~ "moderated"
    end
  end

  describe "can_change_topic?/3" do
    test "allows topic change without topic-lock" do
      modes = Modes.new()
      membership = Membership.new() |> Membership.add("alice")
      assert :ok = Policy.can_change_topic?(modes, membership, "alice")
    end

    test "requires operator with topic-lock (+t)" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+t", [])
      membership = Membership.new() |> Membership.add("alice", :regular)
      assert {:error, _} = Policy.can_change_topic?(modes, membership, "alice")
    end

    test "operator can change topic with topic-lock (+t)" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+t", [])
      membership = Membership.new() |> Membership.add("alice", :operator)
      assert :ok = Policy.can_change_topic?(modes, membership, "alice")
    end

    test "non-member cannot change topic even without topic-lock" do
      modes = Modes.new()
      membership = Membership.new()
      assert {:error, msg} = Policy.can_change_topic?(modes, membership, "outsider")
      assert msg =~ "not in this channel"
    end
  end

  describe "can_speak?/3 additional paths" do
    test "voiced user can speak in moderated channel" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+m", [])
      membership = Membership.new() |> Membership.add("alice", :voiced)
      assert :ok = Policy.can_speak?(modes, membership, "alice")
    end

    test "non-member cannot speak in moderated channel" do
      {:ok, modes} = Modes.apply_changes(Modes.new(), "+m", [])
      membership = Membership.new()
      assert {:error, msg} = Policy.can_speak?(modes, membership, "outsider")
      assert msg =~ "not in this channel"
    end

    test "non-member cannot speak in non-moderated channel" do
      modes = Modes.new()
      membership = Membership.new()
      assert {:error, msg} = Policy.can_speak?(modes, membership, "outsider")
      assert msg =~ "not in this channel"
    end
  end

  describe "operator?/2" do
    test "returns true for operator" do
      membership = Membership.new() |> Membership.add("alice", :operator)
      assert Policy.operator?(membership, "alice")
    end

    test "returns false for regular user" do
      membership = Membership.new() |> Membership.add("alice", :regular)
      refute Policy.operator?(membership, "alice")
    end

    test "returns false for non-member" do
      membership = Membership.new()
      refute Policy.operator?(membership, "ghost")
    end

    test "returns true for owner (owner is also operator)" do
      membership = Membership.new() |> Membership.add("alice", :owner)
      assert Policy.operator?(membership, "alice")
    end
  end

  describe "can_kick?/3" do
    test "operator can kick regular user" do
      m =
        Membership.new()
        |> Membership.add("op", :operator)
        |> Membership.add("user", :regular)

      assert :ok = Policy.can_kick?(m, "op", "user")
    end

    test "half_operator can kick regular user" do
      m =
        Membership.new()
        |> Membership.add("halfop", :half_operator)
        |> Membership.add("user", :regular)

      assert :ok = Policy.can_kick?(m, "halfop", "user")
    end

    test "half_operator cannot kick operator" do
      m =
        Membership.new()
        |> Membership.add("halfop", :half_operator)
        |> Membership.add("op", :operator)

      assert {:error, _} = Policy.can_kick?(m, "halfop", "op")
    end

    test "operator cannot kick owner" do
      m =
        Membership.new()
        |> Membership.add("op", :operator)
        |> Membership.add("owner", :owner)

      assert {:error, _} = Policy.can_kick?(m, "op", "owner")
    end

    test "owner can kick operator" do
      m =
        Membership.new()
        |> Membership.add("owner", :owner)
        |> Membership.add("op", :operator)

      assert :ok = Policy.can_kick?(m, "owner", "op")
    end

    test "regular user cannot kick anyone" do
      m =
        Membership.new()
        |> Membership.add("user", :regular)
        |> Membership.add("other", :regular)

      assert {:error, _} = Policy.can_kick?(m, "user", "other")
    end

    test "equal rank cannot kick" do
      m =
        Membership.new()
        |> Membership.add("op1", :operator)
        |> Membership.add("op2", :operator)

      assert {:error, _} = Policy.can_kick?(m, "op1", "op2")
    end
  end

  describe "can_ban?/2" do
    test "operator can ban" do
      m = Membership.new() |> Membership.add("op", :operator)
      assert :ok = Policy.can_ban?(m, "op")
    end

    test "owner can ban" do
      m = Membership.new() |> Membership.add("owner", :owner)
      assert :ok = Policy.can_ban?(m, "owner")
    end

    test "half_operator cannot ban" do
      m = Membership.new() |> Membership.add("halfop", :half_operator)
      assert {:error, _} = Policy.can_ban?(m, "halfop")
    end

    test "regular user cannot ban" do
      m = Membership.new() |> Membership.add("user", :regular)
      assert {:error, _} = Policy.can_ban?(m, "user")
    end
  end

  describe "can_set_mode?/3" do
    test "owner can set +q" do
      m = Membership.new() |> Membership.add("owner", :owner)
      assert :ok = Policy.can_set_mode?(m, "owner", "q")
    end

    test "operator cannot set +q" do
      m = Membership.new() |> Membership.add("op", :operator)
      assert {:error, _} = Policy.can_set_mode?(m, "op", "q")
    end

    test "operator can set +h" do
      m = Membership.new() |> Membership.add("op", :operator)
      assert :ok = Policy.can_set_mode?(m, "op", "h")
    end

    test "half_operator can set +v" do
      m = Membership.new() |> Membership.add("halfop", :half_operator)
      assert :ok = Policy.can_set_mode?(m, "halfop", "v")
    end

    test "half_operator cannot set +m" do
      m = Membership.new() |> Membership.add("halfop", :half_operator)
      assert {:error, _} = Policy.can_set_mode?(m, "halfop", "m")
    end

    test "operator can set channel flags" do
      m = Membership.new() |> Membership.add("op", :operator)
      assert :ok = Policy.can_set_mode?(m, "op", "n")
      assert :ok = Policy.can_set_mode?(m, "op", "s")
      assert :ok = Policy.can_set_mode?(m, "op", "c")
    end
  end

  describe "can_speak? with +n mode" do
    test "non-member cannot speak with +n" do
      modes = Modes.new()
      {:ok, modes} = Modes.apply_changes(modes, "+n")
      membership = Membership.new() |> Membership.add("alice", :regular)

      assert {:error, _} = Policy.can_speak?(modes, membership, "outsider")
    end

    test "member can speak with +n" do
      modes = Modes.new()
      {:ok, modes} = Modes.apply_changes(modes, "+n")
      membership = Membership.new() |> Membership.add("alice", :regular)

      assert :ok = Policy.can_speak?(modes, membership, "alice")
    end
  end

  describe "can_join? with +R mode" do
    test "unidentified user blocked with +R" do
      modes = Modes.new()
      {:ok, modes} = Modes.apply_changes(modes, "+R")
      membership = Membership.new()

      assert {:error, _} =
               Policy.can_join?(modes, membership, nil, "user", MapSet.new(), false)
    end

    test "identified user allowed with +R" do
      modes = Modes.new()
      {:ok, modes} = Modes.apply_changes(modes, "+R")
      membership = Membership.new()

      assert :ok = Policy.can_join?(modes, membership, nil, "user", MapSet.new(), true)
    end
  end
end
