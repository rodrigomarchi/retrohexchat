# CI pipeline, validation gates and browser E2E

Read when a check fails, when tuning partitions, when adding a check, or when you
need the browser-E2E workflow. The *rule* — `make ci` is the only completion gate —
lives in `AGENTS.md`; this file is the mechanics behind it.

The source of truth is `scripts/ci.exs` and `scripts/ci_impact.exs`. If this file
and those disagree, the scripts win and this file is the defect.

---

## The gate

**ALWAYS use `make ci`** (or `elixir scripts/ci.exs`) to validate code.
This is a standalone Elixir script that runs the complete local guard.
The check list lives in `@full_checks` in `scripts/ci_impact.exs`; the run prints
its own total, so this file does not carry a number that would rot.
No other validation method is acceptable as the final gate.

`make ci.quick`, `make ci.changed`, stale tests, JS changed tests, and Playwright
smokes are iteration tools only. They are useful for short loops, but they never
replace the final `make ci` pass.

**NEVER** skip dialyzer, JS tests, JS lint, or CSS lint in final validation.
**NEVER** run checks individually or via manual parallel Bash calls — use the script.
If any check fails, the task is NOT complete.

## Pipeline (staged parallel execution)

```
Stage 1 (parallel):
  ├─ compile
  ├─ JS lint
  ├─ JS tests
  ├─ CI impact tests
  ├─ CI partition profile plan
  ├─ i18n tooling tests
  ├─ i18n quality
  ├─ LiveView hook contract
  ├─ Frontend bundle budget
  └─ E2E catalog sync

Stage 2 (parallel, after compile):
  ├─ format
  ├─ credo
  ├─ CSS lint
  ├─ i18n catalog coverage
  ├─ i18n catalog ready
  ├─ tests (mix test, partitioned)
  └─ feature tests (mix test --only liveview_feature, partitioned)

Stage 3 (isolated):
  └─ dialyzer
```

**Performance:** measured local runs are `2m52s`-`2m56s` for `make ci`
with a warm Dialyzer PLT. `make ci.serial` runs the same checks with one
partition per suite and takes roughly twice as long.

The normal ExUnit suite and LiveView feature suite are partitioned by default:
`CI_TEST_PARTITIONS=3`, `CI_FEATURE_PARTITIONS=4`, and
`CI_TEST_DB_POOL_SIZE=6`. Use `make ci.serial` only to diagnose
partition-specific issues. Partition/profile tooling writes reports under
`tmp/ci-partition-profile/`.
The two Python i18n checks need no third-party packages, so they run anywhere.
The third, catalog coverage, is `mix gettext.extract --check-up-to-date` and so
runs after compile: it fails when a translatable string exists in the code and
in no template, which is how sixty of them once came to render in English in
every locale.

The fourth, **catalog ready** (`make i18n.catalog.check`), asks the other half
of the question: not whether the `.pot` matches the code, but whether the
catalogues built from it are actually translated — no missing entry, no empty
one, no fuzzy leftover, no dropped placeholder, no English wearing another
locale's name. It sat red on `main` while coverage stayed green, which is how a
wave leaves drift for the next person to trip over. It is in the gate now, so
drift fails the commit that creates it.

Its first step is the one the other two could not do: every `msgid` in a `.pot`
exists in every `.po`. An entry that was never merged into a catalogue is not
empty — it does not exist — so both older checks passed while 65 strings
rendered in English in all thirteen locales.

## Options

- `make ci` — every check (standard final gate)
- `make ci.quick` — skip dialyzer (iteration only)
- `make ci.changed CI_BASE=origin/main EXPLAIN=1` — print the diff-selected plan
- `make ci.changed CI_BASE=origin/main` — run diff-selected checks (iteration only)
- `make ci.serial` — diagnose partition-specific failures
- `make ci.partition-profile` — measure partition-count tradeoffs
- `elixir scripts/ci.exs --only compile,credo` — run specific checks only

**Coverage remains explicit:** `make ci` does not run coverage. Use
`make test.cover` or `make test.cover.all` when coverage is the requested signal,
then still finish with `make ci`.

## Frontend bundle budget

`make lint.bundle` (`assets/scripts/bundle_budget.cjs`) is a stage-1 gate check.
It bundles `js/app.js` with esbuild and fails when an output exceeds its budget.

A budget is a **regression detector, not a description of today's size**. Each
number is roughly the current size plus 10% headroom, so an ordinary change passes
and a step-change has to be argued for:

| Output | Budget |
|---|---|
| `app.js` (raw / gzip) | 470kb / 130kb |
| locale chunk | 20kb |
| feature hook chunk | 50kb |
| any other async chunk | 85kb |

