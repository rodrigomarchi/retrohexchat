# RetroHexChat E2E Suite (Playwright)

**This suite is intentionally excluded from CI.** It exists to validate
user-facing journeys before releases, run locally and sporadically.

## When to run

- Before cutting a release
- After a refactor that touched JS hooks, the LiveView lifecycle, or any
  visible UI flow
- When `make ci` is green but you want browser-level confidence

## Quick start

```bash
make e2e.install     # first time only: npm deps + Chromium
make e2e.db.setup    # first time only: create + migrate retro_hex_chat_e2e
make e2e             # run all specs headed with slow-mo
make e2e.headless    # run all specs headless
make e2e.ui          # interactive Playwright UI mode for debugging
```

## Architecture

- Lives at the **top level** of the repo with its own `package.json`,
  isolated from `apps/retro_hex_chat_web/assets/` (where Vitest lives).
- The complete catalog of mapped and implemented journeys lives in
  `TEST_CATALOG.md`.
- Runs under **MIX_ENV=e2e** on `E2E_PORT` (default `4003`) against a dedicated
  `retro_hex_chat_e2e` Postgres database. See `config/e2e.exs`.
- Real Chromium via Playwright — exercises JS hooks, the LiveView socket,
  PubSub broadcasts, and the full request/response cycle.
- Tests use **black-box** selectors: `data-testid` first, then stable `id`
  or accessible `role`. **No Tailwind class selectors.**

## Why not in CI?

Browser-level runs are slow. CI must stay tight for tight iteration.
For regression sweeps, this suite is run manually.

## Layout

```
e2e/
├── TEST_CATALOG.md        Single source of truth for covered journeys
├── package.json
├── playwright.config.ts
├── tsconfig.json
├── pages/                 Page Object Model (selectors + high-level actions)
│   ├── ChatPage.ts
│   └── ConnectPage.ts
└── tests/                 Specs (one file per user journey)
    └── connect-flow.spec.ts
```

## Load testing (`load/`)

`load/` holds a separate harness (own config, never picked up by the
regression suite) that simulates N concurrent real-browser users against an
**already-running** server — production by default:

```bash
make load.test                                    # 20 users, 3 min, https://retrohexchat.app
LOAD_BASE_URL=http://localhost:4000 make load.test  # point at local dev
LOAD_USERS=10 LOAD_DURATION_MS=60000 make load.test # smaller run
```

Personas: chatters (message cadence under the server rate limits), idle
observers that measure end-to-end message delivery latency, virtual-space
walkers, and a group-call pair with synthetic media (real SFU load). A JSON
report with latency percentiles lands in `test-results/load-report-*.json`.

Run it from a machine that is NOT hosting the server, and watch
`/dev/dashboard` (or Grafana) on the target while it runs. Nicks are
registered with the `ldt` prefix; channels are unique per run.

## Adding a test

1. If the page is new, add a Page Object under `pages/`.
2. Add a spec under `tests/` using the page object.
3. Use unique data per run (see `uniqueNickname()`) so tests stay
   isolated without needing a DB reset.
4. Prefer `getByTestId`, `getByRole`, or `#id` selectors.
