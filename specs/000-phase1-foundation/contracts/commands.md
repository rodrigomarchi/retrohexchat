# Command Handler Contracts

**Date**: 2026-02-09
**Context**: RetroHexChat Phase 1 — "/" Command System

## Handler Behaviour

All "/" commands MUST implement the `RetroHexChat.Commands.Handler`
behaviour. This is the central contract for the command system
(Constitution Principle V).

```elixir
defmodule RetroHexChat.Commands.Handler do
  @moduledoc """
  Behaviour that all "/" command handlers must implement.
  """

  @type context :: %{
    nickname: String.t(),
    active_channel: String.t() | nil,
    channels: [String.t()],
    identified: boolean(),
    operator_in: [String.t()]
  }

  @type result ::
    {:ok, :noop}
    | {:ok, :message, map()}
    | {:ok, :action, map()}
    | {:ok, :system, map()}
    | {:ok, :join, String.t()}
    | {:ok, :part, String.t(), String.t() | nil}
    | {:ok, :nick_change, String.t()}
    | {:ok, :quit, String.t() | nil}
    | {:ok, :ui_action, atom(), map()}
    | {:error, String.t()}

  @doc """
  Execute the command with parsed arguments and user context.
  Returns a tagged result tuple indicating what action to take.
  """
  @callback execute(args :: [String.t()], context :: context()) :: result()

  @doc """
  Validate the raw argument string before execution.
  Returns :ok or {:error, reason}.
  """
  @callback validate(raw_args :: String.t()) :: :ok | {:error, String.t()}

  @doc """
  Return help text for this command.
  Returns a map with :name, :syntax, :description, :examples.
  """
  @callback help() :: %{
    name: String.t(),
    syntax: String.t(),
    description: String.t(),
    examples: [String.t()]
  }
end
```

## Command Registry

Maps command names to handler modules.

```elixir
# RetroHexChat.Commands.Registry
@commands %{
  "join"  => RetroHexChat.Commands.Handlers.Join,
  "part"  => RetroHexChat.Commands.Handlers.Part,
  "leave" => RetroHexChat.Commands.Handlers.Part,  # alias
  "msg"   => RetroHexChat.Commands.Handlers.Msg,
  "query" => RetroHexChat.Commands.Handlers.Query,
  "me"    => RetroHexChat.Commands.Handlers.Me,
  "nick"  => RetroHexChat.Commands.Handlers.Nick,
  "topic" => RetroHexChat.Commands.Handlers.Topic,
  "kick"  => RetroHexChat.Commands.Handlers.Kick,
  "ban"   => RetroHexChat.Commands.Handlers.Ban,
  "mode"  => RetroHexChat.Commands.Handlers.Mode,
  "whois" => RetroHexChat.Commands.Handlers.Whois,
  "list"  => RetroHexChat.Commands.Handlers.List,
  "clear" => RetroHexChat.Commands.Handlers.Clear,
  "away"  => RetroHexChat.Commands.Handlers.Away,
  "quit"  => RetroHexChat.Commands.Handlers.Quit,
  "help"  => RetroHexChat.Commands.Handlers.Help,
  "ns"    => RetroHexChat.Commands.Handlers.Ns,
  "cs"    => RetroHexChat.Commands.Handlers.Cs
}
```

## Command Parser Contract

```elixir
defmodule RetroHexChat.Commands.Parser do
  @doc """
  Parse a raw input string into a command name and argument list.
  Returns {:command, name, args} for "/" commands or {:message, text}
  for regular messages.
  """
  @spec parse(String.t()) ::
    {:command, String.t(), [String.t()]}
    | {:message, String.t()}
end
```

## Command Dispatcher Contract

```elixir
defmodule RetroHexChat.Commands.Dispatcher do
  @doc """
  Dispatch a parsed command to its handler.
  Looks up the handler in the registry, validates args, then executes.
  """
  @spec dispatch(String.t(), [String.t()], Handler.context()) ::
    Handler.result()
end
```

## Dispatch Flow: Handler.execute() → LiveView → Side Effects

This contract defines how `ChatLive` consumes the result of
`Dispatcher.dispatch/3` and translates each result variant into
UI updates and side effects.

