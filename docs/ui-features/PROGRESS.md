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
| 05 | Channel Moderation | P1 | ✅ | — | 2026-06-04 | Complete: status-aware context items, channel mute/unmute, duration prompt |
| 06 | Channel Membership | P1 | ✅ | — | 2026-06-04 | Complete: nicklist send-invite picker + Channel List knock request UI |
| 07 | Messaging | P2 | ✅ | — | 2026-06-05 | Complete: /me action toggle + Send Notice composer |
| 08 | Scripting & Customization | P2 | ✅ | — | 2026-06-05 | Complete: Timers dialog, entry points, and bare /timer launcher |
| 09 | Channel Configuration | P2 | ✅ | — | 2026-06-05 | Complete: Channel Central welcome/throttle/ownership transfer |
| 10 | User Lookups | P3 | ✅ | — | 2026-06-05 | Complete: User Lookup dialog, context Last Seen, and Whois/Whowas result cards |
| 11 | ChanServ | P3 | ✅ | — | 2026-06-05 | Complete: Channel Central registration/access tab |
| 12 | Server Administration | P3 | 🟦 | — | 2026-06-05 | First slice complete: Help → Message of the Day; structured Admin Console remains |

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

### 2026-06-05 — Feature 12: `Server Administration` MOTD menu slice
- **Did:** added the always-available Help → Message of the Day entry and wired `show_motd` through the existing `/motd` command dispatch path so the Status-tab output stays identical to typed commands.
- **Tests:** added `ServerAdministrationFeatureTest` coverage for the Help menu action, MOTD rendering via `toolbar_action`, and HelpTopics discovery/cross-references. Red phase: `make ci.quick` failed on the missing menu/action/docs, then passed after implementation. Final `make ci` green (9/9, including dialyzer).
- **Help docs:** added `ui-message-of-the-day`; updated `/motd` and Special Messages help content plus HelpTopics metadata/cross-references for the new Help menu entry.
- **Follow-ups:** Feature 12 remains in progress for the structured Admin Console tabs: Server Settings, Users, Channels, MOTD editing, Broadcast, Audit Log, TURN, Danger Zone, and Console.

### 2026-06-05 — Feature 11: `ChanServ`
- **Did:** extended Channel Central with a Registration tab after Invite Exceptions; added ChanServ registration snapshot helpers, register/drop actions, SOP/AOP/VOP sub-tabs, inline add/select/remove controls, NickServ identification gating, and role-aware access-list permissions.
- **Tests:** added `ChanServChannelCentralFeatureTest` coverage for the tab entry point, identified operator register/drop flow, unidentified disabled controls, founder AOP management, SOP access limits, and HelpTopics discovery. Red phase: `make ci.quick` failed on missing UI/docs, then passed after implementation. `mix audit.styles` exited 0 with 0 LOW/MEDIUM/HIGH findings. Final `make ci` green (9/9, including dialyzer).
- **Help docs:** added `chanserv-register`, `chanserv-access`, and `chanserv-ui`; updated ChanServ overview, `/cs`, Channel Central, HelpTopics metadata/cross-references, and SVG catalog entry for `icon_tab_registration`.
- **Follow-ups:** `/cs register` handler documentation says registration requires channel operator, but current handler code only enforces NickServ identification; Channel Central enforces operator visibility/permission and the command behavior was left unchanged.

### 2026-06-05 — Feature 10: `User Lookups`
- **Did:** added reusable User Lookup dialog and structured lookup result card; wired Tools > User Lookup, nicklist/chat Last Seen (Whowas) context actions, card footer actions, Escape dismissal, and default card output for typed `/whois` and `/whowas` with `whois_output_mode: :text` fallback.
- **Tests:** added `UserLookupFeatureTest` coverage for menu/context entry points, dialog command mapping, result-card defaults, context whowas, and HelpTopics discovery; updated existing Whois/Whowas tests for card output. Red phase: `make ci.quick` failed on the new expectations, then passed after implementation. `mix audit.styles` exited 0 with 0 LOW/MEDIUM/HIGH findings. Final `make ci` green (9/9, including dialyzer).
- **Help docs:** added `feature-user-lookup`; updated `/whois`, `/whowas`, Context Menus, Keyboard Shortcuts, and HelpTopics metadata/cross-references.
- **Follow-ups:** spec requested User menu, but the current menu bar has File/Edit/View/Tools/Help only; User Lookup was placed under Tools and the discrepancy is recorded here. No shortcut was assigned because the spec notes the candidate conflicts.

