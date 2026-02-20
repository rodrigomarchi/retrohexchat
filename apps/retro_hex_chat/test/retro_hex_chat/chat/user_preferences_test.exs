defmodule RetroHexChat.Chat.UserPreferencesTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.{KeyBindings, Schemas, UserPreferences}

  describe "new/0" do
    @tag :unit
    test "returns default preferences with all 4 categories" do
      prefs = UserPreferences.new()

      assert Map.has_key?(prefs, :display)
      assert Map.has_key?(prefs, :messages)
      assert Map.has_key?(prefs, :key_bindings)
      assert Map.has_key?(prefs, :notifications)
    end

    @tag :unit
    test "display defaults are all visible, no compact, no shading" do
      %{display: display} = UserPreferences.new()

      assert display.show_toolbar == true
      assert display.show_treebar == true
      assert display.show_switchbar == true
      assert display.show_statusbar == true
      assert display.compact_mode == false
      assert display.line_shading == false
    end

    @tag :unit
    test "message defaults" do
      %{messages: messages} = UserPreferences.new()

      assert messages.notice_routing == :active
      assert messages.muted_channels == []
    end

    @tag :unit
    test "key_bindings defaults match KeyBindings.defaults()" do
      %{key_bindings: bindings} = UserPreferences.new()
      assert bindings == KeyBindings.defaults()
    end
  end

  describe "getters" do
    @tag :unit
    test "get_display/1 returns display settings" do
      prefs = UserPreferences.new()
      assert UserPreferences.get_display(prefs) == prefs.display
    end

    @tag :unit
    test "get_messages/1 returns message settings" do
      prefs = UserPreferences.new()
      assert UserPreferences.get_messages(prefs) == prefs.messages
    end

    @tag :unit
    test "get_key_bindings/1 returns key bindings" do
      prefs = UserPreferences.new()
      assert UserPreferences.get_key_bindings(prefs) == prefs.key_bindings
    end
  end

  describe "set_display/3" do
    @tag :unit
    test "toggles a display setting" do
      prefs = UserPreferences.new()
      updated = UserPreferences.set_display(prefs, :show_toolbar, false)
      assert updated.display.show_toolbar == false
    end

    @tag :unit
    test "enables line shading" do
      prefs = UserPreferences.new()
      updated = UserPreferences.set_display(prefs, :line_shading, true)
      assert updated.display.line_shading == true
    end
  end

  describe "set_routing/3" do
    @tag :unit
    test "sets notice_routing" do
      prefs = UserPreferences.new()
      updated = UserPreferences.set_routing(prefs, :notice_routing, :status)
      assert updated.messages.notice_routing == :status
    end
  end

  describe "set_key_binding/3" do
    @tag :unit
    test "updates a single key binding" do
      prefs = UserPreferences.new()
      new_binding = %{key: "a", modifiers: [:alt]}
      updated = UserPreferences.set_key_binding(prefs, :toggle_search, new_binding)
      assert updated.key_bindings.toggle_search == new_binding
    end
  end

  describe "set_key_bindings/3" do
    @tag :unit
    test "replaces all key bindings" do
      prefs = UserPreferences.new()
      new_bindings = KeyBindings.defaults()
      updated = UserPreferences.set_key_bindings(prefs, new_bindings)
      assert updated.key_bindings == new_bindings
    end
  end

  describe "persistence" do
    setup do
      register_nick("TestPrefs")
      :ok
    end

    @tag :integration
    test "save/2 and load/1 round-trip preserves all settings" do
      prefs =
        UserPreferences.new()
        |> UserPreferences.set_display(:line_shading, true)
        |> UserPreferences.set_routing(:notice_routing, :status)

      assert :ok == UserPreferences.save("TestPrefs", prefs)
      assert {:ok, loaded} = UserPreferences.load("TestPrefs")

      assert loaded.display.line_shading == true
      assert loaded.messages.notice_routing == :status
    end

    @tag :integration
    test "save/2 upserts (update existing)" do
      prefs = UserPreferences.new()
      assert :ok == UserPreferences.save("TestPrefs", prefs)

      updated = UserPreferences.set_display(prefs, :compact_mode, true)
      assert :ok == UserPreferences.save("TestPrefs", updated)

      assert {:ok, loaded} = UserPreferences.load("TestPrefs")
      assert loaded.display.compact_mode == true
    end

    @tag :integration
    test "load/1 returns error for non-existent user" do
      assert {:error, :not_found} == UserPreferences.load("NoSuchUser")
    end

    @tag :integration
    test "save/2 and load/1 round-trip preserves key bindings" do
      prefs = UserPreferences.new()

      updated =
        UserPreferences.set_key_binding(prefs, :toggle_search, %{
          key: "g",
          modifiers: [:ctrl]
        })

      assert :ok == UserPreferences.save("TestPrefs", updated)
      assert {:ok, loaded} = UserPreferences.load("TestPrefs")

      assert loaded.key_bindings.toggle_search == %{key: "g", modifiers: [:ctrl]}
    end

    @tag :integration
    test "save/2 and load/1 round-trip preserves command_help_level" do
      prefs =
        UserPreferences.new()
        |> UserPreferences.set_command_help_level(:expert)

      assert :ok == UserPreferences.save("TestPrefs", prefs)
      assert {:ok, loaded} = UserPreferences.load("TestPrefs")

      assert loaded.display.command_help_level == :expert
    end

    @tag :integration
    test "load/1 returns defaults for empty JSONB columns" do
      # Insert a row with empty maps
      %Schemas.UserPreference{}
      |> Schemas.UserPreference.changeset(%{owner_nickname: "TestPrefs"})
      |> RetroHexChat.Repo.insert!()

      assert {:ok, loaded} = UserPreferences.load("TestPrefs")
      defaults = UserPreferences.new()

      assert loaded.display == defaults.display
    end
  end

  describe "get_timestamp_format/1 and set_timestamp_format/2" do
    @tag :unit
    test "get_timestamp_format/1 returns :hh_mm default" do
      prefs = UserPreferences.new()
      assert UserPreferences.get_timestamp_format(prefs) == :hh_mm
    end

    @tag :unit
    test "set_timestamp_format/2 with :hh_mm_ss" do
      prefs = UserPreferences.new() |> UserPreferences.set_timestamp_format(:hh_mm_ss)
      assert UserPreferences.get_timestamp_format(prefs) == :hh_mm_ss
    end

    @tag :unit
    test "set_timestamp_format/2 with :dd_mm_hh_mm" do
      prefs = UserPreferences.new() |> UserPreferences.set_timestamp_format(:dd_mm_hh_mm)
      assert UserPreferences.get_timestamp_format(prefs) == :dd_mm_hh_mm
    end

    @tag :unit
    test "set_timestamp_format/2 with :none" do
      prefs = UserPreferences.new() |> UserPreferences.set_timestamp_format(:none)
      assert UserPreferences.get_timestamp_format(prefs) == :none
    end

    @tag :unit
    test "set_timestamp_format/2 rejects invalid atom" do
      prefs = UserPreferences.new()

      assert_raise FunctionClauseError, fn ->
        UserPreferences.set_timestamp_format(prefs, :invalid)
      end
    end
  end

  describe "command_help_level" do
    @tag :unit
    test "default is :beginner" do
      prefs = UserPreferences.new()
      assert prefs.display.command_help_level == :beginner
    end

    @tag :unit
    test "set_command_help_level/2 accepts :beginner" do
      prefs = UserPreferences.new() |> UserPreferences.set_command_help_level(:beginner)
      assert prefs.display.command_help_level == :beginner
    end

    @tag :unit
    test "set_command_help_level/2 accepts :expert" do
      prefs = UserPreferences.new() |> UserPreferences.set_command_help_level(:expert)
      assert prefs.display.command_help_level == :expert
    end

    @tag :unit
    test "set_command_help_level/2 accepts :off" do
      prefs = UserPreferences.new() |> UserPreferences.set_command_help_level(:off)
      assert prefs.display.command_help_level == :off
    end

    @tag :unit
    test "set_command_help_level/2 rejects invalid values" do
      prefs = UserPreferences.new()

      assert_raise FunctionClauseError, fn ->
        UserPreferences.set_command_help_level(prefs, :invalid)
      end
    end

    @tag :unit
    test "get_command_help_level/1 returns current value" do
      prefs = UserPreferences.new() |> UserPreferences.set_command_help_level(:expert)
      assert UserPreferences.get_command_help_level(prefs) == :expert
    end
  end

  describe "get_quit_message/1 and set_quit_message/2" do
    @tag :unit
    test "get_quit_message/1 returns 'Leaving' default" do
      prefs = UserPreferences.new()
      assert UserPreferences.get_quit_message(prefs) == "Leaving"
    end

    @tag :unit
    test "set_quit_message/2 with valid string" do
      prefs = UserPreferences.new() |> UserPreferences.set_quit_message("Goodbye everyone!")
      assert UserPreferences.get_quit_message(prefs) == "Goodbye everyone!"
    end

    @tag :unit
    test "set_quit_message/2 truncates to 200 characters" do
      long_msg = String.duplicate("a", 250)
      prefs = UserPreferences.new() |> UserPreferences.set_quit_message(long_msg)
      assert String.length(UserPreferences.get_quit_message(prefs)) == 200
    end

    @tag :unit
    test "set_quit_message/2 rejects empty string" do
      prefs = UserPreferences.new()

      assert_raise FunctionClauseError, fn ->
        UserPreferences.set_quit_message(prefs, "")
      end
    end
  end

  describe "muted_channels" do
    @tag :unit
    test "get_muted_channels/1 returns empty list by default" do
      prefs = UserPreferences.new()
      assert UserPreferences.get_muted_channels(prefs) == []
    end

    @tag :unit
    test "set_muted_channels/2 replaces the list" do
      prefs =
        UserPreferences.new()
        |> UserPreferences.set_muted_channels(["#general", "#random"])

      assert UserPreferences.get_muted_channels(prefs) == ["#general", "#random"]
    end

    @tag :unit
    test "toggle_mute_channel/2 adds channel when not muted" do
      prefs =
        UserPreferences.new()
        |> UserPreferences.toggle_mute_channel("#general")

      assert "#general" in UserPreferences.get_muted_channels(prefs)
    end

    @tag :unit
    test "toggle_mute_channel/2 removes channel when already muted" do
      prefs =
        UserPreferences.new()
        |> UserPreferences.set_muted_channels(["#general", "#random"])
        |> UserPreferences.toggle_mute_channel("#general")

      muted = UserPreferences.get_muted_channels(prefs)
      refute "#general" in muted
      assert "#random" in muted
    end

    @tag :unit
    test "default messages include muted_channels key" do
      prefs = UserPreferences.new()
      assert Map.has_key?(prefs.messages, :muted_channels)
    end
  end

  describe "muted_channels persistence" do
    setup do
      register_nick("TestMutePrefs")
      :ok
    end

    @tag :integration
    test "save/2 and load/1 round-trip preserves muted_channels" do
      prefs =
        UserPreferences.new()
        |> UserPreferences.set_muted_channels(["#general", "#random"])

      assert :ok == UserPreferences.save("TestMutePrefs", prefs)
      assert {:ok, loaded} = UserPreferences.load("TestMutePrefs")

      assert loaded.messages.muted_channels == ["#general", "#random"]
    end

    @tag :integration
    test "save/2 and load/1 round-trip preserves empty muted_channels" do
      prefs = UserPreferences.new()

      assert :ok == UserPreferences.save("TestMutePrefs", prefs)
      assert {:ok, loaded} = UserPreferences.load("TestMutePrefs")

      assert loaded.messages.muted_channels == []
    end
  end

  defp register_nick(nickname) do
    RetroHexChat.Repo.insert_all("registered_nicks", [
      %{
        nickname: nickname,
        password_hash: Bcrypt.hash_pwd_salt("password"),
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])
  end
end
