defmodule RetroHexChat.Services.MotdTest do
  # async: false — MOTD uses Application.put_env (global state)
  use RetroHexChat.DataCase, async: false

  @moduletag :unit

  alias RetroHexChat.Services.Motd

  setup do
    Application.delete_env(:retro_hex_chat, :motd_cache)
    :ok
  end

  describe "get/0" do
    test "returns nil when unset" do
      assert Motd.get() == nil
    end

    test "returns text after set" do
      :ok = Motd.set("Welcome to the server!", "Admin")
      assert Motd.get() == "Welcome to the server!"
    end

    test "returns nil after clear" do
      :ok = Motd.set("Temporary MOTD", "Admin")
      assert Motd.get() == "Temporary MOTD"

      :ok = Motd.clear("Admin")
      assert Motd.get() == nil
    end
  end

  describe "set/2" do
    test "persists to DB and updates cache" do
      assert :ok = Motd.set("Hello World", "Admin")

      # Check cache
      assert Motd.get() == "Hello World"

      # Clear cache and reload from DB
      Application.delete_env(:retro_hex_chat, :motd_cache)
      assert Motd.get() == "Hello World"
    end

    test "broadcasts {:motd_updated, ...} to server:settings" do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:settings")

      :ok = Motd.set("Test MOTD", "Admin")

      assert_receive {:motd_updated, %{content: "Test MOTD"}}
    end

    test "overwrites existing MOTD" do
      :ok = Motd.set("First MOTD", "Admin1")
      assert Motd.get() == "First MOTD"

      :ok = Motd.set("Second MOTD", "Admin2")
      assert Motd.get() == "Second MOTD"
    end
  end

  describe "clear/1" do
    test "removes MOTD" do
      :ok = Motd.set("Will be removed", "Admin")
      assert Motd.get() == "Will be removed"

      :ok = Motd.clear("Admin")
      assert Motd.get() == nil
    end

    test "broadcasts {:motd_updated, %{content: nil}}" do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:settings")

      :ok = Motd.set("Will be cleared", "Admin")
      # Consume set broadcast
      assert_receive {:motd_updated, _}

      :ok = Motd.clear("Admin")

      assert_receive {:motd_updated, %{content: nil}}
    end

    test "clearing when no MOTD is set is idempotent" do
      assert Motd.get() == nil
      assert :ok = Motd.clear("Admin")
      assert Motd.get() == nil
    end
  end
end
