# Tasks: P2P File Transfer

**Input**: Design documents from `/specs/037-p2p-file-transfer/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Required per Constitution Principle IV (TDD). Tests MUST be written first.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Configuration, DataChannel creation, and shared module scaffolding

- [X] T001 Add FILE_TRANSFER_* environment variable reading in `config/runtime.exs`
- [X] T002 [P] Add `createDataChannel()` export to `apps/retro_hex_chat_web/assets/js/lib/webrtc.js`
- [X] T003 [P] Create DataChannel in WebRTC initiator flow and handle `ondatachannel` in answerer in `apps/retro_hex_chat_web/assets/js/hooks/webrtc_hook.js`
- [X] T004 Register FileTransferHook in `apps/retro_hex_chat_web/assets/js/app.js`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core protocol library that ALL user stories depend on — message encoding/decoding, constants, and validation

**CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundation

- [X] T005 [P] Write tests for constants, MSG, STATE exports in `apps/retro_hex_chat_web/assets/test/lib/file_transfer.test.js`
- [X] T006 [P] Write tests for `validateFile()` (size limits, blocked extensions, boundary cases) in `apps/retro_hex_chat_web/assets/test/lib/file_transfer.test.js`
- [X] T007 [P] Write tests for `encodeControlMessage()`, `encodeChunk()`, `decodeMessage()` in `apps/retro_hex_chat_web/assets/test/lib/file_transfer.test.js`
- [X] T008 [P] Write tests for `computeHash()` in `apps/retro_hex_chat_web/assets/test/lib/file_transfer.test.js`
- [X] T009 [P] Write tests for `formatFileSize()`, `formatSpeed()`, `formatEta()` in `apps/retro_hex_chat_web/assets/test/lib/file_transfer.test.js`

### Implementation for Foundation

- [X] T010 Implement constants (CHUNK_SIZE, HIGH_WATER_MARK, LOW_WATER_MARK, MSG, STATE) and `validateFile()` in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
- [X] T011 Implement `encodeControlMessage()`, `encodeChunk()`, `decodeMessage()` in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
- [X] T012 Implement `computeHash()` using crypto.subtle in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
- [X] T013 Implement `formatFileSize()`, `formatSpeed()`, `formatEta()` in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`

**Checkpoint**: Foundation ready — `file_transfer.js` has protocol encoding/decoding, validation, hashing, and formatting. All foundation tests pass.

---

## Phase 3: User Story 1 — Send a File to a Peer (Priority: P1) MVP

**Goal**: End-to-end file transfer: select file, send offer, accept, chunked transfer with progress, SHA-256 verify, browser download.

**Independent Test**: Two peers in a lobby — one selects a file, the other accepts, file downloads and matches the original.

### Tests for User Story 1

- [X] T014 [P] [US1] Write tests for `createSenderSession()`, `createReceiverSession()`, `getNextChunk()`, `receiveChunk()`, `assembleFile()`, `cleanupSession()` in `apps/retro_hex_chat_web/assets/test/lib/file_transfer.test.js`
- [X] T015 [P] [US1] Write tests for `calculateProgress()`, `recordSpeedSample()` in `apps/retro_hex_chat_web/assets/test/lib/file_transfer.test.js`
- [X] T016 [P] [US1] Write tests for FileTransferHook mounted/destroyed lifecycle, file input wiring, drag-and-drop wiring, DataChannel message handling, and pushEvent calls in `apps/retro_hex_chat_web/assets/test/hooks/file_transfer_hook.test.js`

### Implementation for User Story 1

