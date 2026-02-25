# Tasks: Notification System

**Input**: Design documents from `/specs/032-notification-system/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/liveview-events.md

**Tests**: Included — Constitution Principle IV (TDD) mandates test-first development for both Elixir and JavaScript.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Domain**: `apps/retro_hex_chat/lib/retro_hex_chat/chat/`
- **Domain tests**: `apps/retro_hex_chat/test/retro_hex_chat/chat/`
- **Web layer**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/`
- **JS lib**: `apps/retro_hex_chat_web/assets/js/lib/`
- **JS hooks**: `apps/retro_hex_chat_web/assets/js/hooks/`
- **JS tests**: `apps/retro_hex_chat_web/assets/test/`
- **CSS**: `apps/retro_hex_chat_web/assets/css/`
- **Components**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/`

---

## Phase 1: Setup

**Purpose**: Shared infrastructure needed before any user story work

- [x] T001 Add `<link rel="icon" href="/favicon.ico">` to root layout in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/layouts/root.html.heex` (favicon currently not referenced — needed for US4 favicon badge)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Domain modules and JS libraries that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

### Tests (write first, must fail)

- [x] T002 [P] Write unit tests for NotificationPreferences in `apps/retro_hex_chat/test/retro_hex_chat/chat/notification_preferences_test.exs` — test new/0 defaults, get/set for all fields (sounds_enabled, browser_notifications, title_flash_enabled, privacy_mode, dnd_enabled, trigger rules, channel_levels), set_channel_level/3 validation, remove_channel_level/2, migration from muted_channels list
- [x] T003 [P] Write unit tests for NotificationRouter in `apps/retro_hex_chat/test/retro_hex_chat/chat/notification_router_test.exs` — test should_notify?/3 for: active channel suppression, muted channel, mentions_only channel with/without highlight, DND mode (badges still count), trigger rule checks (mentions, PMs, channel_messages, joins_leaves), deduplication (mention+PM = single notification), PM always notifies
- [x] T004 [P] Write JS tests for notification_prefs.js in `apps/retro_hex_chat_web/assets/test/lib/notification_prefs.test.js` — test loadPrefs/savePrefs with localStorage, default values, merge behavior

### Implementation

- [x] T005 [P] Implement NotificationPreferences domain module in `apps/retro_hex_chat/lib/retro_hex_chat/chat/notification_preferences.ex` — new/0 with defaults from data-model.md, get/set for all 10 fields, set_channel_level/3 with validation (normal/mentions_only/mute), remove_channel_level/2, to_map/1, from_map/1 for serialization. All public functions with @spec
- [x] T006 [P] Implement NotificationRouter domain module in `apps/retro_hex_chat/lib/retro_hex_chat/chat/notification_router.ex` — should_notify?/3 takes (event_type, channel, prefs) returns {:notify, type} | :skip. Logic: check DND (skip all but badges), check active channel, check channel level, check trigger rules, deduplicate. Pure functions, no Phoenix deps. All public functions with @spec
- [x] T007 [P] Implement notification_prefs.js in `apps/retro_hex_chat_web/assets/js/lib/notification_prefs.js` — loadPrefs() reads from localStorage key `retro_hex_chat_notification_prefs`, returns defaults if missing. savePrefs(prefs) writes to localStorage. defaultPrefs() returns default notification preferences matching data-model.md
- [x] T008 Extend UserPreferences to include notifications category in `apps/retro_hex_chat/lib/retro_hex_chat/chat/user_preferences.ex` — add :notifications key to new/0, add get_notifications/1 and set_notifications/2, update persistence (save/load) to serialize notifications into message_settings JSONB, add migration logic from muted_channels to channel_levels on load. Update @spec annotations

**Checkpoint**: Foundation ready — NotificationPreferences CRUD, NotificationRouter routing logic, localStorage persistence for guests all working and tested

---

## Phase 3: User Story 1 — Notification Routing and Delivery (Priority: P1) MVP

**Goal**: Central notification dispatcher that routes events to toasts, sounds, title flash, browser notifications, and favicon badge simultaneously

