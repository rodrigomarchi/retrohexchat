# Tasks: Sounds & Notifications

**Input**: Design documents from `/specs/014-sounds-notifications/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included per constitution Principle IV (TDD is non-negotiable).

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Exact file paths included in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migration, domain module, Ecto schema, Session integration, JS sound catalog expansion — the foundation all user stories depend on.

- [X] T001 Create Ecto schema for sound_settings table in `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/sound_setting.ex` — primary key `owner_nickname` (FK → registered_nicks), JSONB fields `sound_mappings` and `flash_settings`, changeset with validation. Follow `CtcpSetting` schema pattern exactly.
- [X] T002 Create database migration in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDD_create_sound_settings.exs` — `sound_settings` table with `primary_key: false`, owner_nickname FK to registered_nicks with `on_delete: :delete_all`, JSONB columns `sound_mappings` (default `'{}'`) and `flash_settings` (default `'{}'`), timestamps. Run `mix ecto.migrate`.
- [X] T003 Create SoundSettings domain module in `apps/retro_hex_chat/lib/retro_hex_chat/chat/sound_settings.ex` — implement `new/0` (returns default map with all 10 event types mapped to default sounds and flash settings), `get_sound/2`, `set_sound/3`, `get_flash/2`, `set_flash/3`, `get_sound_mappings/1`, `get_flash_settings/1`, `available_sounds/0` (returns list of `{name, label}` tuples for 15 sounds including "none"), `event_types/0`, `valid_sound?/1`, `save/2`, `load/1`. Follow `CtcpSettings` module pattern. All public functions must have @spec.
- [X] T004 Write unit tests for SoundSettings domain module in `apps/retro_hex_chat/test/retro_hex_chat/chat/sound_settings_test.exs` — test `new/0` returns correct defaults, all getters/setters for each event type, `available_sounds/0` returns 15 entries, `valid_sound?/1` for valid and invalid names, `save/2` and `load/1` round-trip persistence, `set_sound/3` with invalid sound name. Tag `@tag :unit` for pure logic, `@tag :integration` for DB tests.
- [X] T005 Add `sound_settings` field to Session struct in `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` — add `sound_settings: map()` to `@type t`, initialize with `SoundSettings.new()` in `new/1`, add `get_sound_settings/1` and `set_sound_settings/2` with @spec. Follow existing `ctcp_settings`/`flood_protection` getter/setter pattern.
- [X] T006 Expand sound catalog in `apps/retro_hex_chat_web/assets/js/hooks/sound_hook.js` — replace the hardcoded `getSoundConfig(type)` switch statement with a `SOUND_CATALOG` constant map containing all 14 named sounds + "none" (see data-model.md for frequencies/durations/volumes/waveTypes). Update `playBeep` to look up by name from the catalog. Accept sound name strings (e.g., "ding_low") instead of event type strings. Keep mute logic and `toggle_mute` event handler unchanged.
- [X] T007 Load sound settings for registered users on identify — in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`, add `SoundSettings.load/1` call alongside existing settings loading (near CtcpSettings.load, FloodProtection.load) when user identifies. Update session with loaded settings via `Session.set_sound_settings/2`. If `:not_found`, keep defaults.

**Checkpoint**: SoundSettings domain module complete, Session integrated, JS sound catalog expanded, DB migration applied.

---

## Phase 2: Foundational (Sound Dispatch Refactor)

**Purpose**: Replace hardcoded sound dispatch with per-event configurable dispatch. This MUST be complete before any user story can work correctly.

**CRITICAL**: No user story work can begin until this phase is complete.

- [X] T008 Create helper function `play_event_sound/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — takes `socket`, `event_type` atom (e.g., `:highlight`, `:pm`, `:join`), and `session`. Looks up the sound name from `SoundSettings.get_sound(session.sound_settings, event_type)`. If sound is not "none", calls `push_event(socket, "play_sound", %{type: sound_name})`. Returns socket. Add @spec.
- [X] T009 Refactor existing `maybe_play_highlight_sound/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — replace `push_event(socket, "play_sound", %{type: "mention"})` with `play_event_sound(socket, :highlight, session)`. Pass session as parameter to the function.
- [X] T010 Add sound dispatch for PM events in `apply_new_pm/3` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — when a new PM arrives and the PM is not the active one, call `play_event_sound(socket, :pm, session)`.
- [X] T011 Add sound dispatch for join/part/kick events in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — in the `handle_info` clauses for `"user_joined"`, `"user_left"`, and `"user_kicked"` channel events, call `play_event_sound/3` with `:join`, `:part`, `:kick` respectively.
- [X] T012 Add sound dispatch for connect/disconnect events in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — play `:connect` sound when the socket successfully mounts/connects, play `:disconnect` sound in the disconnected handler (if applicable).
- [X] T013 Add sound dispatch for buddy online/offline events in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — in the `handle_info({:notify_debounce, ...})` clause, call `play_event_sound/3` with `:buddy_online` or `:buddy_offline` based on the status.
- [X] T014 Add sound dispatch for regular channel messages in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — in `apply_new_message/4`, when a message arrives in a non-active channel and it is NOT highlighted, call `play_event_sound(socket, :message, session)`.
- [X] T015 Write tests for sound dispatch in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/sound_dispatch_test.exs` — test that `play_event_sound/3` looks up correct sound from settings, test that "none" sounds produce no push_event, test each event type dispatch (highlight, PM, join, part, kick, connect, disconnect, buddy_online, buddy_offline, message). Tag `@tag :liveview`.

