defmodule RetroHexChat.Commands.Handlers.WhoisTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Whois

  @base_context %{
    nickname: "Alice",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts non-empty args" do
      assert :ok = Whois.validate("SomeUser")
    end

    test "rejects empty args" do
      assert {:error, _} = Whois.validate("")
    end
  end

  describe "execute/2" do
    test "returns open_whois for valid target" do
      assert {:ok, :ui_action, :show_whois_info, %{nickname: "SomeUser"}} =
               Whois.execute(["SomeUser"], @base_context)
    end

    test "uses first arg as target when multiple provided" do
      assert {:ok, :ui_action, :show_whois_info, %{nickname: "SomeUser"}} =
               Whois.execute(["SomeUser", "extra"], @base_context)
    end

    test "errors when no target provided" do
      assert {:error, _} = Whois.execute([], @base_context)
    end
  end
end
