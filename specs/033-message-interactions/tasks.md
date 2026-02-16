# Tasks: Quote/Reply & Message Edit/Delete

**Input**: Design documents from `/specs/033-message-interactions/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/chat-service.md, quickstart.md

**Tests**: Included per Constitution Principle IV (TDD is non-negotiable). Tests written first, must fail before implementation.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migration and schema changes that all user stories depend on

- [ ] T001 Create migration adding reply_to_id, reply_to_author, reply_to_preview, edited_at, deleted_at columns to messages and private_messages tables with self-referential FK and indexes in `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_add_message_interactions.exs`
- [ ] T002 [P] Extend Message schema with reply_to_id, reply_to_author, reply_to_preview, edited_at, deleted_at fields and add reply_changeset/2, edit_changeset/2, delete_changeset/1 in `apps/retro_hex_chat/lib/retro_hex_chat/chat/message.ex`
- [ ] T003 [P] Extend PrivateMessage schema with same five new fields and corresponding changesets in `apps/retro_hex_chat/lib/retro_hex_chat/chat/private_message.ex`
- [ ] T004 [P] Create CSS file for message interactions (reply block, edit mode, deleted display, reply compose bar, hover reply button) in `apps/retro_hex_chat_web/assets/css/message-interactions.css` and import it in `apps/retro_hex_chat_web/assets/css/app.css`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain logic (Policy + Queries) that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational Phase

- [ ] T005 [P] Write unit tests for can_edit?/2 and can_delete?/2 in `apps/retro_hex_chat/test/retro_hex_chat/chat/policy_test.exs`: test author match, time window (within/expired), debounce, deleted message rejection, not-own-message rejection
- [ ] T006 [P] Write unit tests for new Message changesets (reply_changeset, edit_changeset, delete_changeset) in `apps/retro_hex_chat/test/retro_hex_chat/chat/message_test.exs`
- [ ] T007 [P] Write integration tests for get_message/1, update_message_content/3, soft_delete_message/2, update_reply_previews/2, get_reply_ids/1 in `apps/retro_hex_chat/test/retro_hex_chat/chat/queries_test.exs`

### Implementation for Foundational Phase

- [ ] T008 [P] Implement can_edit?/2 and can_delete?/2 in `apps/retro_hex_chat/lib/retro_hex_chat/chat/policy.ex` with 5-minute window, author check, deletion guard, and 3-second debounce for edits
- [ ] T009 [P] Implement get_message/1, get_private_message/1, update_message_content/3, soft_delete_message/2, update_reply_previews/2, get_reply_ids/1 (and PM equivalents) in `apps/retro_hex_chat/lib/retro_hex_chat/chat/queries.ex`

**Checkpoint**: Policy and Queries pass all tests. Foundation ready for user stories.

---

## Phase 3: User Story 1 — Reply to a Message (Priority: P1) MVP

**Goal**: Users can reply to any message via context menu or hover button, see a compose bar above input, and send replies with visual quote blocks. Clicking a quote scrolls to the original message.

**Independent Test**: Send messages in a channel, right-click → "Responder", type reply, press Enter. Reply appears with quoted block. Click the quoted block to scroll to the original.

### Tests for User Story 1

- [ ] T010 [P] [US1] Write integration tests for send_message with reply_to_id (including snapshot creation, truncation of long messages) in `apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs`
- [ ] T011 [P] [US1] Write JS lib tests for truncatePreview(), scrollToMessage(), highlightMessage() in `apps/retro_hex_chat_web/assets/test/lib/message_interactions.test.js`
- [ ] T012 [P] [US1] Write JS hook tests for MessageInteractionsHook (scroll_to_message event handling, hover reply button show/hide) in `apps/retro_hex_chat_web/assets/test/hooks/message_interactions_hook.test.js`

### Implementation for User Story 1

- [ ] T013 [US1] Extend send_message/4 in Chat.Service to accept optional reply_to_id, look up parent message, create reply snapshot (author + truncated preview), and include reply fields in PubSub broadcast payload in `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`
- [ ] T014 [US1] Extend send_private_message/4 with same reply_to_id support in `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`
- [ ] T015 [US1] Add edit_message and delete_message calls in Channel GenServer (handle_call for :edit_message, :delete_message) in `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex` — also extend send_message to pass reply_to_id through
- [ ] T016 [US1] Create ReplyComposeBar component showing "Respondendo a {author} — {preview} ✕" with cancel_reply event in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/reply_compose_bar.ex`
- [ ] T017 [US1] Update chat_message component to render reply block above message content when reply_to_id is present, showing reply_to_author and reply_to_preview (or "[mensagem removida]" if parent deleted), with phx-click for scroll-to-parent in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_message.ex`
- [ ] T018 [US1] Enable the existing disabled "Quote/Reply" menu item in the :message context menu, wire it to push ctx_chat_reply event with message_id in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex`
- [ ] T019 [US1] Add reply_to assign to socket, handle reply_to_message/ctx_chat_reply and cancel_reply events in core_events, extend send_input to pass reply_to_id and clear reply state after send in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- [ ] T020 [US1] Add ReplyComposeBar to chat_live.html.heex between formatting toolbar and input form, passing @reply_to assign in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [ ] T021 [US1] Update new_message handler in PubSub handlers to include reply fields (reply_to_id, reply_to_author, reply_to_preview) in the message map inserted into the stream in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`
- [ ] T022 [US1] Create message_interactions.js lib with truncatePreview(text, maxLen), scrollToMessage(id), highlightMessage(id) functions in `apps/retro_hex_chat_web/assets/js/lib/message_interactions.js`
- [ ] T023 [US1] Create MessageInteractionsHook handling scroll_to_message push_event (calls scrollToMessage) and adding hover reply button on mouseenter/mouseleave for .chat-message elements in `apps/retro_hex_chat_web/assets/js/hooks/message_interactions_hook.js`
- [ ] T024 [US1] Register MessageInteractionsHook in the hooks index and attach it to the chat messages container in `apps/retro_hex_chat_web/assets/js/hooks/index.js` and `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [ ] T025 [US1] Handle scroll_to_reply_parent event in core_events: push_event "scroll_to_message" with the parent message ID in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`

**Checkpoint**: Reply feature fully functional. Users can reply via context menu and hover button, see reply compose bar, send replies with visual quote blocks, and click quotes to scroll to originals.

---

## Phase 4: User Story 2 — Edit Own Message (Priority: P2)

**Goal**: Users can edit their last message by pressing ↑ when input is empty. Edit mode shows visual indicator, submitting updates the message in-place with "(editado)" tag for all viewers.

**Independent Test**: Send a message, press ↑ with empty input, modify text, press Enter. Message updates for all viewers with "(editado)" tag. Press Esc to cancel.

### Tests for User Story 2

- [ ] T026 [P] [US2] Write integration tests for edit_message/3 in Chat.Service: successful edit, time window enforcement, author mismatch rejection, debounce, empty content treated as deletion, reply context preserved after edit, reply_to_preview update in child messages in `apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs`
- [ ] T027 [P] [US2] Write JS lib tests for shouldTriggerEditMode(inputValue, isLastMessageOwn) and formatEditTimestamp(datetime) in `apps/retro_hex_chat_web/assets/test/lib/message_interactions.test.js`
- [ ] T028 [P] [US2] Write JS hook tests for enter_edit_mode and exit_edit_mode push_event handling in `apps/retro_hex_chat_web/assets/test/hooks/message_interactions_hook.test.js`

### Implementation for User Story 2

- [ ] T029 [US2] Implement edit_message/3 in Chat.Service: validate via Policy.can_edit?, update content via Queries.update_message_content, broadcast "message_edited", update reply previews and broadcast "reply_quote_updated" if replies exist in `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`
- [ ] T030 [US2] Implement edit_private_message/3 with same logic for PMs in `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`
- [ ] T031 [US2] Update chat_message component to render "(editado)" tag with title tooltip showing edit timestamp when edited_at is present, and add .chat-message--editing class when message ID matches edit_mode_message_id assign in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_message.ex`
- [ ] T032 [US2] Add edit_mode_message_id and edit_original_input assigns to socket. Handle edit_last_message event: find user's last message, check it's the most recent and within window, set edit mode, push_event "enter_edit_mode". Handle cancel_edit: clear assigns, push_event "exit_edit_mode". Handle submit_edit: call Service.edit_message, clear edit mode in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- [ ] T033 [US2] Handle message_edited PubSub event: update message in stream with new content and edited_at. Handle reply_quote_updated: update reply_to_preview for affected reply messages in stream in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`
- [ ] T034 [US2] Add shouldTriggerEditMode(inputValue, isLastMessageOwn) and formatEditTimestamp(datetime) to message_interactions.js lib in `apps/retro_hex_chat_web/assets/js/lib/message_interactions.js`
- [ ] T035 [US2] Modify keyboard_hook.js: on ↑ with empty input, push "edit_last_message" event instead of "history_navigate". Add enter_edit_mode and exit_edit_mode push_event handlers to MessageInteractionsHook (fill input, highlight message, handle Escape for cancel) in `apps/retro_hex_chat_web/assets/js/hooks/keyboard_hook.js` and `apps/retro_hex_chat_web/assets/js/hooks/message_interactions_hook.js`

**Checkpoint**: Edit feature fully functional. Users can press ↑ to edit last message, see edit indicator, submit edits visible to all with "(editado)" tag, and cancel with Escape.

---

## Phase 5: User Story 3 — Delete Own Message (Priority: P3)

**Goal**: Users can delete their own messages via context menu within 5 minutes. Confirmation dialog appears, and deleted messages show as "[mensagem removida]" for all viewers.

**Independent Test**: Send a message, right-click → "Apagar mensagem", confirm. Message replaced with "[mensagem removida]" for all viewers.

### Tests for User Story 3

- [ ] T036 [P] [US3] Write integration tests for delete_message/2 in Chat.Service: successful delete, time window enforcement, author mismatch, already-deleted rejection, reply-to-deleted displays correctly in `apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs`

### Implementation for User Story 3

- [ ] T037 [US3] Implement delete_message/2 in Chat.Service: validate via Policy.can_delete?, soft-delete via Queries.soft_delete_message, broadcast "message_deleted" in `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`
- [ ] T038 [US3] Implement delete_private_message/2 with same logic for PMs in `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`
- [ ] T039 [US3] Update chat_message component to replace message content with "[mensagem removida]" in muted style when deleted_at is present in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_message.ex`
- [ ] T040 [US3] Create DeleteConfirmDialog component using existing Dialog with mode="confirm", showing "Apagar esta mensagem?" with Confirmar/Cancelar buttons in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/delete_confirm_dialog.ex`
- [ ] T041 [US3] Add "Apagar mensagem" item to :message context menu (only for own messages within 5-min window), wire to ctx_chat_delete event in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex`
- [ ] T042 [US3] Add delete_confirm assign to socket. Handle ctx_chat_delete (open dialog), confirm_delete (call Service.delete_message, close dialog), cancel_delete (close dialog) events in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- [ ] T043 [US3] Add DeleteConfirmDialog to chat_live.html.heex passing @delete_confirm assign in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex`
- [ ] T044 [US3] Handle message_deleted PubSub event: update message in stream with deleted_at set (component handles display change) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`

