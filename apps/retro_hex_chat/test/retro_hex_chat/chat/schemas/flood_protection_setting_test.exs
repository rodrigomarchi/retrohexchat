defmodule RetroHexChat.Chat.Schemas.FloodProtectionSettingTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  import Ecto.Query

  alias RetroHexChat.Chat.Schemas.FloodProtectionSetting
  alias RetroHexChat.Repo

  describe "changeset/2" do
    test "valid changeset with all fields" do
      attrs = %{
        owner_nickname: "TestUser",
        flood_threshold: 10,
        flood_window_seconds: 15,
        auto_ignore_duration_seconds: 300,
        spam_threshold: 3,
        spam_window_seconds: 10
      }

      changeset = FloodProtectionSetting.changeset(%FloodProtectionSetting{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with only owner_nickname (uses defaults)" do
      attrs = %{owner_nickname: "TestUser"}
      changeset = FloodProtectionSetting.changeset(%FloodProtectionSetting{}, attrs)
      assert changeset.valid?
    end

    test "rejects flood_threshold of 0" do
      attrs = %{owner_nickname: "TestUser", flood_threshold: 0}
      changeset = FloodProtectionSetting.changeset(%FloodProtectionSetting{}, attrs)
      refute changeset.valid?
    end

    test "rejects flood_threshold above 100" do
      attrs = %{owner_nickname: "TestUser", flood_threshold: 101}
      changeset = FloodProtectionSetting.changeset(%FloodProtectionSetting{}, attrs)
      refute changeset.valid?
    end

    test "rejects spam_threshold of 0" do
      attrs = %{owner_nickname: "TestUser", spam_threshold: 0}
      changeset = FloodProtectionSetting.changeset(%FloodProtectionSetting{}, attrs)
      refute changeset.valid?
    end

    test "rejects spam_threshold above 50" do
      attrs = %{owner_nickname: "TestUser", spam_threshold: 51}
      changeset = FloodProtectionSetting.changeset(%FloodProtectionSetting{}, attrs)
      refute changeset.valid?
    end

    test "rejects auto_ignore_duration_seconds above 86400" do
      attrs = %{owner_nickname: "TestUser", auto_ignore_duration_seconds: 86_401}
      changeset = FloodProtectionSetting.changeset(%FloodProtectionSetting{}, attrs)
      refute changeset.valid?
    end

    test "validates owner_nickname max length 16" do
      attrs = %{owner_nickname: String.duplicate("A", 17)}
      changeset = FloodProtectionSetting.changeset(%FloodProtectionSetting{}, attrs)
      refute changeset.valid?
    end
  end

  describe "persistence" do
    setup do
      # Create a registered nick for FK constraint
      Repo.insert_all("registered_nicks", [
        %{
          nickname: "FloodUser",
          password_hash: Bcrypt.hash_pwd_salt("pass123"),
          registered_at: DateTime.utc_now(),
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      ])

      :ok
    end

    test "insert with valid attrs" do
      attrs = %{
        owner_nickname: "FloodUser",
        flood_threshold: 20,
        spam_threshold: 5
      }

      {:ok, record} =
        %FloodProtectionSetting{}
        |> FloodProtectionSetting.changeset(attrs)
        |> Repo.insert()

      assert record.owner_nickname == "FloodUser"
      assert record.flood_threshold == 20
      assert record.spam_threshold == 5
      # Defaults for non-specified fields
      assert record.flood_window_seconds == 15
      assert record.auto_ignore_duration_seconds == 300
    end

    test "upsert pattern: insert then update" do
      attrs = %{owner_nickname: "FloodUser", flood_threshold: 10}

      {:ok, _} =
        %FloodProtectionSetting{}
        |> FloodProtectionSetting.changeset(attrs)
        |> Repo.insert()

      existing = Repo.get(FloodProtectionSetting, "FloodUser")

      {:ok, updated} =
        existing
        |> FloodProtectionSetting.changeset(%{flood_threshold: 25})
        |> Repo.update()

      assert updated.flood_threshold == 25
    end

    test "cascade delete when registered nick deleted" do
      attrs = %{owner_nickname: "FloodUser"}

      {:ok, _} =
        %FloodProtectionSetting{}
        |> FloodProtectionSetting.changeset(attrs)
        |> Repo.insert()

      assert Repo.get(FloodProtectionSetting, "FloodUser") != nil

      Repo.delete_all(from(rn in "registered_nicks", where: rn.nickname == "FloodUser"))

      assert Repo.get(FloodProtectionSetting, "FloodUser") == nil
    end
  end
end
