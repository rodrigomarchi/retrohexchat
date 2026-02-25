# retro_hex_chat Development Guidelines

## Active Technologies
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x
- PostgreSQL 16+ (39 migrations, 36 schemas) with cursor-based pagination and GIN/trigram indexes
- Retro CSS framework, esbuild for asset bundling
- bcrypt_elixir for password hashing, Plug.Crypto for encryption
- Req 0.5+ (HTTP client for link previews)
- In-memory: GenServer/ETS for runtime, Session structs for guests, localStorage for client state
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, esbuild (024-smart-input-command-help)
- PostgreSQL 16+ (user_preferences JSON column — no migration needed), localStorage (client-side history) (024-smart-input-command-help)
- PostgreSQL 16+ (user_preferences.key_bindings JSON column — no new migration needed) (025-shortcuts-chat-search)
- PostgreSQL 16+ (user_preferences.message_settings JSON column — no new migration needed) (026-context-menus)
- Elixir 1.17+ / OTP 27+, JavaScript ES2020+ + Phoenix 1.8+, Phoenix LiveView 1.0+, esbuild (027-interactive-chat-elements)
- PostgreSQL 16+ (link preview cache via ETS, channel state via GenServer — no new migrations) (027-interactive-chat-elements)
- localStorage (client-side onboarding flag) — no PostgreSQL changes (028-onboarding-empty-states)
- Elixir 1.17+ / OTP 27+ (backend), JavaScript ES2020+ (frontend) + Phoenix 1.8+, Phoenix LiveView 1.0+, esbuild (029-contextual-tips)
- localStorage (tip seen state + global suppression) — no PostgreSQL changes (029-contextual-tips)
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, esbuild + Phoenix LiveView (streams, push_event), existing toast component (Z2) (030-visual-feedback-unread)
- No new PostgreSQL migrations — all state is ephemeral (socket assigns, client-side) (030-visual-feedback-unread)
- No new PostgreSQL migrations — all state is ephemeral (socket assigns, client-side timers) (031-statusbar-loading-states)
- PostgreSQL 16+ (existing `user_preferences.message_settings` JSONB — no new migration), localStorage (guest preferences, DND state) (032-notification-system)
- PostgreSQL 16+ (new columns on `messages` and `private_messages` tables — 1 migration) (033-message-interactions)
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, Phoenix.Token (already in use) (034-p2p-foundation)
- PostgreSQL 16+ (1 new migration: `p2p_sessions` table) (034-p2p-foundation)
- PostgreSQL 16+ (existing `p2p_sessions` table, existing `private_messages` table — no new migrations). GenServer state for ephemeral lobby data. (035-p2p-session-ui)
- Elixir 1.17+ / OTP 27+ (backend), JavaScript ES2020+ (frontend) + Phoenix 1.8+, LiveView 1.0+, ex_stun ~> 0.1 (NEW) (036-webrtc-signaling)
- PostgreSQL 16+ (existing `p2p_sessions` table — no new migrations) (036-webrtc-signaling)
- Elixir 1.17+ / OTP 27+ (backend, minimal changes), JavaScript ES2020+ (frontend, bulk of implementation) + Phoenix 1.8+, LiveView 1.0+, existing WebRTC infrastructure (034-036) (037-p2p-file-transfer)
- No new database tables — all transfer state is ephemeral (client-side JS memory) (037-p2p-file-transfer)
- Elixir 1.17+ / OTP 27+ (backend), JavaScript ES2020+ (frontend) + Phoenix 1.8+, LiveView 1.0+, esbuild. Browser-native WebRTC APIs (getUserMedia, addTrack, replaceTrack, getStats, enumerateDevices, Picture-in-Picture). Zero new npm/Elixir dependencies. (038-audio-video-calls)
- N/A — all call state is ephemeral (LiveView assigns + JS variables). No database migrations. (038-audio-video-calls)
- Elixir 1.17+ / OTP 27+, JavaScript ES2020+ + Phoenix 1.8+, LiveView 1.0+, esbuild, ExSTUN ~> 0.1 (existing) (039-p2p-security-help-polish)
- PostgreSQL 16+ (existing `user_preferences.message_settings` JSONB — no new migrations), ETS (rate limit state) (039-p2p-security-help-polish)
- N/A — no new migrations, all state is ephemeral (socket assigns) (040-p2p-context-menus)
- Elixir 1.17+ / OTP 27+, JavaScript ES2020+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, esbuild (041-session-persistence)
- PostgreSQL 16+ (existing `private_messages` table, existing `autojoin_list_entries` table — no new migrations) (041-session-persistence)

## Project Structure

