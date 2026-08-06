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

## Focused smokes

The selective CI guard uses focused smoke targets when a JS, CSS, or web change
touches a known critical browser surface:

```bash
make e2e.smoke SURFACE=connect  # connect/register/session handoff
make e2e.smoke SURFACE=chat     # chat shell enters and renders server status
make e2e.smoke SURFACE=dialogs  # desktop windows, dialogs, Escape/close paths
make e2e.smoke SURFACE=i18n     # locale switching in the browser
make e2e.smoke SURFACE=calls    # P2P and group-call entry surfaces
make e2e.smoke SURFACE=mobile   # stacked mobile shell and task switching
```

These are local feedback gates. They are intentionally narrower than
`make e2e.headless`, and they do not replace the final `make ci` guard.

## Architecture

- Lives at the **top level** of the repo with its own `package.json`,
  isolated from `apps/retro_hex_chat_web/assets/` (where Vitest lives).
- **Each spec documents its own flows.** A `@flow` header (grouped by
  `@section`) at the top of every `tests/*.spec.ts` describes what that spec
  covers; `TEST_CATALOG.md` is an index generated from those headers by
  `scripts/catalog.mjs`. Edit the spec, then run `make e2e.catalog`. `make ci`
  fails when the index is stale, and a spec with no header is published in the
  catalog as a gap.
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
├── TEST_CATALOG.md        Generated index of covered journeys (+ hand-written rules)
├── scripts/catalog.mjs    Builds that index from the spec @flow headers
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

## Visual evidence (`E2E_SHOTS`)

**Never write a throwaway spec just to capture a screenshot.** Evidence is an
opt-in step inside the real spec:

```ts
import { shot } from "../helpers/screenshots";

await chat.openChannelList();
await shot(page, "channel-list-first-page");
await shot(chat.channelListPanel, "channel-list-end-marker"); // frame one window
```

`shot()` is a **no-op unless `E2E_SHOTS` is set**, so a spec carrying evidence
points behaves exactly like one that does not on a normal run — same timing,
same I/O, same result. Capture with:

```bash
make e2e.shots FILE=tests/chat-infinite-scroll.spec.ts
```

Files land in `e2e/screenshots/<spec>/<test>/<nn>-<name>.png`, numbered in call
order so the sequence reads as the story of the journey, and are attached to the
Playwright HTML report. The directory is gitignored — evidence is regenerated on
demand, never committed.

Why this and not `screenshot: "on"` in the config: that captures everything on
every run, which is noise plus wall clock on a 368-case serial suite. Why not a
disposable spec: it is a tool thrown away after one use, and the next person
needing the same picture writes it again.

## Adding a test

1. If the page is new, add a Page Object under `pages/`.
2. Add a spec under `tests/` using the page object.
3. Use unique data per run (see `uniqueNickname()`) so tests stay
   isolated without needing a DB reset.
4. Prefer `getByTestId`, `getByRole`, or `#id` selectors.
5. Add `shot()` calls at the states worth seeing (see above) — they cost
   nothing when `E2E_SHOTS` is unset.
