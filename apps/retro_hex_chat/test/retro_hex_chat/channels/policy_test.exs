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
  end
end
