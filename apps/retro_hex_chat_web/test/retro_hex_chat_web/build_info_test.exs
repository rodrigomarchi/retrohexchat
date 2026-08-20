defmodule RetroHexChatWeb.BuildInfoTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias RetroHexChatWeb.BuildInfo

  describe "version/0" do
    test "falls back to the compiled application version" do
      System.delete_env("APP_VERSION")

      version = BuildInfo.version()

      assert is_binary(version)
      assert version != ""
    end

    test "prefers the APP_VERSION environment variable when set" do
      System.put_env("APP_VERSION", "deadbeef")
      on_exit(fn -> System.delete_env("APP_VERSION") end)

      assert BuildInfo.version() == "deadbeef"
    end

    test "ignores an empty APP_VERSION and uses the compiled version" do
      System.put_env("APP_VERSION", "")
      on_exit(fn -> System.delete_env("APP_VERSION") end)

      assert BuildInfo.version() != ""
    end
  end
end
