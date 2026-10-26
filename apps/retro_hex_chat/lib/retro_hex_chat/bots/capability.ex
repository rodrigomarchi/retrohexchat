defmodule RetroHexChat.Bots.Capability do
  @moduledoc """
  Behaviour for pluggable bot capabilities.

  Each capability is a module that handles messages and events for a bot.
  Capabilities are composable — a bot can have multiple capabilities active
  at once, and they are evaluated in order until one returns a reply.

  ## Capability Types

  - **Active** capabilities respond to directed commands (dice, trivia, help).
    They use first-match-wins dispatch.
  - **Passive** capabilities monitor all messages silently (moderation).
    They run as pre-processors before active dispatch.

  ## Stateful Capabilities

  Capabilities that need runtime state can implement `init_state/1` and return
  updated state via `{:reply, text, new_state}`. Timer-driven capabilities
  implement `handle_timer/3`.
  """

  @doc """
  Declares the behaviour, with the answers most capabilities give: ignore
  channel events, start enabled (`%{"enabled" => true}`), accept any config.
  A capability defines its own `handle_event/3`, `default_config/0` or
  `validate_config/1` where it has something else to say.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour RetroHexChat.Bots.Capability

      @impl true
      @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
              RetroHexChat.Bots.Capability.capability_result()
      def handle_event(_event, _payload, _ctx), do: :ignore

      @impl true
      @spec default_config() :: map()
      def default_config, do: %{"enabled" => true}

      @impl true
      @spec validate_config(map()) :: :ok | {:error, String.t()}
      def validate_config(_config), do: :ok

      defoverridable handle_event: 3, default_config: 0, validate_config: 1
    end
  end

  @type bot_context :: %{
          optional(:joined_channels) => [String.t()],
          bot_nickname: String.t(),
          bot_name: String.t(),
          bot_id: integer(),
          channel: String.t(),
          command_prefix: String.t(),
          config: map(),
          capability_state: map(),
          author: String.t() | nil
        }

  @type capability_result ::
          {:reply, String.t()}
          | {:reply, String.t(), map()}
          | {:reply_action, String.t()}
          | {:bot_output, map()}
          | {:bot_output, map(), map()}
          | {:multi_output, [map()]}
          | {:multi_output, [map()], map()}
          | {:multi_reply, [String.t()]}
          | {:multi_reply, [String.t()], map()}
          | {:side_effect, map()}
          | :ignore

  @doc "Unique capability identifier."
  @callback name() :: atom()

  @doc "Human-readable description for help/UI."
  @callback description() :: String.t()

  @doc "Called when a message arrives in a channel the bot is in."
  @callback handle_message(content :: String.t(), author :: String.t(), bot_context()) ::
              capability_result()

  @doc "Called when a channel event occurs (user_joined, user_left, topic_changed, etc.)."
  @callback handle_event(event :: atom(), payload :: map(), bot_context()) ::
              capability_result()

  @doc "Default config for this capability (stored in DB as JSONB)."
  @callback default_config() :: map()

  @doc "Validate config changes."
  @callback validate_config(config :: map()) :: :ok | {:error, String.t()}

  @doc "List of bot commands this capability provides (for !help)."
  @callback commands() :: [%{trigger: String.t(), description: String.t()}]

  @doc "Initialize runtime state from config. Called when bot starts."
  @callback init_state(config :: map()) :: map()

  @doc "Handle a timer firing for this capability."
  @callback handle_timer(payload :: term(), state :: map(), bot_context()) ::
              {capability_result(), map()}

  @doc "Whether this capability is passive (processes all messages, not first-match)."
  @callback passive?() :: boolean()

  @doc """
  Called by Server during init to set up initial timers for this capability.
  Returns updated server state with timers scheduled.
  """
  @callback init_timers(
              server_state :: map(),
              cap_name :: atom(),
              config :: map(),
              cap_state :: map()
            ) :: map()

  @doc """
  Called by Server when the bot comes into `channel` after it started, to set
  up what `init_timers/4` would have for a channel it had from the start.
  """
  @callback init_channel_timers(
              server_state :: map(),
              cap_name :: atom(),
              config :: map(),
              cap_state :: map(),
              channel :: String.t()
            ) :: map()

  @doc """
  Called after a timer fires to determine if it should be rescheduled.
  Returns `{:reschedule, delay_ms, new_payload}` or `:no_reschedule`.
  """
  @callback reschedule_delay(payload :: term(), cap_state :: map()) ::
              {:reschedule, non_neg_integer(), term()} | :no_reschedule

  @doc """
  Runtime state keys worth surviving a restart, written back into the bot's
  stored config whenever they change.

  Most capability state is scratch — a trivia round in progress, a flood counter
  — and losing it on deploy costs nothing. Some of it is the opposite: a feed
  list the operator typed, and the memory of which items were already published.
  Without this, an RSS bot forgets its feeds on every deploy, and if it did
  remember them it would announce the whole feed again.

  Keys are strings matching the capability's own state map. Default: none.
  """
  @callback durable_keys() :: [atom()]

  @optional_callbacks [
    commands: 0,
    init_state: 1,
    handle_timer: 3,
    passive?: 0,
    init_timers: 4,
    init_channel_timers: 5,
    reschedule_delay: 2,
    durable_keys: 0
  ]

  @doc """
  What follows `<prefix><bot> <word>` in a message, case-insensitively and
  trimmed: `{:ok, ""}` for the bare command, `:error` when the message is not
  that command. `word` may be a list of aliases (`["roll", "dice"]`). The word
  must end where the command ends — `!bot triviaplease` is not `trivia`.
  """
  @spec subcommand(String.t(), String.t(), String.t(), String.t() | [String.t()]) ::
          {:ok, String.t()} | :error
  def subcommand(content, prefix, bot_name, words) do
    lower = String.downcase(content)
    head = String.downcase(prefix <> bot_name)

    Enum.find_value(List.wrap(words), :error, fn word ->
      command = head <> " " <> String.downcase(word)

      cond do
        lower == command ->
          {:ok, ""}

        String.starts_with?(lower, command <> " ") ->
          {:ok, content |> String.slice(String.length(command <> " ")..-1//1) |> String.trim()}

        true ->
          nil
      end
    end)
  end

  @doc """
  A subcommand with its verb lowercased and the rest as typed:
  `"ADD https://x/Feed #c"` is `"add https://x/Feed #c"`. Matching ignores
  case; an address or a message must not.
  """
  @spec downcase_verb(String.t()) :: String.t()
  def downcase_verb(sub) do
    case String.split(sub, " ", parts: 2) do
      [verb, rest] -> String.downcase(verb) <> " " <> rest
      [verb] -> String.downcase(verb)
    end
  end

  @doc """
  The reply to a `list` subcommand: `empty` when there is nothing to list,
  otherwise `header` and one line per item.
  """
  @spec list_reply([term()], String.t(), String.t(), (term() -> String.t())) ::
          capability_result()
  def list_reply([], empty, _header, _line), do: {:reply, empty}

  def list_reply(items, _empty, header, line),
    do: {:multi_reply, [header | Enum.map(items, line)]}
end
