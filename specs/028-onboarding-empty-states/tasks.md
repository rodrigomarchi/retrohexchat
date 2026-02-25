# Tasks: Onboarding & Empty States

**Input**: Design documents from `/specs/028-onboarding-empty-states/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Required by Constitution Principle IV (TDD). Tests written first, must fail before implementation.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: CSS files, JS lib/hook, and app.css/app.js wiring shared by multiple stories

- [X] T001 [P] Create empty-state CSS in `apps/retro_hex_chat_web/assets/css/empty-state.css` — shared `.empty-state` base class with `user-select: none`, centered text, muted color, `.empty-state-action` button, `.empty-state-tip` italic style (see contracts/components.md)
- [X] T002 [P] Create wizard-dialog CSS in `apps/retro_hex_chat_web/assets/css/wizard-dialog.css` — `.wizard-dialog` window sizing, `.wizard-step-indicator`, `.wizard-content`, `.wizard-logo` (ASCII art), `.wizard-tip`, `.wizard-channel-list`, `.wizard-button-bar`, `.onboarding-tip-banner` (see contracts/components.md)
- [X] T003 [P] Create onboarding JS lib in `apps/retro_hex_chat_web/assets/js/lib/onboarding.js` — export `isOnboardingComplete()` (reads `retro_hex_chat_onboarding_complete` from localStorage), `markOnboardingComplete()` (sets flag). Pure functions, no DOM.
- [X] T004 [P] Create OnboardingHook in `apps/retro_hex_chat_web/assets/js/hooks/onboarding_hook.js` — on `mounted()`: call `isOnboardingComplete()` from lib, `pushEvent("check_onboarding", {first_visit: !complete})`. `handleEvent("mark_onboarding_complete")`: call `markOnboardingComplete()` from lib. (see contracts/liveview-events.md)
- [X] T005 Import new CSS files in `apps/retro_hex_chat_web/assets/css/app.css` — add `@import "./empty-state.css"` in Components layer (alphabetical) and `@import "./wizard-dialog.css"` in Dialogs layer (alphabetical)
- [X] T006 Register OnboardingHook in `apps/retro_hex_chat_web/assets/js/app.js` — import and add `OnboardingHook` to the `Hooks` object

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Tests for shared JS lib — must pass before user story implementation

**⚠️ CRITICAL**: JS lib tests validate the localStorage logic all stories depend on

- [X] T007 [P] Write JS lib tests in `apps/retro_hex_chat_web/assets/test/lib/onboarding.test.js` — test `isOnboardingComplete()` returns false when no key, true when key is "true"; test `markOnboardingComplete()` sets the key. Mock localStorage via jsdom.
- [X] T008 [P] Write JS hook tests in `apps/retro_hex_chat_web/assets/test/hooks/onboarding_hook.test.js` — test `mounted()` calls `pushEvent("check_onboarding", {first_visit: true})` when localStorage empty; test `handleEvent("mark_onboarding_complete")` sets localStorage flag. Follow existing hook test patterns.

**Checkpoint**: JS lib + hook tests green. Foundation ready for user stories.

---

## Phase 3: User Story 1 — First-Time Welcome Wizard (Priority: P1) 🎯 MVP

**Goal**: First-time users see a 3-step wizard (nickname → server → channels) in ConnectLive. Returning users bypass it. Post-wizard tip banner in ChatLive.

**Independent Test**: Clear localStorage, open app → wizard appears. Complete wizard → lands in chat with tip banner. Refresh → wizard does not appear.

### Tests for User Story 1

> **Write these tests FIRST, ensure they FAIL before implementation**

- [X] T009 [P] [US1] Write LiveView tests for wizard flow in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/connect_live_test.exs` — test: wizard renders Step 1 when `wizard_mode: true`; Step 1 shows logo, nickname input, tip text; "wizard_validate_nickname" validates input; "wizard_next" from step "welcome" moves to `:server`; "wizard_next" from step "server" moves to `:channels`; "wizard_back" navigates backward; "wizard_dismiss" triggers `mark_onboarding_complete` push; "wizard_skip" navigates to `/chat?onboarded=true`; "wizard_complete" navigates to `/chat?nickname=X&join=ch1,ch2&onboarded=true`; `wizard_mode: false` shows normal connect form
- [X] T010 [P] [US1] Write LiveView tests for tip banner in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test: when `onboarded=true` query param is present, `show_onboarding_tip` is true and banner renders with expected text; `dismiss_onboarding_tip` event hides banner; banner not shown when `onboarded` param is absent