### 2026-06-05 — Feature 07: `Messaging`
- **Did:** extended the reusable ChatInput with a channel-only `*` action toggle, one-shot `/me` dispatch, inline action/notice validation, notice composer state, Escape/X cancellation, and "Send Notice..." entries in nicklist and chat nick context menus backed by `/notice`.
- **Tests:** added `MessagingUIFeatureTest` coverage for ChatInput action state, `/me` dispatch/reset, empty action errors, context-menu notice ordering, notice composer send/cancel/error behavior, and HelpTopics discovery. Red phase: `make ci.quick` failed on missing UI/docs, then passed after implementation. `mix audit.styles` exited 0 with 0 LOW/MEDIUM/HIGH findings. Final `make ci` green (9/9, including dialyzer).
- **Help docs:** updated `/me`, `/notice`, `/notice_routing`, Notices, Private Messages, Keyboard Shortcuts, and HelpTopics metadata/cross-references. Existing topic IDs were updated rather than adding duplicates.
- **Follow-ups:** none.

### 2026-06-05 — Feature 09: `Channel Configuration`
- **Did:** extended the existing Channel Central General tab with operator-only welcome message editing, operator-only join throttle controls backed by mode `+j/-j`, owner-only ownership transfer with confirmation/error handling, and refreshed owner/operator state after mutations; exposed channel welcome data through channel state projection.
- **Tests:** added `ChannelCentralFeatureTest` coverage for welcome save/clear, throttle apply/remove, non-operator read-only controls, owner transfer confirmation/validation, and HelpTopics discovery. Red phase: `make ci.quick` failed on the new expectations; after implementation, `make ci.quick` passed. `mix audit.styles` exited 0 with 0 LOW/MEDIUM/HIGH findings. Final `make ci` green (9/9, including dialyzer).
- **Help docs:** added `channel-welcome-message` and `channel-transfer-ownership`; updated `/setwelcome`, `/clearwelcome`, `/slow`, `/transfer`, `mode-j`, `channel-permissions`, and HelpTopics metadata/cross-references.
- **Follow-ups:** none.

### 2026-06-05 — Feature 08: `Scripting & Customization`
- **Did:** added the Timers dialog with active-timer table, Add/Edit/Stop controls, repeat-min validation, max-5 state, session-only note, and static Next Fire display; wired Tools menu and toolbar Options entry points with `icon_btn_timers`; changed bare `/timer` to open the dialog; reused result-returning timer helpers for typed commands and dialog events.
- **Tests:** added `TimersDialogFeatureTest` covering menu/toolbar order, bare `/timer` launcher, component empty/row/max/repeat-warning states, Add/Edit/Stop LiveView flow, and help topic discovery; updated `TimerTest` for bare `/timer`. Red phase: `make ci.quick` failed on the new expectations, then passed after implementation. `mix audit.styles` exited 0 with 0 LOW/MEDIUM/HIGH findings. Final `make ci` green (9/9, including dialyzer).
- **Help docs:** updated `/timer`, Timers, Auto Respond, Toolbar, UI overview, and HelpTopics metadata/cross-references; added `ui-timers-dialog`. Existing `cmd-timer` and `feature-timers` topic IDs were updated instead of creating duplicate timer topics.
- **Follow-ups:** none.

### 2026-06-04 — Feature 06: `Channel Membership`
- **Did:** added op-only `Invite to Channel...` to the nicklist context menu; added reusable Invite Channel Picker and Knock Request dialogs; extended Channel List rows with `+i` badges and Request Access behavior; carried `joined?`, `invite_only?`, and mode data through visible channel discovery; added result-returning invite/knock helpers so dialogs close on success and keep errors inline on failure.
- **Tests:** added `ChannelMembershipFeatureTest` covering nicklist invite visibility/order, invite picker command mapping, Channel List `+i` badge/button swap, knock dialog submit/length validation, and HelpTopics discoverability keywords. Red phase: `make ci.quick` failed on missing menu/list/dialog behavior, then passed after implementation. `mix audit.styles` exited 0 with 0 LOW/MEDIUM/HIGH findings. Final `make ci` green (9/9, including dialyzer).
- **Help docs:** updated `/invite`, `/knock`, `/join`, `/list`, Channel Invites, Invite Only mode, Channels overview, Context Menus, Toolbar, and HelpTopics metadata/cross-references. The spec names `invite_send`, `invite_receive`, and `channel_list`, but the existing help system uses `cmd-invite`, `feature-channel-invites`, and `cmd-list`; those existing topics were updated instead of creating duplicate topic IDs.
- **Follow-ups:** none.

### 2026-06-04 — Feature 05: `Channel Moderation`
- **Did:** made nicklist and chat nickname context menus status-aware for Give/Remove Voice and Give/Remove Op; added Mute/Unmute (channel) actions with a Win98-style duration prompt; exposed `channel_mutes` through channel state and projected muted flags into `channel_users`; wired `context_deop`, `context_devoice`, `context_mute`, `context_unmute`, and chat-prefixed equivalents.
- **Tests:** added `ChannelModerationContextMenuFeatureTest` covering component menu actions/labels, LiveView-derived role/mute labels, and real channel-state updates for devoice/deop/mute/unmute. Red phase: `make ci.quick` failed on missing `context_devoice` and formatting; after implementation, `make ci.quick` passed. Final `make ci` green (9/9, including dialyzer). `mix audit.styles` exited 0 with 0 LOW/MEDIUM/HIGH findings.
- **Help docs:** updated moderation command metadata and command pages for `/kick`, `/ban`, `/op`, `/deop`, `/voice`, `/devoice`, `/mute`, and `/unmute`; updated `ui-context-menu` and `feature-context-menus` with status-aware moderation and channel-mute duration behavior.
- **Follow-ups:** half-op-specific menu visibility remains deferred per spec; context-menu Unban was not added because Channel Central remains the managed ban/unban surface.

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

