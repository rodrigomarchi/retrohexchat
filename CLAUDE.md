# retro_hex_chat Development Guidelines

## Active Technologies
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x
- PostgreSQL 16+ (28 migrations, 29 schemas) with cursor-based pagination and GIN/trigram indexes
- 98.css (npm) for Windows 98 UI, esbuild for asset bundling
- bcrypt_elixir for password hashing, Plug.Crypto for encryption
- Req 0.5+ (HTTP client for link previews)
- In-memory: GenServer/ETS for runtime, Session structs for guests, localStorage for client state
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css (npm), esbuild (024-smart-input-command-help)
- PostgreSQL 16+ (user_preferences JSON column — no migration needed), localStorage (client-side history) (024-smart-input-command-help)
- PostgreSQL 16+ (user_preferences.key_bindings JSON column — no new migration needed) (025-shortcuts-chat-search)
- PostgreSQL 16+ (user_preferences.message_settings JSON column — no new migration needed) (026-context-menus)

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
    │   └── components/       # ~40 function components (98.css-based)
    ├── assets/               # CSS (dark-theme.css), JS hooks, static
    └── test/
```

## Commands

```bash
make help                     # Show all available Makefile targets
make setup                    # First-time setup (docker + deps + db)
make server                   # Dev server (localhost:4000)
make test                     # Full suite (excludes E2E)
make test.all                 # Full suite including E2E
make lint                     # All static analysis (format + credo + dialyzer)
make precommit                # compile + format + test
```

## CI-Equivalent Validation (MANDATORY before declaring any task complete)

The CI pipeline (`.github/workflows/ci.yml`) runs 5 checks. You MUST run ALL of them
locally before considering implementation complete. No exceptions.

**Execution strategy — compile first, then parallelize**:

1. Run `mix compile --warnings-as-errors` FIRST (all other checks depend on compilation).
2. If compilation passes, run the remaining 4 checks IN PARALLEL (use parallel Bash tool calls):
   - `mix format --check-formatted`
   - `mix credo --strict`
   - `mix test --include e2e`
   - `mix dialyzer`

**NEVER** skip dialyzer or E2E tests (E2E tests do NOT use a browser — no reason to skip).
If any of these 5 checks fail, the task is NOT complete.

## Code Style

- Elixir: Follow standard conventions, `mix format` enforced
- Every public function MUST have @spec
- LiveViews MUST be thin — delegate to domain contexts
- Each "/" command is a separate Handler module
- PubSub topics: "channel:#{name}", "pm:#{sorted_ids}", "user:#{nickname}"
- Test tags: @tag :unit, @tag :integration, @tag :liveview, @tag :e2e

## Help System (mandatory)

Every new feature MUST include corresponding help documentation:
- Add topics to `RetroHexChat.Chat.HelpTopics` (`apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`)
- New commands → add a topic in the "Commands" category
- New features → add a topic in the "Features" category
- New UI elements → add a topic in the "User Interface" category
- New keyboard shortcuts → update the "Keyboard Shortcuts" topic
- Update "See Also" cross-references in related existing topics
- The Help system is accessible via F1, Help menu > Help Topics, and `/help`

## Constitution

See `.specify/memory/constitution.md` for 11 governing principles.
Key non-negotiables: TDD, umbrella separation, OTP process architecture,
static analysis from day one, 98.css design fidelity, mandatory help documentation.


## Recent Changes
- 026-context-menus: Added Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css (npm), esbuild
- 025-shortcuts-chat-search: Added Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css (npm), esbuild
- 024-smart-input-command-help: Added Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css (npm), esbuild
