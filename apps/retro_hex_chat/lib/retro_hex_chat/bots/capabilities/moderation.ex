defmodule RetroHexChat.Bots.Capabilities.Moderation do
  @moduledoc """
  Auto-moderation capability. Runs as a passive pre-processor on ALL messages.

  Detects:
  - Blocked words (case-insensitive)
  - Spam (repeated messages within time window)
  - Flood (too many messages within time window)
  - Caps lock abuse (high uppercase ratio)

  Returns `{:side_effect, action}` or `:ignore`. Does NOT consume the message
  dispatch (other capabilities can still respond).
  """

  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Bots.Capability

  @impl true
  @spec name() :: atom()
  def name, do: :moderation

  @impl true
  @spec description() :: String.t()
  def description,
    do: gettext("Auto-moderation — blocked words, spam/flood detection, caps filter")

  @impl true
  @spec passive?() :: boolean()
  def passive?, do: true

  @impl true
  @spec init_state(map()) :: map()
  def init_state(_config) do
    %{
      message_history: %{},
      warnings: %{}
    }
  end

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(content, author, ctx) do
    config = ctx.config
    enabled = Map.get(config, "enabled", true)

    if not enabled do
      :ignore
    else
      state = ctx.capability_state
      now = System.monotonic_time(:second)

      state = record_message(state, author, content, now)

      case detect_violation(content, author, state, config, now) do
        nil ->
          # No violation — update state silently (track message history)
          {:side_effect, %{state_update: state}}

        {:violation, reason} ->
          {action_result, new_state} = apply_action(state, author, reason, config)
          {:reply, action_result, new_state}
      end
    end
  end

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec default_config() :: map()
  def default_config do
    %{
      "enabled" => true,
      "blocked_words" => [],
      "spam_threshold" => 3,
      "spam_window_sec" => 10,
      "flood_threshold" => 5,
      "flood_window_sec" => 5,
      "caps_threshold" => 0.7,
      "caps_min_length" => 10,
      "action" => "warn",
      "warn_message" => gettext("Hey {nickname}, please keep it civil."),
      "exempt_roles" => ["op", "admin"]
    }
  end

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(config) do
    action = Map.get(config, "action", "warn")

    if action in ["warn", "mute", "kick"] do
      :ok
    else
      {:error, gettext("action must be one of: warn, mute, kick")}
    end
  end

  @impl true
  @spec commands() :: [%{trigger: String.t(), description: String.t()}]
  def commands, do: []

  # ── Detection Logic ──

  @spec detect_violation(String.t(), String.t(), map(), map(), integer()) ::
          {:violation, String.t()} | nil
  def detect_violation(content, author, state, config, now) do
    checks = [
      fn -> check_blocked_words(content, config) end,
      fn -> check_spam(author, content, state, config, now) end,
      fn -> check_flood(author, state, config, now) end,
      fn -> check_caps(content, config) end
    ]

    Enum.find_value(checks, fn check -> check.() end)
  end

  @spec check_blocked_words(String.t(), map()) :: {:violation, String.t()} | nil
  defp check_blocked_words(content, config) do
    blocked = Map.get(config, "blocked_words", [])
    lower = String.downcase(content)

    if Enum.any?(blocked, &String.contains?(lower, String.downcase(&1))) do
      {:violation, gettext("using blocked words")}
    end
  end

  @spec check_spam(String.t(), String.t(), map(), map(), integer()) ::
          {:violation, String.t()} | nil
  defp check_spam(author, content, state, config, now) do
    threshold = Map.get(config, "spam_threshold", 3)
    window = Map.get(config, "spam_window_sec", 10)
    history = get_user_history(state, author)
    lower = String.downcase(content)

    recent_same =
      history
      |> Enum.filter(fn {msg, ts} -> now - ts <= window and String.downcase(msg) == lower end)
      |> length()

    if recent_same >= threshold do
      {:violation, gettext("spamming (%{count} identical messages)", count: recent_same)}
    end
  end

  @spec check_flood(String.t(), map(), map(), integer()) :: {:violation, String.t()} | nil
  defp check_flood(author, state, config, now) do
    threshold = Map.get(config, "flood_threshold", 5)
    window = Map.get(config, "flood_window_sec", 5)
    history = get_user_history(state, author)

    recent_count =
      history
      |> Enum.count(fn {_msg, ts} -> now - ts <= window end)

    if recent_count >= threshold do
      {:violation,
       gettext("flooding (%{count} messages in %{window}s)",
         count: recent_count,
         window: window
       )}
    end
  end

  @spec check_caps(String.t(), map()) :: {:violation, String.t()} | nil
  defp check_caps(content, config) do
    threshold = Map.get(config, "caps_threshold", 0.7)
    min_length = Map.get(config, "caps_min_length", 10)
    letters = String.replace(content, ~r/[^a-zA-Z]/, "")

    if String.length(letters) >= min_length do
      uppers = letters |> String.graphemes() |> Enum.count(&(&1 == String.upcase(&1)))
      ratio = uppers / String.length(letters)

      if ratio >= threshold do
        {:violation, gettext("excessive caps lock")}
      end
    end
  end

  # ── State Management ──

  @spec record_message(map(), String.t(), String.t(), integer()) :: map()
  defp record_message(state, author, content, now) do
    state = ensure_state(state)
    history = get_user_history(state, author)
    # Keep only last 20 messages per user
    history = Enum.take([{content, now} | history], 20)
    put_in(state, [:message_history, author], history)
  end

  @spec get_user_history(map(), String.t()) :: [{String.t(), integer()}]
  defp get_user_history(state, author) do
    state
    |> Map.get(:message_history, %{})
    |> Map.get(author, [])
  end

  @spec ensure_state(map()) :: map()
  defp ensure_state(state) do
    state
    |> Map.put_new(:message_history, %{})
    |> Map.put_new(:warnings, %{})
  end

  @spec apply_action(map(), String.t(), String.t(), map()) :: {String.t(), map()}
  defp apply_action(state, author, reason, config) do
    state = ensure_state(state)
    warn_count = Map.get(state.warnings, author, 0) + 1
    new_state = put_in(state, [:warnings, author], warn_count)

    template = Map.get(config, "warn_message", gettext("Hey {nickname}, please keep it civil."))
    message = String.replace(template, gettext("{nickname}"), author)
    message = gettext("%{message} (%{reason})", message: message, reason: reason)

    {message, new_state}
  end
end
