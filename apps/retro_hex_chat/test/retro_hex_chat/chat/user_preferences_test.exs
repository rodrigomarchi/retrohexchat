defmodule RetroHexChat.Chat.UserPreferencesTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Chat.{Schemas, UserPreferences}

  describe "new/0" do
    @tag :unit
    test "returns default preferences with display and notifications" do
      prefs = UserPreferences.new()

      assert Map.has_key?(prefs, :display)
      assert Map.has_key?(prefs, :notifications)
    end

    @tag :unit
    test "display defaults are all visible" do
      %{display: display} = UserPreferences.new()

      assert display.show_toolbar == true
      assert display.show_treebar == true
      assert display.show_switchbar == true
      assert display.show_statusbar == true
    end
  end

  describe "getters" do
    @tag :unit
    test "get_display/1 returns display settings" do
      prefs = UserPreferences.new()
      assert UserPreferences.get_display(prefs) == prefs.display
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
    test "toggles show_switchbar" do
      prefs = UserPreferences.new()
      updated = UserPreferences.set_display(prefs, :show_switchbar, false)
      assert updated.display.show_switchbar == false
    end
  end

  describe "persistence" do
    setup do
      register_nick("TestPrefs")
      :ok
    end

    @tag :integration
    test "save/2 and load/1 round-trip preserves display settings" do
      prefs =
        UserPreferences.new()
        |> UserPreferences.set_display(:show_toolbar, false)

      assert :ok == UserPreferences.save("TestPrefs", prefs)
      assert {:ok, loaded} = UserPreferences.load("TestPrefs")

      assert loaded.display.show_toolbar == false
    end

    @tag :integration
    test "save/2 upserts (update existing)" do
      prefs = UserPreferences.new()
      assert :ok == UserPreferences.save("TestPrefs", prefs)

      updated = UserPreferences.set_display(prefs, :show_statusbar, false)
      assert :ok == UserPreferences.save("TestPrefs", updated)

      assert {:ok, loaded} = UserPreferences.load("TestPrefs")
      assert loaded.display.show_statusbar == false
    end

    @tag :integration
    test "load/1 returns error for non-existent user" do
      assert {:error, :not_found} == UserPreferences.load("NoSuchUser")
    end

    @tag :integration
    test "load/1 returns defaults for empty JSONB columns" do
      %Schemas.UserPreference{}
      |> Schemas.UserPreference.changeset(%{owner_nickname: "TestPrefs"})
      |> RetroHexChat.Repo.insert!()

      assert {:ok, loaded} = UserPreferences.load("TestPrefs")
      defaults = UserPreferences.new()

      assert loaded.display == defaults.display
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