### Implementation for User Story 1

- [X] T011 [P] [US1] Create WizardDialog component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/wizard_dialog.ex` — function component with attrs per contracts/components.md (visible, step, nickname, nickname_error, server, port, ssl, connecting, connect_error, channels, selected_channels, custom_channel). Render: dialog overlay + window + title bar ("Assistente de Configuração — RetroHexChat") + step indicator + conditional step content (`:welcome`, `:server`, `:channels`) + button bar (Voltar/Próximo/Conectar/Entrar!/Pular/Cancelar per step). Step 1: ASCII logo + nickname input + tip. Step 2: server/port/ssl fields with defaults + tip. Step 3: channel checkboxes + custom channel input. All with @spec and data-testid attributes.
- [X] T012 [US1] Create wizard event handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/connect_live/wizard_events.ex` — module with `handle_event/3` function matching: `"check_onboarding"` (sets wizard_mode), `"wizard_validate_nickname"` (validates via NicknameValidator), `"wizard_next"` (step transitions + connection attempt for server step), `"wizard_back"` (step regression), `"wizard_toggle_channel"` (add/remove from selected), `"wizard_update_custom_channel"` (updates assign), `"wizard_complete"` (push mark_onboarding_complete + navigate to /chat with join params), `"wizard_skip"` (push mark_onboarding_complete + navigate to /chat without channels), `"wizard_dismiss"` (push mark_onboarding_complete + return to normal form). Follow attach_hook pattern returning `{:halt, socket}`. Add @spec.
- [X] T013 [US1] Modify ConnectLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/connect_live.ex` — add wizard assigns to mount (wizard_mode: false, wizard_step: :welcome, wizard_nickname: "", wizard_server: "irc.retro.chat", wizard_port: 6697, wizard_ssl: true, wizard_connecting: false, wizard_connect_error: nil, wizard_channels: [], wizard_selected_channels: [], wizard_custom_channel: ""). Attach OnboardingHook to root element. Attach wizard_events via `attach_hook/4`. Import WizardDialog component.
- [X] T014 [US1] Modify ConnectLive template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/connect_live.html.heex` — add `phx-hook="OnboardingHook"` to root element. Conditionally render: `<.wizard_dialog :if={@wizard_mode} ... />` when wizard_mode is true, else show existing connect form. Pass all wizard assigns to component. Add `phx-window-keydown="wizard_dismiss"` with `phx-key="Escape"` when wizard is visible.
- [X] T015 [US1] Modify ChatLive in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` — add `show_onboarding_tip` assign, set to `true` when `params["onboarded"] == "true"` in mount/handle_params. Add `handle_event("dismiss_onboarding_tip", _, socket)` that sets assign to false.
- [X] T016 [US1] Modify ChatLive template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — add onboarding tip banner div (`:if={@show_onboarding_tip}`) above message area: "Dica: digite / para ver comandos disponíveis. Use ↑↓ para navegar o histórico." with dismiss button. Use `.onboarding-tip-banner` CSS class and `data-testid="onboarding-tip"`.

**Checkpoint**: Wizard flow complete. First-time → wizard → chat with tip. Returning → direct connect form.

---

## Phase 4: User Story 2 — Empty Channel State (Priority: P2)

**Goal**: Empty channels show a centered welcome message instead of blank space. Disappears when first message arrives.

**Independent Test**: Join an empty channel → welcome message visible. Send a message → welcome message vanishes instantly.

### Tests for User Story 2

- [X] T017 [P] [US2] Write LiveView tests for empty channel state in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test: when channel has no messages, empty state renders with "Bem-vindo ao #channel-name!" text and data-testid; when a message arrives, empty state element is no longer present; empty state text has `.empty-state` CSS class (user-select: none)

### Implementation for User Story 2

- [X] T018 [US2] Add empty channel state to ChatLive template in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` — inside the message container, add conditional block: `<div :if={...empty condition...} class="empty-state channel-empty-state" data-testid="channel-empty-state">` with "Bem-vindo ao #[channel-name]!" + "Este é o início do canal. Diga oi!" + tip "/topic para ver o tópico". Condition should check if message stream/list is empty for the active channel.

