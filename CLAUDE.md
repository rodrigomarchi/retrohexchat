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
make test                     # Full ExUnit suite (excludes LiveView feature tests + Playwright)
make test.all                 # ExUnit suite including LiveView feature tests
make test.stale               # Stale ExUnit loop for local iteration
make test.js.changed          # Vitest tests affected by changed JS files
make lint.js.changed          # ESLint + Prettier on changed JS assets
make lint                     # All static analysis (format + credo + dialyzer + JS lint)
make lint.js                  # ESLint + Prettier check on JS
make lint.js.fix              # Auto-fix ESLint + Prettier issues
make precommit                # compile + format + test
make ci                       # Complete local guard, 13 checks, partitioned (THE standard)
make ci.quick                 # CI without dialyzer (faster iteration)
make ci.changed               # Checks selected from git diff; use EXPLAIN=1 to inspect
make ci.serial                # Full guard with one ExUnit partition per suite
make ci.partition-profile     # Measure ExUnit partition counts
make umbrella.boundary-audit  # Measure umbrella extraction candidates
make e2e.smoke SURFACE=chat   # Focused Playwright smoke by surface
make deploy                   # CI + deploy Sun (production) (THE standard)
make deploy.skip-ci           # Deploy Sun only after CI passed on the same revision
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

**ALWAYS use `make deploy`** (or `elixir scripts/deploy_all.exs`) to deploy unless
`make ci` just passed on the exact revision being deployed. The standard target
runs the full CI pipeline first, then deploys to production (Sun).
NEVER use `make deploy-sun` directly — it skips CI validation.

```
Phase 1: CI Validation (make ci — 13 checks, partitioned, latest ~2m20s-2m25s)
    ↓ (only if all checks pass)
Phase 2: Deploy
    └─ Sun (production) — scp + ssh deploy.sh
```

**Options:**
- `make deploy` — CI + deploy Sun (standard)
- `make deploy.skip-ci` — deploy Sun without CI (use only if CI was just run on this revision)
- `make deploy REF=some-tag` — deploy a specific git ref (default: main)

## CI-Equivalent Validation (MANDATORY before declaring any task complete)

**ALWAYS use `make ci`** (or `elixir scripts/ci.exs`) to validate code.
This is a standalone Elixir script that runs the complete 13-check local guard.
No other validation method is acceptable as the final gate.

`make ci.quick`, `make ci.changed`, stale tests, JS changed tests, and Playwright
smokes are iteration tools only. They are useful for short loops, but they never
replace the final `make ci` pass.

**Pipeline (staged parallel execution, 13 checks):**

```
Stage 1 (parallel):
  ├─ compile
  ├─ JS lint
  ├─ JS tests
  ├─ CI impact tests
  ├─ CI partition profile plan
  ├─ i18n tooling tests
  └─ i18n quality

Stage 2 (parallel, after compile):
  ├─ format
  ├─ credo
  ├─ CSS lint
  ├─ tests (mix test, partitioned)
  └─ feature tests (mix test --only liveview_feature, partitioned)

Stage 3 (isolated):
  └─ dialyzer
```

**Performance:** latest measured local runs are `2m20s`-`2m25s` for `make ci`
with a warm Dialyzer PLT. `make ci.serial` completed the same 13 checks in
`5m28s`.

The normal ExUnit suite and LiveView feature suite are partitioned by default:
`CI_TEST_PARTITIONS=3`, `CI_FEATURE_PARTITIONS=4`, and
`CI_TEST_DB_POOL_SIZE=6`. Use `make ci.serial` only to diagnose
partition-specific issues. Partition/profile tooling writes reports under
`tmp/ci-partition-profile/`.
The two i18n checks need no third-party Python packages, so they run anywhere.

**Browser E2E (Playwright) is NOT part of `make ci`** — it is local only, by
design. The "feature tests" worker is `mix test --only liveview_feature`, not
Playwright. `make ci.changed` can select focused browser smokes for critical UI
surfaces, but those smokes are still local feedback, not the completion gate.

For critical UI diffs, prefer named smokes:

```bash
make e2e.smoke SURFACE=connect  # surfaces: connect, chat, dialogs, i18n, calls, mobile
make e2e.changed
make e2e.shard SHARD=1/2
```

After touching anything under `e2e/`, run that spec yourself:

```bash
MIX_ENV=e2e PGPORT=5433 mix assets.build   # skipping this serves stale CSS/JS
cd e2e && npx playwright test tests/<file>.spec.ts
```

Target a single file — never run the whole Playwright suite locally.

**Screenshots: never write a throwaway spec to capture one.** Visual evidence is
an opt-in step *inside* the real spec, via the `shot()` helper
(`e2e/helpers/screenshots.ts`). It is inert unless `E2E_SHOTS` is set, so a spec
carrying evidence points behaves exactly like one that does not on a normal run.

```bash
make e2e.shots FILE=tests/<file>.spec.ts   # → e2e/screenshots/<spec>/<test>/
```

Add `await shot(page, "state-name")` — or a `Locator` to frame one window — at
the moments worth seeing. A disposable spec deleted after the picture is a tool
thrown away; the same call left in the suite is evidence anyone can regenerate.

**Options:**
- `make ci` — all 13 checks (standard final gate)
- `make ci.quick` — skip dialyzer (iteration only)
- `make ci.changed CI_BASE=origin/main EXPLAIN=1` — print the diff-selected plan
- `make ci.changed CI_BASE=origin/main` — run diff-selected checks (iteration only)
- `make ci.serial` — diagnose partition-specific failures
- `make ci.partition-profile` — measure partition-count tradeoffs
- `elixir scripts/ci.exs --only compile,credo` — run specific checks only

**Coverage remains explicit:** `make ci` does not run coverage. Use
`make test.cover` or `make test.cover.all` when coverage is the requested signal,
then still finish with `make ci`.

**Hosted CI:** GitHub Actions is still `workflow_dispatch` while credits are
constrained. The workflow runs `Impact Plan` first, executes conditional jobs from
the same impact matrix as `make ci.changed`, and reports through the single stable
`CI Report` job for branch protection.

**Umbrella boundaries:** do not extract a new umbrella app from intuition alone.
Run `make umbrella.boundary-audit`, inspect co-change frequency plus `mix xref`
cycles, and record a short decision/RFC before any extraction.

**NEVER** skip dialyzer, JS tests, JS lint, or CSS lint in final validation.
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

There is no hand-written inventory — a list of 344 icons rots the week it is written.
The submodules under `components/icons/` **are** the catalog: grep them, or visit
`/showcase/icons` (dev only) to browse every icon visually.

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
| `glossary` | curated translations for the universal UI vocabulary |

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
- **UI labels are a glossary, not a translation task.** One- and two-word labels
  have no sentence around them, so models pick the conversational sense: "OK"
  became "Está bem.", "No" became "Numéro", "Mute" became "Mignon". Add new
  button, menu and status labels to `scripts/i18n/glossary.py` rather than
  letting the pipeline guess. `OK` stays literal everywhere except Chinese
  (`确定`/`確定`), and no label ends in a full stop.

```bash
make i18n.quality.check   # collapse / degenerate / residue / glossary drift
make i18n.tooling.test    # the Python tooling suite
make i18n.glossary        # apply the curated UI label glossary
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
