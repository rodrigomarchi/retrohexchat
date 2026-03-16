defmodule RetroHexChat.Chat.FloodProtectionTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.FloodProtection

  @moduletag :unit

  describe "new/0" do
    test "returns default settings" do
      settings = FloodProtection.new()

      assert settings.flood_threshold == 10
      assert settings.flood_window_seconds == 15
      assert settings.auto_ignore_duration_seconds == 300
      assert settings.spam_threshold == 3
      assert settings.spam_window_seconds == 10
    end
  end

  describe "getters" do
    setup do
      %{settings: FloodProtection.new()}
    end

    test "get_flood_threshold/1", %{settings: s} do
      assert FloodProtection.get_flood_threshold(s) == 10
    end

    test "get_flood_window_seconds/1", %{settings: s} do
      assert FloodProtection.get_flood_window_seconds(s) == 15
    end

    test "get_auto_ignore_duration_seconds/1", %{settings: s} do
      assert FloodProtection.get_auto_ignore_duration_seconds(s) == 300
    end

    test "get_spam_threshold/1", %{settings: s} do
      assert FloodProtection.get_spam_threshold(s) == 3
    end

    test "get_spam_window_seconds/1", %{settings: s} do
      assert FloodProtection.get_spam_window_seconds(s) == 10
    end
  end

  describe "setters" do
    setup do
      %{settings: FloodProtection.new()}
    end

    test "set_flood_threshold/2 updates value", %{settings: s} do
      updated = FloodProtection.set_flood_threshold(s, 20)
      assert FloodProtection.get_flood_threshold(updated) == 20
    end

    test "set_flood_threshold/2 rejects zero", %{settings: s} do
      assert {:error, :invalid_value} = FloodProtection.set_flood_threshold(s, 0)
    end

    test "set_flood_threshold/2 rejects negative", %{settings: s} do
      assert {:error, :invalid_value} = FloodProtection.set_flood_threshold(s, -1)
    end

    test "set_flood_threshold/2 rejects above max", %{settings: s} do
      assert {:error, :invalid_value} = FloodProtection.set_flood_threshold(s, 101)
    end

    test "set_flood_window_seconds/2 updates value", %{settings: s} do
      updated = FloodProtection.set_flood_window_seconds(s, 30)
      assert FloodProtection.get_flood_window_seconds(updated) == 30
    end

    test "set_flood_window_seconds/2 rejects zero", %{settings: s} do
      assert {:error, :invalid_value} = FloodProtection.set_flood_window_seconds(s, 0)
    end

    test "set_flood_window_seconds/2 rejects above max", %{settings: s} do
      assert {:error, :invalid_value} = FloodProtection.set_flood_window_seconds(s, 301)
    end

    test "set_auto_ignore_duration_seconds/2 updates value", %{settings: s} do
      updated = FloodProtection.set_auto_ignore_duration_seconds(s, 600)
      assert FloodProtection.get_auto_ignore_duration_seconds(updated) == 600
    end

    test "set_auto_ignore_duration_seconds/2 rejects zero", %{settings: s} do
      assert {:error, :invalid_value} = FloodProtection.set_auto_ignore_duration_seconds(s, 0)
    end

    test "set_auto_ignore_duration_seconds/2 rejects above max", %{settings: s} do
      assert {:error, :invalid_value} =
               FloodProtection.set_auto_ignore_duration_seconds(s, 86_401)
    end

    test "set_spam_threshold/2 updates value", %{settings: s} do
      updated = FloodProtection.set_spam_threshold(s, 5)
      assert FloodProtection.get_spam_threshold(updated) == 5
    end

    test "set_spam_threshold/2 rejects zero", %{settings: s} do
      assert {:error, :invalid_value} = FloodProtection.set_spam_threshold(s, 0)
    end

    test "set_spam_threshold/2 rejects above max", %{settings: s} do
      assert {:error, :invalid_value} = FloodProtection.set_spam_threshold(s, 51)
    end

    test "set_spam_window_seconds/2 updates value", %{settings: s} do
      updated = FloodProtection.set_spam_window_seconds(s, 20)
      assert FloodProtection.get_spam_window_seconds(updated) == 20
    end

    test "set_spam_window_seconds/2 rejects zero", %{settings: s} do
      assert {:error, :invalid_value} = FloodProtection.set_spam_window_seconds(s, 0)
    end

    test "set_spam_window_seconds/2 rejects above max", %{settings: s} do
      assert {:error, :invalid_value} = FloodProtection.set_spam_window_seconds(s, 121)
    end
  end
end
