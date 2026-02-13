# API Contracts: Domain Layer

**Feature Branch**: `020-special-messages`
**Date**: 2026-02-13

## Accounts.ServerRoles (New Module)

Encapsulates server-level role checks against application configuration.

```elixir
@spec admin?(String.t(), boolean()) :: boolean()
# Returns true if nickname is in the admins config list AND identified is true.
# Returns false if not identified or not in list.

@spec server_operator?(String.t(), boolean()) :: boolean()
# Returns true if nickname is in the server_operators config list AND identified is true.
# Returns false if not identified or not in list.

@spec admin_list() :: [String.t()]
# Returns the configured list of admin nicknames.

@spec server_operator_list() :: [String.t()]
# Returns the configured list of server operator nicknames.
```

## Accounts.Session Changes

### New Fields
```elixir
@type t :: %__MODULE__{
  ...existing fields...,
  user_modes: MapSet.t(atom()),
  welcomed_channels: MapSet.t(String.t())
}
```

### New Functions
```elixir
@spec has_mode?(t(), atom()) :: boolean()
# Checks if the user has a specific mode active.
# Example: has_mode?(session, :wallops)

@spec set_mode(t(), atom()) :: t()
# Enables a user mode. Returns updated session.

@spec unset_mode(t(), atom()) :: t()
# Disables a user mode. Returns updated session.

@spec add_welcomed_channel(t(), String.t()) :: t()
# Marks a channel as having shown its welcome message this session.

@spec welcomed_channel?(t(), String.t()) :: boolean()
# Returns true if the channel's welcome was already shown this session.
```

## Services.ServerSetting (New Schema)

```elixir
@type t :: %__MODULE__{
  id: integer(),
  key: String.t(),
  value: String.t() | nil,
  updated_by: String.t() | nil,
  inserted_at: DateTime.t(),
  updated_at: DateTime.t()
}

@spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
# Validates key (required, max 50), value (optional), updated_by (max 16).
```

## Services.ChannelWelcomeMessage (New Schema)

```elixir
@type t :: %__MODULE__{
  id: integer(),
  channel_name: String.t(),
  message: String.t(),
  set_by: String.t(),
  inserted_at: DateTime.t(),
  updated_at: DateTime.t()
}

@spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
# Validates channel_name (required, max 50), message (required), set_by (required, max 16).
# Unique constraint on channel_name (upsert pattern).
```

## Services.Queries Changes

### New Functions
```elixir
# --- MOTD / Server Settings ---

@spec get_setting(String.t()) :: String.t() | nil
# Returns the value for a server setting key, or nil if not set.

@spec upsert_setting(String.t(), String.t() | nil, String.t()) ::
  {:ok, ServerSetting.t()} | {:error, Ecto.Changeset.t()}
# Inserts or updates a server setting. Third arg is updated_by nickname.

@spec delete_setting(String.t()) :: :ok
# Deletes a server setting by key. No-op if key doesn't exist.

# --- Channel Welcome Messages ---

@spec get_welcome_message(String.t()) :: ChannelWelcomeMessage.t() | nil
# Returns the welcome message for a channel, or nil.

@spec upsert_welcome_message(String.t(), String.t(), String.t()) ::
  {:ok, ChannelWelcomeMessage.t()} | {:error, Ecto.Changeset.t()}
# Sets or updates a channel's welcome message. Args: channel_name, message, set_by.

@spec delete_welcome_message(String.t()) :: :ok
# Deletes a channel's welcome message. No-op if none exists.
```

## Services.Motd (New Module)

Manages MOTD with in-memory cache for fast reads.

```elixir
@spec get() :: String.t() | nil
# Returns the current MOTD text from cache. Returns nil if no MOTD set.

@spec set(String.t(), String.t()) :: :ok | {:error, String.t()}
# Sets the MOTD text. Args: content, admin_nickname.
# Persists to DB, updates cache, broadcasts {:motd_updated, ...} to "server:settings".

@spec clear(String.t()) :: :ok
# Clears the MOTD. Args: admin_nickname.
# Deletes from DB, clears cache, broadcasts {:motd_updated, ...}.
```

## Channels.Server Changes

### Modified init
```elixir
# On init, loads welcome message from DB (via Queries.get_welcome_message/1)
# and stores in state as: welcome_message: %{message: String.t(), set_by: String.t()} | nil
```

### New Functions
```elixir
@spec set_welcome(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
# Sets the welcome message for a channel. Args: channel_name, message, set_by_nickname.
# Updates GenServer state and persists to DB.
# Broadcasts {:welcome_changed, ...} to "channel:#{channel_name}".

@spec clear_welcome(String.t(), String.t()) :: :ok | {:error, String.t()}
# Clears the welcome message. Args: channel_name, cleared_by_nickname.
# Updates GenServer state and deletes from DB.
# Broadcasts {:welcome_changed, ...} to "channel:#{channel_name}".

@spec get_welcome(String.t()) :: {:ok, %{message: String.t(), set_by: String.t()}} | {:ok, nil}
# Returns the welcome message for a channel, or nil if none set.
```

