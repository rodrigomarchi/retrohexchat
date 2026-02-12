defmodule RetroHexChat.Chat.CtcpSettingsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.CtcpSettings

  describe "new/0" do
    test "returns default settings" do
      settings = CtcpSettings.new()
      assert settings.enabled == true
      assert settings.version_string == "RetroHexChat v1.0"
      assert settings.finger_text == nil
    end
  end

  describe "getters" do
    test "get_enabled/1 returns enabled status" do
      settings = CtcpSettings.new()
      assert CtcpSettings.get_enabled(settings) == true
    end

    test "get_version_string/1 returns version string" do
      settings = CtcpSettings.new()
      assert CtcpSettings.get_version_string(settings) == "RetroHexChat v1.0"
    end

    test "get_finger_text/1 returns finger text" do
      settings = CtcpSettings.new()
      assert CtcpSettings.get_finger_text(settings) == nil
    end
  end

  describe "set_enabled/2" do
    test "sets enabled to false" do
      settings = CtcpSettings.new() |> CtcpSettings.set_enabled(false)
      assert CtcpSettings.get_enabled(settings) == false
    end

    test "sets enabled to true" do
      settings =
        CtcpSettings.new()
        |> CtcpSettings.set_enabled(false)
        |> CtcpSettings.set_enabled(true)

      assert CtcpSettings.get_enabled(settings) == true
    end
  end

  describe "set_version_string/2" do
    test "sets custom version string" do
      settings = CtcpSettings.new() |> CtcpSettings.set_version_string("MyCoolClient v3.0")
      assert CtcpSettings.get_version_string(settings) == "MyCoolClient v3.0"
    end

    test "truncates version string at 200 characters" do
      long_string = String.duplicate("a", 250)
      settings = CtcpSettings.new() |> CtcpSettings.set_version_string(long_string)
      assert String.length(CtcpSettings.get_version_string(settings)) == 200
    end
  end

  describe "set_finger_text/2" do
    test "sets custom finger text" do
      settings =
        CtcpSettings.new() |> CtcpSettings.set_finger_text("Alice - Elixir developer from Brazil")

      assert CtcpSettings.get_finger_text(settings) == "Alice - Elixir developer from Brazil"
    end

    test "sets finger text to nil" do
      settings =
        CtcpSettings.new()
        |> CtcpSettings.set_finger_text("custom")
        |> CtcpSettings.set_finger_text(nil)

      assert CtcpSettings.get_finger_text(settings) == nil
    end

    test "truncates finger text at 200 characters" do
      long_string = String.duplicate("b", 250)
      settings = CtcpSettings.new() |> CtcpSettings.set_finger_text(long_string)
      assert String.length(CtcpSettings.get_finger_text(settings)) == 200
    end
  end
end
