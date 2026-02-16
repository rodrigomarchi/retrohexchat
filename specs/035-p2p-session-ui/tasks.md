# Tasks: P2P Lobby & Session UI

**Input**: Design documents from `/specs/035-p2p-session-ui/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: TDD is non-negotiable per Constitution Principle IV. Tests are written before or alongside implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Wire up routes, CSS imports, hook registration, and PM type extension — the scaffolding all user stories depend on.

- [x] T001 Add `/p2p/:token` route to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/router.ex` in the browser scope
- [x] T002 [P] Add `"p2p_invite"` to allowed type values in `apps/retro_hex_chat/lib/retro_hex_chat/chat/private_message.ex` changeset validation
- [x] T003 [P] Create empty CSS files `apps/retro_hex_chat_web/assets/css/p2p-session.css` and `apps/retro_hex_chat_web/assets/css/p2p-lobby.css`, add imports to `apps/retro_hex_chat_web/assets/css/app.css` in Layer 4 (Components) alphabetically
- [x] T004 [P] Create stub JS lib module `apps/retro_hex_chat_web/assets/js/lib/p2p.js` with exported `detectCapabilities()` and `requestPermission(type)` functions returning placeholder values
- [x] T005 [P] Create stub JS hooks `apps/retro_hex_chat_web/assets/js/hooks/p2p_capability_hook.js` and `apps/retro_hex_chat_web/assets/js/hooks/p2p_session_hook.js`, register both in `apps/retro_hex_chat_web/assets/js/app.js` Hooks object

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extend the P2P domain layer with lobby messaging and action request capabilities. All user stories depend on this.

**CRITICAL**: No user story work can begin until this phase is complete.

### Tests for Foundational

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T006 Write tests for SessionServer lobby message operations (send_message, message cap at 100, content validation, broadcast) in `apps/retro_hex_chat/test/retro_hex_chat/p2p/session_server_lobby_test.exs`
- [x] T007 [P] Write tests for SessionServer action request operations (request_action, respond_action, 60s timeout expiry, first-request-wins, cannot respond own) in `apps/retro_hex_chat/test/retro_hex_chat/p2p/session_server_lobby_test.exs` (separate describe block)

### Implementation for Foundational

- [x] T008 Extend SessionServer GenServer state with `messages: []` and `action_request: nil` fields in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/session_server.ex`. Add `send_message/4` public API that appends to messages list (FIFO cap at 100), resets activity timer, and broadcasts `p2p_lobby_message` on `"p2p:#{token}"`. Only allowed when status is "lobby".
- [x] T009 Add `request_action/4` and `respond_action/4` public API to SessionServer in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/session_server.ex`. request_action sets action_request in state, starts 60s timer via Process.send_after, broadcasts `p2p_action_request`. respond_action updates status, cancels timer, broadcasts `p2p_action_response`. If accepted, transition session to "connecting". Handle `{:timeout, :action_request_expiry}` to expire and broadcast `p2p_action_expired`.
- [x] T010 Add `send_lobby_message/3`, `request_action/3`, `respond_action/3` to `apps/retro_hex_chat/lib/retro_hex_chat/p2p/service.ex` — each validates inputs (content length, action_type values), resolves nickname, and delegates to SessionServer
- [x] T011 Expose new lobby functions as delegates in `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex`: `send_lobby_message/3`, `request_action/3`, `respond_action/3`

**Checkpoint**: P2P domain layer now supports ephemeral lobby chat and bilateral consent action requests. All SessionServer lobby tests pass.

---

## Phase 3: User Story 1 — Initiate P2P Session via Slash Command (Priority: P1) MVP

**Goal**: Users can type `/p2p <nick>` to create a P2P session. An invitation PM with lobby link appears in the private chat between both users, and the peer receives a toast notification with Aceitar/Recusar/Ignorar buttons.

**Independent Test**: Type `/p2p <nick>` and verify the PM invitation appears for both users and the toast notification appears for the peer with action buttons.

