# P2P API Contracts

**Feature**: 034-p2p-foundation | **Date**: 2026-02-16

These are internal Elixir module contracts (not HTTP APIs). This feature is domain-only — no web endpoints.

## RetroHexChat.P2P (Facade)

Public API for the P2P bounded context. All external callers use this module.

```elixir
@spec create_session(creator_id :: integer(), peer_id :: integer(), opts :: keyword()) ::
        {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}

@spec join_session(token :: String.t(), user_id :: integer()) ::
        :ok | {:error, String.t()}

@spec close_session(token :: String.t(), user_id :: integer(), reason :: String.t()) ::
        :ok | {:error, String.t()}

@spec get_session(token :: String.t()) ::
        {:ok, Session.t()} | {:error, :not_found}

@spec transition_status(token :: String.t(), new_status :: atom()) ::
        :ok | {:error, String.t()}

@spec session_info(token :: String.t()) ::
        {:ok, map()} | {:error, :not_found}
```

## RetroHexChat.P2P.Service

Orchestration layer — coordinates Policy, Queries, SessionServer, and PubSub.

```elixir
@spec create_session(creator_id :: integer(), peer_id :: integer(), opts :: keyword()) ::
        {:ok, %{session: Session.t(), token: String.t()}} | {:error, String.t()}

@spec join_session(token :: String.t(), user_id :: integer()) ::
        :ok | {:error, String.t()}

@spec close_session(token :: String.t(), user_id :: integer(), reason :: String.t()) ::
        :ok | {:error, String.t()}
```

### create_session/3 flow

1. `Policy.can_create?(creator_id, peer_id)` — authorization check
2. `SessionToken.sign(creator_id, peer_id)` — generate token
3. `Queries.insert_session(attrs)` — persist to DB
4. `Supervisor.start_child(token)` — start GenServer
5. `PubSub.broadcast("user:#{peer_nick}", {:p2p_invite, ...})` — notify peer
6. Return `{:ok, %{session: session, token: token}}`

### join_session/2 flow

1. `SessionToken.verify(token)` — validate token
2. `Policy.can_join?(user_id, session)` — authorization check
3. `SessionServer.join(token, user_id)` — notify GenServer (may trigger pending → lobby)

### close_session/3 flow

1. `SessionToken.verify(token)` — validate token
2. `SessionServer.close(token, user_id, reason)` — GenServer handles state transition
3. GenServer updates DB and broadcasts close event

## RetroHexChat.P2P.Policy

Authorization rules. All functions return `:ok | {:error, String.t()}`.

```elixir
@spec can_create?(creator_id :: integer(), peer_id :: integer()) ::
        :ok | {:error, String.t()}
# Checks: both registered, not self, no active session, no block/ignore

@spec can_join?(user_id :: integer(), session :: Session.t()) ::
        :ok | {:error, String.t()}
# Checks: user is creator or peer, session not in terminal state

@spec can_close?(user_id :: integer(), session :: Session.t()) ::
        :ok | {:error, String.t()}
# Checks: user is creator or peer, session not already in terminal state
```

## RetroHexChat.P2P.SessionServer

GenServer managing a single session's lifecycle.

```elixir
@spec start_link(String.t()) :: GenServer.on_start()
# Starts GenServer registered via P2P.Registry.via_tuple(token)

@spec join(String.t(), integer()) :: :ok | {:error, String.t()}
# Records peer presence, may transition pending → lobby

@spec close(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
# Transitions to closed, updates DB, broadcasts, stops process

@spec activity(String.t()) :: :ok
# Resets lobby inactivity timer

@spec get_state(String.t()) :: {:ok, map()} | {:error, :not_found}
# Returns current GenServer state for inspection

@spec transition(String.t(), atom()) :: :ok | {:error, String.t()}
# External trigger for state transitions (connecting, active)
```

### Internal messages (handle_info)

- `{:timeout, :pending_expiry}` — Expire pending session after 5 minutes
- `{:timeout, :lobby_warning}` — Send inactivity warning at 10 minutes
- `{:timeout, :lobby_expiry}` — Expire lobby session at 15 minutes
- `{:timeout, :connecting_timeout}` — Fail connecting after 30 seconds

## RetroHexChat.P2P.SessionToken

Token generation and verification.

```elixir
@spec sign(creator_id :: integer(), peer_id :: integer(), session_id :: integer()) ::
        String.t()

@spec verify(token :: String.t()) ::
        {:ok, %{creator_id: integer(), peer_id: integer(), session_id: integer()}}
        | {:error, :expired | :invalid}
```

## RetroHexChat.P2P.Queries

Database operations for p2p_sessions.

```elixir
@spec insert_session(map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}

@spec get_session_by_token(String.t()) :: Session.t() | nil

@spec get_session(integer()) :: Session.t() | nil

@spec update_status(Session.t(), String.t(), map()) ::
        {:ok, Session.t()} | {:error, Ecto.Changeset.t()}

@spec active_session_exists?(integer(), integer()) :: boolean()
# Bidirectional check: (A→B) OR (B→A) with non-terminal status

@spec list_stale_sessions(DateTime.t()) :: [Session.t()]
# Sessions in non-terminal state older than their timeout threshold

@spec expire_session(Session.t()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
```

## RetroHexChat.P2P.CleanupTask

Periodic task for stale session cleanup.

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
# Starts periodic cleanup GenServer

@spec run_cleanup() :: {:ok, non_neg_integer()}
# Manual trigger, returns count of expired sessions
```

## RetroHexChat.P2P.Supervisor

DynamicSupervisor for session processes.

```elixir
@spec start_link(keyword()) :: Supervisor.on_start()

@spec start_child(String.t()) :: DynamicSupervisor.on_start_child()
# Starts a SessionServer for the given token

@spec stop_child(pid()) :: :ok | {:error, :not_found}
```

## RetroHexChat.P2P.Registry

Registry helpers for session process lookup.

```elixir
@spec via_tuple(String.t()) :: {:via, Registry, {atom(), String.t()}}

@spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}

@spec registry_name() :: atom()
```

## PubSub Events

### Published to `"user:#{nickname}"`

```elixir
%{event: "p2p_invite", payload: %{
  token: String.t(),
  from: String.t(),        # creator nickname
  session_type: String.t() # "generic", "file_transfer", etc.
}}
```

### Published to `"p2p:#{token}"`

```elixir
# Peer joined
%{event: "p2p_peer_joined", payload: %{user_id: integer(), nickname: String.t()}}

# Inactivity warning
%{event: "p2p_inactivity_warning", payload: %{expires_in_seconds: 300}}

# Session state changed
%{event: "p2p_status_changed", payload: %{status: String.t(), reason: String.t() | nil}}

# Session closed
%{event: "p2p_session_closed", payload: %{reason: String.t(), closed_by: String.t() | nil}}
```
