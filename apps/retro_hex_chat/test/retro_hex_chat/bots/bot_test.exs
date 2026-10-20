defmodule RetroHexChat.Bots.BotTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Bot

  @valid_attrs %{name: "TestBot", nickname: "TestBot", created_by: "admin"}

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      cs = Bot.changeset(%Bot{}, @valid_attrs)
      assert cs.valid?
    end

    test "name must be 2-16 chars" do
      cs = Bot.changeset(%Bot{}, %{@valid_attrs | name: "X"})
      refute cs.valid?

      cs = Bot.changeset(%Bot{}, %{@valid_attrs | name: String.duplicate("A", 17)})
      refute cs.valid?
    end

    test "nickname must start with a letter" do
      cs = Bot.changeset(%Bot{}, %{@valid_attrs | nickname: "123bot"})
      refute cs.valid?
    end

    test "name only allows letters, numbers, _ and -" do
      cs = Bot.changeset(%Bot{}, %{@valid_attrs | name: "bot name"})
      refute cs.valid?

      cs = Bot.changeset(%Bot{}, %{@valid_attrs | name: "bot-name_1"})
      assert cs.valid?
    end

    test "command_prefix must be 1-3 chars" do
      cs = Bot.changeset(%Bot{}, Map.put(@valid_attrs, :command_prefix, "!!!!"))
      refute cs.valid?

      cs = Bot.changeset(%Bot{}, Map.put(@valid_attrs, :command_prefix, "!!"))
      assert cs.valid?
    end

    test "cooldown_ms minimum 500" do
      cs = Bot.changeset(%Bot{}, Map.put(@valid_attrs, :cooldown_ms, 100))
      refute cs.valid?

      cs = Bot.changeset(%Bot{}, Map.put(@valid_attrs, :cooldown_ms, 500))
      assert cs.valid?
    end

    test "defaults are applied" do
      cs = Bot.changeset(%Bot{}, @valid_attrs)
      assert Ecto.Changeset.get_field(cs, :command_prefix) == "!"
      assert Ecto.Changeset.get_field(cs, :enabled) == true
      assert Ecto.Changeset.get_field(cs, :cooldown_ms) == 2000
    end
  end

  describe "update_changeset/2" do
    test "allows updating optional fields" do
      cs = Bot.update_changeset(%Bot{}, %{description: "Updated", cooldown_ms: 3000})
      assert cs.valid?
    end

    test "rejects invalid cooldown" do
      cs = Bot.update_changeset(%Bot{}, %{cooldown_ms: 100})
      refute cs.valid?
    end
  end
end
