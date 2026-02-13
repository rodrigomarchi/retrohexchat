# retro_hex_chat Development Guidelines

## Active Technologies
- Elixir 1.17+ / OTP 27+ + Phoenix 1.7+, Phoenix LiveView 1.0+, 98.css (001-text-formatting-colors)
- PostgreSQL 16+ (existing schema, no migrations) (001-text-formatting-colors)
- Elixir 1.17+ / OTP 27+ + Phoenix 1.7+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css (002-notify-list)
- PostgreSQL 16+ (new `notify_list_entries` table) + in-memory Session state for guests (002-notify-list)
- PostgreSQL 16+ (new `contacts` + `nick_color_overrides` tables) + in-memory Session state for guests (003-address-book)
- PostgreSQL 16+ (new `highlight_words` table) + in-memory Session state for guests (004-highlight-mentions)
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css, Req 0.5+ (HTTP client, already in mix.lock) (005-url-catcher)
- In-memory only (socket assigns + ETS cache). No PostgreSQL changes. (005-url-catcher)
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css (006-ignore-system)
- PostgreSQL 16+ (new `ignore_list_entries` table) + in-memory Session state for guests (006-ignore-system)
- PostgreSQL 16+ (two new tables: `ban_exceptions`, `invite_exceptions`) + in-memory GenServer state extension (007-channel-central)
- PostgreSQL 16+ (existing `messages` and `private_messages` tables, read-only — no new migrations) (008-log-viewer)
- PostgreSQL 16+ (3 new tables: `perform_entries`, `autojoin_entries`, `perform_settings`) + in-memory Session state for guests + browser localStorage for reconnection (009-perform-auto-commands)
- In-memory only (socket assigns for pending invites, Session struct for auto-join preference). No PostgreSQL changes. The existing `invite_exceptions` MapSet in Channel.Server is used transiently to authorize the join. (010-channel-invite-system)
- PostgreSQL 16+ (1 new table: `notice_routing_settings`) + in-memory Session state for guests (011-notice-system)
- PostgreSQL 16+ (new `ctcp_settings` table) + in-memory Session state for guests (012-ctcp-system)
- PostgreSQL 16+ (1 new table: `flood_protection_settings`) + in-memory socket assigns for trackers (013-flood-protection)
- PostgreSQL 16+ (1 new table: `sound_settings` with JSONB columns) + in-memory Session state for guests + localStorage for mute state (014-sounds-notifications)
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css, Plug.Crypto (transitive, for password encryption) (015-favorites)
- PostgreSQL 16+ (new `favorites` table) + in-memory Session state for guests (015-favorites)
- PostgreSQL 16+ (1 new table: `user_bios`) + in-memory ETS for whowas cache + socket assigns for idle tracking (016-user-information)
- PostgreSQL 16+ (3 new tables: `aliases`, `custom_menu_items`, `autorespond_rules`) + in-memory Session state for guests + socket assigns for timers and rate limit cooldowns (018-scripting-aliases)
- PostgreSQL 16+ (1 migration: add `mode_join_throttle` column to `registered_channels` table) + in-memory GenServer state for channel modes, membership, join throttle timestamps (019-channel-features-advanced)

- Elixir 1.17+ / OTP 27+ + Phoenix 1.7+, Phoenix LiveView 1.0+, Ecto 3.x
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

See `.specify/memory/constitution.md` for 10 governing principles.
Key non-negotiables: TDD, umbrella separation, OTP process architecture,
static analysis from day one, 98.css design fidelity.

## Recent Changes
- 019-channel-features-advanced: Added Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css
- 018-scripting-aliases: Added Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css
- 018-scripting-aliases: Added [if applicable, e.g., PostgreSQL, CoreData, files or N/A]
