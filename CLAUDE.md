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
- 007-channel-central: Added Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css
- 006-ignore-system: Added Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css
- 005-url-catcher: Added Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css, Req 0.5+ (HTTP client, already in mix.lock)
