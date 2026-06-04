# retro_hex_chat Development Guidelines

## Active Technologies
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x
- PostgreSQL 16+ (39 migrations, 36 schemas) with cursor-based pagination and GIN/trigram indexes
- Tailwind CSS (`retrohex.css`) + esbuild for asset bundling
- bcrypt_elixir for password hashing, Plug.Crypto for encryption
- Req 0.5+ (HTTP client for link previews)
- In-memory: GenServer/ETS for runtime, Session structs for guests, localStorage for client state
- ExSTUN ~> 0.1 (WebRTC signaling)

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
    │   ├── live/app/          # ConnectLive, ChatLive, P2PSessionLive, etc.
    │   ├── live/chat_live/   # Shared event handlers, helpers, hooks
    │   └── components/       # UI components (ui/), icons, layouts
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

All styling uses **Tailwind CSS** via `retrohex.css` (entry point).
UI components live in `components/ui/` and use Tailwind utility classes.

### No Hardcoded Colors or CSS Values in Elixir/JS
- **NEVER** put hex colors (`#fff`, `#3a3500`) in Elixir code — colors live in CSS only
- Use Tailwind classes or CSS custom properties for dynamic values
- Inline `style=` is acceptable ONLY for dynamic `left`/`top` positioning and CSS custom properties
- `make ci` enforces `mix audit.styles --strict` through CSS lint — it must show 0 LOW, 0 MEDIUM, 0 HIGH findings
- Exception: `log_exporter.ex` embeds CSS for standalone HTML exports (must stay self-contained)

## SVG Architecture (mandatory — NO inline SVGs)

**NEVER** write inline `<svg>` tags in LiveViews, components, templates, or layouts.
All SVGs MUST live in dedicated modules. The CSS lint (`make lint.css`) enforces this.

### Icons → `RetroHexChatWeb.Icons` facade

All icons are function components in submodules under `components/icons/`:

| Submodule | Subject |
|-----------|---------|
| `Icons.People` | Users, contacts, social |
| `Icons.Communication` | Chat, channels, networking |
| `Icons.Media` | Audio, video, devices |
| `Icons.Files` | Documents, folders, clipboard |
| `Icons.Hardware` | Servers, databases, platforms |
| `Icons.Code` | Terminal, scripting, automation |
| `Icons.Security` | Locks, shields, bans |
| `Icons.Arrows` | Directional, navigation |
| `Icons.Marks` | Checkmarks, X marks, status |
| `Icons.Tools` | Settings, editing, search |
| `Icons.Alerts` | Notifications, info, warnings |
| `Icons.Symbols` | Currency, stars, misc |
| `Icons.Formatting` | Text formatting (bold, italic, etc.) — 14×14 |
| `Icons.Games` | P2P game icons — 32×32 |

**Adding a new icon:**
1. Choose submodule by **what the icon depicts** (not where it's used)
2. Add `attr :class, :string, default: nil` + `@spec` + `~H""" <svg> """`
3. Add `defdelegate` in `components/icons.ex` facade
4. Use `<Icons.icon_name />` in templates (or `<.icon_name />` if imported)

**Naming:** `icon_<name>`, `icon_btn_<name>` (buttons), `icon_dialog_<name>` (title bars), `icon_tab_<name>` (tabs), `icon_group_<name>` (32×32 groups), `icon_fmt_<name>` (formatting), `icon_game_<name>` (games)

**Sizes:** 32×32 (desktop/game), 16×16 (toolbar/tab/dialog), 14×14 (formatting)

### Diagrams → `RetroHexChatWeb.Components.Diagrams`

Complex SVG illustrations (flowcharts, architecture diagrams, mockups) go in `components/diagrams.ex`.
Same pattern: `attr :class` + `@spec` + `~H""" <svg> """`.

### Exceptions

- `log_exporter.ex` — embeds CSS/SVG for standalone HTML exports

### Catalog

See `docs/svg-catalog.md` for full inventory. Visit `/showcase/icons` (dev only) to browse all icons visually.

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