**Independent Test**: Send a mention from user A to user B in a non-active channel. Verify toast appears, sound plays, title flashes, and favicon shows red dot. Verify no notification fires when the channel is active.

### Tests (write first, must fail)

- [x] T009 [P] [US1] Write JS tests for notification_dispatcher.js in `apps/retro_hex_chat_web/assets/test/lib/notification_dispatcher.test.js` — test dispatch(event, prefs, context): active channel suppression, DND skips toasts/sounds but not badges, privacy mode masks content, fan-out calls to toast/sound/title/browser/favicon, deduplication
- [x] T010 [P] [US1] Write JS tests for notification_toast.js in `apps/retro_hex_chat_web/assets/test/lib/notification_toast.test.js` — test queue management: max 3 visible, auto-dismiss after 5s, FIFO queuing, click callback, privacy mode content masking
- [x] T011 [P] [US1] Write JS tests for browser_notification.js in `apps/retro_hex_chat_web/assets/test/lib/browser_notification.test.js` — test requestPermission flow, show() with granted/denied/default states, fallback behavior, privacy mode content, never auto-request
- [x] T012 [P] [US1] Write JS tests for favicon_badge.js in `apps/retro_hex_chat_web/assets/test/lib/favicon_badge.test.js` — test show() draws red dot overlay, clear() restores original, persistence across calls, handles missing favicon link gracefully
- [x] T013 [P] [US1] Write JS hook tests for notification_dispatcher_hook in `apps/retro_hex_chat_web/assets/test/hooks/notification_dispatcher_hook.test.js` — test mounted() registers event handlers, handleEvent("notify") calls dispatcher, handleEvent("notification_batch") shows summary toast, destroyed() cleans up
- [x] T014 [P] [US1] Write Elixir integration test for notification push events in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/notification_test.exs` — test that receiving a channel message with mention in a non-active channel triggers push_event("notify") with correct payload, and that active channel messages do NOT trigger push_event("notify")

### Implementation

- [x] T015 [P] [US1] Implement notification_dispatcher.js in `apps/retro_hex_chat_web/assets/js/lib/notification_dispatcher.js` — createDispatcher(deps) factory that receives sound/titleFlash/favicon/toast/browserNotif dependencies. dispatch(event, prefs, context) checks DND, active channel, channel level, trigger rules, then calls enabled output channels. Handles dedup. Privacy mode content masking
- [x] T016 [P] [US1] Implement notification_toast.js in `apps/retro_hex_chat_web/assets/js/lib/notification_toast.js` — createNotificationToastManager() with show(toast), queue management (max 3 visible), auto-dismiss (5s), click-to-navigate callback, summary toast for batches. Reuses toast.js DOM builders (createToastElement, animateIn, animateOut)
- [x] T017 [P] [US1] Implement browser_notification.js in `apps/retro_hex_chat_web/assets/js/lib/browser_notification.js` — requestPermission() wraps Notification.requestPermission(), show(title, body, onClick) creates browser notification if permission granted, getPermission() returns current state, isSupported() checks API availability. Never auto-requests
- [x] T018 [P] [US1] Implement favicon_badge.js in `apps/retro_hex_chat_web/assets/js/lib/favicon_badge.js` — createFaviconBadge() loads current favicon into canvas, show() draws red circle overlay at bottom-right and updates link href, clear() restores original favicon href, isActive() returns badge state
- [x] T019 [US1] Implement notification_dispatcher_hook.js in `apps/retro_hex_chat_web/assets/js/hooks/notification_dispatcher_hook.js` — mounted() creates dispatcher with dependencies (sound, titleFlash, favicon, toast, browserNotif), registers handleEvent for "notify" and "notification_batch", loads prefs from localStorage for guests. handleEvent delegates to dispatcher. Hook=wiring only, all logic in lib modules
- [x] T020 [US1] Register NotificationDispatcherHook in `apps/retro_hex_chat_web/assets/js/app.js` — import and add to Hooks object
- [x] T021 [US1] Implement server-side notification helpers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/notifications.ex` — build_notification_event/4 creates payload per contracts/liveview-events.md, maybe_push_notification/3 checks NotificationRouter.should_notify? and pushes event, add_notification_entry/2 adds to socket assigns (max 50 FIFO), increment_notification_count/1
- [x] T022 [US1] Implement notification event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/event_handlers/notification_events.ex` — handle_event for "browser_permission_result", attach_hook for notification events
- [x] T023 [US1] Wire notification hook into ChatLive template — add `<div id="notification-dispatcher-hook" phx-hook="NotificationDispatcherHook">` to chat layout, add notification toast container `<div id="notification-toasts" class="notification-toast-container">`
- [x] T024 [US1] Integrate notification dispatching into existing PubSub handlers — modify channel message handling in ChatLive to call Notifications.maybe_push_notification/3 after existing unread badge increment. Wire into PM handler, join/leave handlers. Ensure existing play_event_sound and maybe_flash_channel calls are replaced by the unified notification push
- [x] T025 [US1] Add notification-related CSS for toast container in `apps/retro_hex_chat_web/assets/css/notification-center.css` — position notification toast container fixed bottom-right, stacking layout for up to 3 toasts. Import in `apps/retro_hex_chat_web/assets/css/app.css`
- [x] T026 [US1] Initialize notification socket assigns in ChatLive mount — add notification_entries: [], notification_count: 0, show_notification_center: false, dnd_enabled: false to mount assigns. Load notification preferences into session

**Checkpoint**: US1 complete — mentions/PMs in non-active channels trigger coordinated notifications (toast + sound + title flash + favicon badge). Active channel suppression works. Browser notifications fire if permission was granted.

---

## Phase 4: User Story 2 — Global and Per-Channel Settings (Priority: P2)

**Goal**: Settings > Notifications panel with global toggles, per-channel levels, and trigger rules

**Independent Test**: Open Settings > Notifications, change #general to "Mentions only", verify only mentions trigger notifications from that channel. Toggle sounds off, verify no sounds play.

### Tests (write first, must fail)

- [x] T027 [P] [US2] Write LiveView test for notifications panel rendering in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/notification_test.exs` — test panel shows global toggles, per-channel dropdowns for joined channels, trigger rule checkboxes, PM locked to "Always", browser permission button when not granted
- [x] T028 [P] [US2] Write Elixir test for save_notification_prefs event handling — test that the event persists preferences for registered users (via UserPreferences.save) and pushes update_notification_prefs back to client