- [X] T017 [US1] Implement `createSenderSession()`, `createReceiverSession()` in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
- [X] T018 [US1] Implement `getNextChunk()` with File.slice() reading and backpressure tracking in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
- [X] T019 [US1] Implement `receiveChunk()`, `assembleFile()`, `cleanupSession()` in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
- [X] T020 [US1] Implement `calculateProgress()` and `recordSpeedSample()` with rolling average in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
- [X] T021 [US1] Implement FileTransferHook `mounted()`: file input listener, drag-and-drop listeners, DataChannel `onmessage` handler, handleEvent registrations in `apps/retro_hex_chat_web/assets/js/hooks/file_transfer_hook.js`
- [X] T022 [US1] Implement FileTransferHook sender flow: validate file → hash → request_action → on channel open send file-offer → on accept start chunked send loop with backpressure in `apps/retro_hex_chat_web/assets/js/hooks/file_transfer_hook.js`
- [X] T023 [US1] Implement FileTransferHook receiver flow: display offer (pushEvent) → on accept send file-accept → receive chunks → on transfer-done hash and verify → trigger download via URL.createObjectURL() in `apps/retro_hex_chat_web/assets/js/hooks/file_transfer_hook.js`
- [X] T024 [US1] Implement FileTransferHook `destroyed()`: cleanup session, remove listeners, revoke object URLs in `apps/retro_hex_chat_web/assets/js/hooks/file_transfer_hook.js`
- [X] T025 [US1] Add file transfer UI components to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`: hidden file input, "Enviar Arquivo" button wiring, drop zone overlay, file offer display (name/size/type with Aceitar/Rejeitar buttons), 98.css progress-indicator bar with speed/ETA text, success/error status messages
- [X] T026 [US1] Add ft_* event handlers to `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex`: handle ft_offer_sent, ft_offer_received, ft_accepted, ft_rejected, ft_progress, ft_completed, ft_failed — update assigns for UI rendering, pass file transfer config as assigns
- [X] T027 [US1] Create `apps/retro_hex_chat_web/assets/css/file-transfer.css`: drop zone styling (.file-transfer-drop-zone, --active modifier), progress bar wrapper with percentage/speed/ETA text, file offer display, file validation error styling
- [X] T028 [US1] Import file-transfer.css in `apps/retro_hex_chat_web/assets/css/app.css` (Layer 4: Components, alphabetical order)

**Checkpoint**: User Story 1 complete — end-to-end file transfer works with progress, verification, and download.

---

## Phase 4: User Story 2 — Cancel an Active Transfer (Priority: P2)

**Goal**: Either peer can cancel a transfer at any time. Both sides clean up partial data and see who cancelled.

**Independent Test**: Start a transfer, click "Cancelar" mid-transfer, verify both sides show cancellation message and partial data is cleaned up.

### Tests for User Story 2

- [X] T029 [P] [US2] Write tests for cancel message encoding/decoding and session cleanup on cancel in `apps/retro_hex_chat_web/assets/test/lib/file_transfer.test.js`
- [X] T030 [P] [US2] Write tests for FileTransferHook cancel button wiring and incoming cancel message handling in `apps/retro_hex_chat_web/assets/test/hooks/file_transfer_hook.test.js`

### Implementation for User Story 2

- [X] T031 [US2] Implement cancel handling in sender/receiver sessions: send cancel message, clean up partial chunks, reset state in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
- [X] T032 [US2] Implement FileTransferHook cancel flow: cancel button click → send cancel via DataChannel → pushEvent ft_cancelled; incoming cancel → cleanup → pushEvent ft_cancelled in `apps/retro_hex_chat_web/assets/js/hooks/file_transfer_hook.js`
- [X] T033 [US2] Add cancel button ("Cancelar") to progress bar UI and handle ft_cancelled event (show "Transferencia cancelada por [name]") in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex` and `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_session_live.ex`

**Checkpoint**: User Story 2 complete — cancellation works from either side with proper cleanup.

---

## Phase 5: User Story 3 — Resume Transfer After Disconnection (Priority: P3)

**Goal**: After a WebRTC reconnection, transfer resumes from where it left off using the receiver's have-chunks array.

**Independent Test**: Simulate connection drop mid-transfer, reconnect, verify only missing chunks are sent and final file passes hash verification.

### Tests for User Story 3

- [X] T034 [P] [US3] Write tests for `encodeHaveChunks()`, `decodeHaveChunks()`, `markChunksReceived()` in `apps/retro_hex_chat_web/assets/test/lib/file_transfer.test.js`
- [X] T035 [P] [US3] Write tests for FileTransferHook reconnection flow: pause on disconnect, send have-chunks on reconnect, resume sending missing chunks in `apps/retro_hex_chat_web/assets/test/hooks/file_transfer_hook.test.js`

