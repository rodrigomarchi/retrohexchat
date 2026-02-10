defmodule RetroHexChat.Commands.PolicyTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Policy

  describe "pre_dispatch_check/2" do
    test "returns :ok (current stub)" do
      assert :ok = Policy.pre_dispatch_check("join", %{nickname: "alice"})
    end
  end

  describe "require_channel/1" do
    test "returns :ok when active_channel is present" do
      assert :ok = Policy.require_channel(%{active_channel: "#lobby"})
    end

    test "returns error when active_channel is nil" do
      assert {:error, _} = Policy.require_channel(%{active_channel: nil})
    end
  end

  describe "require_identified/1" do
    test "returns :ok when identified is true" do
      assert :ok = Policy.require_identified(%{identified: true})
    end

    test "returns error when identified is false" do
      assert {:error, _} = Policy.require_identified(%{identified: false})
    end

    test "returns error when identified key is absent" do
      assert {:error, _} = Policy.require_identified(%{})
    end
  end

  describe "require_operator/2" do
    test "returns :ok when channel is in operator_in list" do
      ctx = %{operator_in: ["#lobby", "#admin"]}
      assert :ok = Policy.require_operator(ctx, "#lobby")
    end

    test "returns error when channel is not in operator_in list" do
      ctx = %{operator_in: ["#admin"]}
      assert {:error, _} = Policy.require_operator(ctx, "#lobby")
    end
  end
end
