defmodule RetroHexChat.Bots.PolicyTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Policy

  describe "can_manage?/1" do
    test "admin can manage" do
      assert Policy.can_manage?(%{is_admin: true, is_server_operator: false})
    end

    test "server operator can manage" do
      assert Policy.can_manage?(%{is_admin: false, is_server_operator: true})
    end

    test "regular user cannot manage" do
      refute Policy.can_manage?(%{is_admin: false, is_server_operator: false})
    end
  end

  describe "can_create?/1" do
    test "delegates to can_manage?" do
      assert Policy.can_create?(%{is_admin: true, is_server_operator: false})
      refute Policy.can_create?(%{is_admin: false, is_server_operator: false})
    end
  end

  describe "authorize/1" do
    test "returns :ok for admin" do
      assert :ok == Policy.authorize(%{is_admin: true, is_server_operator: false})
    end

    test "returns error for regular user" do
      assert {:error, _} = Policy.authorize(%{is_admin: false, is_server_operator: false})
    end
  end

  # What a message in a channel gets to ask: nothing but a nickname is known
  # there, so the roles are resolved rather than read off a session.
  describe "admin?/1" do
    test "an administrator is recognised by name" do
      assert Policy.admin?("TestAdmin")
    end

    test "a server operator is recognised by name" do
      assert Policy.admin?("TestOper")
    end

    test "anyone else is not" do
      refute Policy.admin?("passerby")
    end

    test "an absent author is not" do
      # Channel events carry no author; the absence must read as "no standing"
      # rather than crash the bot mid-dispatch.
      refute Policy.admin?(nil)
    end
  end
end
