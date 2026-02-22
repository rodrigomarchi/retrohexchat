defmodule RetroHexChat.Bots.Capabilities.Trivia do
  @moduledoc """
  Interactive trivia/quiz capability with scoring and timers.

  Commands:
    - `!Bot trivia start` — start a new round
    - `!Bot trivia stop` — stop the current round
    - `!Bot trivia score` — show current scores
    - `!Bot answer <text>` — submit an answer
  """
  @behaviour RetroHexChat.Bots.Capability

  alias RetroHexChat.Bots.Capabilities.Trivia.QuestionBank

  @impl true
  @spec name() :: atom()
  def name, do: :trivia

  @impl true
  @spec description() :: String.t()
  def description, do: "Interactive quiz and trivia with scoring"

  @impl true
  @spec init_state(map()) :: map()
  def init_state(_config) do
    %{active_games: %{}}
  end

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(content, author, ctx) do
    prefix = ctx.command_prefix
    bot_name = ctx.bot_nickname
    state = ctx.capability_state

    case parse_command(content, prefix, bot_name) do
      {:trivia, "start"} ->
        handle_start(ctx.channel, state, ctx.config)

      {:trivia, "stop"} ->
        handle_stop(ctx.channel, state)

      {:trivia, "score"} ->
        handle_score(ctx.channel, state)

      {:answer, text} ->
        handle_answer(ctx.channel, author, text, state, ctx.config)

      :ignore ->
        :ignore
    end
  end

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec handle_timer(term(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          {RetroHexChat.Bots.Capability.capability_result(), map()}
  def handle_timer(%{type: :hint, channel: channel}, state, _ctx) do
    case get_game(state, channel) do
      nil ->
        {:ignore, state}

      game ->
        hint = get_hint(game.question)

        if hint do
          {{:reply, "Hint: #{hint}"}, state}
        else
          {:ignore, state}
        end
    end
  end

  def handle_timer(%{type: :timeout, channel: channel}, state, ctx) do
    case get_game(state, channel) do
      nil ->
        {:ignore, state}

      game ->
        config = ctx.config
        show_answer = Map.get(config, "show_answer_on_timeout", true)

        timeout_msg =
          if show_answer do
            "Time's up! The answer was: #{game.question.answer}"
          else
            "Time's up! Nobody got it."
          end

        {result, new_state} = advance_question(channel, game, state, config, timeout_msg)
        {result, new_state}
    end
  end

  def handle_timer(_payload, state, _ctx), do: {:ignore, state}

  @impl true
  @spec default_config() :: map()
  def default_config do
    %{
      "enabled" => true,
      "category" => "general",
      "time_limit_sec" => 30,
      "questions_per_round" => 10,
      "points_per_answer" => 10,
      "hint_after_sec" => 15,
      "show_answer_on_timeout" => true
    }
  end

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(config) do
    category = Map.get(config, "category", "general")

    if category in QuestionBank.categories() do
      :ok
    else
      {:error,
       "Unknown category '#{category}'. Available: #{Enum.join(QuestionBank.categories(), ", ")}"}
    end
  end

  @impl true
  @spec commands() :: [%{trigger: String.t(), description: String.t()}]
  def commands do
    [
      %{trigger: "trivia start", description: "Start a trivia round"},
      %{trigger: "trivia stop", description: "Stop the current round"},
      %{trigger: "trivia score", description: "Show current scores"},
      %{trigger: "answer", description: "Submit a trivia answer"}
    ]
  end

  # ── Command Parsing ──

  @spec parse_command(String.t(), String.t(), String.t()) ::
          {:trivia, String.t()} | {:answer, String.t()} | :ignore
  defp parse_command(content, prefix, bot_name) do
    lower = String.downcase(content)
    cmd_prefix = String.downcase(prefix) <> String.downcase(bot_name)

    cond do
      String.starts_with?(lower, cmd_prefix <> " trivia ") ->
        sub =
          content |> String.slice(String.length(cmd_prefix <> " trivia ")..-1//1) |> String.trim()

        {:trivia, String.downcase(sub)}

      String.starts_with?(lower, cmd_prefix <> " trivia") ->
        {:trivia, ""}

      String.starts_with?(lower, cmd_prefix <> " answer ") ->
        text =
          content |> String.slice(String.length(cmd_prefix <> " answer ")..-1//1) |> String.trim()

        {:answer, text}

      true ->
        :ignore
    end
  end

  # ── Game Logic ──

  # Converts {{:reply, text}, state} from advance_question to {:reply, text, state} for handle_message
  @spec unwrap_advance({{:reply, String.t()}, map()}) :: {:reply, String.t(), map()}
  defp unwrap_advance({{:reply, text}, new_state}), do: {:reply, text, new_state}

  @spec handle_start(String.t(), map(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp handle_start(channel, state, config) do
    if get_game(state, channel) do
      {:reply, "A trivia round is already in progress! Use 'trivia stop' to end it."}
    else
      category = Map.get(config, "category", "general")
      count = Map.get(config, "questions_per_round", 10)
      questions = QuestionBank.random_questions(category, count)

      case questions do
        [] ->
          {:reply, "No questions available for category '#{category}'."}

        [first | rest] ->
          game = %{
            question: first,
            question_number: 1,
            total_questions: length(questions),
            scores: %{},
            remaining: rest,
            asked_at: System.monotonic_time(:second)
          }

          new_state = put_game(state, channel, game)
          q_text = format_question(game)

          {:reply, "Trivia started! (#{category}, #{game.total_questions} questions)\n#{q_text}",
           new_state}
      end
    end
  end

  @spec handle_stop(String.t(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_stop(channel, state) do
    case get_game(state, channel) do
      nil ->
        {:reply, "No trivia round in progress."}

      game ->
        new_state = remove_game(state, channel)
        scores_text = format_final_scores(game.scores)
        {:reply, "Trivia stopped! #{scores_text}", new_state}
    end
  end

  @spec handle_score(String.t(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_score(channel, state) do
    case get_game(state, channel) do
      nil ->
        {:reply, "No trivia round in progress."}

      game ->
        {:reply, format_scores(game.scores, game.question_number, game.total_questions)}
    end
  end

  @spec handle_answer(String.t(), String.t(), String.t(), map(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp handle_answer(channel, author, text, state, config) do
    case get_game(state, channel) do
      nil ->
        :ignore

      game ->
        if answer_matches?(text, game.question.answer) do
          points = Map.get(config, "points_per_answer", 10)
          new_scores = Map.update(game.scores, author, points, &(&1 + points))
          game = %{game | scores: new_scores}

          correct_msg = "Correct, #{author}! (+#{points} points)"
          unwrap_advance(advance_question(channel, game, state, config, correct_msg))
        else
          :ignore
        end
    end
  end

  @spec advance_question(String.t(), map(), map(), map(), String.t()) ::
          {RetroHexChat.Bots.Capability.capability_result(), map()}
  defp advance_question(channel, game, state, _config, prefix_msg) do
    case game.remaining do
      [] ->
        new_state = remove_game(state, channel)
        scores_text = format_final_scores(game.scores)
        {{:reply, "#{prefix_msg}\nRound over! #{scores_text}"}, new_state}

      [next | rest] ->
        new_game = %{
          game
          | question: next,
            question_number: game.question_number + 1,
            remaining: rest,
            asked_at: System.monotonic_time(:second)
        }

        new_state = put_game(state, channel, new_game)
        q_text = format_question(new_game)
        {{:reply, "#{prefix_msg}\n#{q_text}"}, new_state}
    end
  end

  @spec answer_matches?(String.t(), String.t()) :: boolean()
  def answer_matches?(given, expected) do
    normalize(given) == normalize(expected)
  end

  @spec normalize(String.t()) :: String.t()
  defp normalize(text) do
    text |> String.downcase() |> String.trim() |> String.replace(~r/\s+/, " ")
  end

  # ── State Helpers ──

  @spec get_game(map(), String.t()) :: map() | nil
  defp get_game(state, channel) do
    get_in(state, [:active_games, channel])
  end

  @spec put_game(map(), String.t(), map()) :: map()
  defp put_game(state, channel, game) do
    put_in(state, [:active_games, channel], game)
  end

  @spec remove_game(map(), String.t()) :: map()
  defp remove_game(state, channel) do
    update_in(state, [:active_games], &Map.delete(&1, channel))
  end

  # ── Formatting ──

  @spec format_question(map()) :: String.t()
  defp format_question(game) do
    "Q#{game.question_number}/#{game.total_questions}: #{game.question.question}"
  end

  @spec format_scores(map(), integer(), integer()) :: String.t()
  defp format_scores(scores, q_num, total) when map_size(scores) == 0 do
    "Scores (Q#{q_num}/#{total}): No scores yet."
  end

  defp format_scores(scores, q_num, total) do
    ranked =
      scores
      |> Enum.sort_by(fn {_name, pts} -> pts end, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {{name, pts}, rank} -> "#{rank}. #{name}: #{pts}pts" end)
      |> Enum.join(", ")

    "Scores (Q#{q_num}/#{total}): #{ranked}"
  end

  @spec format_final_scores(map()) :: String.t()
  defp format_final_scores(scores) when map_size(scores) == 0 do
    "No scores recorded."
  end

  defp format_final_scores(scores) do
    ranked =
      scores
      |> Enum.sort_by(fn {_name, pts} -> pts end, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {{name, pts}, rank} -> "#{rank}. #{name}: #{pts}pts" end)
      |> Enum.join(", ")

    "Final scores: #{ranked}"
  end

  @spec get_hint(map()) :: String.t() | nil
  defp get_hint(%{hints: [hint | _]}), do: hint
  defp get_hint(_), do: nil
end