```text
User types input → ChatLive.handle_event("send_input", ...)
  │
  ├─ Parser.parse(input) → {:message, text}
  │   → Chat.Service.send_message(channel, nickname, text)
  │     → Policy check (rate limit, moderated, content length)
  │     → Persist to DB
  │     → PubSub broadcast to "channel:#{name}"
  │     → {:ok, :noop} (LiveView does nothing; PubSub handle_info renders)
  │
  └─ Parser.parse(input) → {:command, name, args}
      → Policy.pre_dispatch_check(name, context) — rate limit commands
      → Dispatcher.dispatch(name, args, context)
        │
        ├─ {:ok, :noop}
        │   → No UI action (command handled entirely server-side)
        │
        ├─ {:ok, :message, payload}
        │   → Chat.Service.send_message(channel, nick, content, :message)
        │
        ├─ {:ok, :action, payload}
        │   → Chat.Service.send_message(channel, nick, content, :action)
        │
        ├─ {:ok, :system, payload}
        │   → Chat.Service.send_system_message(channel, content)
        │
        ├─ {:ok, :join, channel_name}
        │   → Channels.Server.join(channel, nickname, password)
        │   → Subscribe to PubSub "channel:#{name}"
        │   → Track in Presence
        │   → Update assigns: add channel to list, switch active_channel
        │   → Load initial 50 messages via Chat.Queries
        │
        ├─ {:ok, :part, channel_name, message}
        │   → Channels.Server.part(channel, nickname, message)
        │   → Unsubscribe from PubSub "channel:#{name}"
        │   → Untrack from Presence for that channel
        │   → Update assigns: remove channel, switch to next channel
        │
        ├─ {:ok, :nick_change, new_nick}
        │   → Update assigns.nickname
        │   → Update Presence metadata
        │   → Broadcast nick_changed to all shared channels
        │
        ├─ {:ok, :quit, message}
        │   → Execute full disconnect cleanup (see services.md)
        │   → Redirect to ConnectLive
        │
        ├─ {:ok, :ui_action, :open_channel_list, _}
        │   → Push navigate to ChannelListLive (or open modal)
        │
        ├─ {:ok, :ui_action, :open_whois, %{nickname: nick}}
        │   → Push assign to show whois dialog component
        │
        ├─ {:ok, :ui_action, :clear_chat, _}
        │   → Reset stream for active channel (visual only)
        │
        ├─ {:ok, :ui_action, :open_query, %{nickname: nick}}
        │   → Add PM to assigns.pm_conversations
        │   → Subscribe to PubSub "pm:#{sorted_nicks}"
        │   → Switch active view to PM
        │
        ├─ {:ok, :ui_action, :show_help, %{text: help_text}}
        │   → Display help text as service message in current view
        │
        └─ {:error, message}
            → Display red error message in current chat view
            → Do NOT persist error messages to DB
```

**Key principle**: Handlers return pure data (tagged tuples). They MUST
NOT call PubSub, DB, or Presence directly. The LiveView (via Dispatcher)
is responsible for orchestrating side effects based on the result. This
keeps handlers testable as pure functions.

**Exception**: `/ns` and `/cs` handlers delegate to their respective
GenServers (NickServ, ChanServ), which encapsulate their own side effects
(DB writes, timers). The handler returns the GenServer's result to the
LiveView for UI rendering.

## Per-Command Contracts

### /join

```
Syntax: /join #channel [password]
Args: [channel_name] or [channel_name, password]
Validation: channel_name must start with #, max 50 chars, no spaces
Context required: nickname
Effects: Creates channel if not exists (user becomes operator),
         joins existing channel, subscribes to PubSub topic
Errors: "Invalid channel name", "Channel is full (+l)",
        "Channel is invite-only (+i)", "Bad channel key (+k)",
        "You are banned from this channel",
        "Maximum channel limit reached (10)"
```

### /part

```
Syntax: /part [#channel] [message]
Args: [] or [channel_name] or [channel_name, ...message_words]
Validation: If channel specified, must start with #
Context required: nickname, active_channel (fallback if no channel specified)
Effects: Removes user from channel, broadcasts part message,
         may terminate channel process if last user and unregistered
Errors: "You are not in that channel"
```

### /msg

```
Syntax: /msg <nickname> <message>
Args: [target_nickname, ...message_words]
Validation: At least 2 args (nickname + message)
Context required: nickname
Effects: Sends PM, opens PM window for recipient, persists message
Errors: "User not found", "No message specified"
```

### /query

