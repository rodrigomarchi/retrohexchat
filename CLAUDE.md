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
- Elixir 1.17+ / OTP 27+, JavaScript ES2020+ + Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css (npm), esbuild (027-interactive-chat-elements)
- PostgreSQL 16+ (link preview cache via ETS, channel state via GenServer — no new migrations) (027-interactive-chat-elements)
- localStorage (client-side onboarding flag) — no PostgreSQL changes (028-onboarding-empty-states)
- Elixir 1.17+ / OTP 27+ (backend), JavaScript ES2020+ (frontend) + Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css (npm), esbuild (029-contextual-tips)
- localStorage (tip seen state + global suppression) — no PostgreSQL changes (029-contextual-tips)
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, 98.css (npm), esbuild + Phoenix LiveView (streams, push_event), 98.css, existing toast component (Z2) (030-visual-feedback-unread)
- No new PostgreSQL migrations — all state is ephemeral (socket assigns, client-side) (030-visual-feedback-unread)
- No new PostgreSQL migrations — all state is ephemeral (socket assigns, client-side timers) (031-statusbar-loading-states)
- PostgreSQL 16+ (existing `user_preferences.message_settings` JSONB — no new migration), localStorage (guest preferences, DND state) (032-notification-system)
- PostgreSQL 16+ (new columns on `messages` and `private_messages` tables — 1 migration) (033-message-interactions)
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, Phoenix.Token (already in use) (034-p2p-foundation)
- PostgreSQL 16+ (1 new migration: `p2p_sessions` table) (034-p2p-foundation)
- PostgreSQL 16+ (existing `p2p_sessions` table, existing `private_messages` table — no new migrations). GenServer state for ephemeral lobby data. (035-p2p-session-ui)
- Elixir 1.17+ / OTP 27+ (backend), JavaScript ES2020+ (frontend) + Phoenix 1.8+, LiveView 1.0+, ex_stun ~> 0.1 (NEW), 98.css (036-webrtc-signaling)
- PostgreSQL 16+ (existing `p2p_sessions` table — no new migrations) (036-webrtc-signaling)
- Elixir 1.17+ / OTP 27+ (backend, minimal changes), JavaScript ES2020+ (frontend, bulk of implementation) + Phoenix 1.8+, LiveView 1.0+, 98.css (npm), existing WebRTC infrastructure (034-036) (037-p2p-file-transfer)
- No new database tables — all transfer state is ephemeral (client-side JS memory) (037-p2p-file-transfer)
- Elixir 1.17+ / OTP 27+ (backend), JavaScript ES2020+ (frontend) + Phoenix 1.8+, LiveView 1.0+, 98.css (npm), esbuild. Browser-native WebRTC APIs (getUserMedia, addTrack, replaceTrack, getStats, enumerateDevices, Picture-in-Picture). Zero new npm/Elixir dependencies. (038-audio-video-calls)
- N/A — all call state is ephemeral (LiveView assigns + JS variables). No database migrations. (038-audio-video-calls)
- Elixir 1.17+ / OTP 27+, JavaScript ES2020+ + Phoenix 1.8+, LiveView 1.0+, 98.css (npm), esbuild, ExSTUN ~> 0.1 (existing) (039-p2p-security-help-polish)
- PostgreSQL 16+ (existing `user_preferences.message_settings` JSONB — no new migrations), ETS (rate limit state) (039-p2p-security-help-polish)
- N/A — no new migrations, all state is ephemeral (socket assigns) (040-p2p-context-menus)

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
make lint                     # All static analysis (format + credo + dialyzer + JS lint)
make lint.js                  # ESLint + Prettier check on JS
make lint.js.fix              # Auto-fix ESLint + Prettier issues
make precommit                # compile + format + test
```

## CI-Equivalent Validation (MANDATORY before declaring any task complete)

The CI pipeline (`.github/workflows/ci.yml`) runs 9 checks. You MUST run ALL of them
locally before considering implementation complete. No exceptions.

**Execution strategy — compile first, then parallelize**:

1. Run `mix compile --warnings-as-errors` FIRST (all other checks depend on compilation).
2. If compilation passes, run the remaining 8 checks IN PARALLEL (use parallel Bash tool calls):
   - `mix format --check-formatted`
   - `mix credo --strict`
   - `make lint.js` (ESLint + Prettier on JS/test files)
   - `make lint.css` (inline style audit)
   - `npm test --prefix apps/retro_hex_chat_web/assets` (JS tests)
   - `mix test --include e2e`
   - `mix dialyzer`

**NEVER** skip dialyzer, E2E tests, JS tests, JS lint, or CSS lint.
If any of these 9 checks fail, the task is NOT complete.

## Code Style

- Elixir: Follow standard conventions, `mix format` enforced
- JavaScript: ESLint + Prettier enforced (`make lint.js`), auto-fix with `make lint.js.fix`
- Every public function MUST have @spec
- LiveViews MUST be thin — delegate to domain contexts
- Each "/" command is a separate Handler module
- PubSub topics: "channel:#{name}", "pm:#{sorted_ids}", "user:#{nickname}"
- Test tags: @tag :unit, @tag :integration, @tag :liveview, @tag :e2e

## CSS Architecture

### File Organization (6 layers, imported in order)
1. **Foundation**: tokens.css, utilities.css — design tokens and u-* utilities
2. **Layout & Shell**: layout.css, shell.css — app structure, toolbar, status bar, floating positions
3. **Shared Patterns**: tables.css, forms.css — reusable table/form patterns
4. **Components**: One file per independent UI widget (nicklist, tab-bar, search, etc.)
5. **Chat**: chat.css, syntax-tooltip.css, formatting.css, status-messages.css
6. **Dialogs**: dialogs.css (generic patterns) + one file per complex dialog

### File Naming
- Lowercase, hyphen-separated: `component-name.css`
- Dialog-specific files: `name-dialog.css` (e.g., `options-dialog.css`)
- No plurals (exception: `dialogs.css` for the generic framework)

### When to Create a New File
- The concern has **40+ lines** of CSS
- Maps to a specific component or group of related components
- Has its own class prefix (e.g., `.emoji-`, `.tab-`, `.nicklist-`)

### When to Add to an Existing File
- Under 40 lines and closely related to an existing file
- Minor tweak/override of parent patterns (e.g., dialog sizing tweaks stay in dialogs.css)

### Target File Size
- Sweet spot: **50–200 lines**
- Under 40 → merge into related file
- Over 250 → evaluate for splitting

### Class Naming
- Component: `.component-element` (e.g., `.nicklist-header`, `.tab-close`)
- Modifier: `--suffix` (e.g., `.tab-item--active`, `.dialog-overlay--dark`)
- Utility: `u-` prefix (e.g., `.u-flex`, `.u-text-sm`)
- Token: `--category-name` (e.g., `--color-error`, `--z-modal`)

### Import Rules
- All imports go in `app.css` only — no file imports another
- Within each layer, alphabetical order
- New component → add import in the correct layer

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
- 040-p2p-context-menus: Added Elixir 1.17+ / OTP 27+, JavaScript ES2020+ + Phoenix 1.8+, LiveView 1.0+, 98.css (npm), esbuild
- 039-p2p-security-help-polish: Added Elixir 1.17+ / OTP 27+, JavaScript ES2020+ + Phoenix 1.8+, LiveView 1.0+, 98.css (npm), esbuild, ExSTUN ~> 0.1 (existing)
- 038-audio-video-calls: Added Elixir 1.17+ / OTP 27+ (backend), JavaScript ES2020+ (frontend) + Phoenix 1.8+, LiveView 1.0+, 98.css (npm), esbuild. Browser-native WebRTC APIs (getUserMedia, addTrack, replaceTrack, getStats, enumerateDevices, Picture-in-Picture). Zero new npm/Elixir dependencies.