### Implementation

- [x] T029 [US2] Implement notifications_panel component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/notifications_panel.ex` — retro-styled panel with: (1) Global toggles section: Sounds enabled checkbox, Browser notifications checkbox with "Request permission" button, Title flash checkbox; (2) Trigger rules section: Mentions, PMs, Channel messages, Joins/leaves checkboxes; (3) Per-channel levels: list of joined channels with Normal/Mentions only/Mute dropdown, PMs locked to "Always" (disabled dropdown); (4) Privacy mode checkbox; (5) DND toggle. Uses draft state pattern matching options_dialog.ex
- [x] T030 [US2] Add "Notifications" panel to options dialog in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex` — add "notifications" to @panels list, add `<.notifications_panel :if={@active_panel == "notifications"} draft={@options_draft} />` conditional, wire phx-click events for notification settings changes
- [x] T031 [US2] Handle save_notification_prefs event in notification_events.ex — validate and apply preference changes to session, persist for registered users via UserPreferences.save/2, push update_notification_prefs to client, sync DND state to socket assign
- [x] T032 [US2] Handle browser_permission_result event — update browser_notifications toggle based on permission ("denied" → toggle off, "granted" → toggle on), persist preference
- [x] T033 [US2] Wire per-channel level changes into notification routing — when channel level changes, update notification preferences in session and push to client. When user leaves a channel (existing leave handler), call NotificationPreferences.remove_channel_level/2 to clean up
- [x] T034 [US2] Handle guest preference persistence — in notification_dispatcher_hook.js, after receiving "update_notification_prefs" event, call notification_prefs.js savePrefs() to sync to localStorage. On mount, load from localStorage and push to server via "save_notification_prefs"

**Checkpoint**: US2 complete — Settings > Notifications panel fully functional. Per-channel levels, global toggles, and trigger rules all affect notification routing. Preferences persist for both registered users and guests.

