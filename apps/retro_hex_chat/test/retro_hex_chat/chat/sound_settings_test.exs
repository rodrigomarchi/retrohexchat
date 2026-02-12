defmodule RetroHexChat.Chat.SoundSettingsTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.SoundSettings
  alias RetroHexChat.Services.Queries

  describe "new/0" do
    @tag :unit
    test "returns default settings with all 10 event types" do
      settings = SoundSettings.new()

      assert is_map(settings.sound_mappings)
      assert is_map(settings.flash_settings)
      assert map_size(settings.sound_mappings) == 10
      assert map_size(settings.flash_settings) == 10

      for event <- SoundSettings.event_types() do
        assert Map.has_key?(settings.sound_mappings, event)
        assert Map.has_key?(settings.flash_settings, event)
      end
    end

    @tag :unit
    test "default sound mappings have sensible values" do
      settings = SoundSettings.new()

      assert settings.sound_mappings.message == "ding_low"
      assert settings.sound_mappings.pm == "chime_high"
      assert settings.sound_mappings.highlight == "alert"
      assert settings.sound_mappings.join == "click"
      assert settings.sound_mappings.part == "click"
      assert settings.sound_mappings.kick == "buzz"
      assert settings.sound_mappings.connect == "chime_short"
      assert settings.sound_mappings.disconnect == "chime_low"
      assert settings.sound_mappings.buddy_online == "notify"
      assert settings.sound_mappings.buddy_offline == "blip"
    end

    @tag :unit
    test "default flash settings enable pm, highlight, and buddy_online" do
      settings = SoundSettings.new()

      assert settings.flash_settings.pm == true
      assert settings.flash_settings.highlight == true
      assert settings.flash_settings.buddy_online == true
      assert settings.flash_settings.message == false
      assert settings.flash_settings.join == false
      assert settings.flash_settings.part == false
      assert settings.flash_settings.kick == false
      assert settings.flash_settings.connect == false
      assert settings.flash_settings.disconnect == false
      assert settings.flash_settings.buddy_offline == false
    end
  end

  describe "get_sound/2 and set_sound/3" do
    @tag :unit
    test "gets and sets sound for each event type" do
      settings = SoundSettings.new()

      for event <- SoundSettings.event_types() do
        updated = SoundSettings.set_sound(settings, event, "ring")
        assert SoundSettings.get_sound(updated, event) == "ring"
      end
    end

    @tag :unit
    test "set_sound with 'none' disables the sound" do
      settings = SoundSettings.new()
      updated = SoundSettings.set_sound(settings, :highlight, "none")
      assert SoundSettings.get_sound(updated, :highlight) == "none"
    end

    @tag :unit
    test "set_sound does not affect other event types" do
      settings = SoundSettings.new()
      updated = SoundSettings.set_sound(settings, :pm, "buzz")
      assert SoundSettings.get_sound(updated, :pm) == "buzz"
      assert SoundSettings.get_sound(updated, :highlight) == "alert"
    end
  end

  describe "get_flash/2 and set_flash/3" do
    @tag :unit
    test "gets and sets flash for each event type" do
      settings = SoundSettings.new()

      updated = SoundSettings.set_flash(settings, :message, true)
      assert SoundSettings.get_flash(updated, :message) == true

      updated2 = SoundSettings.set_flash(updated, :message, false)
      assert SoundSettings.get_flash(updated2, :message) == false
    end

    @tag :unit
    test "set_flash does not affect other event types" do
      settings = SoundSettings.new()
      updated = SoundSettings.set_flash(settings, :join, true)
      assert SoundSettings.get_flash(updated, :join) == true
      assert SoundSettings.get_flash(updated, :part) == false
    end
  end

  describe "get_sound_mappings/1 and get_flash_settings/1" do
    @tag :unit
    test "returns the full maps" do
      settings = SoundSettings.new()
      assert SoundSettings.get_sound_mappings(settings) == settings.sound_mappings
      assert SoundSettings.get_flash_settings(settings) == settings.flash_settings
    end
  end

  describe "available_sounds/0" do
    @tag :unit
    test "returns 15 entries including 'none'" do
      sounds = SoundSettings.available_sounds()
      assert length(sounds) == 15
      assert {"none", "None"} in sounds
      assert {"alert", "Alert"} in sounds
      assert {"ding_low", "Ding Low"} in sounds
    end

    @tag :unit
    test "each entry is a {name, label} tuple" do
      for {name, label} <- SoundSettings.available_sounds() do
        assert is_binary(name)
        assert is_binary(label)
      end
    end
  end

  describe "event_types/0" do
    @tag :unit
    test "returns all 10 event types" do
      types = SoundSettings.event_types()
      assert length(types) == 10
      assert :message in types
      assert :pm in types
      assert :highlight in types
      assert :join in types
      assert :part in types
      assert :kick in types
      assert :connect in types
      assert :disconnect in types
      assert :buddy_online in types
      assert :buddy_offline in types
    end
  end

  describe "valid_sound?/1" do
    @tag :unit
    test "returns true for valid sound names" do
      assert SoundSettings.valid_sound?("none")
      assert SoundSettings.valid_sound?("beep")
      assert SoundSettings.valid_sound?("ding_low")
      assert SoundSettings.valid_sound?("alert")
    end

    @tag :unit
    test "returns false for invalid sound names" do
      refute SoundSettings.valid_sound?("invalid")
      refute SoundSettings.valid_sound?("")
      refute SoundSettings.valid_sound?("mention")
    end
  end

  describe "save/2 and load/1" do
    @tag :integration
    test "round-trips settings through the database" do
      nick = "SoundTestUser"
      insert_registered_nick(nick)

      settings =
        SoundSettings.new()
        |> SoundSettings.set_sound(:pm, "buzz")
        |> SoundSettings.set_flash(:join, true)

      assert :ok = SoundSettings.save(nick, settings)

      assert {:ok, loaded} = SoundSettings.load(nick)
      assert loaded.sound_mappings.pm == "buzz"
      assert loaded.flash_settings.join == true
      assert loaded.flash_settings.highlight == true
    end

    @tag :integration
    test "save overwrites existing settings" do
      nick = "SoundTestUser2"
      insert_registered_nick(nick)

      settings1 = SoundSettings.set_sound(SoundSettings.new(), :highlight, "ring")
      assert :ok = SoundSettings.save(nick, settings1)

      settings2 = SoundSettings.set_sound(SoundSettings.new(), :highlight, "whoosh")
      assert :ok = SoundSettings.save(nick, settings2)

      assert {:ok, loaded} = SoundSettings.load(nick)
      assert loaded.sound_mappings.highlight == "whoosh"
    end

    @tag :integration
    test "load returns error for non-existent user" do
      assert {:error, :not_found} = SoundSettings.load("nonexistent_user")
    end
  end

  defp insert_registered_nick(nickname) do
    {:ok, _} = Queries.insert_registered_nick(nickname, "password123")
  end
end