### Tests for User Story 1

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T012 [P] [US1] Write unit tests for `/p2p` command handler (validate empty args, validate with nick, execute success returning `:ui_action`, execute with offline nick, execute with self-nick, execute with blocked user) in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/p2p_test.exs`
- [x] T013 [P] [US1] Write tests for JS `detectCapabilities()` and `requestPermission()` in `apps/retro_hex_chat_web/assets/test/lib/p2p.test.js` — test with mocked `navigator.mediaDevices` and `RTCPeerConnection` present/absent

### Implementation for User Story 1

- [x] T014 [US1] Create `/p2p` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/p2p.ex` implementing Handler behaviour. validate/1 checks non-empty args. execute/2 resolves target nick, calls `RetroHexChat.P2P.create_session/3`, returns `{:ok, :ui_action, :p2p_invite, %{target, session_type: "generic", token}}`. Implement help/0 and category/0 (`:user`).
- [x] T015 [US1] Register the `"p2p"` command in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex` `@commands` map pointing to `Handlers.P2p`
- [x] T016 [US1] Add `:p2p_invite` result handling in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex` `handle_dispatch_result/3`: (1) call `Chat.Service.send_private_message/5` with type "p2p_invite" and content containing lobby link, (2) push toast notification to peer via `push_event("notify", ...)` with type "p2p_invite" including token/from/session_type, (3) show system message to initiator confirming session creation
- [x] T017 [US1] Extend notification toast in `apps/retro_hex_chat_web/assets/js/lib/notification_toast.js` to handle `type: "p2p_invite"` — render 3 action buttons (Aceitar/Recusar/Ignorar). Aceitar navigates to `/p2p/:token`. Recusar calls `pushEvent("reject_p2p", {token})`. Ignorar dismisses toast. Toast should not auto-dismiss (unlike regular notifications).
- [x] T018 [US1] Add `handle_event("reject_p2p", ...)` in ChatLive (notification_events.ex or command_dispatch.ex) that calls `P2P.close_session(token, user_id, "rejected")` and sends rejection PM to initiator via `Chat.Service.send_private_message/5`
- [x] T019 [US1] Implement `detectCapabilities()` in `apps/retro_hex_chat_web/assets/js/lib/p2p.js` — checks `window.RTCPeerConnection`, `navigator.mediaDevices?.getUserMedia`, `RTCPeerConnection.prototype.createDataChannel`. Returns `{webrtc: bool, getUserMedia: bool, dataChannel: bool}`. Implement `requestPermission(type)` that calls `getUserMedia({audio/video})` and returns promise resolving to `{granted: bool, type}`.

**Checkpoint**: Users can type `/p2p mario`, mario sees an invitation PM and toast. Mario can Accept (navigate to lobby), Reject (session closed, rejection PM sent), or Ignore (toast dismissed). All US1 tests pass.

---

## Phase 4: User Story 2 — P2P Lobby with Peer Presence and Ephemeral Chat (Priority: P2)

**Goal**: Both peers navigate to `/p2p/:token` and see a Windows 98-style lobby with each other's nicknames, presence indicators, and ephemeral real-time chat.

**Independent Test**: Two users navigate to the same `/p2p/:token` — they see each other's names, presence indicators update, and chat messages exchange instantly. Refreshing clears messages.

