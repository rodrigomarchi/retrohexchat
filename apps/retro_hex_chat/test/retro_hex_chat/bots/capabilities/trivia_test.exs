defmodule RetroHexChat.Bots.Capabilities.TriviaTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Trivia
  alias RetroHexChat.Bots.Capabilities.Trivia.QuestionBank

  @default_config Trivia.default_config()

  @ctx %{
    bot_nickname: "QuizBot",
    bot_name: "QuizBot",
    channel: "#trivia",
    command_prefix: "!",
    config: @default_config,
    capability_state: Trivia.init_state(@default_config)
  }

  describe "name/0" do
    test "returns :trivia" do
      assert Trivia.name() == :trivia
    end
  end

  describe "description/0" do
    test "does not say Coming soon" do
      refute Trivia.description() =~ "Coming soon"
    end
  end

  describe "init_state/1" do
    test "initializes with empty active_games" do
      state = Trivia.init_state(@default_config)
      assert state.active_games == %{}
    end
  end

  describe "trivia start" do
    test "starts a trivia round" do
      result = Trivia.handle_message("!QuizBot trivia start", "user1", @ctx)
      assert {:reply, text, new_state} = result
      assert text =~ "Trivia started!"
      assert text =~ "Q1/"
      assert Map.has_key?(new_state.active_games, "#trivia")
    end

    test "refuses to start when round already in progress" do
      {:reply, _, state} = Trivia.handle_message("!QuizBot trivia start", "user1", @ctx)
      ctx = %{@ctx | capability_state: state}
      result = Trivia.handle_message("!QuizBot trivia start", "user2", ctx)
      assert {:reply, text} = result
      assert text =~ "already in progress"
    end
  end

  describe "trivia stop" do
    test "stops a round" do
      {:reply, _, state} = Trivia.handle_message("!QuizBot trivia start", "user1", @ctx)
      ctx = %{@ctx | capability_state: state}
      result = Trivia.handle_message("!QuizBot trivia stop", "user1", ctx)
      assert {:reply, text, new_state} = result
      assert text =~ "stopped"
      refute Map.has_key?(new_state.active_games, "#trivia")
    end

    test "reports when no round in progress" do
      result = Trivia.handle_message("!QuizBot trivia stop", "user1", @ctx)
      assert {:reply, text} = result
      assert text =~ "No trivia round"
    end
  end

  describe "trivia score" do
    test "shows scores during round" do
      {:reply, _, state} = Trivia.handle_message("!QuizBot trivia start", "user1", @ctx)
      ctx = %{@ctx | capability_state: state}
      result = Trivia.handle_message("!QuizBot trivia score", "user1", ctx)
      assert {:reply, text} = result
      assert text =~ "Scores"
    end

    test "reports when no round in progress" do
      result = Trivia.handle_message("!QuizBot trivia score", "user1", @ctx)
      assert {:reply, text} = result
      assert text =~ "No trivia round"
    end
  end

  describe "answer submission" do
    test "accepts correct answer" do
      {:reply, _, state} = Trivia.handle_message("!QuizBot trivia start", "user1", @ctx)

      # Get the current question's answer
      game = state.active_games["#trivia"]
      answer = game.question.answer

      ctx = %{@ctx | capability_state: state}
      result = Trivia.handle_message("!QuizBot answer #{answer}", "user1", ctx)
      assert {:reply, text, new_state} = result
      assert text =~ "Correct"
      assert text =~ "user1"

      # Check score was awarded
      if Map.has_key?(new_state.active_games, "#trivia") do
        assert new_state.active_games["#trivia"].scores["user1"] == 10
      end
    end

    test "ignores wrong answer" do
      {:reply, _, state} = Trivia.handle_message("!QuizBot trivia start", "user1", @ctx)
      ctx = %{@ctx | capability_state: state}
      result = Trivia.handle_message("!QuizBot answer definitely_wrong_xyzzy", "user1", ctx)
      assert :ignore == result
    end

    test "ignores answer when no round in progress" do
      result = Trivia.handle_message("!QuizBot answer something", "user1", @ctx)
      assert :ignore == result
    end
  end

  describe "answer_matches?/2" do
    test "case insensitive" do
      assert Trivia.answer_matches?("Paris", "paris")
    end

    test "trims whitespace" do
      assert Trivia.answer_matches?("  Paris  ", "Paris")
    end

    test "normalizes whitespace" do
      assert Trivia.answer_matches?("blue  whale", "blue whale")
    end

    test "rejects wrong answers" do
      refute Trivia.answer_matches?("London", "Paris")
    end
  end

  describe "handle_timer/3" do
    test "hint timer provides hint" do
      {:reply, _, state} = Trivia.handle_message("!QuizBot trivia start", "user1", @ctx)
      ctx = %{@ctx | capability_state: state}
      payload = %{type: :hint, channel: "#trivia"}
      {result, _state} = Trivia.handle_timer(payload, state, ctx)
      assert {:reply, text} = result
      assert text =~ "Hint:"
    end

    test "timeout timer reveals answer and advances" do
      {:reply, _, state} = Trivia.handle_message("!QuizBot trivia start", "user1", @ctx)
      ctx = %{@ctx | capability_state: state}
      payload = %{type: :timeout, channel: "#trivia"}
      {result, _new_state} = Trivia.handle_timer(payload, state, ctx)
      assert {:reply, text} = result
      assert text =~ "Time's up!"
    end

    test "ignores timer when no game active" do
      payload = %{type: :timeout, channel: "#trivia"}
      state = Trivia.init_state(@default_config)
      {result, _state} = Trivia.handle_timer(payload, state, @ctx)
      assert :ignore == result
    end
  end

  describe "round completion" do
    test "ends round when all questions answered" do
      config = Map.put(@default_config, "questions_per_round", 1)
      ctx = %{@ctx | config: config}
      {:reply, _, state} = Trivia.handle_message("!QuizBot trivia start", "user1", ctx)

      game = state.active_games["#trivia"]
      answer = game.question.answer

      ctx2 = %{ctx | capability_state: state}

      {:reply, text, new_state} =
        Trivia.handle_message("!QuizBot answer #{answer}", "user1", ctx2)

      assert text =~ "Round over!"
      refute Map.has_key?(new_state.active_games, "#trivia")
    end
  end

  describe "commands/0" do
    test "returns trivia commands" do
      cmds = Trivia.commands()
      triggers = Enum.map(cmds, & &1.trigger)
      assert "trivia start" in triggers
      assert "answer" in triggers
    end
  end

  describe "QuestionBank" do
    test "has multiple categories" do
      cats = QuestionBank.categories()
      assert "general" in cats
      assert "science" in cats
      assert "technology" in cats
    end

    test "returns questions for valid category" do
      questions = QuestionBank.random_questions("general", 5)
      assert length(questions) == 5
    end

    test "returns limited questions" do
      questions = QuestionBank.random_questions("general", 2)
      assert length(questions) == 2
    end

    test "falls back to general for unknown category" do
      questions = QuestionBank.random_questions("nonexistent", 3)
      assert length(questions) == 3
    end
  end
end
