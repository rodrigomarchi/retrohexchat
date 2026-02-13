defmodule RetroHexChat.Services.ServerSettingTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Services.ServerSetting

  @moduletag :unit

  describe "changeset/2" do
    test "valid with key only" do
      changeset = ServerSetting.changeset(%ServerSetting{}, %{key: "motd"})
      assert changeset.valid?
    end

    test "valid with all fields" do
      changeset =
        ServerSetting.changeset(%ServerSetting{}, %{
          key: "motd",
          value: "Welcome!",
          updated_by: "Admin"
        })

      assert changeset.valid?
    end

    test "invalid without key" do
      changeset = ServerSetting.changeset(%ServerSetting{}, %{value: "some value"})
      refute changeset.valid?
      assert errors_on(changeset)[:key]
    end

    test "invalid with key exceeding max length" do
      changeset =
        ServerSetting.changeset(%ServerSetting{}, %{key: String.duplicate("a", 51)})

      refute changeset.valid?
      assert errors_on(changeset)[:key]
    end

    test "invalid with updated_by exceeding max length" do
      changeset =
        ServerSetting.changeset(%ServerSetting{}, %{
          key: "motd",
          updated_by: String.duplicate("a", 17)
        })

      refute changeset.valid?
      assert errors_on(changeset)[:updated_by]
    end

    test "allows nil value" do
      changeset = ServerSetting.changeset(%ServerSetting{}, %{key: "motd", value: nil})
      assert changeset.valid?
    end
  end
end
