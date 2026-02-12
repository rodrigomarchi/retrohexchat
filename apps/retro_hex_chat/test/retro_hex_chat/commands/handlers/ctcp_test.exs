defmodule RetroHexChat.Commands.Handlers.CtcpTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Ctcp

  @context %{
    nickname: "TestUser",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "returns :ok for empty input" do
      assert :ok = Ctcp.validate("")
    end

    test "returns :ok for valid input" do
      assert :ok = Ctcp.validate("Alice ping")
    end

    test "returns :ok for any input (validation in execute)" do
      assert :ok = Ctcp.validate("anything")
    end
  end

  describe "execute/2" do
    test "returns error with usage for no args" do
      assert {:error, msg} = Ctcp.execute([], @context)
      assert msg =~ "/ctcp"
      assert msg =~ "<target>"
      assert msg =~ "<type>"
    end

    test "returns error with usage for one arg (no type)" do
      assert {:error, msg} = Ctcp.execute(["Alice"], @context)
      assert msg =~ "/ctcp"
      assert msg =~ "<type>"
    end

    test "returns {:ok, :ctcp, map} for valid ping" do
      assert {:ok, :ctcp, %{target: "Alice", type: :ping}} =
               Ctcp.execute(["Alice", "ping"], @context)
    end

    test "returns {:ok, :ctcp, map} for valid version" do
      assert {:ok, :ctcp, %{target: "Bob", type: :version}} =
               Ctcp.execute(["Bob", "version"], @context)
    end

    test "returns {:ok, :ctcp, map} for valid time" do
      assert {:ok, :ctcp, %{target: "Alice", type: :time}} =
               Ctcp.execute(["Alice", "time"], @context)
    end

    test "returns {:ok, :ctcp, map} for valid finger" do
      assert {:ok, :ctcp, %{target: "Alice", type: :finger}} =
               Ctcp.execute(["Alice", "finger"], @context)
    end

    test "handles case insensitivity for type" do
      assert {:ok, :ctcp, %{type: :ping}} = Ctcp.execute(["Alice", "PING"], @context)
      assert {:ok, :ctcp, %{type: :ping}} = Ctcp.execute(["Alice", "Ping"], @context)
      assert {:ok, :ctcp, %{type: :version}} = Ctcp.execute(["Alice", "VERSION"], @context)
      assert {:ok, :ctcp, %{type: :time}} = Ctcp.execute(["Alice", "TIME"], @context)
      assert {:ok, :ctcp, %{type: :finger}} = Ctcp.execute(["Alice", "FINGER"], @context)
    end

    test "returns error for invalid type with valid types listed" do
      assert {:error, msg} = Ctcp.execute(["Alice", "unknown"], @context)
      assert msg =~ "Unknown CTCP type: unknown"
      assert msg =~ "ping"
      assert msg =~ "version"
      assert msg =~ "time"
      assert msg =~ "finger"
    end

    test "ignores extra args after type" do
      assert {:ok, :ctcp, %{target: "Alice", type: :ping}} =
               Ctcp.execute(["Alice", "ping", "extra", "args"], @context)
    end
  end

  describe "help/0" do
    test "returns correct help map" do
      help = Ctcp.help()
      assert help.name == "ctcp"
      assert help.syntax =~ "/ctcp"
      assert help.description =~ "CTCP"
      assert is_list(help.examples)
      assert length(help.examples) > 0
    end
  end
end
