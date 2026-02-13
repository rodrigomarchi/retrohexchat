defmodule RetroHexChat.Accounts.ServerRolesTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Accounts.ServerRoles

  @moduletag :unit

  describe "admin?/2" do
    test "returns true when identified and in admin list" do
      assert ServerRoles.admin?("TestAdmin", true)
    end

    test "returns false when not identified" do
      refute ServerRoles.admin?("TestAdmin", false)
    end

    test "returns false when not in admin list" do
      refute ServerRoles.admin?("SomeoneElse", true)
    end

    test "returns false when not identified and not in list" do
      refute ServerRoles.admin?("SomeoneElse", false)
    end
  end

  describe "server_operator?/2" do
    test "returns true when identified and in operator list" do
      assert ServerRoles.server_operator?("TestOper", true)
    end

    test "returns false when not identified" do
      refute ServerRoles.server_operator?("TestOper", false)
    end

    test "returns false when not in operator list" do
      refute ServerRoles.server_operator?("SomeoneElse", true)
    end

    test "returns false when not identified and not in list" do
      refute ServerRoles.server_operator?("SomeoneElse", false)
    end
  end

  describe "admin_list/0" do
    test "returns configured admin list" do
      assert is_list(ServerRoles.admin_list())
      assert "TestAdmin" in ServerRoles.admin_list()
    end
  end

  describe "server_operator_list/0" do
    test "returns configured operator list" do
      assert is_list(ServerRoles.server_operator_list())
      assert "TestOper" in ServerRoles.server_operator_list()
    end
  end
end