- **[Feature 12] MOTD tests must not delete the global cache during parallel CI** — feature tests and regular tests run concurrently in `make ci.quick`; deleting `:motd_cache` can force unrelated LiveView mounts to query Ecto outside their sandbox owner. Set cache to `:unset` instead.
- **[Feature 12] Menu affordances should dispatch through the command pipeline** — Help → Message of the Day uses `CommandDispatch.dispatch_command(..., "motd", [])`, preserving `/motd` behavior and Status-tab rendering.
- **[Feature 11] ChanServ UI should project service state through a domain snapshot** — Channel Central needs founder, viewer role, and grouped access lists together; keep that aggregation in `Services.ChanServ` so event handlers only refresh assigns.
- **[Feature 11] UI may need stricter gates than legacy command handlers** — `/cs register` help/spec says channel operator required, while the handler currently enforces identification only; apply the UI permission gate and record the handler discrepancy instead of changing command semantics opportunistically.
- **[Feature 10] Lookup UI should dispatch through `/whois` and `/whowas`** — context menus, dialog buttons, and result-card buttons can share command handlers by routing through `CommandDispatch`, while UI actions choose card vs text output.
- **[Feature 10] Specs may name a menu that does not exist in the current shell** — Feature 10 requested a User menu, but `MenuBarApp` currently exposes File/Edit/View/Tools/Help; place utility launchers under Tools and record the discrepancy instead of inventing a parallel menu.
- **[Feature 07] Input modes should dispatch through existing commands** — action and notice UI can synthesize `/me ...` and `/notice nick ...`, preserving handler validation and command-result routing instead of adding parallel send paths.
- **[Feature 07] `/notice_routing` docs must follow handler reality** — the handler ignores args and reports fixed active-window routing; update help content rather than documenting obsolete configurable modes.
- **[Feature 09] Channel Central configuration can reuse command-backed server APIs** — welcome messages, join throttle, and ownership transfer already live in `Channels.Server`; UI events should stay thin and call those APIs instead of duplicating command handlers.
- **[Feature 09] `/slow` is a user-friendly wrapper around `+j`** — the Channel Central throttle field should map seconds to `+j 5:<seconds>` and `0` to `-j`, matching the handler's count/window model.
- **[Feature 08] Timer dialogs should reuse scheduling helpers** — typed `/timer` commands and dialog saves both need to cancel old refs, clamp intervals, assign target windows, and emit system messages; keep that lifecycle in shared helpers and let events only manage dialog assigns.
- **[Feature 08] Existing timer help IDs already cover command and feature docs** — the spec asked for a Timers command topic, but this help system already has `cmd-timer` and `feature-timers`; add the new UI-specific `ui-timers-dialog` topic and update cross-references rather than duplicating command metadata.
- **[Feature 06] Channel List needs mode metadata, not just display fields** — `Autocomplete.list_visible_channels/1` originally returned only name/topic/user count; UI affordances for restricted channels need `joined?`, `invite_only?`, and modes preserved through filtering.
- **[Feature 06] Dialog-backed UI actions need result-returning helpers** — socket-only `handle_ui_action/3` is fine for typed commands, but dialogs need `{:ok, socket}` / `{:error, socket, message}` to close on success and render inline errors without duplicating server validation.
- **[Feature 06] Help spec topic keys can map to existing IDs** — Feature 06 requested `invite_send`, `invite_receive`, and `channel_list`, while this help system already models them as `cmd-invite`, `feature-channel-invites`, and `cmd-list`; update the existing topics and record the mapping.
- **[Feature 04] Specs can lag key-binding reality** — Feature 04 requested `Ctrl+F`, but `KeyBindings.defaults/0`, existing tests, and help content use `Ctrl+Shift+F`; trust code and record the discrepancy.
- **[Feature 05] Channel mutes must be part of channel state projection** — `Server.get_state/1` did not expose `channel_mutes`, so status-aware UI needed the hot-state projection updated before the menu could render Mute vs Unmute.
- **[Feature 05] UI event permissions must match command handlers** — `Server.channel_mute/4` allows half-operators, while `/mute` and `/unmute` handlers require operators; context-menu events add an operator/owner guard to avoid bypassing command semantics.
- **[Feature 05] Channel user roles are single-valued** — op and voice are represented as one current role in membership state, so tests should exercise op and voice transitions separately rather than assuming independent role flags.
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
