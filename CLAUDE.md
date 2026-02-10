# retro_hex_chat Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-09

## Active Technologies
- Elixir 1.17+ / OTP 27+ + Phoenix 1.7+, Phoenix LiveView 1.0+, Ecto 3.x, (001-phase1-foundation)
- PostgreSQL 16+ via Ecto (cursor-based pagination, GIN/trigram (001-phase1-foundation)

- Elixir 1.17+ / OTP 27+ + Phoenix 1.7+, Phoenix LiveView 1.0+, Ecto 3.x (001-phase1-foundation)
- PostgreSQL 16+ with cursor-based pagination and GIN/trigram indexes
- 98.css (npm) for Windows 98 UI, esbuild for asset bundling
- bcrypt_elixir for password hashing

## Project Structure

```text
apps/
├── retro_hex_chat/           # Domain (pure Elixir, zero Phoenix deps)
│   ├── lib/retro_hex_chat/   # 7 bounded contexts: Accounts, Chat,
│   │                         # Channels, Services, Presence, Commands,
│   │                         # RateLimit
│   ├── priv/repo/migrations/
│   └── test/
└── retro_hex_chat_web/       # Web layer (Phoenix + LiveView)
    ├── lib/retro_hex_chat_web/
    │   ├── live/             # ConnectLive, ChatLive, ChannelListLive
    │   └── components/       # ~15 function components (98.css-based)
    ├── assets/               # CSS (dark-theme.css), JS hooks, static
    └── test/
```

## Commands

```bash
mix test                      # Full suite (<60s)
mix test --only unit          # Unit tests (<10s)
mix test --only integration   # Integration tests
mix test --only liveview      # LiveView tests
mix format --check-formatted  # Format check
mix credo --strict            # Lint
mix dialyzer                  # Type checking
mix ecto.setup                # Create + migrate + seed
mix phx.server                # Dev server (localhost:4000)
```

## Code Style

- Elixir: Follow standard conventions, `mix format` enforced
- Every public function MUST have @spec
- LiveViews MUST be thin — delegate to domain contexts
- Each "/" command is a separate Handler module
- PubSub topics: "channel:#{name}", "pm:#{sorted_ids}", "user:#{id}"
- Test tags: @tag :unit, @tag :integration, @tag :liveview

## Constitution

See `.specify/memory/constitution.md` for 10 governing principles.
Key non-negotiables: TDD, umbrella separation, OTP process architecture,
static analysis from day one, 98.css design fidelity.

## Recent Changes
- 001-phase1-foundation: Added Elixir 1.17+ / OTP 27+ + Phoenix 1.7+, Phoenix LiveView 1.0+, Ecto 3.x,

- 001-phase1-foundation: Full Phase 1 plan — 12 user stories, 76 FRs, 18 commands

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
