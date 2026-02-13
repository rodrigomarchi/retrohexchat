defmodule RetroHexChat.Services.ChannelWelcomeMessageTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Services.ChannelWelcomeMessage

  @moduletag :unit

  describe "changeset/2" do
    test "valid with all required fields" do
      changeset =
        ChannelWelcomeMessage.changeset(%ChannelWelcomeMessage{}, %{
          channel_name: "#test",
          message: "Welcome!",
          set_by: "Operator"
        })

      assert changeset.valid?
    end

    test "invalid without channel_name" do
      changeset =
        ChannelWelcomeMessage.changeset(%ChannelWelcomeMessage{}, %{
          message: "Welcome!",
          set_by: "Op"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:channel_name]
    end

    test "invalid without message" do
      changeset =
        ChannelWelcomeMessage.changeset(%ChannelWelcomeMessage{}, %{
          channel_name: "#test",
          set_by: "Op"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:message]
    end

    test "invalid without set_by" do
      changeset =
        ChannelWelcomeMessage.changeset(%ChannelWelcomeMessage{}, %{
          channel_name: "#test",
          message: "Welcome!"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:set_by]
    end

    test "invalid with channel_name exceeding max length" do
      changeset =
        ChannelWelcomeMessage.changeset(%ChannelWelcomeMessage{}, %{
          channel_name: String.duplicate("a", 51),
          message: "Welcome!",
          set_by: "Op"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:channel_name]
    end

    test "invalid with set_by exceeding max length" do
      changeset =
        ChannelWelcomeMessage.changeset(%ChannelWelcomeMessage{}, %{
          channel_name: "#test",
          message: "Welcome!",
          set_by: String.duplicate("a", 17)
        })

      refute changeset.valid?
      assert errors_on(changeset)[:set_by]
    end
  end
end
