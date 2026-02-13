defmodule RetroHexChat.Commands.Handlers.MotdTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Motd
  alias RetroHexChat.Services

  @base_context %{
    nickname: "TestUser",
    active_channel: nil,
    channels: [],
    identified: false,
    operator_in: [],
    half_operator_in: [],
    is_admin: false,
    is_server_operator: false
  }

  setup do
    Application.delete_env(:retro_hex_chat, :motd_cache)
    :ok
  end

  describe "validate/1" do
    test "accepts any input" do
      assert :ok = Motd.validate("")
      assert :ok = Motd.validate("anything")
    end
  end

  describe "execute/2" do
    test "returns no MOTD message when no MOTD is set" do
      assert {:ok, :system, %{content: "No MOTD has been set."}} =
               Motd.execute([], @base_context)
    end

    test "returns show_motd ui_action when MOTD is set" do
      Services.Motd.set("Welcome to our server!", "Admin")

      assert {:ok, :ui_action, :show_motd, %{content: "Welcome to our server!"}} =
               Motd.execute([], @base_context)
    end

    test "any user can execute" do
      Services.Motd.set("Test MOTD", "Admin")

      # Regular user
      ctx = %{@base_context | is_admin: false, is_server_operator: false}

      assert {:ok, :ui_action, :show_motd, %{content: "Test MOTD"}} =
               Motd.execute([], ctx)
    end

    test "admin can also execute" do
      Services.Motd.set("Test MOTD", "Admin")

      # Admin user
      ctx = %{@base_context | is_admin: true}

      assert {:ok, :ui_action, :show_motd, %{content: "Test MOTD"}} =
               Motd.execute([], ctx)
    end
  end

  describe "help/0" do
    test "returns help map" do
      help = Motd.help()
      assert help.name == "motd"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end
  end
end