---

## Phase 5: User Story 3 — Do Not Disturb Mode (Priority: P3)

**Goal**: DND toggle in toolbar + settings that suppresses all toasts, sounds, title flash, and browser notifications while badges accumulate

**Independent Test**: Enable DND, send mentions, verify no interruptions occur but badges increment. Reload page, verify DND persists.

### Tests (write first, must fail)

- [x] T035 [P] [US3] Write LiveView test for DND toggle in toolbar — test phx-click="toggle_dnd" toggles dnd_enabled assign, pushes dnd_changed event to client, DND indicator visible when active
- [x] T036 [P] [US3] Write JS test for DND persistence in notification_prefs.test.js — test that DND state saves/loads from localStorage, survives simulated page reload

### Implementation

- [x] T037 [US3] Add DND toggle button to toolbar in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/toolbar.ex` — 16x16 moon/bell SVG icon, phx-click="toggle_dnd", conditional CSS class when DND active, tooltip "Do Not Disturb"
- [x] T038 [US3] Handle toggle_dnd event in notification_events.ex — flip dnd_enabled in session preferences, update socket assign, persist preferences, push dnd_changed event to client
- [x] T039 [US3] Add DND visual indicator CSS — toolbar button highlight/icon change when DND active (e.g., crossed-out bell or moon icon) in `apps/retro_hex_chat_web/assets/css/shell.css`
- [x] T040 [US3] Ensure DND persistence on page reload — on ChatLive mount, read dnd_enabled from loaded preferences and set socket assign. Client reads from localStorage (guests) and applies immediately before first notification can fire

**Checkpoint**: US3 complete — DND can be toggled from toolbar or settings, survives page reloads, suppresses all interruptions while badges accumulate.

---

## Phase 6: User Story 4 — Favicon Badge (Priority: P4)

**Goal**: Browser favicon shows red dot overlay when unread notifications exist

**Independent Test**: Send a mention in non-active channel, verify favicon shows red dot. Read all messages, verify favicon restores to normal.

### Tests (write first, must fail)

- [x] T041 [US4] Write JS test verifying favicon badge integrates with dispatcher in notification_dispatcher.test.js — add test case: when dispatch fires, faviconBadge.show() is called; when all read, faviconBadge.clear() is called

### Implementation

- [x] T042 [US4] Wire favicon badge into notification dispatcher — in notification_dispatcher.js, call faviconBadge.show() when notification count > 0, call faviconBadge.clear() when "mark_all_notifications_read" is handled. Ensure favicon state persists across in-app navigations (no unnecessary clear/redraw)
- [x] T043 [US4] Handle favicon clear on navigation to channel — when user navigates to a channel with unread, if all notification entries become read, clear favicon badge. Wire into notification_dispatcher_hook.js handleEvent for navigation events

**Checkpoint**: US4 complete — Favicon shows red dot when unread notifications exist, clears when all read.

---

## Phase 7: User Story 5 — Notification Center (Priority: P5)

**Goal**: Bell icon in toolbar with dropdown panel showing recent notifications, click-to-navigate, "Mark all as read"

**Independent Test**: Generate 3 notifications, click bell icon, verify panel shows all 3 in reverse chronological order. Click an entry, verify navigation. Click "Mark all as read", verify all cleared.

### Tests (write first, must fail)

- [x] T044 [P] [US5] Write LiveView test for notification center panel rendering in notification_test.exs — test bell icon renders with badge count, panel toggles on click, entries display in reverse chronological order, click_notification navigates, mark_all_notifications_read clears entries and resets count
- [x] T045 [P] [US5] Write unit test for notification entry management — test add_notification_entry enforces 50-entry FIFO limit, entries sorted by timestamp desc, mark_all_read clears all, joins/leaves don't create entries

### Implementation

- [x] T046 [US5] Implement notification_center component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/notification_center.ex` — retro-styled dropdown panel anchored to bell icon: (1) Header with "Notifications" title and "Mark all as read" button; (2) Scrollable list of entries with relative timestamps (e.g., "2 min ago"), sender, summary; (3) Each entry clickable via phx-click="click_notification" phx-value-id={entry.id}; (4) Empty state message when no entries; (5) Bell icon with badge count overlay
- [x] T047 [US5] Add bell icon to toolbar in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/toolbar.ex` — 16x16 bell SVG, phx-click="toggle_notification_center", badge count overlay showing notification_count when > 0
- [x] T048 [US5] Handle notification center events in notification_events.ex — toggle_notification_center flips show_notification_center assign, click_notification navigates to channel/PM and marks entry as read, mark_all_notifications_read clears notification_entries and resets notification_count to 0, clears all treebar unread badges, pushes favicon clear event
- [x] T049 [US5] Style notification center panel in `apps/retro_hex_chat_web/assets/css/notification-center.css` — retro window styling, positioned absolute below bell icon, max-height with scroll, entry hover state, badge count styling on bell icon, z-index above other panels
- [x] T050 [US5] Render notification center conditionally in chat layout — add `<.notification_center :if={@show_notification_center} entries={@notification_entries} count={@notification_count} />` to the appropriate position in the ChatLive template

**Checkpoint**: US5 complete — Bell icon shows badge count, panel opens with notification list, entries navigate on click, "Mark all as read" clears everything.

---

## Phase 8: User Story 6 — Privacy Mode (Priority: P6)

**Goal**: When enabled, toasts and browser notifications show generic content instead of message preview

**Independent Test**: Enable privacy mode, send a mention, verify toast shows "New message in #channel" without sender name or content.

### Tests (write first, must fail)

- [x] T051 [US6] Write JS test for privacy mode in notification_dispatcher.test.js — add test cases: when privacy_mode=true, dispatch passes masked content to toast and browser notification; when false, passes full content

### Implementation

- [x] T052 [US6] Implement privacy mode content masking in notification_dispatcher.js — when prefs.privacy_mode is true, replace toast/browser notification content with "New message in #channel" (or "New private message" for PMs), hide sender name. Notification center entries always show full content (they're behind a click)

**Checkpoint**: US6 complete — Privacy mode hides message content in toasts and browser notifications.

---

## Phase 9: Edge Cases & Batch Notifications

**Purpose**: Handle reconnect batching, toast queue overflow, and other edge cases from spec

- [x] T053 [P] Write JS test for batch notifications in notification_toast.test.js — test showBatch(count, channels) displays summary toast "15 new messages in 3 channels"
- [x] T054 [P] Write Elixir test for reconnect notification batching in notification_test.exs — test that when multiple messages arrive during reconnect, notification_batch event is pushed instead of individual notifications
- [x] T055 Implement batch notification handling on server in helpers/notifications.ex — detect reconnect scenario (e.g., >5 notifications within 1 second), aggregate into single notification_batch event with count and channel list
- [x] T056 Implement batch toast display in notification_toast.js — showBatch(count, channelNames) creates summary toast "N new messages in M channels", auto-dismiss after 5s, no click navigation
- [x] T057 Wire notification_batch event in notification_dispatcher_hook.js — handleEvent("notification_batch") calls toast manager's showBatch()
- [x] T058 Handle channel leave cleanup — in existing channel leave handler, call NotificationPreferences.remove_channel_level/2 and persist updated preferences. Already wired in T033, verify with test

**Checkpoint**: Edge cases handled — reconnect batching, channel leave cleanup working.

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, final integration, and CI validation

- [x] T059 [P] Add help topics to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` — topics for: "Notifications" (Features category — overview of notification system), "Do Not Disturb" (Features category — DND usage), "Notification Center" (User Interface category — bell icon panel), "Notification Settings" (Features category — per-channel levels, global toggles, trigger rules). Update "See Also" in related existing topics (Sounds, Keyboard Shortcuts)
- [x] T060 [P] Add notification-related keyboard shortcuts to help topics — document any new shortcuts (e.g., bell icon toggle) in the "Keyboard Shortcuts" topic
- [x] T061 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1
- **Phase 3 (US1 — MVP)**: Depends on Phase 2. BLOCKS Phases 4–9 (other stories build on the dispatcher)
- **Phase 4 (US2 — Settings)**: Depends on Phase 3 (needs dispatcher and notification routing working)
- **Phase 5 (US3 — DND)**: Depends on Phase 3 (needs dispatcher to check DND). Can run in parallel with Phase 4
- **Phase 6 (US4 — Favicon)**: Depends on Phase 3 (needs dispatcher). Can run in parallel with Phases 4 and 5
- **Phase 7 (US5 — Notification Center)**: Depends on Phase 3 (needs notification entries in socket assigns)
- **Phase 8 (US6 — Privacy)**: Depends on Phase 3 (needs dispatcher). Can run in parallel with Phases 4–7
- **Phase 9 (Edge Cases)**: Depends on Phase 3
- **Phase 10 (Polish)**: Depends on all previous phases

