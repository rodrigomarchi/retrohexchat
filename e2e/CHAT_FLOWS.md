# Chat Flow Catalog

Persistent map of every chat-related user flow this suite covers (or plans
to). Mirrors the structure of `FLOWS.md` (auth/lifecycle) — `Status` is the
single source of truth for "what's actually green".

**Last reviewed:** 2026-05-28 (Groups A–F landed)

## Ground rules (inherited from FLOWS.md)

- **Strict black-box.** Every prerequisite is reached through the browser
  using normal user actions.
- **Self-contained isolation.** Each spec generates unique data (nicks,
  channel names, message text) so it never collides with previous runs.
- **Page Object Model.** Selectors and high-level actions live on the
  page objects (`ChatPage`, `ConnectPage`); specs read like scenarios.

## Status legend

- `done`  — spec implemented and passing
- `wip`   — implementation in progress
- `todo`  — planned, not started
- `block` — blocked on UI investigation or a product gap

## Group A — Basic messaging (single context)

| #  | Flow                                                              | Planned spec file                | Status |
|----|-------------------------------------------------------------------|----------------------------------|--------|
| A1 | Type and send a message via Enter → it appears in the message list | `tests/chat-send.spec.ts`        | done   |
| A1b| Send button click submits the message and resets the input          | `tests/chat-send.spec.ts`        | done   |
| A2 | Send button reflects textarea content: disabled → enabled → disabled | `tests/chat-send.spec.ts`        | done   |
| A3 | Character counter shows `<count>/1000` as the user types            | `tests/chat-send.spec.ts`        | done   |
| A4 | `/me dance` renders as an action-style line containing the nick     | `tests/chat-commands-basic.spec.ts` | done   |
| A5 | Switching to Status tab reveals the server welcome banner           | `tests/chat-welcome.spec.ts`     | done   |

**Product fix during Group A:**

- `CharCounterHook` now also keeps `[data-testid="chat-input-send"]`
  in sync with the textarea content. Previously the chat input had no
  `phx-change`, so the server-side `disabled={@char_count == 0}` left
  the Send button permanently disabled — the button was effectively
  dead UI and only Enter worked. Now both paths are functional and
  both are covered (A1 = Enter, A1b = button click).

## Group B — Multi-user real-time (two contexts in `#lobby`)

| #  | Flow                                                              | Planned spec file                | Status |
|----|-------------------------------------------------------------------|----------------------------------|--------|
| B1 | A sends a message → B sees it in real time in the same channel    | `tests/chat-multiuser.spec.ts`   | done   |
| B2 | B joins `#lobby` → A sees `<nick> has joined the channel`         | `tests/chat-multiuser.spec.ts`   | done   |
| B3 | B disconnects → A sees `<nick> has left` system message           | `tests/chat-multiuser.spec.ts`   | done   |
| B4 | Nicklist: B joins → A's nicklist shows B (`nicklist-item-<nick>`) | `tests/chat-multiuser.spec.ts`   | done   |

## Group C — Channels and navigation

| #  | Flow                                                              | Planned spec file                | Status |
|----|-------------------------------------------------------------------|----------------------------------|--------|
| C1 | `/join #room` creates a new tab and switches to it                | `tests/chat-channels.spec.ts`    | done   |
| C2 | Switching tabs (Status ↔ `#lobby`) preserves the message history  | `tests/chat-channels.spec.ts`    | done   |
| C3 | Close-tab button on a channel tab removes it                      | `tests/chat-channels.spec.ts`    | done   |
| C4 | `/part #room` leaves the channel and removes the tab              | `tests/chat-channels.spec.ts`    | done   |
| C5 | `/topic My new topic` updates the visible topic bar               | `tests/chat-channels.spec.ts`    | done   |

## Group D — Private messages

| #  | Flow                                                              | Planned spec file                | Status |
|----|-------------------------------------------------------------------|----------------------------------|--------|
| D1 | `/msg <bob> hi` opens a PM tab on the sender side (no focus steal — user must click) | `tests/chat-pm.spec.ts` | done   |
| D2 | Bob receives the PM in a new tab labeled with the sender nick     | `tests/chat-pm.spec.ts`          | done   |
| D3 | Bob replies on his PM tab → A's PM tab carries the reply          | `tests/chat-pm.spec.ts`          | done   |
| D4 | Closing the PM tab removes it from the tablist                    | `tests/chat-pm.spec.ts`          | done   |

**Design decision captured during D1:**

- `/msg` (and all incoming chat events) MUST NOT auto-switch the active
  tab. Sender's view stays put; the new PM tab just appears in the
  tablist. Same on the recipient's side: an indicator draws attention,
  but the user explicitly clicks to read. Captured in
  `feedback_chat_no_auto_focus_steal.md` (user memory).

## Group E — Identity & status

| #  | Flow                                                              | Planned spec file                | Status |
|----|-------------------------------------------------------------------|----------------------------------|--------|
| E1 | `/nick newname` confirms the dialog and updates the own nicklist entry | `tests/chat-identity.spec.ts`    | done   |
| E2 | `/away At lunch` then `/away` emits set/clear away status messages | `tests/chat-identity.spec.ts`    | done   |

## Group F — Help, formatting, autocomplete

| #  | Flow                                                              | Planned spec file                | Status |
|----|-------------------------------------------------------------------|----------------------------------|--------|
| F1 | `/help` lists available commands in the active message list       | `tests/chat-help.spec.ts`        | done   |
| F2 | Bold formatting button inserts the IRC bold control code          | `tests/chat-formatting.spec.ts`  | done   |
| F3 | Typing `@` in the input shows the nickname autocomplete dropdown  | `tests/chat-autocomplete.spec.ts` | done  |
| F4 | Typing `/jo` shows the command autocomplete dropdown              | `tests/chat-autocomplete.spec.ts` | done  |

## Page objects (current + planned for chat)

| Page Object              | Status | Used by              |
|--------------------------|--------|----------------------|
| `pages/ChatPage.ts`      | extend | grows as new helpers are needed per group |
| `pages/AutocompletePage.ts` | not needed | F3, F4 covered by `ChatPage` locators |

## Implementation order

Default attack plan: **A → B → C → D → E → F**. After each group: run,
update status, commit. The catalog is the contract; the order is a
suggestion that can be re-shuffled when a regression appears elsewhere.
