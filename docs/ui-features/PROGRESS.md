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
| 01 | Identity, Account & Presence | P0 | ✅ | — | 2026-06-04 | Complete: Account dialog, status widget, NickServ auth/drop/ghost, nick/profile/presence/modes |
| 02 | Buddy List (Notify) | P0 | ✅ | — | 2026-06-04 | View/toolbar entry points + status-bar badge wired |
| 03 | Bots | P0 | ✅ | — | 2026-06-04 | Tools/Options entry points + General tab toggle |
| 04 | Window & Display (Edit menu) | P1 | ✅ | — | 2026-06-04 | Complete: Edit menu Clear/Copy/Find; Find relocated from View |
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

### 2026-06-04 — Feature 04: `Window & Display (Edit menu)`
- **Did:** added the top-level Edit menu between File and View; moved Find out of View; wired Clear Window through `/clear`; added client-side Copy selection enablement/copying in `MenuBarHook`; fixed menu trigger `data-disabled` values so disabled menu triggers match the hook/CSS contract.
- **Tests:** added `WindowDisplayEditMenuFeatureTest` for menu ordering/actions, disconnected disabled state, `clear_window`, and relocated Find behavior; expanded `MenuBarHook` JS tests for Copy enablement, Clipboard API copy, and `execCommand` fallback. Final `make ci` green (9/9, including dialyzer).
- **Help docs:** added `ui-edit-menu`; updated `/clear`, Search, UI overview, Toolbar, Keyboard Shortcuts, and HelpTopics metadata/cross-references.
- **Follow-ups:** none. Shortcut note: the spec says `Ctrl+F`, but the actual key-binding code and existing docs/tests use `Ctrl+Shift+F`, so the UI/help kept `Ctrl+Shift+F`.

### 2026-06-04 — Feature 01: `Identity, Account & Presence` complete
- **Did:** completed the remaining Account dialog behavior: advanced Ghost session form mapped to `/ns ghost`, inline nickname validation before `/nick`, live bio draft counter with 200-character cap, Profile tab `/bio` view behavior, Register/Login password-change validation, and away-message reuse/clear semantics. Aligned `NicknameValidator` with the `/nick` handler rules.
- **Tests:** expanded LiveView feature coverage for Ghost errors/success, inline nickname validation, Profile-tab bio view/counter, and kept prior Account entry/auth/drop coverage. Updated unit tests for nickname validator edge cases. Final `make ci` green (9/9, including dialyzer).
- **Help docs:** updated Account Dialog, Identity & Presence, and HelpTopics keywords for Ghost, unregister/drop, nickname validation, and bio counter discovery.
- **Follow-ups:** none for Feature 01.

### 2026-06-04 — Feature 01: `Identity, Account & Presence` adaptive NickServ auth
- **Did:** made the Account dialog Register/Login tab adapt to real NickServ state, hiding invalid Register/Identify choices; added a Drop registration password form wired to `/ns drop`; exposed command-dispatch results so Account events can keep NickServ errors inline while preserving existing status output.
- **Tests:** added LiveView feature coverage for registered-nick identify-only rendering, inline bad-password feedback, and Drop registration command mapping. `make ci.quick` first failed on the new tests, then passed after implementation; final `make ci` green (9/9, including dialyzer).
- **Help docs:** updated Account Dialog and Identity & Presence help content plus help-topic keywords for Drop/unregister discovery.
- **Follow-ups:** Feature 01 remains in progress for advanced Ghost-session UI, richer nickname validation before `/nick`, and any remaining account-dialog refinements from the spec.

### 2026-06-04 — Feature 01: `Identity, Account & Presence` first slice
- **Did:** added reusable Account status-bar and Account dialog UI components, wired File-menu/status-bar entry points, and added thin `ChatLive.AccountEvents` command dispatch for register/identify, nick, bio, away, `/umode +w/-w`, and NickServ info.
- **Tests:** added `AccountEntryPointsFeatureTest` covering menu/status-bar exposure, dialog launch paths, quick away toggle, registration, and profile/presence/user-mode command mapping. `make ci.quick` green; final `make ci` green (9/9, including dialyzer).
- **Help docs:** added Account dialog and identity/presence topics; updated NickServ, `/ns`, `/nick`, `/bio`, `/away`, `/umode`, UI overview, toolbar, and status-bar cross-references.
- **Follow-ups:** Feature 01 remains in progress for the remaining spec depth beyond this slice, including any richer NickServ recovery flows, inline service-error handling, and account-dialog state refinements called out by the feature spec.

