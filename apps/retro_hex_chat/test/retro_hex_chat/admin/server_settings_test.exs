defmodule RetroHexChat.Admin.ServerSettingsTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Admin
  alias RetroHexChat.Services.Queries

  describe "server_setting/1" do
    test "answers the default while no admin has set it" do
      assert Admin.server_setting("registration") == "open"
      assert Admin.server_setting("welcome_message") == ""
    end

    test "answers what an admin set" do
      {:ok, _} = Queries.upsert_setting("welcome_message", "Be kind.", "Admin")

      assert Admin.server_setting("welcome_message") == "Be kind."
    end

    test "knows no setting outside the server's own" do
      assert_raise FunctionClauseError, fn -> Admin.server_setting("theme") end
    end
  end

  describe "server_name/0" do
    test "is the brand, untranslated, until an admin names the server" do
      assert Admin.server_name() == "RetroHexChat"

      {:ok, _} = Queries.upsert_setting("server_name", "Night Owls", "Admin")

      assert Admin.server_name() == "Night Owls"
    end
  end

  test "server_settings_values/0 answers every setting the way server_setting/1 does" do
    {:ok, _} = Queries.upsert_setting("server_name", "Night Owls", "Admin")

    assert Admin.server_settings_values() ==
             Map.new(Admin.server_setting_keys(), &{&1, Admin.server_setting(&1)})
  end
end
