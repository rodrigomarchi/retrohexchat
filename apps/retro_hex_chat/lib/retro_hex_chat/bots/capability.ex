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

  @type bot_context :: %{
          bot_nickname: String.t(),
          bot_name: String.t(),
          channel: String.t(),
          command_prefix: String.t(),
          config: map(),
          capability_state: map()
        }

  @type capability_result ::
          {:reply, String.t()}
          | {:reply, String.t(), map()}
          | {:reply_action, String.t()}
          | {:multi_reply, [String.t()]}
          | {:notice, String.t(), String.t()}
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
  Called after a timer fires to determine if it should be rescheduled.
  Returns `{:reschedule, delay_ms, new_payload}` or `:no_reschedule`.
  """
  @callback reschedule_delay(payload :: term(), cap_state :: map()) ::
              {:reschedule, non_neg_integer(), term()} | :no_reschedule

  @optional_callbacks [
    commands: 0,
    init_state: 1,
    handle_timer: 3,
    passive?: 0,
    init_timers: 4,
    reschedule_delay: 2
  ]
end
