# Quickstart: RetroHexChat Phase 1

**Date**: 2026-02-09
**Purpose**: Developer setup guide for running RetroHexChat locally.

## Prerequisites

- Elixir 1.17+ (`elixir --version`)
- Erlang/OTP 27+ (`erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().'`)
- PostgreSQL 16+ (`psql --version`)
- Node.js 18+ (`node --version`) — for retro design system npm install and esbuild
- Git

## Setup

```bash
# Clone the repository
git clone <repo-url> retro_hex_chat
cd retro_hex_chat

# Install Elixir dependencies
mix deps.get

# Install Node.js dependencies (for retro design system)
cd apps/retro_hex_chat_web/assets && npm install && cd ../../..

# Create and migrate the database
mix ecto.setup

# Start the development server
mix phx.server
```

Visit [`http://localhost:4000`](http://localhost:4000) — you should see
the retro-style connection dialog.

## Project Structure

```
apps/
├── retro_hex_chat/          # Domain (pure Elixir, no Phoenix deps)
│   ├── lib/retro_hex_chat/  # Bounded contexts
│   ├── priv/repo/migrations # Database migrations
│   └── test/                # Unit + integration tests
│
└── retro_hex_chat_web/      # Web layer (Phoenix + LiveView)
    ├── lib/retro_hex_chat_web/
    │   ├── live/            # LiveViews
    │   └── components/      # Function components
    ├── assets/              # CSS, JS hooks, static files
    └── test/                # LiveView tests
```

## Running Tests

```bash
# Full test suite (must complete in <60 seconds)
mix test

# Unit tests only (must complete in <10 seconds)
mix test --only unit

# Integration tests
mix test --only integration

# LiveView tests
mix test --only liveview

# Run tests in a specific context
mix test apps/retro_hex_chat/test/retro_hex_chat/channels/
```

## Static Analysis

```bash
# All three must pass with zero violations
mix format --check-formatted
mix credo --strict
mix dialyzer
```

## Key Development Patterns

### Adding a New "/" Command

1. Create `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/mycommand.ex`
2. Implement the `RetroHexChat.Commands.Handler` behaviour:
   - `execute/2` — Command logic
   - `validate/1` — Argument validation
   - `help/0` — Help text
3. Register in `RetroHexChat.Commands.Registry`
4. Write tests first (`@tag :unit`)

### Adding a New LiveView Component

1. Create `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/mycomponent.ex`
2. Use retro design system semantic HTML classes
3. Zero business logic — delegate to domain contexts
4. Write component tests with Floki

### PubSub Topics

- `"channel:#{name}"` — Channel events
- `"pm:#{sorted_nicks}"` — Private messages
- `"user:#{nickname}"` — User-scoped events
- `"service:nickserv"` / `"service:chanserv"` — Service messages

## Environment Configuration

- `dev` — Local development, verbose logging, seeded #lobby
- `test` — Async sandbox, bcrypt reduced rounds (4), no sounds
- `prod` — Production settings, release config

## Database

```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Reset (drop + create + migrate)
mix ecto.reset

# Run seeds (creates #lobby channel registration)
mix run apps/retro_hex_chat/priv/repo/seeds.exs
```

## Useful Commands

```bash
# Interactive shell with app loaded
iex -S mix

# Phoenix server in IEx
iex -S mix phx.server

# Generate a migration
mix ecto.gen.migration create_messages -r RetroHexChat.Repo
```