**Checkpoint**: All 10 event types dispatch sounds based on user's per-event configuration. Existing hardcoded sounds replaced.

---

## Phase 3: User Story 1 — Per-Event Sound Configuration (Priority: P1) MVP

**Goal**: Users can open a Sounds dialog, see all 10 event types, change sound assignments per event, preview sounds, and save with OK/Cancel/Apply.

**Independent Test**: Open Sounds dialog → change sound for "highlight" → click OK → trigger highlight → hear new sound.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T016 [P] [US1] Write LiveView tests for Sounds dialog in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/sound_settings_test.exs` — test: dialog opens when "open_sound_settings_dialog" event fires, dialog shows all 10 event types, each event has a dropdown and preview button, "sound_settings_change" updates draft, "sound_settings_apply" commits draft to session, "sound_settings_ok" commits and closes, "close_sound_settings_dialog" discards draft, Cancel after Apply only discards post-Apply changes. Tag `@tag :liveview`.

### Implementation for User Story 1

- [X] T017 [US1] Create sound settings dialog component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/sound_settings_dialog.ex` — 2000s-erad function component with `visible`, `sound_settings_draft` attrs. Render fieldset with 10 rows (one per event type): event label, sound dropdown (populated from `SoundSettings.available_sounds/0`), flash checkbox, preview button. OK/Cancel/Apply buttons at bottom. Follow `CtcpSettingsDialog` / `FloodProtectionDialog` pattern (dialog-overlay, window class, title-bar). Each dropdown fires `phx-change="sound_settings_change"` with event_type and sound params. Flash checkbox fires `phx-click="sound_flash_toggle"`. Preview button fires `phx-click="sound_preview"`. All public functions must have @spec.
- [X] T018 [US1] Add dialog event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — implement `handle_event` for: `"open_sound_settings_dialog"` (set `show_sound_settings_dialog: true`, `sound_settings_draft: session.sound_settings`), `"close_sound_settings_dialog"` (set `show_sound_settings_dialog: false`, clear draft), `"sound_settings_change"` (update draft's sound_mappings via `SoundSettings.set_sound/3`), `"sound_flash_toggle"` (update draft's flash_settings via `SoundSettings.set_flash/3`), `"sound_preview"` (call `push_event(socket, "play_sound", %{type: sound_name})`), `"sound_settings_apply"` (commit draft to session + persist for registered users + show system message, keep dialog open), `"sound_settings_ok"` (same as apply + close dialog). Initialize `show_sound_settings_dialog: false` and `sound_settings_draft: nil` in mount assigns.
- [X] T019 [US1] Add "Sounds" menu item to Tools menu in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex` — add `<div class="menu-dropdown-item" data-testid="menu-sounds" phx-click="open_sound_settings_dialog">Sounds</div>` in the Tools dropdown, before CTCP Settings.
- [X] T020 [US1] Render sound settings dialog in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` render function — add `<SoundSettingsDialog.sound_settings_dialog visible={@show_sound_settings_dialog} sound_settings_draft={@sound_settings_draft} />` alongside other dialog components.