### Implementation for User Story 3

- [X] T036 [US3] Implement `encodeHaveChunks()`, `decodeHaveChunks()`, `markChunksReceived()` in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
- [X] T037 [US3] Implement FileTransferHook resume flow: on DataChannel close → pause session (STATE.PAUSED); on new DataChannel open → receiver sends have-chunks → sender calls markChunksReceived() and resumes getNextChunk() loop in `apps/retro_hex_chat_web/assets/js/hooks/file_transfer_hook.js`
- [X] T038 [US3] Update progress bar UI to show "Reconectando..." during PAUSED state and "Retomando transferencia..." on resume in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`

**Checkpoint**: User Story 3 complete — resume after disconnect works with non-contiguous chunk tracking.

---

## Phase 6: User Story 4 — Integrity Verification Failure (Priority: P4)

**Goal**: When SHA-256 mismatch is detected, notify both peers and offer retry option.

**Independent Test**: Corrupt received data before verification, confirm mismatch is detected and retry option is presented.

### Tests for User Story 4

- [X] T039 [P] [US4] Write tests for hash mismatch detection and retry initiation (full re-transfer from scratch) in `apps/retro_hex_chat_web/assets/test/lib/file_transfer.test.js`
- [X] T040 [P] [US4] Write tests for FileTransferHook hash-result handling: match=false → show error + retry button, retry click → send retry message → restart transfer in `apps/retro_hex_chat_web/assets/test/hooks/file_transfer_hook.test.js`

### Implementation for User Story 4

- [X] T041 [US4] Implement hash mismatch handling: receiver sends hash-result with match=false, sender receives retry message → reset session and restart full transfer in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
- [X] T042 [US4] Implement FileTransferHook hash failure flow: on hash-result(match=false) → pushEvent ft_failed("Verificacao de integridade falhou") → show retry button; on retry click → send retry message → restart in `apps/retro_hex_chat_web/assets/js/hooks/file_transfer_hook.js`
- [X] T043 [US4] Add hash failure UI: "Verificacao de integridade falhou" error message with "Tentar novamente" button on sender side in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`

**Checkpoint**: User Story 4 complete — hash mismatch is detected, reported, and retryable.

---

## Phase 7: User Story 5 — Concurrent Transfer Queueing (Priority: P5)

**Goal**: Enforce one-transfer-at-a-time limit and queue additional requests.

**Independent Test**: Attempt to send a second file during an active transfer, verify queue message appears, then confirm queued transfer starts after first completes.

### Tests for User Story 5

- [X] T044 [P] [US5] Write tests for `isTransferActive()`, `createQueueEntry()`, and queue-then-dequeue flow in `apps/retro_hex_chat_web/assets/test/lib/file_transfer.test.js`
- [X] T045 [P] [US5] Write tests for FileTransferHook queue behavior: block second send, show queue message, auto-initiate queued transfer on completion in `apps/retro_hex_chat_web/assets/test/hooks/file_transfer_hook.test.js`

### Implementation for User Story 5