```text
apps/
├── retro_hex_chat/           # Domain (pure Elixir, zero Phoenix deps)
│   ├── lib/retro_hex_chat/   # 11 bounded contexts: Accounts, Admin,
│   │                         # Bots, Channels, Chat, Commands, Config,
│   │                         # P2P, Presence, RateLimit, Services
│   ├── priv/repo/migrations/
│   └── test/
└── retro_hex_chat_web/       # Web layer (Phoenix + LiveView)
    ├── lib/retro_hex_chat_web/
    │   ├── live/             # ConnectLive, ChatLive, ChannelListLive
    │   └── components/       # ~57 function components (retro-styled)
    ├── assets/               # CSS, JS hooks, static
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
make ci                       # ALL CI checks with parallel pipeline (THE standard)
make ci.quick                 # CI without dialyzer (faster iteration)
make deploy                   # CI + deploy Sun & Moon in parallel (THE standard)
make deploy.sun               # CI + deploy Sun (production) only
make deploy.moon              # CI + deploy Moon (staging) only
make deploy.skip-ci           # Deploy both without CI (already validated)
```

## Deploy (MANDATORY — always use the pipeline)

**ALWAYS use `make deploy`** (or `elixir scripts/deploy_all.exs`) to deploy.
This runs the full CI pipeline first, then deploys to both environments in parallel.
NEVER use `make deploy-sun` / `make deploy-moon` directly — those skip CI validation.

```
Phase 1: CI Validation (make ci — 9 parallel checks, ~64s)
    ↓ (only if all checks pass)
Phase 2: Deploy (parallel)
    ├─ Sun (production) — scp + ssh deploy.sh
    └─ Moon (staging)   — scp + ssh deploy.sh
```

**Options:**
- `make deploy` — CI + deploy both (standard)
- `make deploy.sun` — CI + deploy production only
- `make deploy.moon` — CI + deploy staging only
- `make deploy.skip-ci` — deploy both without CI (use only if CI was just run)
- `make deploy REF=some-tag` — deploy a specific git ref (default: main)

## CI-Equivalent Validation (MANDATORY before declaring any task complete)

**ALWAYS use `make ci`** (or `elixir scripts/ci.exs`) to validate code.
This is a standalone Elixir script that runs all 9 CI checks with maximum parallelism.
No other validation method is acceptable.

**Pipeline (2-stage parallel execution, 9 checks):**

```
Stage 1 (parallel):        Stage 2 (parallel, after compile):
  ├─ compile                 ├─ format
  ├─ JS lint                 ├─ credo
  └─ JS tests                ├─ CSS lint
                             ├─ tests (unit + integration + liveview)
                             ├─ E2E tests (separate worker)
                             └─ dialyzer
```

**Performance:** ~64s parallel vs ~104s serial (**38% faster**).
Tests are split into two parallel workers for maximum throughput.

**Options:**
- `make ci` — all 9 checks (standard)
- `make ci.quick` — skip dialyzer (faster iteration)
- `elixir scripts/ci.exs --only compile,credo` — specific checks only

**NEVER** skip dialyzer, E2E tests, JS tests, JS lint, or CSS lint.
**NEVER** run checks individually or via manual parallel Bash calls — use the script.
If any check fails, the task is NOT complete.

## Code Style

- Elixir: Follow standard conventions, `mix format` enforced
- JavaScript: ESLint + Prettier enforced (`make lint.js`), auto-fix with `make lint.js.fix`
- Every public function MUST have @spec
- LiveViews MUST be thin — delegate to domain contexts
- Each "/" command is a separate Handler module
- PubSub topics: "channel:#{name}", "pm:#{sorted_ids}", "user:#{nickname}", "game:#{token}"
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

### No Hardcoded Colors or CSS Values in Elixir/JS
- **NEVER** put hex colors (`#fff`, `#3a3500`) in Elixir code — colors live in CSS only
- Use CSS classes (`irc-bg-4`, `highlight-bg-default`, `nick-color-3`) instead of inline `background-color` / `color`
- For dynamic values use CSS custom properties: `style={"--progress: #{percent}%"}` + CSS `width: var(--progress)`
- Inline `style=` is acceptable ONLY for dynamic `left`/`top` positioning and CSS custom properties
- Run `mix audit.styles` to verify — must show 0 LOW, 0 MEDIUM, 0 HIGH findings
- Exception: `log_exporter.ex` embeds CSS for standalone HTML exports (must stay self-contained)

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
static analysis from day one, retro design fidelity, mandatory help documentation.


## Recent Changes
- 041-session-persistence: Added Elixir 1.17+ / OTP 27+, JavaScript ES2020+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, esbuild
- 040-p2p-context-menus: Added Elixir 1.17+ / OTP 27+, JavaScript ES2020+ + Phoenix 1.8+, LiveView 1.0+, esbuild
- 039-p2p-security-help-polish: Added Elixir 1.17+ / OTP 27+, JavaScript ES2020+ + Phoenix 1.8+, LiveView 1.0+, esbuild, ExSTUN ~> 0.1 (existing)
