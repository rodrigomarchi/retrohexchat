defmodule RetroHexChat.Commands.Handlers.SetMotdTest do
  # async: false — MOTD uses Application.put_env (global state)
  use RetroHexChat.DataCase, async: false

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.SetMotd
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
      assert :ok = SetMotd.validate("Welcome message")
      assert :ok = SetMotd.validate("")
    end
  end

  describe "execute/2" do
    test "non-admin rejected with permission denied error" do
      ctx = %{@base_context | is_admin: false}

      assert {:error, "Permission denied: you must be a server administrator."} =
               SetMotd.execute(["Welcome"], ctx)
    end

    test "empty args returns usage error" do
      assert {:error, "Usage: /setmotd <text>"} =
               SetMotd.execute([], @base_context)
    end

    test "admin can set MOTD" do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:settings")

      assert {:ok, :system, %{content: "MOTD has been updated."}} =
               SetMotd.execute(["Welcome", "to", "RetroHexChat!"], @base_context)

      # Verify MOTD was set
      assert Motd.get() == "Welcome to RetroHexChat!"

      # Verify broadcast was sent
      assert_receive {:motd_updated, %{content: "Welcome to RetroHexChat!"}}
    end

    test "admin can set MOTD with single word" do
      assert {:ok, :system, %{content: "MOTD has been updated."}} =
               SetMotd.execute(["Welcome"], @base_context)

      assert Motd.get() == "Welcome"
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = SetMotd.help()
      assert help.name == "setmotd"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
