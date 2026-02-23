defmodule RetroHexChat.Commands.Handlers.Admin.TurnTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Admin.Turn

  @admin_context %{
    nickname: "TestAdmin",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: true,
    operator_in: [],
    half_operator_in: [],
    is_admin: true,
    is_server_operator: false
  }

  describe "execute([\"stats\"], context) — TURN disabled" do
    setup do
      original = Application.get_env(:retro_hex_chat, :turn_listener_count)
      Application.put_env(:retro_hex_chat, :turn_listener_count, 0)
      on_exit(fn -> Application.put_env(:retro_hex_chat, :turn_listener_count, original) end)
      :ok
    end

    test "returns not configured message when listener_count is 0" do
      assert {:ok, :system, %{content: text}} = Turn.execute(["stats"], @admin_context)
      assert text =~ "not configured"
      assert text =~ "listener_count = 0"
    end
  end

  describe "execute([\"stats\"], context) — TURN enabled" do
    test "returns TURN stats when configured" do
      assert {:ok, :system, %{content: text}} = Turn.execute(["stats"], @admin_context)
      assert text =~ "TURN Server Stats"
      assert text =~ "Status: running"
      assert text =~ "Listeners:"
      assert text =~ "Active allocations: 0"
      assert text =~ "Relay ports: 0/"
      assert text =~ "Port range:"
    end
  end

  describe "execute([\"allocations\"], context) — TURN disabled" do
    setup do
      original = Application.get_env(:retro_hex_chat, :turn_listener_count)
      Application.put_env(:retro_hex_chat, :turn_listener_count, 0)
      on_exit(fn -> Application.put_env(:retro_hex_chat, :turn_listener_count, original) end)
      :ok
    end

    test "returns not configured message" do
      assert {:ok, :system, %{content: text}} = Turn.execute(["allocations"], @admin_context)
      assert text =~ "not configured"
    end
  end

  describe "execute([\"allocations\"], context) — TURN enabled" do
    test "returns no allocations message when empty" do
      assert {:ok, :system, %{content: text}} = Turn.execute(["allocations"], @admin_context)
      assert text =~ "No active TURN allocations"
    end
  end

  describe "error handling" do
    test "returns usage error when no subcommand given" do
      assert {:error, msg} = Turn.execute([], @admin_context)
      assert msg =~ "Usage:"
      assert msg =~ "stats"
      assert msg =~ "allocations"
    end

    test "returns error for unknown subcommand" do
      assert {:error, msg} = Turn.execute(["unknown"], @admin_context)
      assert msg =~ "Unknown turn subcommand: unknown"
    end
  end
end