**Checkpoint**: User Story 1 fully functional — Sounds dialog opens, shows 10 events with dropdowns, preview works, OK/Cancel/Apply saves/discards correctly, settings persist for registered users.

---

## Phase 4: User Story 2 — Global Mute Toggle (Priority: P2)

**Goal**: Users can mute/unmute all sounds with one click in the status bar. Mute persists across page reloads. Visual notifications unaffected by mute.

**Independent Test**: Click mute button → trigger highlight → no sound plays → unmute → trigger highlight → sound plays → reload page → mute state persisted.

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T021 [P] [US2] Write LiveView tests for mute toggle in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/mute_toggle_test.exs` — test: mute button renders in status bar, clicking mute fires "toggle_mute" event, mute state reflected in status bar icon, mute state is client-side (localStorage). Tag `@tag :liveview`.

### Implementation for User Story 2

- [X] T022 [US2] Add mute toggle button to status bar in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/status_bar.ex` — add a new `<p class="status-bar-field">` containing a clickable speaker icon button with `phx-click="toggle_mute"`. Add `muted` boolean attr to component. Display speaker icon (text-based: `♪` unmuted, `♪̸` or `🔇` muted — use simple text like "[SND]" / "[MUTE]" for retro style). Add `data-testid="mute-toggle"`.
- [X] T023 [US2] Add mute event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — implement `handle_event("toggle_mute", ...)` that calls `push_event(socket, "toggle_mute", %{})` (sends to JS hook which toggles localStorage). Track mute state in socket assigns for UI rendering: `assign(socket, muted: !socket.assigns.muted)`. Initialize `muted: false` in mount. Pass `muted` attr to status_bar component.
- [X] T024 [US2] Sync mute state from localStorage on mount — in `apps/retro_hex_chat_web/assets/js/hooks/sound_hook.js`, add a `pushEvent("mute_state_sync", {muted: this.muted})` call in `mounted()` to inform the server of the client's mute state. In `chat_live.ex`, add `handle_event("mute_state_sync", %{"muted" => muted}, socket)` to set `assign(socket, muted: muted)`.
- [X] T025 [US2] Add CSS for mute button in `apps/retro_hex_chat_web/assets/css/layout.css` — style the mute toggle button within the status bar to look like a retro status bar indicator (small, clickable, togglable appearance).

**Checkpoint**: User Story 2 fully functional — mute button in status bar toggles all sounds, persists across reloads via localStorage, visual notifications still work while muted.

---

## Phase 5: User Story 3 — Visual Activity Indicators (Priority: P3)

**Goal**: Treebar entries flash/pulse for non-active channels/PMs with new activity (gated by per-event flash settings). Title bar alternates when browser tab is unfocused.