### Tests for User Story 2

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T020 [P] [US2] Write LiveView tests for P2PSessionLive mount/auth in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/p2p_session_live_test.exs`: valid token + authorized user mounts successfully, guest is redirected, unauthorized user gets 404, expired token redirects to /chat with flash, terminal session redirects
- [x] T021 [P] [US2] Write LiveView tests for P2PSessionLive lobby chat in same test file (separate describe): sending messages appears for both peers, presence indicator updates on join, system messages for peer join/leave
- [x] T022 [P] [US2] Write JS hook tests for P2PSessionHook (beforeunload listener attached/removed) in `apps/retro_hex_chat_web/assets/test/hooks/p2p_session_hook.test.js` and P2PCapabilityHook (pushEvent called with capabilities) in `apps/retro_hex_chat_web/assets/test/hooks/p2p_capability_hook.test.js`

### Implementation for User Story 2

- [x] T023 [US2] Create `P2PSessionLive` in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex` with mount/3: extract nickname from http_session, verify registered, fetch session by token (Queries.get_session_by_token), verify participant (creator_id or peer_id matches), check not terminal, call P2P.join_session, subscribe to `"p2p:#{token}"`, initialize assigns per liveview-api.md contract. Implement render/1 using p2p_lobby component.
- [x] T024 [US2] Add handle_info clauses to P2PSessionLive for PubSub events: `p2p_status_changed` (update session_status, redirect if terminal), `p2p_lobby_message` (append to messages), `p2p_session_closed` (redirect to /chat with flash), `p2p_inactivity_warning` (set warning flag)
- [x] T025 [US2] Add handle_event clauses to P2PSessionLive: `send_lobby_message` (delegate to P2P.send_lobby_message), `p2p_capabilities` (assign capabilities map), `p2p_leave` (delegate to P2P.close_session with "tab_closed")
- [x] T026 [US2] Create lobby UI components in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`: `p2p_lobby/1` (main container as 98.css window), `p2p_presence/1` (peer names with online/offline indicators using `--color-online`/`--color-offline` tokens), `p2p_chat/1` (message list + input form with phx-submit="send_lobby_message")
- [x] T027 [US2] Style lobby layout in `apps/retro_hex_chat_web/assets/css/p2p-session.css`: `.p2p-session` container using 98.css window class, title bar with session info, full-height layout. Style lobby components in `apps/retro_hex_chat_web/assets/css/p2p-lobby.css`: `.p2p-lobby-chat` message area with scrollable list, `.p2p-lobby-presence` with status indicators, `.p2p-lobby-input` form styling. Use design tokens throughout, support dark theme.
- [x] T028 [US2] Implement P2PCapabilityHook in `apps/retro_hex_chat_web/assets/js/hooks/p2p_capability_hook.js`: on mounted, call `detectCapabilities()` from lib/p2p.js async, then pushEvent("p2p_capabilities", results). Implement P2PSessionHook in `apps/retro_hex_chat_web/assets/js/hooks/p2p_session_hook.js`: on mounted, add beforeunload listener that calls pushEvent("p2p_leave"). On destroyed, remove listener.

**Checkpoint**: Both peers can enter the lobby, see each other's presence, exchange ephemeral chat messages. Auth/access control works for all edge cases (guest, unauthorized, expired token). All US2 tests pass.

---

## Phase 5: User Story 3 — Bilateral Consent Action Requests (Priority: P3)

**Goal**: Lobby shows action buttons (Enviar Arquivo, Chamada de Audio, Chamada de Video). Clicking sends a consent request to the peer. Peer accepts or rejects. Browser capabilities detected async; unsupported actions disabled with tooltips. Permission requested only after consent. 60s timeout on requests.

**Independent Test**: One peer clicks an action button, other peer sees consent request with Accept/Reject. Disabling buttons when browser lacks capability.

### Tests for User Story 3

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T029 [P] [US3] Write LiveView tests for action request flow in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/p2p_session_live_test.exs` (new describe block): request_action event broadcasts to peer, respond_action accepted transitions to connecting, respond_action rejected clears request, capability-disabled buttons render correctly
- [x] T030 [P] [US3] Write unit tests for SessionServer action request timeout (60s expiry broadcasts p2p_action_expired, lobby returns to normal) in `apps/retro_hex_chat/test/retro_hex_chat/p2p/session_server_lobby_test.exs` (if not already covered in T007)

### Implementation for User Story 3

