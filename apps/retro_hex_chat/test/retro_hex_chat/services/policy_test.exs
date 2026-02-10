defmodule RetroHexChat.Services.PolicyTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Services.{NickServ, Policy}

  describe "identify_required?/1" do
    test "returns true for registered nick" do
      NickServ.register("testuser", "pass123")
      assert Policy.identify_required?("testuser")
    end

    test "returns false for unregistered nick" do
      refute Policy.identify_required?("unknown_user_xyz")
    end
  end

  describe "identified?/1" do
    test "returns true when identified" do
      NickServ.register("id_user", "pass123")
      NickServ.identify("id_user", "pass123")
      assert Policy.identified?("id_user")
    end

    test "returns false when not identified" do
      refute Policy.identified?("not_identified_user")
    end
  end
end
