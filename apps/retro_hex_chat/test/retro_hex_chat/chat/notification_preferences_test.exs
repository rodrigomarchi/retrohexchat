defmodule RetroHexChat.Chat.NotificationPreferencesTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.NotificationPreferences

  @moduletag :unit

  describe "new/0" do
    test "returns default notification preferences" do
      prefs = NotificationPreferences.new()

      assert prefs.sounds_enabled == true
      assert prefs.browser_notifications == false
      assert prefs.title_flash_enabled == true
      assert prefs.privacy_mode == false
      assert prefs.dnd_enabled == false
    end

    test "returns default trigger rules" do
      prefs = NotificationPreferences.new()

      assert prefs.trigger_mentions == true
      assert prefs.trigger_pms == true
      assert prefs.trigger_channel_messages == false
      assert prefs.trigger_joins_leaves == false
    end

    test "returns empty channel levels" do
      prefs = NotificationPreferences.new()
      assert prefs.channel_levels == %{}
    end
  end

  describe "set_sounds_enabled/2" do
    test "sets sounds_enabled to false" do
      prefs = NotificationPreferences.new() |> NotificationPreferences.set_sounds_enabled(false)
      assert prefs.sounds_enabled == false
    end

    test "sets sounds_enabled to true" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_sounds_enabled(false)
        |> NotificationPreferences.set_sounds_enabled(true)

      assert prefs.sounds_enabled == true
    end
  end

  describe "set_browser_notifications/2" do
    test "sets browser_notifications to true" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_browser_notifications(true)

      assert prefs.browser_notifications == true
    end
  end

  describe "set_title_flash_enabled/2" do
    test "sets title_flash_enabled to false" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_title_flash_enabled(false)

      assert prefs.title_flash_enabled == false
    end
  end

  describe "set_privacy_mode/2" do
    test "sets privacy_mode to true" do
      prefs = NotificationPreferences.new() |> NotificationPreferences.set_privacy_mode(true)
      assert prefs.privacy_mode == true
    end
  end

  describe "set_dnd_enabled/2" do
    test "sets dnd_enabled to true" do
      prefs = NotificationPreferences.new() |> NotificationPreferences.set_dnd_enabled(true)
      assert prefs.dnd_enabled == true
    end
  end

  describe "set_trigger_mentions/2" do
    test "sets trigger_mentions to false" do
      prefs =
        NotificationPreferences.new() |> NotificationPreferences.set_trigger_mentions(false)

      assert prefs.trigger_mentions == false
    end
  end

  describe "set_trigger_pms/2" do
    test "sets trigger_pms to false" do
      prefs = NotificationPreferences.new() |> NotificationPreferences.set_trigger_pms(false)
      assert prefs.trigger_pms == false
    end
  end

  describe "set_trigger_channel_messages/2" do
    test "sets trigger_channel_messages to true" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_trigger_channel_messages(true)

      assert prefs.trigger_channel_messages == true
    end
  end

  describe "set_trigger_joins_leaves/2" do
    test "sets trigger_joins_leaves to true" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_trigger_joins_leaves(true)

      assert prefs.trigger_joins_leaves == true
    end
  end

  describe "set_channel_level/3" do
    test "sets channel to normal" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_channel_level("#general", :normal)

      assert NotificationPreferences.get_channel_level(prefs, "#general") == :normal
    end

    test "sets channel to mentions_only" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_channel_level("#dev", :mentions_only)

      assert NotificationPreferences.get_channel_level(prefs, "#dev") == :mentions_only
    end

    test "sets channel to mute" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_channel_level("#music", :mute)

      assert NotificationPreferences.get_channel_level(prefs, "#music") == :mute
    end

    test "rejects invalid levels" do
      prefs = NotificationPreferences.new()
      assert prefs == NotificationPreferences.set_channel_level(prefs, "#general", :invalid)
    end

    test "overwrites existing channel level" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_channel_level("#general", :mute)
        |> NotificationPreferences.set_channel_level("#general", :mentions_only)

      assert NotificationPreferences.get_channel_level(prefs, "#general") == :mentions_only
    end
  end

  describe "get_channel_level/2" do
    test "returns :normal for channels without explicit level" do
      prefs = NotificationPreferences.new()
      assert NotificationPreferences.get_channel_level(prefs, "#unknown") == :normal
    end
  end

  describe "remove_channel_level/2" do
    test "removes channel level entry" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_channel_level("#dev", :mute)
        |> NotificationPreferences.remove_channel_level("#dev")

      assert NotificationPreferences.get_channel_level(prefs, "#dev") == :normal
      assert prefs.channel_levels == %{}
    end

    test "is a no-op for non-existent channel" do
      prefs = NotificationPreferences.new()
      assert prefs == NotificationPreferences.remove_channel_level(prefs, "#unknown")
    end
  end

  describe "to_map/1 and from_map/1" do
    test "round-trips all fields" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_sounds_enabled(false)
        |> NotificationPreferences.set_browser_notifications(true)
        |> NotificationPreferences.set_privacy_mode(true)
        |> NotificationPreferences.set_dnd_enabled(true)
        |> NotificationPreferences.set_trigger_channel_messages(true)
        |> NotificationPreferences.set_channel_level("#dev", :mentions_only)
        |> NotificationPreferences.set_channel_level("#music", :mute)

      map = NotificationPreferences.to_map(prefs)
      restored = NotificationPreferences.from_map(map)

      assert restored.sounds_enabled == false
      assert restored.browser_notifications == true
      assert restored.privacy_mode == true
      assert restored.dnd_enabled == true
      assert restored.trigger_channel_messages == true
      assert restored.channel_levels == %{"#dev" => :mentions_only, "#music" => :mute}
    end

    test "from_map returns defaults for empty map" do
      prefs = NotificationPreferences.from_map(%{})
      default = NotificationPreferences.new()
      assert prefs == default
    end

    test "from_map handles string keys" do
      map = %{
        "sounds_enabled" => false,
        "dnd_enabled" => true,
        "channel_levels" => %{"#dev" => "mentions_only"}
      }

      prefs = NotificationPreferences.from_map(map)
      assert prefs.sounds_enabled == false
      assert prefs.dnd_enabled == true
      assert prefs.channel_levels == %{"#dev" => :mentions_only}
    end
  end

  describe "migrate_from_muted_channels/2" do
    test "converts muted_channels list to channel_levels" do
      prefs = NotificationPreferences.new()
      muted = ["#music", "#offtopic"]

      migrated = NotificationPreferences.migrate_from_muted_channels(prefs, muted)

      assert migrated.channel_levels == %{"#music" => :mute, "#offtopic" => :mute}
    end

    test "does not overwrite existing channel levels" do
      prefs =
        NotificationPreferences.new()
        |> NotificationPreferences.set_channel_level("#music", :mentions_only)

      migrated = NotificationPreferences.migrate_from_muted_channels(prefs, ["#music"])

      assert migrated.channel_levels == %{"#music" => :mentions_only}
    end

    test "handles empty muted list" do
      prefs = NotificationPreferences.new()
      migrated = NotificationPreferences.migrate_from_muted_channels(prefs, [])
      assert migrated == prefs
    end
  end
end
