# Quickstart: P2P Foundation

**Feature**: 034-p2p-foundation | **Date**: 2026-02-16

## Prerequisites

- Elixir 1.17+ / OTP 27+ installed
- PostgreSQL 16+ running
- Project dependencies fetched (`mix deps.get`)
- Database created (`mix ecto.create`)

## Setup

```bash
# From repo root
cd apps/retro_hex_chat

# Run the new migration
mix ecto.migrate

# Verify the p2p_sessions table exists
mix run -e "RetroHexChat.Repo.query!(\"SELECT 1 FROM p2p_sessions LIMIT 0\") |> IO.inspect()"
```

## Verify OTP Processes

After starting the application, verify the P2P supervision tree is active:

```bash
# Start the server
make server

# In IEx console:
# Check P2P Registry is running
Process.whereis(RetroHexChat.P2P.SessionRegistry) |> IO.inspect()

# Check P2P Supervisor is running
Process.whereis(RetroHexChat.P2P.Supervisor) |> IO.inspect()

# Check CleanupTask is running
Process.whereis(RetroHexChat.P2P.CleanupTask) |> IO.inspect()
```

## Usage (IEx / Test)

```elixir
# Create a session between two registered users
{:ok, result} = RetroHexChat.P2P.create_session(alice_id, bob_id)
token = result.token

# Join the session as the peer
:ok = RetroHexChat.P2P.join_session(token, bob_id)

# Check session state
{:ok, info} = RetroHexChat.P2P.session_info(token)
# => %{status: "lobby", creator_id: ..., peer_id: ..., ...}

# Close the session
:ok = RetroHexChat.P2P.close_session(token, alice_id, "user_closed")
```

## Running Tests

```bash
# All P2P tests
mix test test/retro_hex_chat/p2p/ --trace

# Specific modules
mix test test/retro_hex_chat/p2p/schema/session_test.exs
mix test test/retro_hex_chat/p2p/policy_test.exs
mix test test/retro_hex_chat/p2p/session_server_test.exs
mix test test/retro_hex_chat/p2p/service_test.exs
mix test test/retro_hex_chat/p2p/cleanup_task_test.exs

# Unit tests only (fast)
mix test test/retro_hex_chat/p2p/ --only unit

# Integration tests (DB-backed)
mix test test/retro_hex_chat/p2p/ --only integration
```

## Key Modules

| Module | Purpose | Test First? |
|--------|---------|-------------|
| `P2P.Schema.Session` | Ecto schema + changesets | Yes (changeset validations) |
| `P2P.Queries` | DB operations | Yes (insert, lookup, status update) |
| `P2P.SessionToken` | Token sign/verify | Yes (sign, verify, expiry, tamper) |
| `P2P.Policy` | Authorization rules | Yes (all reject/allow scenarios) |
| `P2P.Registry` | Process lookup helpers | Yes (via_tuple, lookup) |
| `P2P.Supervisor` | DynamicSupervisor | Yes (start_child, stop_child) |
| `P2P.SessionServer` | GenServer state machine | Yes (transitions, timeouts, crash recovery) |
| `P2P.Service` | Orchestration | Yes (create, join, close flows) |
| `P2P.CleanupTask` | Periodic cleanup | Yes (stale detection, expiry) |
| `P2P` | Facade (delegates to Service) | Minimal (delegation tests) |

## Implementation Order

1. Schema + Migration (foundation — everything else depends on this)
2. Queries (DB operations for the schema)
3. SessionToken (independent, no DB dependency beyond config)
4. Policy (depends on Queries for duplicate check, IgnoreList for block check)
5. Registry + Supervisor (OTP infrastructure)
6. SessionServer (depends on Registry, Queries, PubSub)
7. Service (orchestrates all of the above)
8. CleanupTask (depends on Queries, Registry, Supervisor)
9. Facade (thin delegation layer)
10. Application.ex update (register new supervision children)