**Checkpoint**: Empty channels show welcome message. Message arrival removes it instantly.

---

## Phase 5: User Story 3 — Empty Nicklist State (Priority: P3)

**Goal**: Empty nicklist shows "Ninguém aqui — Você é o(a) primeiro(a)!" instead of blank space.

**Independent Test**: Join a channel alone → nicklist shows message. Another user joins → message vanishes.

### Tests for User Story 3

- [X] T019 [P] [US3] Write LiveView test for empty nicklist in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test: when `channel_users` is empty, nicklist renders empty state with expected text and data-testid; when users are present, empty state is absent

### Implementation for User Story 3

- [X] T020 [US3] Add empty state to nicklist component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/nicklist.ex` — add conditional block: `<div :if={@users == []} class="empty-state nicklist-empty-state" data-testid="nicklist-empty-state">` with "Ninguém aqui — Você é o(a) primeiro(a)!" before the existing user list rendering.

**Checkpoint**: Empty nicklist shows friendly message. User joining removes it.

---

## Phase 6: User Story 4 — Empty Treebar State (Priority: P4)

**Goal**: Empty treebar shows guidance message with "Explorar canais" button that opens channel list.

**Independent Test**: User with no channels → treebar shows message + button. Click button → channel list opens. Join channel → message vanishes.

### Tests for User Story 4

- [X] T021 [P] [US4] Write LiveView test for empty treebar in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test: when `channels == []` and `pm_conversations == []`, treebar renders empty state with expected text, "Explorar canais" button, and data-testid; clicking "Explorar canais" triggers channel list event; when channels exist, empty state is absent

### Implementation for User Story 4

- [X] T022 [US4] Add empty state to treebar component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar.ex` — add conditional block at top of component: `<div :if={@channels == [] and @pm_conversations == []} class="empty-state treebar-empty-state" data-testid="treebar-empty-state">` with "Nenhum canal — /join #canal para começar" and `<button type="button" class="empty-state-action" phx-click="open_channel_list">Explorar canais</button>`. Place before the existing tree-view sections.

**Checkpoint**: Empty treebar shows message + button. Channel list opens on click.

---

## Phase 7: User Story 5 — Empty URL Catcher State (Priority: P5)

**Goal**: Empty URL catcher shows explanatory message instead of blank table.

**Independent Test**: Open URL catcher with no URLs → message visible. URL posted in chat → message vanishes.

### Tests for User Story 5

- [X] T023 [P] [US5] Write LiveView test for empty URL catcher in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_test.exs` — test: when URL list is empty, URL catcher renders empty state with "Nenhuma URL capturada" text and data-testid; when URLs exist, empty state is absent

### Implementation for User Story 5

- [X] T024 [US5] Add empty state to URL catcher component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/url_catcher_window.ex` — add conditional block inside the table area: `<div :if={@urls == []} class="empty-state url-catcher-empty-state" data-testid="url-catcher-empty-state">` with "Nenhuma URL capturada." + "URLs mencionadas no chat aparecerão aqui." Replace the empty table body when no URLs are present.

**Checkpoint**: Empty URL catcher shows explanatory message.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, E2E tests, final validation

