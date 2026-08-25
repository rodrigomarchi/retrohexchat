defmodule RetroHexChat.Bots.Capabilities.GreeterTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Greeter
  alias RetroHexChat.Bots.GreetingLedgerStub

  @ctx %{
    bot_nickname: "GreetBot",
    bot_name: "GreetBot",
    bot_id: 1,
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

  describe "handle_event/3 — a bot that only greets" do
    test "produces exactly one output, as it did before onboarding existed" do
      assert {:bot_output, output} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, @ctx)

      assert output == %{content: "Welcome, Alice!", delivery: "public", target: "Alice"}
    end

    test "uses custom greeting" do
      ctx = put_in(@ctx.config["greeting"], "Hey {nickname}, welcome to {channel}!")

      assert {:bot_output, %{content: "Hey Bob, welcome to #general!"}} =
               Greeter.handle_event(:user_joined, %{nickname: "Bob"}, ctx)
    end

    test "uses configured delivery for greeting" do
      ctx = put_in(@ctx.config["greeting_delivery"], "private_notice")

      assert {:bot_output, output} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)

      assert output.delivery == "private_notice"
      assert output.target == "Alice"
    end

    test "stays silent when the greeting is cleared" do
      # `/bot set <name> greeting none` stores nil. A bot that stands in every
      # room — the moderator — is set this way so it does not double the welcome
      # each room's host already gives.
      ctx = put_in(@ctx.config["greeting"], nil)

      assert :ignore == Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)
    end

    test "a cleared greeting never reaches the ledger" do
      # The moderator stands in every room and answers no join. Writing a row for
      # each one would make the ledger grow with the rooms nobody is greeted in.
      GreetingLedgerStub.put_answer(:within_window)
      ctx = put_in(@ctx.config["greeting"], nil)

      assert :ignore == Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)
    end
  end

  describe "handle_event/3 — announcement and tour" do
    setup do
      ctx =
        @ctx
        |> put_in([:config, "greeting"], "Yo {nickname}, this is {channel}.")
        |> put_in([:config, "greeting_delivery"], "private_notice")
        |> put_in([:config, "public_greeting"], "* {botname} waves at {nickname}")
        |> put_in([:config, "onboarding_1"], "/join #room · /msg nick · /nick new")
        |> put_in([:config, "onboarding_2"], "Every room is a tab. /help lists it all.")

      {:ok, ctx: ctx}
    end

    test "a newcomer is announced once and toured privately", %{ctx: ctx} do
      GreetingLedgerStub.put_answer(:first_time)

      assert {:multi_output, outputs} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)

      assert [announcement, greeting, line_one, line_two] = outputs

      assert announcement == %{
               content: "* GreetBot waves at Alice",
               delivery: "public",
               target: "Alice"
             }

      assert greeting.content == "Yo Alice, this is #general."
      assert greeting.delivery == "private_notice"
      assert line_one.content == "/join #room · /msg nick · /nick new"
      assert line_two.content == "Every room is a tab. /help lists it all."

      assert Enum.all?([greeting, line_one, line_two], &(&1.delivery == "private_notice"))
      assert Enum.all?(outputs, &(&1.target == "Alice"))
    end

    test "somebody coming back after the window is toured but not announced", %{ctx: ctx} do
      GreetingLedgerStub.put_answer(:window_elapsed)

      assert {:multi_output, outputs} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)

      refute Enum.any?(outputs, &(&1.delivery == "public"))
      assert length(outputs) == 3
    end

    test "somebody who was just here hears nothing at all", %{ctx: ctx} do
      GreetingLedgerStub.put_answer(:within_window)

      assert :ignore == Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)
    end

    test "onboarding lines keep the order their keys are numbered in", %{ctx: ctx} do
      ctx = put_in(ctx.config["onboarding_4"], "fourth")
      GreetingLedgerStub.put_answer(:first_time)

      assert {:multi_output, outputs} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)

      assert Enum.map(outputs, & &1.content) == [
               "* GreetBot waves at Alice",
               "Yo Alice, this is #general.",
               "/join #room · /msg nick · /nick new",
               "Every room is a tab. /help lists it all.",
               "fourth"
             ]
    end

    test "a gap in the numbering closes rather than emitting a blank line", %{ctx: ctx} do
      ctx =
        ctx
        |> put_in([:config, "onboarding_2"], nil)
        |> put_in([:config, "onboarding_3"], "third")

      GreetingLedgerStub.put_answer(:first_time)

      assert {:multi_output, outputs} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)

      assert Enum.map(outputs, & &1.content) == [
               "* GreetBot waves at Alice",
               "Yo Alice, this is #general.",
               "/join #room · /msg nick · /nick new",
               "third"
             ]
    end

    test "onboarding follows its own delivery when one is set", %{ctx: ctx} do
      ctx = put_in(ctx.config["onboarding_delivery"], "channel_notice")
      GreetingLedgerStub.put_answer(:first_time)

      assert {:multi_output, [_announcement, greeting, line_one, line_two]} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)

      assert greeting.delivery == "private_notice"
      assert line_one.delivery == "channel_notice"
      assert line_two.delivery == "channel_notice"
    end

    test "onboarding falls back to the greeting's delivery when it has none", %{ctx: ctx} do
      GreetingLedgerStub.put_answer(:first_time)

      assert {:multi_output, [_announcement, _greeting, line_one, _line_two]} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)

      assert line_one.delivery == "private_notice"
    end

    test "an announcement alone still reaches the room", %{ctx: ctx} do
      ctx =
        ctx
        |> put_in([:config, "greeting"], nil)
        |> put_in([:config, "onboarding_1"], nil)
        |> put_in([:config, "onboarding_2"], nil)

      GreetingLedgerStub.put_answer(:first_time)

      assert {:bot_output, %{delivery: "public", content: "* GreetBot waves at Alice"}} =
               Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)
    end

    test "an announcement alone says nothing to somebody already met", %{ctx: ctx} do
      ctx =
        ctx
        |> put_in([:config, "greeting"], nil)
        |> put_in([:config, "onboarding_1"], nil)
        |> put_in([:config, "onboarding_2"], nil)

      GreetingLedgerStub.put_answer(:window_elapsed)

      assert :ignore == Greeter.handle_event(:user_joined, %{nickname: "Alice"}, ctx)
    end
  end

  describe "handle_event/3 — farewells" do
    test "ignores user_left when farewell is nil" do
      assert :ignore == Greeter.handle_event(:user_left, %{nickname: "Alice"}, @ctx)
    end

    test "responds to user_left when farewell is set" do
      ctx = put_in(@ctx.config["farewell"], "Bye {nickname}!")

      assert {:bot_output, %{content: "Bye Alice!", delivery: "public", target: "Alice"}, _state} =
               Greeter.handle_event(:user_left, %{nickname: "Alice"}, ctx)
    end

    test "suppresses a repeated farewell inside the window without the ledger" do
      # Farewells are disabled in every seeded script and a duplicate goodbye
      # costs nobody anything, so they keep the in-process window rather than a
      # row per person per room.
      ctx =
        @ctx
        |> put_in([:config, "farewell"], "Bye {nickname}!")
        |> put_in([:config, "repeat_window_sec"], 3600)

      assert {:bot_output, _output, state} =
               Greeter.handle_event(:user_left, %{nickname: "Alice"}, ctx)

      ctx = %{ctx | capability_state: state}

      assert :ignore == Greeter.handle_event(:user_left, %{nickname: "Alice"}, ctx)

      assert {:bot_output, %{target: "Bob"}, _state} =
               Greeter.handle_event(:user_left, %{nickname: "Bob"}, ctx)
    end

    test "ignores unknown events" do
      assert :ignore == Greeter.handle_event(:topic_changed, %{}, @ctx)
    end
  end

  describe "onboarding_keys/0" do
    test "numbers every line the capability will read, in order" do
      assert Greeter.onboarding_keys() == ~w(onboarding_1 onboarding_2 onboarding_3 onboarding_4)
      assert length(Greeter.onboarding_keys()) == Greeter.max_onboarding_lines()
    end
  end

  describe "default_config/0" do
    test "returns config with greeting and nil farewell" do
      config = Greeter.default_config()
      assert is_binary(config["greeting"])
      assert is_nil(config["farewell"])
      assert is_nil(config["public_greeting"])
      assert config["greeting_delivery"] == "private_notice"
      assert config["onboarding_delivery"] == "private_notice"
      assert config["farewell_delivery"] == "silent"
      assert config["repeat_window_sec"] == 3600
    end
  end

  describe "validate_config/1" do
    test "rejects an onboarding delivery that is not a delivery" do
      assert {:error, message} = Greeter.validate_config(%{"onboarding_delivery" => "shout"})
      assert message =~ "onboarding_delivery"
    end

    test "accepts every delivery mode for onboarding" do
      for mode <- ~w(public channel_notice private_notice silent) do
        assert :ok == Greeter.validate_config(%{"onboarding_delivery" => mode})
      end
    end
  end
end
