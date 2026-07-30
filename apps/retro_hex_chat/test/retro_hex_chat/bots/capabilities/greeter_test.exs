defmodule RetroHexChat.Bots.Capabilities.GreeterTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Greeter

  @ctx %{
    bot_nickname: "GreetBot",
    bot_name: "GreetBot",
    channel: "#general",
    command_prefix: "!",
    config: %{"greeting" => "Welcome, {nickname}!", "farewell" => nil},
    capability_state: %{recent_deliveries: %{}}
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
      assert {:bot_output, output, %{recent_deliveries: _}} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, @ctx)

      assert output == %{content: "Welcome, Alice!", delivery: "public", target: "Alice"}
    end

    test "uses custom greeting" do
      ctx = put_in(@ctx.config["greeting"], "Hey {nickname}, welcome to {channel}!")

      assert {:bot_output, %{content: "Hey Bob, welcome to #general!"}, _state} =
               Greeter.handle_event(:user_joined, %{nickname: "Bob"}, ctx)
    end

    test "uses configured delivery for greeting" do
      ctx = put_in(@ctx.config["greeting_delivery"], "private_notice")

      assert {:bot_output, output, _state} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)

      assert output.delivery == "private_notice"
      assert output.target == "Alice"
    end

    test "suppresses repeated identical delivery to the same nick in the same channel" do
      ctx =
        @ctx
        |> put_in([:config, "greeting_delivery"], "private_notice")
        |> put_in([:config, "repeat_window_sec"], 3600)

      assert {:bot_output, _output, state} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)

      ctx = %{ctx | capability_state: state}

      assert :ignore == Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)
    end

    test "allows the same greeting for a different nick" do
      ctx =
        @ctx
        |> put_in([:config, "greeting_delivery"], "private_notice")
        |> put_in([:config, "repeat_window_sec"], 3600)

      assert {:bot_output, _output, state} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)

      ctx = %{ctx | capability_state: state}

      assert {:bot_output, %{target: "Bob"}, _state} =
               Greeter.handle_event(:user_joined, %{nickname: "Bob"}, ctx)
    end

    test "stays silent when the greeting is cleared" do
      # `/bot set <name> greeting none` stores nil. A bot that stands in every
      # room — the moderator — is set this way so it does not double the welcome
      # each room's host already gives.
      ctx = put_in(@ctx.config["greeting"], nil)

      assert :ignore ==
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)
    end

    test "ignores user_left when farewell is nil" do
      assert :ignore == Greeter.handle_event(:user_left, %{nickname: "Alice"}, @ctx)
    end

    test "responds to user_left when farewell is set" do
      ctx = put_in(@ctx.config["farewell"], "Bye {nickname}!")

      assert {:bot_output, %{content: "Bye Alice!", delivery: "public", target: "Alice"}, _state} =
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
      assert config["greeting_delivery"] == "private_notice"
      assert config["farewell_delivery"] == "silent"
      assert config["repeat_window_sec"] == 3600
    end
  end
end