**Checkpoint**: Delete feature fully functional. Users can delete own messages with confirmation, all viewers see "[mensagem removida]", and replies to deleted messages show appropriate placeholder.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Help documentation, edge cases, and full validation

- [ ] T045 [P] Add help topics for "Message Reply", "Message Edit", and "Message Delete" features with usage instructions and cross-references in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex`
- [ ] T046 [P] Update "Keyboard Shortcuts" help topic to include ↑ for edit mode in `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/keyboard_shortcuts.ex`
- [ ] T047 Handle edge case: edit-to-empty triggers delete confirmation flow (from US2 submit_edit, if content is empty, redirect to delete flow with confirmation) in `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- [ ] T048 Run full CI-equivalent validation pipeline: `mix compile --warnings-as-errors`, then in parallel: `mix format --check-formatted`, `mix credo --strict`, `make lint.js`, `make lint.css`, `npm test --prefix apps/retro_hex_chat_web/assets`, `mix test --include e2e`, `mix dialyzer`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (migration must run, schemas must compile)
- **User Story 1 (Phase 3)**: Depends on Phase 2 (Policy + Queries must be complete)
- **User Story 2 (Phase 4)**: Depends on Phase 2 only — can run in parallel with US1
- **User Story 3 (Phase 5)**: Depends on Phase 2 only — can run in parallel with US1 and US2
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (Reply)**: Independent after Phase 2. Establishes reply rendering in chat_message and PubSub patterns.
- **US2 (Edit)**: Independent after Phase 2. Shares chat_message.ex and core_events.ex with US1 but touches different rendering branches. Edit updates reply previews (depends on reply data model from Phase 1, not US1 implementation).
- **US3 (Delete)**: Independent after Phase 2. Shares chat_message.ex and core_events.ex. Depends on reply display for "[mensagem removida]" in quotes (established in Phase 1 schema, not US1 code).

