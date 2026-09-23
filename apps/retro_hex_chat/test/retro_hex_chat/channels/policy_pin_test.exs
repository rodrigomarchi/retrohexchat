defmodule RetroHexChat.Channels.PolicyPinTest do
  @moduledoc """
  Who may keep a line in view.

  The same bar as the topic, and for the same reason: both are the channel
  speaking about itself to everybody who walks in. Half-operators moderate the
  conversation; they do not author what the channel says about itself.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.Channels.Policy

  setup do
    membership =
      Membership.new()
      |> Membership.add("Owner", :owner)
      |> Membership.add("Op", :operator)
      |> Membership.add("HalfOp", :half_operator)
      |> Membership.add("Voiced", :voiced)
      |> Membership.add("Regular", :regular)

    %{membership: membership}
  end

  test "an owner may", %{membership: membership} do
    assert :ok = Policy.can_pin?(membership, "Owner")
  end

  test "an operator may", %{membership: membership} do
    assert :ok = Policy.can_pin?(membership, "Op")
  end

  test "a half-operator may not", %{membership: membership} do
    assert {:error, _reason} = Policy.can_pin?(membership, "HalfOp")
  end

  test "being voiced is not being an operator", %{membership: membership} do
    assert {:error, _reason} = Policy.can_pin?(membership, "Voiced")
  end

  test "a regular member may not", %{membership: membership} do
    assert {:error, _reason} = Policy.can_pin?(membership, "Regular")
  end

  test "somebody who is not even in the channel may not", %{membership: membership} do
    assert {:error, _reason} = Policy.can_pin?(membership, "Stranger")
  end
end
