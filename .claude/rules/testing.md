---
paths:
  - "**/test/**"
  - "**/*_test.exs"
  - "**/*.test.js"
---

# Testing

Test tags: `@tag :unit`, `@tag :integration`, `@tag :liveview`, `@tag :e2e`.

The three rules that have cost the most time here:

- **Never assert on async `send_update` stream messages in LiveView tests.** Assert
  on synchronous state (`:sys.get_state`), domain/component unit tests, or persisted
  data. No `sleep`, no render-retry.
- **Green tests prove nothing on their own.** The RSS parser passed every unit test
  and rejected every real feed. Fetch the real thing, drive the real screen, then
  revert the fix once to confirm the test goes red.
- **A red test found is yours to fix now**, regardless of which session introduced it.

**Full playbook:** [`docs/guide/testing.md`](../../docs/guide/testing.md) — the
complete conventions and the gotchas that have burned this suite.

**Browser E2E** is local-only and never the completion gate. Target a single file,
never a whole suite: [`docs/reference/ci-pipeline.md`](../../docs/reference/ci-pipeline.md).

**A new Playwright spec documents itself.** Add an `@flow` header (under an
`@section`) describing each flow it covers, then run `make e2e.catalog` to
regenerate `e2e/TEST_CATALOG.md`. `make ci` fails if the index is stale, and a
spec with no header is published as a gap in the catalog.
