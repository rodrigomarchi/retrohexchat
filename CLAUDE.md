# retro_hex_chat Development Guidelines

## Active Technologies
- Elixir 1.17+ / OTP 27+ + Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x
- PostgreSQL 16+ (39 migrations, 36 schemas) with cursor-based pagination and GIN/trigram indexes
- Tailwind CSS (`retrohex.css`) + esbuild for asset bundling
- bcrypt_elixir for password hashing, Plug.Crypto for encryption
- Req 0.5+ (HTTP client for link previews)
- In-memory: GenServer/ETS for runtime, Session structs for guests, localStorage for client state
- ExSTUN ~> 0.1 (WebRTC signaling)
- PromEx exports Prometheus metrics at `/metrics`; Grafana dashboards are provisioned from the infra repo

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
    │   ├── prom_ex.ex       # PromEx plugins/dashboards for Prometheus/Grafana
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
make deploy                   # CI + deploy Sun (production) (THE standard)
make deploy.skip-ci           # Deploy Sun without CI (already validated)
```

## Git Safety

Before any direct commit or push to `main`, inspect the remote and pull first:

```bash
git fetch origin
git status --short --branch
git pull --ff-only origin main
```

If local edits are uncommitted, use `git pull --ff-only --autostash origin main`.
Only push after confirming local `main` is current.

## Deploy (MANDATORY — always use the pipeline)

**ALWAYS use `make deploy`** (or `elixir scripts/deploy_all.exs`) to deploy.
This runs the full CI pipeline first, then deploys to production (Sun).
NEVER use `make deploy-sun` directly — it skips CI validation.

```
Phase 1: CI Validation (make ci — 11 parallel checks, ~64s)
    ↓ (only if all checks pass)
Phase 2: Deploy
    └─ Sun (production) — scp + ssh deploy.sh
```

**Options:**
- `make deploy` — CI + deploy Sun (standard)
- `make deploy.skip-ci` — deploy Sun without CI (use only if CI was just run)
- `make deploy REF=some-tag` — deploy a specific git ref (default: main)

## CI-Equivalent Validation (MANDATORY before declaring any task complete)

**ALWAYS use `make ci`** (or `elixir scripts/ci.exs`) to validate code.
This is a standalone Elixir script that runs all 11 CI checks with maximum parallelism.
No other validation method is acceptable.

**Pipeline (2-stage parallel execution, 11 checks):**

```
Stage 1 (parallel):          Stage 2 (parallel, after compile):
  ├─ compile                   ├─ format
  ├─ JS lint                   ├─ credo
  ├─ JS tests                  ├─ CSS lint
  ├─ i18n tooling tests        ├─ tests (unit + integration + liveview)
  └─ i18n quality              ├─ E2E tests (separate worker)
                               └─ dialyzer
```

**Performance:** ~64s parallel vs ~104s serial (**38% faster**).
Tests are split into two parallel workers for maximum throughput.
The two i18n checks need no third-party Python packages, so they run anywhere.

**Options:**
- `make ci` — all 11 checks (standard)
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
| `Icons.Flags` | Language flags for the locale menu — 14×14 |

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

See `docs/reference/svg-catalog.md` for full inventory. Visit `/showcase/icons` (dev only) to browse all icons visually.

## i18n

`config/i18n_locales.exs` is the **single source of truth** for the supported set.
Adding or dropping a language is a one-file edit: the Makefile list, the browser
catalog exports, and the Python checkers all derive from it via
`scripts/i18n/locales.py`. Never hardcode a locale list anywhere else.

Enabled: `en` + `pt_BR, pt_PT, es, fr, de, it, nl, pl, ru, id, ja, zh_hans, zh_hant`.
All are LTR — the RTL code path is retained but currently unexercised.

### Tooling (`scripts/i18n/`)

| Module | Responsibility |
|--------|----------------|
| `locales` | the supported set, parsed from the Elixir registry |
| `protection` | masking fragments a translator must not touch |
| `quality` | guards deciding whether output is fit to ship |
| `translator` | engines behind one interface, injectable in tests |
| `pipeline` | batching and fallbacks, pure of I/O and engine choice |
| `catalogs` | all catalog filesystem access |

Keep the modules pure and the engine injected — `ScriptedTranslator` is how the
tests drive the pipeline without Argos models. Add a regression test to
`scripts/tests/` for every translation defect you find in the wild.

### Rules

- **Never `dgettext` an identifier.** Audit-log action keys (`channel.create`),
  service names, and command syntax are literals. Translating them corrupts the
  audit log, which persists whatever string it is handed.
- **A bad translation is worse than English.** The pipeline rejects output that
  loses a placeholder, keeps a sentinel, loops, or collapses, and keeps the
  source instead so a human can see it needs work.
- **Never mask fragments with markup-shaped tokens.** Models treat them as tags
  and mangle them; sentinels are bare alphanumerics (`XPH0X`).

```bash
make i18n.quality.check   # collapsed / degenerate / sentinel-leaking entries
make i18n.tooling.test    # the Python tooling suite
make i18n.repair          # re-translate unusable entries (needs the venv)
```

`make i18n.repair` needs `argostranslate polib opencc-python-reimplemented` in a
throwaway venv; everything in `make ci` runs on stdlib alone.

## Help System (mandatory)

Every new feature MUST include corresponding help documentation:
- Add topics to `RetroHexChat.Chat.HelpTopics` (`apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`)
- New commands → add a topic in the "Commands" category
- New features → add a topic in the "Features" category
- New UI elements → add a topic in the "User Interface" category
- New keyboard shortcuts → update the "Keyboard Shortcuts" topic
- Update "See Also" cross-references in related existing topics
- The Help system is accessible via F1, Help menu > Help Topics, and `/help`

## Governing Principles & Durable Guidance

See `docs/AGENT-GUIDE.md` for the 11 governing principles plus the crystallized,
hard-won engineering learnings (state tiers, command/dispatch architecture,
LiveComponent island decomposition, WebRTC/P2P, testing gotchas).
Key non-negotiables: TDD, umbrella separation, OTP process architecture,
static analysis from day one, retro design fidelity, mandatory help documentation.