### Within Each User Story

- Tests written FIRST and must FAIL before implementation
- Domain layer (Service) before web layer (components, events)
- Components before LiveView integration (events, template)
- JS lib before JS hooks
- Hooks registered before template references

### Parallel Opportunities

- **Phase 1**: T002, T003, T004 can run in parallel (different files)
- **Phase 2**: T005, T006, T007 tests in parallel; T008, T009 implementation in parallel
- **Phase 3–5**: After Phase 2, all three user stories CAN run in parallel (separate story concerns)
- **Within US1**: T010, T011, T012 tests in parallel; T016, T017, T018 components in parallel
- **Within US2**: T026, T027, T028 tests in parallel
- **Phase 6**: T045, T046 in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all US1 tests in parallel:
Task: T010 "Service tests for reply in service_test.exs"
Task: T011 "JS lib tests for message_interactions.test.js"
Task: T012 "JS hook tests for message_interactions_hook.test.js"

# Launch parallel US1 components (after service):
Task: T016 "ReplyComposeBar component"
Task: T017 "ChatMessage reply block rendering"
Task: T018 "Context menu reply item"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migration + schemas + CSS)
2. Complete Phase 2: Foundational (Policy + Queries)
3. Complete Phase 3: User Story 1 (Reply)
4. **STOP and VALIDATE**: Test reply feature independently
5. Run full CI pipeline (T048)

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (Reply) → Test → Validate (MVP!)
3. Add US2 (Edit) → Test → Validate
4. Add US3 (Delete) → Test → Validate
5. Polish → Final CI validation → Done

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All user stories share Phase 1 schema changes and Phase 2 policy/queries
- The Channel GenServer (T015) is placed in US1 but its edit/delete calls are used by US2/US3
- CSS (T004) is created once in setup; each story adds classes as needed
- Constitution Principle IV (TDD): Tests are mandatory, not optional