**Independent Test**: Send message to non-active channel → treebar entry flashes → switch to channel → flash stops. Unfocus tab → send message → title alternates.

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T026 [P] [US3] Write LiveView tests for visual notifications in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/visual_notifications_test.exs` — test: flash_channels MapSet populated when event has flash enabled, flash_channels cleared on channel switch, flash_channels not populated when event has flash disabled, PM flash uses "pm:#{nick}" key, `title_flash_start` event pushed when tab unfocused and activity arrives, `title_flash_stop` event pushed when switching to active channel. Tag `@tag :liveview`.

### Implementation for User Story 3

- [X] T027 [US3] Add `flash_channels` MapSet to socket assigns in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — initialize `flash_channels: MapSet.new()` in mount. Clear flash for channel/PM on switch (in `switch_channel` and `switch_pm` handlers): `MapSet.delete(socket.assigns.flash_channels, channel_or_pm_key)`.
- [X] T028 [US3] Create helper `maybe_flash_channel/4` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — takes `socket`, `channel_or_pm_key` (string), `event_type` (atom), `session`. Checks `SoundSettings.get_flash(session.sound_settings, event_type)`. If true, adds key to `flash_channels` MapSet. Returns socket. Add @spec.
- [X] T029 [US3] Integrate `maybe_flash_channel/4` into all event dispatch points in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — call in `apply_new_message/4` (for `:message` and `:highlight`), `apply_new_pm/3` (for `:pm`), join/part/kick handlers, buddy online/offline handlers. Use the correct channel or `"pm:#{nick}"` key.
- [X] T030 [US3] Pass `flash_channels` to treebar component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` render — add `flash_channels={MapSet.to_list(@flash_channels)}` to the treebar component call.
- [X] T031 [US3] Update treebar component to use `flash_channels` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar.ex` — add `flash_channels` attr (list, default []). In `treebar_item_class/4`, add `tree-highlight` class if channel is in `flash_channels` (in addition to existing highlight_channels check). In `pm_item_class/3`, add `tree-highlight` class if `"pm:#{pm}"` is in `flash_channels`.
- [X] T032 [US3] Create TitleFlashHook in `apps/retro_hex_chat_web/assets/js/hooks/title_flash_hook.js` — JS hook that handles `"title_flash_start"` event (stores original title, starts `setInterval` every 1.5s alternating between original and `"* New activity - RetroHexChat"`), `"title_flash_stop"` event (clears interval, restores original title). Also listen to `visibilitychange` — when tab becomes visible, push `"tab_focused"` event to server. Export hook.
- [X] T033 [US3] Register TitleFlashHook in `apps/retro_hex_chat_web/assets/js/app.js` — import `TitleFlashHook` and add to `Hooks` object.
- [X] T034 [US3] Attach TitleFlashHook to app container in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` render — add `phx-hook="TitleFlashHook"` to the appropriate container element (or a dedicated hidden div with id `"title-flash"`).
- [X] T035 [US3] Push title flash events from LiveView in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — when activity arrives in a non-active channel/PM, call `push_event(socket, "title_flash_start", %{message: "* New activity"})`. Add `handle_event("tab_focused", ...)` that calls `push_event(socket, "title_flash_stop", %{})` and clears `flash_channels` for the currently active channel.

**Checkpoint**: User Story 3 fully functional — treebar entries flash per event-type flash settings, title bar alternates when tab unfocused, flash stops on switch, title restores on focus.

---

## Phase 6: User Story 4 — PM Typing Indicator (Priority: P4)

**Goal**: Users see "NickName is typing..." in PM conversations when the other user is typing. Indicator disappears after 5s timeout or when message is sent. PM-only (not channels). Respects ignore list.

**Independent Test**: User A types in PM to User B → User B sees "Alice is typing..." → User A stops → indicator disappears after 5s → User A sends → indicator disappears immediately.

