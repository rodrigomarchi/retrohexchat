# Feature Specification: Session Persistence — PM Conversations, Auto-Join & Notifications

**Feature Branch**: `041-session-persistence`
**Created**: 2026-02-19
**Status**: Draft
**Input**: User description: "Session Persistence — PM Conversations, Auto-Join & Notifications for RetroHexChat"

## Clarifications

### Session 2026-02-19

- Q: When a user explicitly closes a PM conversation from the treebar, should it reappear on their next connect? → A: Always reappear — closing is session-only, next connect restores from DB history. Users who want to permanently hide someone should use `/ignore`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - PM Conversation Restore on Connect (Priority: P1)

A registered user connects to the chat. Immediately, the Private section in the treebar populates with all people they've previously exchanged private messages with, ordered by most recent conversation first. The user sees "Alice" at the top (last PM was 2 minutes ago), then "Bob" (last PM yesterday), then "Charlie" (last PM a week ago). Clicking any name loads the full conversation history. No `/query` command is needed.

**Why this priority**: This is the most impactful gap — without it, the chat feels stateless and users lose all PM context on every page load. This is the foundation that makes PMs usable across sessions.

**Independent Test**: Can be fully tested by creating a registered user with PM history, connecting, and verifying the treebar Private section is populated with correct partners in recency order.

**Acceptance Scenarios**:

1. **Given** a registered user with PM history involving 3 partners, **When** the user connects, **Then** the Private section shows all 3 partners ordered by most recent message first
2. **Given** a registered user with PM history involving 60 partners, **When** the user connects, **Then** only the 50 most recent PM partners are shown
3. **Given** a registered user with no PM history, **When** the user connects, **Then** the Private section is empty (no errors)
4. **Given** a guest user, **When** they connect, **Then** no PM conversations are restored from the database
5. **Given** a registered user who has sent PMs to themselves, **When** they connect, **Then** their own nick does not appear in the PM conversation list

---

### User Story 2 - Incoming PM Auto-Opens Conversation (Priority: P1)

A user is chatting in #general. A new user "Dave" (whom they've never spoken to) sends them a PM. Instantly: "Dave" appears at the top of the Private section in the treebar with an unread badge showing "1". A toast popup shows the message preview. The title bar flashes. A PM notification sound plays. If the tab is in the background, a browser notification appears. The user clicks Dave in the treebar and sees the message.

**Why this priority**: Equal priority with Story 1 because without auto-open, users can receive PMs they never see. This is critical for real-time communication and matches mIRC behavior where incoming PMs instantly open a query window.

**Independent Test**: Can be fully tested by having User A send a PM to User B who does not have User A in their conversation list, and verifying the conversation auto-appears with all notification signals.

**Acceptance Scenarios**:

1. **Given** a user with no existing conversation with "Dave", **When** Dave sends a PM, **Then** "Dave" appears at the top of the Private section with an unread badge of "1"
2. **Given** a user viewing #general, **When** an incoming PM arrives from a new contact, **Then** a toast popup, title bar flash, PM sound, and browser notification (if backgrounded) all trigger
3. **Given** a user who has ignored "Eve", **When** Eve sends a PM, **Then** the conversation does NOT auto-open in the treebar
4. **Given** a user already has "Dave" in their conversation list, **When** Dave sends another PM, **Then** "Dave" moves to the top of the list and the unread count increments
5. **Given** a user sends a PM to someone new, **When** the PM is sent, **Then** the recipient also appears in the sender's conversation list

---

### User Story 3 - Auto-Join Channel on Join, Remove on Part (Priority: P2)

A registered user joins #elixir for the first time via `/join #elixir`. The channel is automatically added to their auto-join list. Next time they connect, #elixir is auto-joined along with #lobby and any other saved channels. If they `/part #elixir`, it's removed from the auto-join list. The auto-join list has a 20-channel limit — if full, the join still works but the channel isn't added to auto-join, and a system message explains why.

**Why this priority**: Important for session continuity but less critical than PM persistence since users already have the `/autojoin` command for manual management. This automates an existing capability.

**Independent Test**: Can be fully tested by having a registered user join a channel, verifying it's added to auto-join, then parting and verifying it's removed. Reconnecting confirms persistence.

**Acceptance Scenarios**:

1. **Given** a registered user not in #elixir, **When** they `/join #elixir`, **Then** #elixir is added to their auto-join list
2. **Given** a registered user in #elixir, **When** they `/part #elixir`, **Then** #elixir is removed from their auto-join list
3. **Given** a registered user with 20 channels in auto-join, **When** they `/join #new-channel`, **Then** the join succeeds but auto-join is not updated, and a system message explains the limit
4. **Given** a registered user joining #lobby, **When** the join completes, **Then** #lobby is NOT added to auto-join (it's always joined by default)
5. **Given** a guest user, **When** they `/join #elixir`, **Then** no auto-join entry is created (no DB persistence for guests)
6. **Given** channels being auto-joined on connect, **When** each auto-join fires, **Then** the auto-join handler does NOT re-add those channels to the auto-join list (prevents circular behavior)
7. **Given** a registered user who parts and rejoins the same channel, **When** they rejoin, **Then** no duplicate entry is created in the auto-join list
8. **Given** a channel with a key (+k), **When** a registered user joins with the correct key, **Then** the auto-join entry stores the channel key for future auto-joins