- [X] T046 [US5] Implement `isTransferActive()` and `createQueueEntry()` in `apps/retro_hex_chat_web/assets/js/lib/file_transfer.js`
- [X] T047 [US5] Implement FileTransferHook queueing: check isTransferActive() before initiating → if active, queue file and show message → on transfer complete, dequeue and auto-present offer in `apps/retro_hex_chat_web/assets/js/hooks/file_transfer_hook.js`
- [X] T048 [US5] Add queue status UI: "Transferencia em andamento, arquivo na fila" message in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`

**Checkpoint**: User Story 5 complete — concurrent transfers are queued and auto-initiated.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Validation, cleanup, and edge case hardening

- [X] T049 [P] Update WebRTC hook tests for DataChannel creation changes in `apps/retro_hex_chat_web/assets/test/hooks/webrtc_hook.test.js`
- [X] T050 [P] Add "Conexao perdida" handling: on irrecoverable connection loss, clean up and pushEvent ft_failed in `apps/retro_hex_chat_web/assets/js/hooks/file_transfer_hook.js`
- [X] T051 [P] Add file rejection flow: on file-reject message → pushEvent ft_rejected → show "rejeitou a transferencia de arquivo" message in `apps/retro_hex_chat_web/assets/js/hooks/file_transfer_hook.js` and `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/p2p_lobby.ex`
- [X] T052 Run full CI-equivalent validation pipeline per CLAUDE.md: `mix compile --warnings-as-errors`, then in parallel: `mix format --check-formatted`, `mix credo --strict`, `make lint.js`, `make lint.css`, `npm test --prefix apps/retro_hex_chat_web/assets`, `mix test --include e2e`, `mix dialyzer`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on T001-T004 (setup). BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion. **Required before US3, US4, US5.**
- **User Story 2 (Phase 4)**: Depends on Phase 3 (builds on transfer session and hook).
- **User Story 3 (Phase 5)**: Depends on Phase 3 (extends the sender/receiver session and hook).
- **User Story 4 (Phase 6)**: Depends on Phase 3 (extends hash verification flow).
- **User Story 5 (Phase 7)**: Depends on Phase 3 (extends hook with queue management).
- **Polish (Phase 8)**: Depends on all user stories complete.

### User Story Dependencies

- **US1 (P1)**: Foundation only — core transfer, required by all others
- **US2 (P2)**: Depends on US1 (cancel extends the active transfer flow)
- **US3 (P3)**: Depends on US1 (resume extends the chunk tracking). Can parallelize with US2.
- **US4 (P4)**: Depends on US1 (retry extends hash verification). Can parallelize with US2, US3.
- **US5 (P5)**: Depends on US1 (queue wraps the initiation flow). Can parallelize with US2, US3, US4.

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Lib functions before hook wiring
- Hook wiring before LiveView components
- LiveView components before CSS
- Story complete before moving to next priority

### Parallel Opportunities

- **Phase 1**: T002 and T003 can run in parallel
- **Phase 2**: T005-T009 (all foundation tests) can run in parallel; T010-T013 can partially overlap
- **Phase 3**: T014-T016 (US1 tests) can run in parallel
- **Phases 4-7**: US2, US3, US4, US5 can run in parallel after US1 completes (they extend different aspects of the transfer)
- **Phase 8**: T049-T051 can run in parallel

---

## Parallel Example: Foundation Tests

```bash
# Launch all foundation tests together:
Task: "Write tests for constants, MSG, STATE exports"
Task: "Write tests for validateFile()"
Task: "Write tests for encodeControlMessage(), encodeChunk(), decodeMessage()"
Task: "Write tests for computeHash()"
Task: "Write tests for formatFileSize(), formatSpeed(), formatEta()"
```

## Parallel Example: User Stories 2-5 (after US1 complete)

```bash
# These can run in parallel since they extend different aspects:
Task: US2 — Cancel (extends cancel flow in lib + hook)
Task: US3 — Resume (extends have-chunks in lib + hook)
Task: US4 — Hash failure (extends hash-result in lib + hook)
Task: US5 — Queue (adds queue management in lib + hook)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundation (T005-T013)
3. Complete Phase 3: User Story 1 (T014-T028)
4. **STOP and VALIDATE**: End-to-end file transfer works
5. Run CI validation (T052)

### Incremental Delivery

1. Setup + Foundation → Protocol library ready
2. Add US1 → Test end-to-end → **MVP!**
3. Add US2 → Cancellation works
4. Add US3 → Resume after disconnect works
5. Add US4 → Hash failure handled gracefully
6. Add US5 → Queue management for concurrent requests
7. Polish (Phase 8) → Edge cases, CI validation

---

## Notes

- [P] tasks = different files or independent sections, no dependencies
- [Story] label maps task to specific user story for traceability
- Constitution Principle IV mandates TDD — all tests written before implementation
- This feature is ~90% JavaScript (lib + hook) with minimal Elixir changes (config + thin LiveView handlers)
- No new database migrations needed
- All transfer state is ephemeral (client-side JS memory)