- [X] T025 [P] Add onboarding help topics to `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/` — add a "Welcome Wizard" topic in the "Getting Started" category covering the 3-step wizard flow. Add an "Empty States" topic in the "User Interface" category describing the 4 empty states and their behavior. Update "See Also" cross-references in related existing topics. Follow existing topic structure (id, title, category, keywords, content).
- [X] T026 [P] Write E2E tests for wizard + empty states in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/connect_live_test.exs` and `chat_live_test.exs` — tag `@tag :e2e`. Test full wizard flow end-to-end: mount ConnectLive with wizard_mode → complete all 3 steps → verify navigation to ChatLive with tip banner. Test returning user bypass (wizard_mode: false → normal form). Test empty state lifecycle in ChatLive: empty channel → send message → empty state gone.
- [X] T027 Run `make ci` — full CI validation pipeline (9 parallel checks). Fix any failures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — CSS, JS lib, JS hook, and wiring can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (T003, T004) — JS tests need lib + hook to exist
- **User Story 1 (Phase 3)**: Depends on Phase 1 (all) + Phase 2 — wizard needs CSS, JS hook, and tested lib
- **User Stories 2–5 (Phases 4–7)**: Depend on Phase 1 (T001 for empty-state.css) — independent of US1 and each other
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (Wizard)**: Needs all Phase 1 + Phase 2 tasks. Standalone after that.
- **US2 (Empty Channel)**: Needs T001 (empty-state.css) + T005 (app.css import). Independent of US1.
- **US3 (Empty Nicklist)**: Needs T001 + T005. Independent of US1, US2.
- **US4 (Empty Treebar)**: Needs T001 + T005. Independent of US1, US2, US3.
- **US5 (Empty URL Catcher)**: Needs T001 + T005. Independent of US1–US4.

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Component/template changes after tests
- Story complete before moving to next priority

### Parallel Opportunities

- Phase 1: T001, T002, T003, T004 are all different files → fully parallel
- Phase 2: T007, T008 are different test files → fully parallel
- Phase 3: T009, T010, T011 are different files → parallel (tests + component)
- Phases 4–7: US2, US3, US4, US5 are independent stories → all can run in parallel after Phase 1

---

## Parallel Example: User Story 1

```bash
# Launch tests + component in parallel (different files):
Task: T009 "LiveView tests for wizard flow in connect_live_test.exs"
Task: T010 "LiveView tests for tip banner in chat_live_test.exs"
Task: T011 "WizardDialog component in wizard_dialog.ex"

# Then sequential (same files or dependencies):
Task: T012 "Wizard event handler in wizard_events.ex"
Task: T013 "Modify ConnectLive in connect_live.ex"
Task: T014 "Modify ConnectLive template in connect_live.html.heex"
Task: T015 "Modify ChatLive in chat_live.ex"
Task: T016 "Modify ChatLive template in chat_live.html.heex"
```

## Parallel Example: Empty States (US2–US5)

```bash
# All 4 empty states can run in parallel (different components):
Task: T017+T018 "Empty Channel State (chat_live.html.heex)"
Task: T019+T020 "Empty Nicklist State (nicklist.ex)"
Task: T021+T022 "Empty Treebar State (treebar.ex)"
Task: T023+T024 "Empty URL Catcher State (url_catcher_window.ex)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (CSS, JS, wiring)
2. Complete Phase 2: Foundational (JS tests green)
3. Complete Phase 3: User Story 1 (wizard + tip banner)
4. **STOP and VALIDATE**: Test wizard flow end-to-end
5. Deploy/demo if ready — users get guided onboarding

### Incremental Delivery

1. Setup + Foundational → Infrastructure ready
2. Add US1 (Wizard) → Test → Deploy (MVP!)
3. Add US2–US5 (Empty States) → Can be done in parallel → Test → Deploy
4. Polish (Help topics, E2E, CI validation) → Final release

### Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Each user story is independently completable and testable
- Empty states (US2–US5) are small, quick wins after wizard is done
- Total: 27 tasks across 8 phases