```
Syntax: /query <nickname>
Args: [target_nickname]
Validation: Exactly 1 arg
Context required: nickname
Effects: Opens PM window in treebar (UI action, no message sent)
Errors: "User not found"
```

### /me

```
Syntax: /me <action>
Args: [...action_words]
Validation: At least 1 arg
Context required: nickname, active_channel
Effects: Broadcasts action message to current channel/PM
Errors: "No action specified"
```

### /nick

```
Syntax: /nick <new_nickname>
Args: [new_nickname]
Validation: IRC nickname rules (1-16 chars, starts with letter/special,
            no spaces)
Context required: nickname
Effects: Changes nickname everywhere, broadcasts nick change to all
         shared channels, updates Presence
Errors: "Nickname already in use", "Invalid nickname"
```

### /topic

```
Syntax: /topic [#channel] <new topic>
Args: [channel_name, ...topic_words] or [...topic_words]
Validation: Must be in channel, respect +t mode
Context required: nickname, active_channel, operator status
Effects: Changes channel topic, broadcasts topic change
Errors: "You must be a channel operator to change the topic",
        "You are not in that channel"
```

### /kick

```
Syntax: /kick #channel <nickname> [reason]
Args: [channel_name, target_nickname] or
      [channel_name, target_nickname, ...reason_words]
Validation: Must be operator in channel
Context required: nickname, operator status
Effects: Removes target from channel, broadcasts kick message
Errors: "Permission denied", "User not in channel",
        "Cannot kick yourself"
```

### /ban

```
Syntax: /ban #channel <nickname>
Args: [channel_name, target_nickname]
Validation: Must be operator in channel
Context required: nickname, operator status
Effects: Adds ban, persists for registered channels
Errors: "Permission denied", "User not in channel"
```

### /mode

```
Syntax: /mode #channel <+/-flags> [params]
Args: [channel_name, mode_string] or
      [channel_name, mode_string, ...params]
Validation: Must be operator, valid mode flags
Context required: nickname, operator status
Effects: Applies mode changes, broadcasts mode change message
Supported flags: o, v, m, i, t, k, l
Errors: "Permission denied", "Unknown mode flag",
        "Missing parameter for mode +k/+l/+o/+v"
```

### /whois

```
Syntax: /whois <nickname>
Args: [target_nickname]
Validation: Exactly 1 arg
Context required: none
Effects: Opens dialog with user info (channels, connected time, away)
Errors: "User not found"
```

### /list

```
Syntax: /list
Args: []
Validation: none
Context required: none
Effects: Opens channel list dialog (UI action)
```

### /clear

```
Syntax: /clear
Args: []
Validation: none
Context required: active_channel
Effects: Clears visual chat (UI action, no DB changes)
```

### /away

```
Syntax: /away [message]
Args: [] or [...message_words]
Validation: none
Context required: nickname
Effects: Sets/clears away status, updates Presence
```

### /quit

```
Syntax: /quit [message]
Args: [] or [...message_words]
Validation: none
Context required: nickname
Effects: Disconnects user, broadcasts quit to all channels,
         cleans up all state, shows connection dialog
```

### /help

```
Syntax: /help [command]
Args: [] or [command_name]
Validation: none
Context required: none
Effects: Shows help text (all commands or specific command)
```

### /ns (NickServ)

```
Syntax: /ns <subcommand> [args]
Subcommands: register, identify, ghost, info, drop, help
Args: [subcommand, ...subcommand_args]
Validation: Valid subcommand
Context required: nickname, identified status
Effects: Delegates to NickServ GenServer
```

### /cs (ChanServ)

```
Syntax: /cs <subcommand> [args]
Subcommands: register, drop, op, deop, voice, devoice, info, help,
             sop, aop, vop (with add/del/list sub-subcommands)
Args: [subcommand, ...subcommand_args]
Validation: Valid subcommand, user must be identified
Context required: nickname, identified status, channel membership
Effects: Delegates to ChanServ GenServer
```

## Channel Server Contract