## Commands.Handler Context Changes

### Modified Type
```elixir
@type context :: %{
  nickname: String.t(),
  active_channel: String.t() | nil,
  channels: [String.t()],
  identified: boolean(),
  operator_in: [String.t()],
  half_operator_in: [String.t()],
  is_admin: boolean(),                # NEW
  is_server_operator: boolean()       # NEW
}
```

## New Command Handlers

### Commands.Handlers.SetMotd
```elixir
@spec execute([String.t()], Handler.context()) :: Handler.result()
# Args: text words joined as MOTD content.
# Requires: context.is_admin == true
# Returns: {:ok, :system, %{content: "MOTD has been updated."}}
# Errors: "Permission denied: you must be a server administrator."
#         "Usage: /setmotd <text>"

@spec validate(String.t()) :: :ok | {:error, String.t()}
@spec help() :: map()
```

### Commands.Handlers.ClearMotd
```elixir
@spec execute([String.t()], Handler.context()) :: Handler.result()
# Args: none expected.
# Requires: context.is_admin == true
# Returns: {:ok, :system, %{content: "MOTD has been cleared."}}
# Errors: "Permission denied: you must be a server administrator."

@spec validate(String.t()) :: :ok | {:error, String.t()}
@spec help() :: map()
```

### Commands.Handlers.Motd
```elixir
@spec execute([String.t()], Handler.context()) :: Handler.result()
# Args: none expected.
# No permission required — any user can read the MOTD.
# Returns: {:ok, :ui_action, :show_motd, %{content: String.t()}}
#   or:    {:ok, :system, %{content: "No MOTD has been set."}}

@spec validate(String.t()) :: :ok | {:error, String.t()}
@spec help() :: map()
```

### Commands.Handlers.SetWelcome
```elixir
@spec execute([String.t()], Handler.context()) :: Handler.result()
# Args: message words joined as welcome text.
# Requires: user is owner or operator in active_channel
# Returns: {:ok, :ui_action, :set_welcome, %{channel: String.t(), message: String.t()}}
# Errors: "Permission denied: you must be a channel operator."
#         "You must be in a channel to use this command."
#         "Usage: /setwelcome <message>"

@spec validate(String.t()) :: :ok | {:error, String.t()}
@spec help() :: map()
```

### Commands.Handlers.ClearWelcome
```elixir
@spec execute([String.t()], Handler.context()) :: Handler.result()
# Args: none expected.
# Requires: user is owner or operator in active_channel
# Returns: {:ok, :ui_action, :clear_welcome, %{channel: String.t()}}
# Errors: "Permission denied: you must be a channel operator."
#         "You must be in a channel to use this command."

@spec validate(String.t()) :: :ok | {:error, String.t()}
@spec help() :: map()
```

### Commands.Handlers.Wallops
```elixir
@spec execute([String.t()], Handler.context()) :: Handler.result()
# Args: message words joined as wallops content.
# Requires: context.is_server_operator == true OR context.is_admin == true
# Returns: {:ok, :system, %{content: "Wallops sent."}}
# Errors: "Permission denied: you must be a server operator."
#         "Usage: /wallops <message>"

@spec validate(String.t()) :: :ok | {:error, String.t()}
@spec help() :: map()
```

### Commands.Handlers.Announce
```elixir
@spec execute([String.t()], Handler.context()) :: Handler.result()
# Args: message words joined as announcement content.
# Requires: context.is_admin == true
# Returns: {:ok, :system, %{content: "Announcement sent to all users."}}
# Errors: "Permission denied: you must be a server administrator."
#         "Usage: /announce <message>"

@spec validate(String.t()) :: :ok | {:error, String.t()}
@spec help() :: map()
```

### Commands.Handlers.Umode
```elixir
@spec execute([String.t()], Handler.context()) :: Handler.result()
# Args: [mode_string] e.g. "+w", "-w"
# Returns: {:ok, :ui_action, :set_user_mode, %{mode_string: String.t()}}
# Errors: "Usage: /umode <+/-mode>"
#         "Unknown user mode: X"

@spec validate(String.t()) :: :ok | {:error, String.t()}
@spec help() :: map()
```

## Commands.Registry Changes

### New Registrations
```elixir
"setmotd"      => RetroHexChat.Commands.Handlers.SetMotd
"clearmotd"    => RetroHexChat.Commands.Handlers.ClearMotd
"motd"         => RetroHexChat.Commands.Handlers.Motd
"setwelcome"   => RetroHexChat.Commands.Handlers.SetWelcome
"clearwelcome" => RetroHexChat.Commands.Handlers.ClearWelcome
"wallops"      => RetroHexChat.Commands.Handlers.Wallops
"announce"     => RetroHexChat.Commands.Handlers.Announce
"umode"        => RetroHexChat.Commands.Handlers.Umode
```
