# CI pipeline, validation gates and browser E2E

Read when a check fails, when tuning partitions, when adding a check, or when you
need the browser-E2E workflow. The *rule* — `make ci` is the only completion gate —
lives in `AGENTS.md`; this file is the mechanics behind it.

The source of truth is `scripts/ci.exs` and `scripts/ci_impact.exs`. If this file
and those disagree, the scripts win and this file is the defect.

---

## The gate

**ALWAYS use `make ci`** (or `elixir scripts/ci.exs`) to validate code.
This is a standalone Elixir script that runs the complete 14-check local guard.
No other validation method is acceptable as the final gate.

`make ci.quick`, `make ci.changed`, stale tests, JS changed tests, and Playwright
smokes are iteration tools only. They are useful for short loops, but they never
replace the final `make ci` pass.

**NEVER** skip dialyzer, JS tests, JS lint, or CSS lint in final validation.
**NEVER** run checks individually or via manual parallel Bash calls — use the script.
If any check fails, the task is NOT complete.

## Pipeline (staged parallel execution, 14 checks)

```
Stage 1 (parallel):
  ├─ compile
  ├─ JS lint
  ├─ JS tests
  ├─ CI impact tests
  ├─ CI partition profile plan
  ├─ i18n tooling tests
  ├─ i18n quality
  └─ LiveView hook contract

Stage 2 (parallel, after compile):
  ├─ format
  ├─ credo
  ├─ CSS lint
  ├─ tests (mix test, partitioned)
  └─ feature tests (mix test --only liveview_feature, partitioned)

Stage 3 (isolated):
  └─ dialyzer
```

**Performance:** measured local runs are `2m20s`-`2m25s` for `make ci`
with a warm Dialyzer PLT. `make ci.serial` completed the same checks in
`5m28s`.

The normal ExUnit suite and LiveView feature suite are partitioned by default:
`CI_TEST_PARTITIONS=3`, `CI_FEATURE_PARTITIONS=4`, and
`CI_TEST_DB_POOL_SIZE=6`. Use `make ci.serial` only to diagnose
partition-specific issues. Partition/profile tooling writes reports under
`tmp/ci-partition-profile/`.
The two i18n checks need no third-party Python packages, so they run anywhere.

## Options

- `make ci` — all 14 checks (standard final gate)
- `make ci.quick` — skip dialyzer (iteration only)
- `make ci.changed CI_BASE=origin/main EXPLAIN=1` — print the diff-selected plan
- `make ci.changed CI_BASE=origin/main` — run diff-selected checks (iteration only)
- `make ci.serial` — diagnose partition-specific failures
- `make ci.partition-profile` — measure partition-count tradeoffs
- `elixir scripts/ci.exs --only compile,credo` — run specific checks only

**Coverage remains explicit:** `make ci` does not run coverage. Use
`make test.cover` or `make test.cover.all` when coverage is the requested signal,
then still finish with `make ci`.

## What `make ci` does NOT run

Two static checks live in `make lint` but are outside the 14-check gate. Knowing
which is which matters — a rule that is not in the gate is a rule the gate cannot
protect.

| Check | In `make ci`? | In `make lint`? | Selected by `ci.changed`? |
|---|---|---|---|
| `make lint.hooks` (LiveView hook contract) | **yes** | yes | yes, on JS changes |
| `make lint.bundle` (frontend bundle budget) | **no** | yes | yes, on asset changes |

`lint.bundle` is excluded from the gate because **it is currently red**: `app.js`
is over its 390kb budget, and `space_canvas_hook` and `group_call_webrtc_hook` are
over their 50kb chunk budgets. Until those are brought back under budget (or the
budgets are deliberately revised), the bundle standard is enforced by `make lint`
and by `make ci.changed` on asset diffs, not by `make ci`. Run `make lint.bundle`
before shipping anything that grows the frontend.

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
Phase 1: CI Validation (make ci — 14 checks, partitioned, ~2m20s-2m25s)
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
