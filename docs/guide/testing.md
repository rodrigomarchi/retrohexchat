# Testing conventions & gotchas

Read before writing or debugging tests: the flaky-suite rules, what to assert on, and the gotchas that have burned this suite.

Part of the [Agent Guide](../AGENT-GUIDE.md) (§13). Section numbers there are stable — `§13` still means this file.

---

- **`make ci` (the complete local guard) is the ONLY final validation and the
  completeness gate, not E2E and not `ci.changed`.** A task isn't done until it's fully
  green. The guard partitions the normal ExUnit suite and the LiveView feature suite by
  default (`CI_TEST_PARTITIONS=3`, `CI_FEATURE_PARTITIONS=4`,
  `CI_TEST_DB_POOL_SIZE=6`); use `make ci.serial` only to diagnose partition-specific issues. All
  warnings/failures are yours — never "pre-existing" without proof. `make ci.quick` (skips
  dialyzer) and `make ci.changed` (diff-selected checks) are for iteration only.
  Per-feature Playwright alone does NOT catch LiveViewTest/component regressions; when an
  E2E spec and a `make ci` LiveViewTest disagree, `make ci` is authoritative — the spec is
  stale.
- **Use the fast loops deliberately.** `make test.stale`, `make test.domain.stale`,
  `make test.web.stale`, `make test.failed`, `make test.js.changed SINCE=origin/main`,
  `make test.js.related FILES="js/app.js"`, `make lint.js.changed SINCE=origin/main`,
  `make e2e.changed`, `make e2e.smoke SURFACE=connect|chat|dialogs|i18n|calls|mobile`,
  `make e2e.shard SHARD=1/2`, `make ci.partition-profile`, and
  `make umbrella.boundary-audit` are local feedback tools.
  They never replace the final `make ci` gate.
- **Coverage remains explicit.** The fast `make ci` guard does not run coverage while
  partitioning the ExUnit suites; use `make test.cover` or `make test.cover.all` when
  coverage is the requested signal.
- **Hosted CI reports through one final check.** The GitHub Actions workflow remains
  manually triggered while credits are constrained, but it now runs `Impact Plan`
  first and exposes `CI Report` as the stable final status. Conditional jobs may be
  skipped by design; branch protection should require the final report check.
- **Do not extract a new umbrella app from vibes.** Run `make umbrella.boundary-audit`
  first, inspect co-change frequency and `mix xref` cycles, then write a short
  decision/RFC. Current data shows `chat` is frequent but tightly coupled to web/E2E,
  so extraction is not approved yet.
- **Critical UI diffs get browser smokes by surface.** `make ci.changed` selects focused
  Playwright smokes for known critical JS/CSS/web surfaces: connect flow, chat shell,
  dialogs/window manager, i18n, P2P/group call, and mobile layout. E2E helper/page/global
  setup changes still widen to broader E2E because the selector cannot trust one surface.
- **Never assert on async `send_update` / stream messages.** Assert on synchronous state
  (`:sys.get_state`), domain/component unit tests, or persisted data. No `sleep` / render-retry.
  (See [`liveview-islands.md` §6.3](liveview-islands.md) for the flush rule when a synchronous read is genuinely needed.)
- **Feature tests run concurrently — never mutate shared global state destructively.** Set caches
  to `:unset`/neutral values instead of deleting them (deleting `:motd_cache` forced unrelated
  mounts to query outside their Ecto sandbox owner). Accept BOTH valid values when another test
  may be flipping a global (e.g. TURN listener count).
- **Seed through the real domain context** (`AuditLogs.log/4`, `Chat.Queries`, a real registered
  nick/channel process) over parsing command text. Verify command dispatch by subscribing the
  test process to the PubSub topic, using unique message text, and asserting both inline output
  and the broadcast payload.
- **Don't execute genuinely destructive commands in feature UI tests** (nuke/purge tear down
  shared channel/bot processes) — cover the preview + invalid-confirmation path in LiveView and
  leave destructive execution to isolated command tests. Require typed-confirmation strings
  (matching the channel/server name) before dispatching.
- **Floki text extraction can leak icon text** (e.g. `#`) into label assertions — wrap visible
  labels in explicit `data-testid` spans when exact matches matter. Hidden dialogs still render
  their static markup; assert on target state/content or show-trigger presence, not on absence of
  the dialog's `data-testid`.
- Component test: `use RetroHexChatWeb.ConnCase, async: true` + `@moduletag :unit` (CI splits by
  tag; untagged tests run in the wrong worker). `@moduledoc` explaining the ownership decision
  (passthrough vs owned) + `@spec` on every public function *including* callbacks (`mount/1`,
  `update/2`, `render/1`, `handle_async/3`) and helpers (`id/0`, `open/1`, `close/1`).
- **`phx-change` is a form binding** — it does not fire on a bare `<input>`. Wrap it in a
  `<form phx-change=...>` (this was a real never-worked filter bug), or use `phx-keyup`/`keydown`.
- **State that must appear in a *focused*, value-bound input must be set before the input mounts**
  (same render it becomes visible), not in a later async action — LiveView won't patch the `value`
  of a focused input.
- **Removing dead state: grep by module/function name, not filename** ("0 refs" was false because
  only the filename was grepped). A client→server sync with no server reader is dead.
- **Baseline before blaming your change:** a spec that *passes* on your branch can't be a
  regression, so only re-run *failing* specs against a clean baseline via
  `git stash push -- <file>` → `MIX_ENV=e2e mix compile` → run → `git stash pop`. Fails on both =
  pre-existing; passes on baseline, fails on branch = real regression.
- **Connect-burst first-click race** (recurring, not a regression): `waitUntilConnected()` only
  waits for the WS handshake, which resolves before the join-render settles, so the first
  `phx-click`/menu-open after connect is eaten by the render burst. Fix with an idempotent Page
  Object helper that re-clicks if the target doesn't appear in ~2s, not scattered
  `waitForTimeout`s.
- Playwright E2E requires **`mix assets.build` first**, or it serves a stale bundle without the
  new hook.