---

### User Story 4 - PM Conversation Ordering by Recency (Priority: P2)

The Private section in the treebar always reflects the most recent conversation activity. When a new PM arrives or is sent, that conversation moves to the top of the list. This provides an at-a-glance view of recent communication partners, similar to a messaging app's conversation list.

**Why this priority**: Enhances usability of the PM conversation list but depends on Stories 1 and 2 being implemented first.

**Independent Test**: Can be tested by having multiple PM conversations and verifying that sending or receiving a message in any conversation moves it to the top of the list.

**Acceptance Scenarios**:

1. **Given** a user with conversations [Alice, Bob, Charlie] ordered by recency, **When** Charlie sends a new PM, **Then** the order becomes [Charlie, Alice, Bob]
2. **Given** a user with conversations [Alice, Bob], **When** the user sends a PM to Bob, **Then** the order becomes [Bob, Alice]
3. **Given** a user who just connected with restored conversations, **Then** conversations are ordered by the timestamp of the most recent message in each conversation

---

### Edge Cases

- **Hundreds of PM partners**: Limit restored conversations to 50 most recent on mount to avoid performance issues
- **PM from ignored user**: Ignore check fires before auto-open — conversation does NOT auto-appear
- **Auto-join at capacity (20 max)**: Join succeeds but auto-add fails gracefully with a system message explaining the limit
- **Channel with key (+k)**: Auto-join stores the key for future use
- **Part and rejoin same channel**: No duplicate entry in auto-join list
- **PM to self**: Should not create a conversation entry in the treebar
- **Nick changes**: PM conversations are keyed by nick at time of message — no retroactive update needed
- **Guest PM conversations**: Tracked in-session only, lost on disconnect, no DB restore attempted
- **Closing a PM conversation**: Closing is session-only — the conversation reappears on next connect since DB history persists. Users who want to permanently hide a contact should use `/ignore`
- **Restore does not block mount**: PM conversation loading must not delay the initial page render

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST restore PM conversation partners for registered users on connect by querying the database for distinct PM partners, limited to the 50 most recent
- **FR-002**: System MUST order PM conversations by most recent message timestamp, both on restore and during active use
- **FR-003**: System MUST auto-open a new PM conversation in the treebar when an incoming PM arrives from a contact not currently in the conversation list
- **FR-004**: System MUST move a conversation to the top of the Private section when a new PM is sent or received in that conversation
- **FR-005**: System MUST NOT auto-open PM conversations from ignored users
- **FR-006**: System MUST NOT include the user's own nick in the PM conversation list
- **FR-007**: System MUST automatically add a channel to the registered user's auto-join list when they join via `/join`
- **FR-008**: System MUST automatically remove a channel from the registered user's auto-join list when they `/part`
- **FR-009**: System MUST NOT add #lobby to the auto-join list (always joined by default)
- **FR-010**: System MUST NOT add channels to the auto-join list during the auto-join execution on connect (prevents circular behavior)
- **FR-011**: System MUST NOT create duplicate entries in the auto-join list when a user parts and rejoins the same channel
- **FR-012**: System MUST display a system message when the auto-join list is full (20 channels) and a new channel cannot be added
- **FR-013**: System MUST store channel keys in auto-join entries for key-protected channels (+k)
- **FR-014**: System MUST NOT persist auto-join entries for guest users
- **FR-015**: System MUST trigger all existing notification signals (toast, title flash, sound, browser notification, unread badge) when a PM auto-opens a new conversation
- **FR-016**: PM conversation restore MUST NOT block the initial page mount — loading should be asynchronous if needed
- **FR-017**: Guest users MUST have in-session PM conversation tracking that is lost on disconnect
- **FR-018**: System MUST include help documentation for PM persistence and auto-join behavior

### Key Entities

- **PM Conversation Partner**: A distinct nickname with whom the user has exchanged private messages, with a most-recent-message timestamp for ordering
- **Auto-Join Entry**: A channel name (and optional key) saved in the user's auto-join list for automatic reconnection, with a maximum of 20 entries per user

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Registered users see their PM conversation partners in the treebar immediately upon connecting, with zero manual commands required
- **SC-002**: 100% of incoming PMs from non-ignored, non-self contacts auto-open a conversation in the treebar within 1 second of receipt
- **SC-003**: Channels joined via `/join` are automatically remembered and re-joined on the next connection for registered users
- **SC-004**: PM conversation list accurately reflects recency order after every sent or received message
- **SC-005**: The auto-join list correctly handles capacity limits, showing a clear message when the 20-channel limit is reached
- **SC-006**: All existing notification signals (toast, sound, badge, browser notification, title flash) fire when a new PM conversation is auto-opened
- **SC-007**: Guest users experience no errors related to persistence features — in-session tracking works, no DB operations attempted
- **SC-008**: Page mount time is not noticeably affected by PM conversation restoration