- [x] T031 [US3] Create `p2p_actions/1` component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`: render 3 action buttons with phx-click="request_action" and phx-value-action_type. Disable buttons based on capabilities assign (getUserMedia for audio/video, dataChannel for file). Show tooltip on disabled buttons. When action_request is pending and from other peer, show consent banner with Accept/Reject buttons (phx-click="respond_action"). When action_request is pending and from self, show waiting indicator. Show "Aguardando conexao..." when session_status is "connecting".
- [x] T032 [US3] Add handle_event clauses to P2PSessionLive for `request_action` (delegate to P2P.request_action) and `respond_action` (delegate to P2P.respond_action; if accepted, push_event "p2p_request_permission" with permission type)
- [x] T033 [US3] Add handle_info clauses to P2PSessionLive for `p2p_action_request` (set action_request assign, only if from other peer), `p2p_action_response` (update action_request, if accepted trigger permission flow), `p2p_action_expired` (clear action_request, add "Pedido expirou" system message to messages)
- [x] T034 [US3] Add permission request handling to P2PCapabilityHook in `apps/retro_hex_chat_web/assets/js/hooks/p2p_capability_hook.js`: handleEvent("p2p_request_permission", ...) calls `requestPermission(type)` from lib/p2p.js, then pushEvent("permission_result", {granted, type})
- [x] T035 [US3] Add handle_event("permission_result", ...) to P2PSessionLive: if granted, track in assigns; if both peers granted, call P2P.transition_status(token, "connecting"). If denied, show friendly error message in lobby chat and offer retry. Style action buttons and consent banner in `apps/retro_hex_chat_web/assets/css/p2p-lobby.css` (`.p2p-lobby-actions`, `.p2p-lobby-consent`, disabled state with tooltip).

**Checkpoint**: Action buttons work, bilateral consent flow complete. Capability detection disables unsupported actions. Permission requests only after consent. 60s timeout expires with message. All US3 tests pass.

---

## Phase 6: User Story 4 — Close Session and Cleanup (Priority: P4)

**Goal**: Either peer can close the session via button, tab close, or navigation away. Remaining peer is redirected to /chat with system message. Session marked closed in DB.

**Independent Test**: One peer clicks "Encerrar Sessao" — both redirected. One peer closes tab — other redirected after grace period.

### Tests for User Story 4

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T036 [US4] Write LiveView tests for session close in `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/p2p_session_live_test.exs` (new describe block): close_session event closes DB session and redirects, terminate/2 calls close_session, p2p_session_closed broadcast redirects remaining peer

### Implementation for User Story 4

- [x] T037 [US4] Add handle_event("close_session", ...) to P2PSessionLive: call P2P.close_session(token, user_id, "user_closed"), redirect to /chat with flash "Sessao P2P encerrada"
- [x] T038 [US4] Implement terminate/2 in P2PSessionLive: if session still active (not terminal), call P2P.close_session(token, user_id, "disconnected"). Guard against double-close race by checking session status before closing.
- [x] T039 [US4] Add "Encerrar Sessao" button to lobby UI in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex` — styled as 98.css button with phx-click="close_session". Add inactivity warning banner when `inactivity_warning` assign is true, showing countdown message.

**Checkpoint**: Session close works via button, tab close, and navigation. Remaining peer redirected with message. Inactivity warning displays. All US4 tests pass.

---

## Phase 7: User Story 5 — Slash Commands for Specific Actions (Priority: P5)

**Goal**: `/call <nick>` and `/sendfile <nick>` create sessions with pre-selected action types. When both peers enter the lobby, the action request is automatically presented.

**Independent Test**: Type `/call mario` — session created with audio_call type, lobby auto-presents audio call consent request to mario.