Two chunks carry a **named override** in `CHUNK_OVERRIDES`, because raising the
generic feature budget to fit them would let the next new hook ship at 100kb
unnoticed:

| Chunk | Budget | Why |
|---|---|---|
| `space_canvas_hook` | 120kb | isometric renderer: tile/sprite pipeline, collision, camera, animation clock |
| `group_call_webrtc_hook` | 85kb | SFU client: transport, simulcast, device management, layout engine |

**Adding an override requires a reason in the code**, not just a bigger number.
A budget raised without a rationale is a rubber stamp — it still goes green, and
it stops telling you anything. If a chunk outgrows its override, the honest moves
are to split it, lazy-load more of it, or write down why it legitimately grew.

### There is one app entry, and the measurement says keep it that way

The four surfaces that are not the chat — `/call/:token`, `/space/:slug`,
`/p2p/:token`, `/play/:game` — all load `app.js`. Whether they should get an
entry of their own was left open while they were being built, and answered by
measuring it, on 2026-08-31, from esbuild's metafile:

| Part of `app.js` | Raw bytes | Share |
|---|---|---|
| `phoenix_live_view` | 227_247 | 49.2% |
| everything the satellites also use (window manager, ui, connection, i18n, hooks) | 162_257 | 35.1% |
| **chat-only (`lib/chat` + `hooks/chat`)** | **65_852** | **14.3%** |
| — total | 461_837 | (451.0 kb raw / 103.7 kb gzip as built) |

So a `surface.js` entry would save a satellite **at most 14%** of the entry, and
only for somebody who lands on a satellite address without ever having loaded
the chat. For the common path it *costs*: these addresses are reached from the
chat's own "open in a tab", where `app.js` is already in cache and a second entry
is a fresh ~396 KB download.

**Decision: do not split.** Half the entry is LiveSocket, which every screen needs
and which is one cached URL for all of them. Revisit only if the chat-only share
grows past roughly a third — and measure again rather than assuming, because that
share is the whole argument.

**Hosted CI:** GitHub Actions is still `workflow_dispatch` while credits are
constrained. The workflow runs `Impact Plan` first, executes conditional jobs from
the same impact matrix as `make ci.changed`, and reports through the single stable
`CI Report` job for branch protection.

---

## Browser E2E (Playwright)

**Browser E2E is NOT part of `make ci`** — it is local only, by
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

### The catalog is generated from the specs

Each `e2e/tests/*.spec.ts` documents its own flows in an `@flow` header, grouped
by `@section`. `e2e/TEST_CATALOG.md` is an index built from those headers, and
**E2E catalog sync** in stage 1 fails when the two disagree.

```bash
make e2e.catalog          # regenerate the index after editing a spec header
make e2e.catalog.check    # what CI runs
```

Add or change a flow in the spec, never in the catalog. A spec with no `@flow`
header is listed in the catalog as a gap — that list exists because 23 specs were
running with no documentation at all while the catalog called itself the single
source of truth.

### Screenshots

**Never write a throwaway spec to capture one.** Visual evidence is
an opt-in step *inside* the real spec, via the `shot()` helper
(`e2e/helpers/screenshots.ts`). It is inert unless `E2E_SHOTS` is set, so a spec
carrying evidence points behaves exactly like one that does not on a normal run.

```bash
make e2e.shots FILE=tests/<file>.spec.ts   # → e2e/screenshots/<spec>/<test>/
```

Add `await shot(page, "state-name")` — or a `Locator` to frame one window — at
the moments worth seeing. A disposable spec deleted after the picture is a tool
thrown away; the same call left in the suite is evidence anyone can regenerate.

---

## Deploy

**ALWAYS use `make deploy`** (or `elixir scripts/deploy_all.exs`) to deploy unless
`make ci` just passed on the exact revision being deployed. The standard target
runs the full CI pipeline first, then deploys to production (Sun).
NEVER use `make deploy-sun` directly — it skips CI validation.

```
Phase 1: CI Validation (make ci — partitioned, ~3m)
    ↓ (only if all checks pass)
Phase 2: Deploy
    └─ Sun (production) — scp + ssh deploy.sh
```

**Options:**
- `make deploy` — CI + deploy Sun (standard)
- `make deploy.skip-ci` — deploy Sun without CI (use only if CI was just run on this revision)
- `make deploy REF=some-tag` — deploy a specific git ref (default: main)

---

## Umbrella boundaries

Do not extract a new umbrella app from intuition alone.
Run `make umbrella.boundary-audit`, inspect co-change frequency plus `mix xref`
cycles, and record a short decision/RFC before any extraction.
