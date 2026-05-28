# E2E Flow Catalog

Persistent map of every user flow this suite covers (or plans to). Update this
file as specs land — `Status` column is the single source of truth for
"what's actually green".

**Last reviewed:** 2026-05-28 (all rounds 1–4 landed — 17/17 specs green)

## Ground rules

- **Strict black-box.** No test-only routes, no DB reset endpoints, no
  backdoors. If a spec needs pre-state, it must produce that state through
  the browser, like a real user would.
- **Self-contained isolation.** Every spec generates unique data (e.g.,
  `uniqueNickname()`) so it doesn't collide with previous runs. No DB
  reset between runs.
- **Page Object Model.** Selectors and high-level actions live in
  `pages/*.ts`. Specs read like English-language scenarios.

## Status legend

- `done`  — spec implemented and passing
- `wip`   — implementation in progress
- `todo`  — planned, not started
- `block` — blocked on UI investigation or a product gap

## Round 0 — happy path (foundation)

| # | Flow                                                | Spec file                | Status |
|---|-----------------------------------------------------|--------------------------|--------|
| A | Brand-new user registers a nickname and lands on /chat | `tests/connect-flow.spec.ts` | done   |

## Round 1 — pure UI validation (no pre-state needed)

Cheap to implement, single browser context, no fixtures.

| #  | Flow                                                          | Planned spec file                 | Status |
|----|---------------------------------------------------------------|-----------------------------------|--------|
| C1 | Empty nickname keeps the Connect button disabled              | `tests/nickname-validation.spec.ts` | done   |
| C2 | Nickname > 16 chars shows inline error                        | `tests/nickname-validation.spec.ts` | done   |
| C3 | Nickname containing a space shows inline error                | `tests/nickname-validation.spec.ts` | done   |
| C4 | Nickname starting with a digit shows inline error             | `tests/nickname-validation.spec.ts` | done   |
| E  | Register step: passwords don't match shows inline error       | `tests/register-validation.spec.ts` | done   |
| F  | Register step: password < 5 chars shows inline error          | `tests/register-validation.spec.ts` | done   |
| G  | "Back" button returns from :register/:password to :nickname   | `tests/navigation.spec.ts`        | done   |
| H  | Direct `/chat` access without session bounces to `/connect`   | `tests/chat-guard.spec.ts`        | done   |
| I  | `/connect?reason=expired` surfaces "Session expired"          | `tests/disconnect-reason.spec.ts` | done   |
| J  | `/connect?reason=disconnected` surfaces "Session ended"       | `tests/disconnect-reason.spec.ts` | done   |

## Round 2 — UI-based pre-state (register → logout → next action)

Each spec drives the full lifecycle so the prerequisite is observable in
the spec itself — no hidden fixtures.

| # | Flow                                                                  | Planned spec file              | Status |
|---|-----------------------------------------------------------------------|--------------------------------|--------|
| B | Register a nick, log out, reconnect with correct password lands on /chat | `tests/returning-user.spec.ts` | done   |
| D | Returning user: wrong password shows error, retry with correct password works | `tests/returning-user.spec.ts` | done   |
| L | Logged-in user triggers logout via UI → lands on `/connect`           | `tests/logout.spec.ts`         | done   |

**Resolved blockers:**

- **L** — logout = File menu → Disconnect → confirm dialog → push_navigate
  to `/connect` (no `?reason=` query in this flow; the reason banner is
  reserved for SessionController-driven flows like session-expired).

## Round 3 — multi-context (highest signal, replaces real PubSub coverage)

Pure browser scenarios that LiveViewTest physically cannot reproduce.

| # | Flow                                                                        | Planned spec file                 | Status |
|---|-----------------------------------------------------------------------------|-----------------------------------|--------|
| K | Same nickname connects from a second context → first context is force-disconnected with "Session ended — logged in from another window" | `tests/multi-tab-takeover.spec.ts` | done   |

## Round 4 — admin orchestration (two roles, two contexts)

Drives an admin user in one context and the affected user in another.
Uses the `TestAdmin` nick already pre-configured in `config/e2e.exs`.

| # | Flow                                                                              | Planned spec file                   | Status |
|---|-----------------------------------------------------------------------------------|-------------------------------------|--------|
| M | Admin bans user via `/admin user ban` → victim force-disconnected with "Server banned" | `tests/admin-ban.spec.ts`           | done   |
| N | Admin closes registration via `/admin server set registration closed` → new user gets "Registration is currently closed…" error (test restores `open` in finally) | `tests/admin-registration-closed.spec.ts` | done   |

**Resolved blockers:**

- **M, N** — admin actions are chat commands (`/admin user ban X`,
  `/admin server set registration closed`). The `/ban` command is
  *channel*-scoped (mode +b), not server-wide; for server bans the
  correct path is `/admin user ban`, which broadcasts
  `{:force_disconnect, ...}` on the user's PubSub topic.

## Page Objects (current + planned)

| Page Object              | Status | Used by              |
|--------------------------|--------|----------------------|
| `pages/ConnectPage.ts`   | done   | A, C1–C4, E, F, G, H, I, J, B, D, K, M, N |
| `pages/ChatPage.ts`      | todo   | B, D, L, K, M (chat-side assertions / actions like logout) |
| `pages/AdminConsole.ts`  | todo   | M, N (admin actions)  |

## Implementation order

Default attack plan: **Round 1 → Round 2 → Round 3 → Round 4**. Cheapest
specs first to grow muscle memory and Page Object Model coverage, then the
multi-context scenarios that are uniquely valuable for browser E2E.

This order can be re-shuffled — if a regression appears in Round 3/4
territory, jump there. The flow catalog is the contract; the order is a
suggestion.