### Tests for User Story 5

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T040 [P] [US5] Write unit tests for `/call` handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/call_test.exs`: validate, execute with session_type "audio_call", help/category
- [x] T041 [P] [US5] Write unit tests for `/sendfile` handler in `apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/send_file_test.exs`: validate, execute with session_type "file_transfer", help/category

### Implementation for User Story 5

- [x] T042 [P] [US5] Create `/call` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/call.ex` — same pattern as P2p handler but with `session_type: "audio_call"`. Register `"call"` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`.
- [x] T043 [P] [US5] Create `/sendfile` command handler in `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/send_file.ex` — same pattern as P2p handler but with `session_type: "file_transfer"`. Register `"sendfile"` in `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`.
- [x] T044 [US5] Add auto-present logic to P2PSessionLive: on mount, if session.session_type is not "generic" and both peers are joined, automatically create an action request matching the session_type. This triggers the bilateral consent flow from US3 without manual button click.

**Checkpoint**: `/call` and `/sendfile` create typed sessions. Lobby auto-presents the action request. All US5 tests pass.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Invitation PM rendering, edge case hardening, and CI validation.

- [x] T045 Add P2P invite card rendering in ChatLive message display — when a PM has type "p2p_invite", render it with a distinct card style showing session type badge and clickable lobby link instead of plain text. Update the chat message component in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/` to detect and style `p2p_invite` type PMs.
- [x] T046 [P] Add PM content formatting for each session type in the `:p2p_invite` dispatch handler in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex`: generic → "Sessao P2P iniciada", audio_call → "Chamada de audio iniciada", file_transfer → "Transferencia de arquivo iniciada" — each with the lobby link `/p2p/:token`
- [x] T047 [P] Review and handle remaining edge cases: (1) rejection PM content "mario recusou o convite P2P" with correct session type description, (2) lobby redirect flash messages for expired/closed sessions, (3) lobby system messages for peer join/leave events in SessionServer broadcasts
- [x] T048 Run full CI-equivalent validation pipeline per CLAUDE.md: `mix compile --warnings-as-errors`, then in parallel: `mix format --check-formatted`, `mix credo --strict`, `make lint.js`, `make lint.css`, `npm test --prefix apps/retro_hex_chat_web/assets`, `mix test --include e2e`, `mix dialyzer`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Stories (Phase 3–7)**: All depend on Foundational phase completion
  - US1 (Phase 3): No dependencies on other user stories
  - US2 (Phase 4): No dependencies on other user stories (but benefits from US1 for end-to-end flow)
  - US3 (Phase 5): Depends on US2 (needs lobby LiveView to exist)
  - US4 (Phase 6): Depends on US2 (needs lobby LiveView to exist)
  - US5 (Phase 7): Depends on US1 (same command pattern) + US3 (action request auto-present)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundational)
                      ↓
              ┌───────┼───────┐
              ↓       ↓       ↓
           US1(P3)  US2(P4)  (wait)
              │       │
              │       ├──→ US3(P5) ──┐
              │       └──→ US4(P6)   │
              │                      ↓
              └─────────────→ US5(P7)
                                ↓
                          Polish(P8)
```

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Domain layer before web layer
- Components before LiveView integration
- Core implementation before edge cases

### Parallel Opportunities

- **Phase 1**: T002, T003, T004, T005 can all run in parallel
- **Phase 2**: T006 and T007 can run in parallel (separate describe blocks)
- **Phase 3 (US1)**: T012 and T013 can run in parallel (different languages)
- **Phase 4 (US2)**: T020, T021, T022 can all run in parallel (different test files)
- **Phase 5 (US3)**: T029 and T030 can run in parallel
- **Phase 7 (US5)**: T040 and T041 can run in parallel; T042 and T043 can run in parallel
- **US1 and US2 can proceed in parallel** after Foundational completes (different files)

---

## Parallel Example: User Story 1

```bash
# Launch all tests for US1 together:
Task: "Unit tests for /p2p handler in p2p_test.exs"
Task: "JS tests for detectCapabilities() in p2p.test.js"

# Then implementation (sequential within, but US2 can start in parallel):
Task: "Create /p2p handler in handlers/p2p.ex"
Task: "Register in registry.ex"
Task: "Add dispatch result handling in command_dispatch.ex"
Task: "Extend notification toast for p2p_invite"
Task: "Add reject_p2p handler in ChatLive"
Task: "Implement detectCapabilities() in lib/p2p.js"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Type `/p2p <nick>`, verify PM and toast appear
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Test: `/p2p` command + PM + toast (MVP!)
3. Add US2 → Test: lobby page with presence + chat
4. Add US3 → Test: bilateral consent action requests
5. Add US4 → Test: session close + cleanup
6. Add US5 → Test: `/call` and `/sendfile` shortcuts
7. Polish → CI validation pass

### Sequential Strategy (Single Developer)

1. Phase 1 → Phase 2 → Phase 3 (US1) → Phase 4 (US2) → Phase 5 (US3) → Phase 6 (US4) → Phase 7 (US5) → Phase 8 (Polish)
2. Each phase is a commit-worthy checkpoint
3. US3 and US4 can be swapped if desired (both depend only on US2)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All test tasks follow TDD: write test → verify it fails → implement → verify it passes
- Commit after each phase or logical group
- Stop at any checkpoint to validate story independently
- SessionServer lobby tests (T006/T007) cover the domain foundation; LiveView tests (T020/T021/T029/T036) cover the web integration
- JS tests use Vitest + jsdom with mocked browser APIs
- Total: 48 tasks across 8 phases