```elixir
defmodule RetroHexChat.Channels.Server do
  @doc "Start a channel GenServer"
  @spec start_link(String.t()) :: GenServer.on_start()

  @doc "Join a user to the channel"
  @spec join(String.t(), String.t(), String.t() | nil) ::
    {:ok, map()} | {:error, String.t()}

  @doc "Remove a user from the channel"
  @spec part(String.t(), String.t(), String.t() | nil) ::
    :ok | {:error, String.t()}

  @doc "Send a message to the channel"
  @spec send_message(String.t(), String.t(), String.t(), atom()) ::
    :ok | {:error, String.t()}

  @doc "Get current channel state"
  @spec get_state(String.t()) :: {:ok, map()} | {:error, :not_found}

  @doc "Apply mode changes"
  @spec set_mode(String.t(), String.t(), String.t(), [String.t()]) ::
    :ok | {:error, String.t()}

  @doc "Kick a user from the channel"
  @spec kick(String.t(), String.t(), String.t(), String.t() | nil) ::
    :ok | {:error, String.t()}

  @doc "Ban a user from the channel"
  @spec ban(String.t(), String.t(), String.t(), String.t() | nil) ::
    :ok | {:error, String.t()}

  @doc "Set channel topic"
  @spec set_topic(String.t(), String.t(), String.t()) ::
    :ok | {:error, String.t()}
end
```

## PubSub Topic Convention

All PubSub topics follow the naming convention from Constitution VII.

| Pattern | Example | Used For |
|---------|---------|----------|
| `"channel:#{name}"` | `"channel:#elixir"` | Channel messages, joins, parts, kicks, mode changes, topic changes |
| `"pm:#{sorted_nicks}"` | `"pm:Admin:Rodrigo"` | Private messages between two users (nicks sorted alphabetically, joined with `:`) |
| `"user:#{nickname}"` | `"user:Rodrigo"` | User-scoped events: away, force_rename, service messages targeted at user |
| `"service:nickserv"` | `"service:nickserv"` | NickServ broadcast messages (global, not per-user) |
| `"service:chanserv"` | `"service:chanserv"` | ChanServ broadcast messages (global, not per-user) |

**PM topic key**: `"pm:#{Enum.sort([nick_a, nick_b]) |> Enum.join(":")}"`.
Both participants subscribe to the same topic. Nicknames (not IDs) are
used because Phase 1 has no persistent user IDs.

**Nick change and PM topics**: When a user changes nickname via `/nick`,
the LiveView MUST:
1. Unsubscribe from old PM topics (`"pm:OldNick:OtherUser"`)
2. Resubscribe to new PM topics (`"pm:NewNick:OtherUser"`)
3. The DB uses nicknames at time of send (immutable per message row)
4. Conversation history query uses both old and new nicknames

## PubSub Message Contracts

```elixir
# Channel messages (broadcast to "channel:#{name}")
%{event: "new_message", payload: %{
  channel: "#elixir",
  author: "Rodrigo",
  content: "Hello!",
  type: :message,  # :message | :action | :system | :service | :error
  timestamp: ~U[2026-02-09 12:00:00Z]
}}

# User events (broadcast to "channel:#{name}")
%{event: "user_joined", payload: %{nickname: "Rodrigo", channel: "#elixir"}}
%{event: "user_left", payload: %{nickname: "Rodrigo", channel: "#elixir", message: "Bye!"}}
%{event: "user_kicked", payload: %{nickname: "BadUser", by: "Op", channel: "#elixir", reason: "Spam"}}
%{event: "nick_changed", payload: %{old_nick: "Rodrigo", new_nick: "Rod"}}
%{event: "topic_changed", payload: %{channel: "#elixir", topic: "New topic", by: "Rodrigo"}}
%{event: "mode_changed", payload: %{channel: "#elixir", modes: "+mt", by: "Rodrigo"}}

# Private messages (broadcast to "pm:#{sorted_nicks}")
# Topic example: "pm:Admin:Rodrigo" (sorted alphabetically)
%{event: "new_pm", payload: %{
  sender: "Rodrigo",
  recipient: "Admin",
  content: "Hey!",
  type: :message,
  timestamp: ~U[2026-02-09 12:00:00Z]
}}

# User-scoped events (broadcast to "user:#{nickname}")
%{event: "away_changed", payload: %{nickname: "Rodrigo", away: true, message: "Gone for lunch"}}
%{event: "force_rename", payload: %{old_nick: "Rodrigo", new_nick: "Guest_12345", reason: "NickServ timeout"}}

# Service messages (broadcast to "user:#{target_nickname}")
# NickServ/ChanServ messages are sent to the specific target user, NOT
# to the global service topic. The global topic is reserved for future
# broadcast announcements.
%{event: "service_message", payload: %{
  service: :nickserv,
  content: "Nickname Rodrigo has been registered.",
  type: :service
}}
```
