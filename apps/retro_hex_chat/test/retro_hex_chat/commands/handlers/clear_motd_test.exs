defmodule RetroHexChat.Commands.Handlers.ClearMotdTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.ClearMotd
  alias RetroHexChat.Services.Motd

  @base_context %{
    nickname: "Admin",
    active_channel: nil,
    channels: [],
    identified: true,
    operator_in: [],
    half_operator_in: [],
    is_admin: true,
    is_server_operator: false
  }

  setup do
    Application.delete_env(:retro_hex_chat, :motd_cache)
    :ok
  end

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = ClearMotd.validate("")
      assert :ok = ClearMotd.validate("anything")
    end
  end

  describe "execute/2" do
    test "non-admin rejected with permission denied error" do
      ctx = %{@base_context | is_admin: false}

      assert {:error, "Permission denied: you must be a server administrator."} =
               ClearMotd.execute([], ctx)
    end

    test "admin can clear MOTD" do
      # Set MOTD first
      Motd.set("Temporary MOTD", "Admin")
      assert Motd.get() == "Temporary MOTD"

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:settings")

      assert {:ok, :system, %{content: "MOTD has been cleared."}} =
               ClearMotd.execute([], @base_context)

      # Verify MOTD was cleared
      assert Motd.get() == nil

      # Verify broadcast was sent
      assert_receive {:motd_updated, %{content: nil}}
    end

    test "clearing when no MOTD is set is idempotent" do
      assert Motd.get() == nil

      assert {:ok, :system, %{content: "MOTD has been cleared."}} =
               ClearMotd.execute([], @base_context)

      assert Motd.get() == nil
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = ClearMotd.help()
      assert help.name == "clearmotd"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