### Within Each User Story

- Tests MUST be written first and FAIL before implementation
- Domain modules before web layer
- JS lib modules before hooks (hook=wiring, lib=logic)
- Server-side before client-side wiring

### Parallel Opportunities

- **Phase 2**: T002, T003, T004 can run in parallel (different test files). T005, T006, T007 can run in parallel (different source files)
- **Phase 3**: T009–T014 (all tests) can run in parallel. T015–T018 (JS libs) can run in parallel
- **Phase 4–8**: After US1, US3/US4/US6 can run in parallel (different concerns, different files)

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Launch all foundational tests together:
Task: "Write unit tests for NotificationPreferences"    # T002
Task: "Write unit tests for NotificationRouter"          # T003
Task: "Write JS tests for notification_prefs.js"         # T004

# Then launch all implementations together:
Task: "Implement NotificationPreferences module"         # T005
Task: "Implement NotificationRouter module"              # T006
Task: "Implement notification_prefs.js"                  # T007
```

## Parallel Example: Phase 3 (US1 — MVP)

```bash
# Launch all US1 JS lib tests together:
Task: "JS tests for notification_dispatcher.js"          # T009
Task: "JS tests for notification_toast.js"               # T010
Task: "JS tests for browser_notification.js"             # T011
Task: "JS tests for favicon_badge.js"                    # T012

