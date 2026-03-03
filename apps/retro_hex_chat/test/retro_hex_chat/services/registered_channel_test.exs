defmodule RetroHexChat.Services.RegisteredChannelTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Services.RegisteredChannel

  @moduletag :unit

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      attrs = %{name: "#elixir", founder_nickname: "Alice"}
      changeset = RegisteredChannel.changeset(%RegisteredChannel{}, attrs)
      assert changeset.valid?
    end

    test "requires name and founder_nickname" do
      changeset = RegisteredChannel.changeset(%RegisteredChannel{}, %{})
      refute changeset.valid?

      assert %{name: ["can't be blank"], founder_nickname: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "validates name max length 50" do
      attrs = %{name: String.duplicate("#", 51), founder_nickname: "Alice"}
      changeset = RegisteredChannel.changeset(%RegisteredChannel{}, attrs)
      refute changeset.valid?
    end

    test "validates founder_nickname max length 16" do
      attrs = %{name: "#elixir", founder_nickname: String.duplicate("a", 17)}
      changeset = RegisteredChannel.changeset(%RegisteredChannel{}, attrs)
      refute changeset.valid?
    end

    test "accepts optional fields" do
      attrs = %{
        name: "#elixir",
        founder_nickname: "Alice",
        topic: "Welcome!",
        modes: "+mt",
        mode_key: "secret",
        mode_limit: 50
      }

      changeset = RegisteredChannel.changeset(%RegisteredChannel{}, attrs)
      assert changeset.valid?
    end

    test "sets registered_at on new records" do
      attrs = %{name: "#elixir", founder_nickname: "Alice"}
      changeset = RegisteredChannel.changeset(%RegisteredChannel{}, attrs)
      assert changeset.changes[:registered_at]
    end
  end
end
