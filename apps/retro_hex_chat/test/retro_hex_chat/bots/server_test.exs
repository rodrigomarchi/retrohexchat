defmodule RetroHexChat.Bots.ServerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.{Registry, Server, Supervisor}

  @bot_data %{
    id: 999,
    name: "ServerTestBot",
    nickname: "ServerTestBot",
    command_prefix: "!",
    created_by: "admin",
    enabled: true,
    cooldown_ms: 100,
    capabilities: %{
      "mention" => %{"response" => "Hi {nickname}!", "enabled" => true},
      "greeter" => %{"greeting" => "Welcome {nickname}!", "enabled" => true},
      "help" => %{"enabled" => true},
      "custom_commands" => %{"enabled" => true}
    },
    channel_configs: [],
    custom_commands: []
  }

  setup do
    on_exit(fn ->
      # Clean up any running bot
      Supervisor.stop_bot("ServerTestBot")
    end)

    :ok
  end

  describe "start_link/1" do
    test "starts a bot process" do
      {:ok, pid} = Supervisor.start_bot(@bot_data)
      assert Process.alive?(pid)
      assert {:ok, ^pid} = Registry.lookup("ServerTestBot")
    end

    test "registered in BotRegistry" do
      {:ok, _pid} = Supervisor.start_bot(@bot_data)
      assert "ServerTestBot" in Registry.registered_bots()
    end
  end

  describe "get_state/1" do
    test "returns bot state" do
      {:ok, _} = Supervisor.start_bot(@bot_data)
      {:ok, state} = Server.get_state("ServerTestBot")
      assert state.name == "ServerTestBot"
      assert state.nickname == "ServerTestBot"
      assert state.command_prefix == "!"
      assert state.enabled == true
    end

    test "returns error when not found" do
      assert {:error, :not_found} = Server.get_state("NonExistent")
    end
  end

  describe "set_enabled/2" do
    test "toggles enabled state" do
      {:ok, _} = Supervisor.start_bot(@bot_data)
      :ok = Server.set_enabled("ServerTestBot", false)
      {:ok, state} = Server.get_state("ServerTestBot")
      refute state.enabled
    end
  end

  describe "update_config/2" do
    test "updates config values" do
      {:ok, _} = Supervisor.start_bot(@bot_data)
      :ok = Server.update_config("ServerTestBot", %{cooldown_ms: 5000})
      {:ok, state} = Server.get_state("ServerTestBot")
      assert state.cooldown_ms == 5000
    end
  end

  describe "reload_commands/2" do
    test "updates custom commands" do
      {:ok, _} = Supervisor.start_bot(@bot_data)

      commands = %{
        "rules" => %{"response" => "Read #rules", "description" => "Rules", "enabled" => true}
      }

      Server.reload_commands("ServerTestBot", commands)
      {:ok, state} = Server.get_state("ServerTestBot")
      assert Map.has_key?(state.custom_commands, "rules")
    end
  end
end