### Tests for User Story 4

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T036 [P] [US4] Write LiveView tests for typing indicator in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/typing_indicator_test.exs` — test: `pm_typing` event broadcasts typing to PM PubSub topic, receiving typing event sets `pm_typing_from` assign, typing indicator cleared after 5s timeout (use `Process.send_after` assertion), `pm_stop_typing` clears indicator immediately, typing from ignored user is not displayed, typing events not sent when active_pm is nil, bidirectional typing (both users see each other's indicator). Tag `@tag :liveview`.

### Implementation for User Story 4

- [X] T037 [US4] Add typing debounce to KeyboardHook or create TypingHook in `apps/retro_hex_chat_web/assets/js/hooks/sound_hook.js` (or a dedicated section in KeyboardHook) — detect `input` events on the message textarea (id `"chat-input"`). When user types and active PM is set: debounce 500ms, then call `this.pushEvent("pm_typing", {})`. Track last typing time to avoid re-sending within the debounce window. When message is submitted (form submit detected), call `this.pushEvent("pm_stop_typing", {})`.
- [X] T038 [US4] Add typing event handlers in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — implement `handle_event("pm_typing", ...)`: if `session.active_pm` is not nil, broadcast `%{event: "typing", payload: %{nickname: session.nickname}}` to `"pm:#{pm_topic(session.nickname, session.active_pm)}"`. Implement `handle_event("pm_stop_typing", ...)`: broadcast `%{event: "stop_typing", payload: %{nickname: session.nickname}}` to the same topic.
- [X] T039 [US4] Handle typing PubSub events in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `handle_info(%{event: "typing", payload: %{nickname: nick}}, socket)`: if nick is the active PM partner AND nick is not on ignore list AND nick is not self, set `assign(socket, pm_typing_from: nick)` and schedule `Process.send_after(self(), :clear_typing_indicator, 5_000)` (cancel any existing timer first via `pm_typing_timer` assign). Add `handle_info(%{event: "stop_typing", payload: %{nickname: nick}}, socket)`: clear `pm_typing_from` if it matches nick, cancel timer. Add `handle_info(:clear_typing_indicator, socket)`: set `pm_typing_from: nil`.
- [X] T040 [US4] Initialize typing assigns in mount in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `pm_typing_from: nil` and `pm_typing_timer: nil` to mount assigns.
- [X] T041 [US4] Render typing indicator in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` render function — below the message stream area (or at the bottom of the chat panel), conditionally render: `<div :if={@pm_typing_from && @session.active_pm} class="typing-indicator" data-testid="typing-indicator">{@pm_typing_from} is typing...</div>`.
- [X] T042 [US4] Add typing indicator CSS in `apps/retro_hex_chat_web/assets/css/layout.css` — style `.typing-indicator` with subtle appearance: small font size (11px), gray/muted color (#999), italic, positioned below the message area, with a gentle fade-in animation.
- [X] T043 [US4] Clear typing indicator on PM switch in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — in `handle_event("switch_pm", ...)` and `handle_event("switch_channel", ...)`, clear `pm_typing_from: nil` and cancel any pending timer.

**Checkpoint**: User Story 4 fully functional — typing indicator shows in PM conversations, disappears on timeout/send, respects ignore list, PM-only, bidirectional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, edge cases, final validation.

- [X] T044 [P] Add help topics for Sounds & Notifications in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` — add topics: "Sounds" (Features category: explains Sounds dialog, per-event configuration, sound catalog, OK/Cancel/Apply), "Mute" (Features category: explains global mute toggle, status bar location, localStorage persistence), "Typing Indicator" (Features category: explains PM typing indicator, 5s timeout, PM-only behavior), "Visual Notifications" (Features category: explains treebar flash, title bar alternation, per-event flash toggle). Add "See Also" cross-references between all four topics and to existing "Notifications", "Private Messages", "Ignore List" topics.
- [X] T045 [P] Handle edge case: PM sound for active PM in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — ensure no PM sound plays when the PM is currently active (user is viewing it). Sound should only play for background PMs.
- [X] T046 [P] Handle edge case: clear typing on new PM message in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — in `apply_new_pm/3`, if the message sender matches `pm_typing_from`, clear the typing indicator (the user sent their message).
- [X] T047 Run full CI-equivalent validation pipeline (see CLAUDE.md "CI-Equivalent Validation"): `mix compile --warnings-as-errors` first, then in parallel: `mix format --check-formatted`, `mix credo --strict`, `mix test --include e2e`, `mix dialyzer`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 completion — BLOCKS all user stories
- **Phase 3 (US1)**: Depends on Phase 2 — can start once sound dispatch is working
- **Phase 4 (US2)**: Depends on Phase 1 only (mute is client-side, independent of dispatch refactor) — can run in parallel with Phase 2/3
- **Phase 5 (US3)**: Depends on Phase 2 (needs flash settings from sound dispatch) — can run in parallel with Phase 3 and 4
- **Phase 6 (US4)**: Depends on Phase 1 only (typing is independent of sound settings) — can run in parallel with Phases 2-5
- **Phase 7 (Polish)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1 - Sound Config)**: Depends on Phase 2 (sound dispatch). No dependency on other stories.
- **US2 (P2 - Mute)**: Independent of other stories. Only depends on Phase 1 (existing mute in sound_hook.js).
- **US3 (P3 - Visual Flash)**: Depends on Phase 2 (needs flash settings integration). Independent of US1/US2.
- **US4 (P4 - Typing)**: Fully independent. Only depends on Phase 1 (Session integration).

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD — Principle IV)
- Component/module creation before LiveView integration
- LiveView handlers before render integration
- CSS/JS last

### Parallel Opportunities

- **Phase 1**: T001 and T002 (schema + migration) can run in parallel with T006 (JS catalog)
- **Phase 1**: T003 (domain module) depends on T001 (schema). T004 (tests) depends on T003.
- **Phase 3-6**: User stories can largely proceed in parallel:
  - US2 (mute) and US4 (typing) are fully independent of Phase 2
  - US1 and US3 can start as soon as Phase 2 completes
- **Phase 7**: T044, T045, T046 are all independent and parallelizable

---

## Parallel Example: Phase 1 Setup

```
# These can run in parallel (different files):
T001: Create Ecto schema (sound_setting.ex)
T006: Expand JS sound catalog (sound_hook.js)

# Then sequentially:
T002: Create migration (depends on schema pattern from T001)
T003: Create domain module (depends on T001 schema)
T005: Session integration (depends on T003)
T004: Write unit tests (depends on T003)
T007: Load on identify (depends on T003, T005)
```

## Parallel Example: User Stories (after Phase 2)

```
# These can proceed in parallel (independent stories):
US2 (Phase 4): Mute toggle — only needs Phase 1
US4 (Phase 6): Typing indicator — only needs Phase 1

# These need Phase 2 first, then can run in parallel:
US1 (Phase 3): Sound config dialog
US3 (Phase 5): Visual flash indicators
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T007)
2. Complete Phase 2: Sound Dispatch Refactor (T008-T015)
3. Complete Phase 3: User Story 1 — Sound Config Dialog (T016-T020)
4. **STOP and VALIDATE**: Test Sounds dialog independently
5. Deploy/demo if ready — users can already configure per-event sounds

### Incremental Delivery

1. Phase 1 + Phase 2 → Foundation ready
2. Add US1 (Sound Config) → Test independently → Deploy (MVP!)
3. Add US2 (Mute Toggle) → Test independently → Deploy
4. Add US3 (Visual Flash) → Test independently → Deploy
5. Add US4 (Typing Indicator) → Test independently → Deploy
6. Phase 7 (Polish) → Final validation → Deploy

### Fast-Track Option

Since US2 (Mute) and US4 (Typing) are independent of Phase 2:
1. Phase 1 → Start US2 and US4 immediately
2. Phase 2 → Then start US1 and US3
3. All four stories converge for Phase 7

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- TDD is mandatory (Constitution Principle IV) — tests written first
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Total: 47 tasks (7 setup + 8 foundational + 5 US1 + 5 US2 + 10 US3 + 8 US4 + 4 polish)