### 2026-06-04 — Feature 03: `Bots`
- **Did:** added admin-only "Bot Management" launchers to the Tools menu and toolbar Options dropdown; added the General-tab Enable/Disable button using the existing `bot_toggle_enabled` event; refreshed the selected bot assign after toggling so dialog state updates immediately.
- **Tests:** added `BotManagementEntryPointsFeatureTest` for admin-only launcher visibility, `toolbar_action` dialog opening, non-admin blocking, and the General-tab toggle; added HelpTopics coverage for `ui-bot-management`. `make ci.quick` green; final `make ci` green (9/9, including dialyzer). Cleared project-wide `mix audit.styles` LOW/MEDIUM/HIGH findings and wired strict style audit into CSS lint so `make ci` blocks regressions.
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

- **[Feature 04] Specs can lag key-binding reality** — Feature 04 requested `Ctrl+F`, but `KeyBindings.defaults/0`, existing tests, and help content use `Ctrl+Shift+F`; trust code and record the discrepancy.
- **[Feature 04] Menu trigger `data-disabled` must be a string** — `data-disabled={true}` renders as a boolean-style attribute, while `MenuBarHook` and CSS compare against `"true"`; emit `"true"`/`"false"` explicitly.
- **[Feature 04] JS-toggled visual states need CSS-owned classes** — CSS consistency lint scans `classList.*` strings in JS, so toggle a defined project class such as `menubar-copy-disabled` instead of raw Tailwind utilities.
- **[Feature 02] `toolbar_action` dispatches through `dispatch_to_hooks/3`** — menu/toolbar items can use existing v1 event names such as `toggle_notify_list` when a hook module already handles that event.
- **[Feature 02] Hidden dialogs keep their title text in initial HTML** — LiveView tests for dark-dialog launchers should assert action/test IDs or show-trigger presence rather than only label text.
- **[Feature 03] `mix audit.styles --strict` is now part of CSS lint** — `make ci` blocks LOW/MEDIUM/HIGH style audit findings; INFO findings remain diagnostic.
- **[Feature 03] Dialog mutations should refresh selected assigns** — when an event updates the selected row in the database, assign the updated struct back to the dialog so status labels/buttons do not stay stale.
- **[Feature 03] `ToolbarApp` should mirror menu discoverability even when the compact app header is primary** — feature tests can still cover reusable toolbar Options entries with `render_component/2`.
- **[Feature 01] UI is component composition, not feature-specific markup** — build reusable `components/ui/**` components and compose them in screens/dialogs; LiveViews/templates should only pass assigns and event names.
- **[Feature 01] New menu/toolbar actions need both hook lists** — `attach_all_hooks/1` handles client events, while `@event_hook_fns` powers internal `toolbar_action` dispatch through `dispatch_to_hooks/3`.
- **[Feature 01] Account auth UI must normalize against NickServ state** — menu intent is only an entry point; the dialog should derive Register/Identify/Drop availability from the current nickname registration state.
- **[Feature 01] Inline command errors can reuse command dispatch results** — returning `{socket, result}` from command dispatch lets UI flows surface service errors inline without duplicating command handlers.
- **[Feature 01] Hidden dialogs remain in rendered LiveView HTML** — tests for "not opened" dialog flows should assert missing target state/content, not absence of the dialog component's static `data-testid`.
- **[Feature 01] Domain nickname validation should match command handlers** — account/UI validation should use the same allowed first/rest character rules as `/nick`, including backtick allowed only after the first character.

---

## Cross-cutting reminders (do not relearn these the hard way)

- **`make ci` is the only acceptable validation** — all 9 checks must pass before a feature
  is "done". Never run checks individually. (See root `CLAUDE.md`.)
- **Help docs are mandatory** (Constitution Principle XI) — every user-facing change updates
  `Chat.HelpTopics` + cross-references before it counts as done.
- **Enhance existing components, never create parallel ones** — e.g. specs 09 & 11 extend
  Channel Central; specs 02 & 03 wire existing dialogs into menus.
- **No dedicated one-off UI code in feature screens** — create or extend reusable UI
  components first, then compose them from LiveView/templates with thin wiring only.
- **No inline SVGs, no hardcoded colors** — icons go in `Icons.*` submodules; see
  `docs/svg-catalog.md` and `/showcase/icons`.
- **Thin LiveViews** (Principle VII) — logic lives in domain contexts, not in the LiveView.
- **Never commit without an explicit request from the user.**
