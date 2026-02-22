defmodule RetroHexChat.Bots.Capabilities.GreeterTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Greeter

  @ctx %{
    bot_nickname: "GreetBot",
    bot_name: "GreetBot",
    channel: "#general",
    command_prefix: "!",
    config: %{"greeting" => "Welcome, {nickname}!", "farewell" => nil}
  }

  describe "name/0" do
    test "returns :greeter" do
      assert Greeter.name() == :greeter
    end
  end

  describe "handle_message/3" do
    test "always ignores messages" do
      assert :ignore == Greeter.handle_message("hello", "Alice", @ctx)
    end
  end

  describe "handle_event/3" do
    test "greets on user_joined" do
      assert {:reply, "Welcome, Alice!"} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, @ctx)
    end

    test "uses custom greeting" do
      ctx = put_in(@ctx.config["greeting"], "Hey {nickname}, welcome to {channel}!")

      assert {:reply, "Hey Bob, welcome to #general!"} =
               Greeter.handle_event(:user_joined, %{nickname: "Bob"}, ctx)
    end

    test "ignores user_left when farewell is nil" do
      assert :ignore == Greeter.handle_event(:user_left, %{nickname: "Alice"}, @ctx)
    end

    test "responds to user_left when farewell is set" do
      ctx = put_in(@ctx.config["farewell"], "Bye {nickname}!")

      assert {:reply, "Bye Alice!"} =
               Greeter.handle_event(:user_left, %{nickname: "Alice"}, ctx)
    end

    test "ignores unknown events" do
      assert :ignore == Greeter.handle_event(:topic_changed, %{}, @ctx)
    end
  end

  describe "default_config/0" do
    test "returns config with greeting and nil farewell" do
      config = Greeter.default_config()
      assert is_binary(config["greeting"])
      assert is_nil(config["farewell"])
    end
  end
end
