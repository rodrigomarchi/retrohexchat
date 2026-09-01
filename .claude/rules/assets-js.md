---
paths:
  - "apps/retro_hex_chat_web/assets/js/**"
---

# JS hooks & bundle

JavaScript is ESLint + Prettier enforced (`make lint.js`), auto-fix with
`make lint.js.fix`. Use the repo's Prettier, never `npx prettier` — `npx` fetches a
different version that disagrees with `make format.check`:
`apps/retro_hex_chat_web/assets/node_modules/.bin/prettier --write <file>`.

There is exactly ONE hook registration pattern. A LiveSocket entrypoint imports a
single `build*Hooks()` function and passes the returned map to `LiveSocket(...)`.
No entrypoint may import individual hook implementations or define an inline hooks
object. Critical hooks are eager in `critical_hooks.js`; lazy feature hooks are
declared **only** in `lazy_feature_hooks.js`.

**Full standard:** [`docs/AGENT-GUIDE.md` §15](../../docs/AGENT-GUIDE.md) — the
readiness protocol for lazy hooks that receive server-pushed startup events, the
approved dynamic-import sites, and exactly what the CI guard rejects. **§15.1**
governs what may live *inside* a hook: a hook is a thin binding (listeners,
`handleEvent`, `pushEvent`, and creating a `lib/` controller); every decision,
calculation and state machine lives in a `lib/` module tested without LiveView.
The guard enforces a 200-line hook budget, a forbidden-primitive list, a ceiling
on `hook._private` calls in tests, and no mutable module scope in `js/lib/`.
`scripts/surface_snapshot.sh --check` pins the observable surface.

**Enforcement:** `make lint.hooks` and `make lint.bundle` are both part of
`make ci`. If the bundle budget fails, do not just raise the number: a chunk that
outgrew its budget should be split or lazy-loaded, and a budget raised without a
written rationale stops telling you anything. Overrides live in `CHUNK_OVERRIDES`
in `assets/scripts/bundle_budget.cjs` and each carries a reason. See
[`docs/reference/ci-pipeline.md`](../../docs/reference/ci-pipeline.md).

**No silent catch, and a promise counts.** Every `try/catch` in
connection/media/game JS must log or surface — no silent swallow (best-effort
audio is the sole exception). A throw inside a `.then` is the same bug wearing
a different shape: it becomes an unhandled rejection, eats the rest of the
callback, and says nothing anywhere. `log.info` does not exist — the logger is
`Object.freeze({debug, error, warn})` — and calling it inside a `.then` is
exactly how the cross-tab note came to never appear.
