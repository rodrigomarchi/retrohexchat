# UI Features — Progress & Learnings Log

Living log for the UI-feature implementation effort (the specs in this folder). Every
agent/iteration **must update this file** when it finishes a unit of work: move the status,
add a progress entry, and record any learning. This is the shared memory across loop
iterations — read it before starting, write to it before stopping.

- Specs: [`README.md`](README.md) · Coverage analysis: [`../ui-feature-coverage.md`](../ui-feature-coverage.md)
- Status values: `⬜ not started` · `🟦 in progress` · `✅ done` · `🚧 blocked`
- "Done" means: spec implemented **and** `make ci` green **and** help topics added/updated.

---

## Status board

| # | Feature | Priority | Status | Branch / PR | Last touched | Notes |
|---|---------|----------|--------|-------------|--------------|-------|
| 01 | Identity, Account & Presence | P0 | ⬜ | — | — | Biggest gap; status-bar widget + Account dialog |
| 02 | Buddy List (Notify) | P0 | ✅ | — | 2026-06-04 | View/toolbar entry points + status-bar badge wired |
| 03 | Bots | P0 | ✅ | — | 2026-06-04 | Tools/Options entry points + General tab toggle |
| 04 | Window & Display (Edit menu) | P1 | ⬜ | — | — | New Edit menu; Clear/Copy/Find |
| 05 | Channel Moderation | P1 | ⬜ | — | — | Status-aware context items (deop/devoice/mute) |
| 06 | Channel Membership | P1 | ⬜ | — | — | Send-invite UI + knock |
| 07 | Messaging | P2 | ⬜ | — | — | /me action toggle + send-notice |
| 08 | Scripting & Customization | P2 | ⬜ | — | — | New Timers dialog |
| 09 | Channel Configuration | P2 | ⬜ | — | — | Extend Channel Central (slow/transfer/welcome) |
| 10 | User Lookups | P3 | ⬜ | — | — | Whowas lookup + whois result card |
| 11 | ChanServ | P3 | ⬜ | — | — | Channel Central registration/access tab |
| 12 | Server Administration | P3 | ⬜ | — | — | Structured Admin Console + MOTD/broadcast |

**Suggested order:** 02 → 03 (cheap wiring wins) → 01 (highest impact) → 04 → 05 → 06 → 08 → 09 → 07 → 10 → 11 → 12.

---

## Progress log

Newest first. One entry per completed unit of work.

> _(template)_
> ### YYYY-MM-DD — Feature NN: `<short title>`
> - **Did:** what changed (files/components touched, at a high level)
> - **Tests:** what was added; `make ci` result
> - **Help docs:** topics added/updated
> - **Follow-ups:** anything deferred

### 2026-06-04 — Feature 03: `Bots`
- **Did:** added admin-only "Bot Management" launchers to the Tools menu and toolbar Options dropdown; added the General-tab Enable/Disable button using the existing `bot_toggle_enabled` event; refreshed the selected bot assign after toggling so dialog state updates immediately.
- **Tests:** added `BotManagementEntryPointsFeatureTest` for admin-only launcher visibility, `toolbar_action` dialog opening, non-admin blocking, and the General-tab toggle; added HelpTopics coverage for `ui-bot-management`. `make ci.quick` green; final `make ci` green (9/9, including dialyzer). `mix audit.styles` exited 0 but still reports existing project-wide findings outside this increment.
- **Help docs:** added `ui-bot-management` metadata/content; updated BotService, `/bot`, UI overview, and toolbar docs with Bot Management entry points and cross-references. No keyboard shortcut was added, so the keyboard shortcuts topic did not change.
- **Follow-ups:** no implementation follow-up for the completed wiring/toggle scope. Existing out-of-scope spec questions remain: delete confirmation, inline setting editing, capability config editing, per-channel toggles, and default New Bot capabilities.

### 2026-06-04 — Feature 02: `Buddy List (Notify)`
- **Did:** added View menu and toolbar Options dropdown entries for "Notify List"; added a hidden-on-mobile status-bar buddy badge that opens the Notify List when tracked users are online; passed the online-buddy count from `ChatLive`.
- **Tests:** added `NotifyListEntryPointsFeatureTest` for menu/toolbar action exposure, `toolbar_action` dispatch, status-bar badge rendering, and clickable LiveView behavior. `make ci.quick` green; final `make ci` green (9/9, including dialyzer). `mix audit.styles` exited 0 but reports existing project-wide findings outside this increment.
- **Help docs:** updated `feature-notify-list`, `ui-overview`, `ui-toolbar`, `feature-status-bar`, and HelpTopics metadata/search keywords for Notify List/status-bar discovery. No keyboard shortcut was added, so the keyboard shortcuts topic did not change.
- **Follow-ups:** none for Feature 02.

---

## Learnings log

Accumulating, reusable lessons discovered **during implementation** (gotchas, patterns,
surprises). Keep each entry one or two lines. Promote the durable ones to the project's
`Chat.HelpTopics`, `CLAUDE.md`, or the auto-memory `MEMORY.md` when broadly useful.

> _(template)_
> - **[Feature NN] <lesson>** — why it matters / how to apply next time.

- **[Feature 02] `toolbar_action` dispatches through `dispatch_to_hooks/3`** — menu/toolbar items can use existing v1 event names such as `toggle_notify_list` when a hook module already handles that event.
- **[Feature 02] Hidden dialogs keep their title text in initial HTML** — LiveView tests for dark-dialog launchers should assert action/test IDs or show-trigger presence rather than only label text.
- **[Feature 02] `mix audit.styles` is advisory in this tree** — it exits 0 while reporting unbaselined project-wide findings; `make ci` CSS lint remains the enforced gate.
- **[Feature 03] Dialog mutations should refresh selected assigns** — when an event updates the selected row in the database, assign the updated struct back to the dialog so status labels/buttons do not stay stale.
- **[Feature 03] `ToolbarApp` should mirror menu discoverability even when the compact app header is primary** — feature tests can still cover reusable toolbar Options entries with `render_component/2`.

---

## Cross-cutting reminders (do not relearn these the hard way)

- **`make ci` is the only acceptable validation** — all 9 checks must pass before a feature
  is "done". Never run checks individually. (See root `CLAUDE.md`.)
- **Help docs are mandatory** (Constitution Principle XI) — every user-facing change updates
  `Chat.HelpTopics` + cross-references before it counts as done.
- **Enhance existing components, never create parallel ones** — e.g. specs 09 & 11 extend
  Channel Central; specs 02 & 03 wire existing dialogs into menus.
- **No inline SVGs, no hardcoded colors** — icons go in `Icons.*` submodules; see
  `docs/svg-catalog.md` and `/showcase/icons`.
- **Thin LiveViews** (Principle VII) — logic lives in domain contexts, not in the LiveView.
- **Never commit without an explicit request from the user.**