# Launch all US1 JS lib implementations together:
Task: "Implement notification_dispatcher.js"             # T015
Task: "Implement notification_toast.js"                  # T016
Task: "Implement browser_notification.js"                # T017
Task: "Implement favicon_badge.js"                       # T018
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 2: Foundational (T002–T008)
3. Complete Phase 3: User Story 1 (T009–T026)
4. **STOP and VALIDATE**: Test US1 independently — mentions trigger coordinated notifications, active channel suppression works
5. Run CI-equivalent validation (T061)

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1 (Notification Routing) → Core notification system working (MVP!)
3. US2 (Settings) → Users can configure notifications
4. US3 (DND) → Users can pause interruptions
5. US4 (Favicon) → At-a-glance unread indicator in browser tab
6. US5 (Notification Center) → Centralized notification review
7. US6 (Privacy) → Sensitive content protection
8. Edge Cases → Reconnect batching, cleanup
9. Polish → Help docs, CI validation

### Task Count Summary

| Phase | Story | Tasks | Test Tasks | Implementation Tasks |
|-------|-------|-------|------------|---------------------|
| 1 | Setup | 1 | 0 | 1 |
| 2 | Foundational | 7 | 3 | 4 |
| 3 | US1 — Routing & Delivery | 18 | 6 | 12 |
| 4 | US2 — Settings | 8 | 2 | 6 |
| 5 | US3 — DND | 6 | 2 | 4 |
| 6 | US4 — Favicon | 3 | 1 | 2 |
| 7 | US5 — Notification Center | 7 | 2 | 5 |
| 8 | US6 — Privacy | 2 | 1 | 1 |
| 9 | Edge Cases | 6 | 2 | 4 |
| 10 | Polish | 3 | 0 | 3 |
| **Total** | | **61** | **19** | **42** |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No new database migrations — all notification preferences stored in existing `message_settings` JSONB column
- Notification entries are ephemeral (socket assigns) — not persisted to DB
- JS follows hook=wiring/lib=logic pattern per Constitution IV
- All Elixir public functions require @spec per Constitution VI
- Help topics mandatory per Constitution XI
