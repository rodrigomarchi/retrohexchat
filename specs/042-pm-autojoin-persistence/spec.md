# Feature Specification: Session Persistence — PM Conversations, Auto-Join & Notifications

**Feature Branch**: `042-pm-autojoin-persistence`
**Created**: 2026-02-21
**Status**: Draft
**Input**: User description: "Session Persistence — PM Conversations, Auto-Join & Notifications for RetroHexChat"

## User Scenarios & Testing

### User Story 1 - PM Conversation Restoration on Connect (Priority: P1)

A registered user connects to the chat. Immediately upon connection, the Private section in the treebar shows all people they've ever exchanged PMs with, ordered by most recent conversation first. They see "Alice" at the top (last PM was 2 minutes ago), then "Bob" (last PM yesterday), then "Charlie" (last PM a week ago). The user clicks Alice in the treebar and sees the full conversation history. No `/query` command needed.

Guest users also see PM conversations from their current session but lose them on disconnect (no DB persistence).

**Why this priority**: This is the core gap — the pm_conversations list starts empty on every page load despite the database having full PM history. The existing `restore_pm_conversations` function already queries PM partners from the DB but is only called for identified users via `load_persisted_data`. The user experience of manually `/query`-ing every conversation partner on reconnect is unacceptable.

**Independent Test**: Can be fully tested by registering a user, sending PMs to multiple partners, reconnecting, and verifying the treebar Private section shows all partners in recency order without any manual action.

**Acceptance Scenarios**:

1. **Given** a registered user who has exchanged PMs with 5 different users, **When** they connect and are identified, **Then** all 5 PM partners appear in the treebar's Private section ordered by most recent conversation first.
2. **Given** a registered user with no PM history, **When** they connect, **Then** the treebar's Private section is empty (no partners shown).
3. **Given** a registered user with PM history involving 60 different partners, **When** they connect, **Then** only the 50 most recent partners are shown in the treebar.
4. **Given** a guest user who started PM conversations during their session, **When** they disconnect and reconnect with the same nickname, **Then** the PM conversations list is empty (no persistence for guests).
5. **Given** a registered user, **When** PM restoration completes, **Then** PubSub subscriptions for all restored PM topics are established (so incoming messages are received).
6. **Given** a registered user whose PM history includes their own nickname (PM to self), **When** they connect, **Then** conversations with their own nickname are excluded from the list.

---

### User Story 2 - Auto-Open PM on Incoming Message (Priority: P2)

A user is chatting in #general. A new user "Dave" (whom they've never spoken to) sends them a PM. Instantly: (1) "Dave" appears at the TOP of the Private section in the treebar with an unread badge showing "1". (2) A toast popup appears with the message preview. (3) The title bar flashes. (4) A PM notification sound plays. (5) If the tab is in the background, a browser notification appears. The user clicks Dave in the treebar and sees the message.

If the PM sender is on the user's ignore list, the conversation does NOT auto-open and the PM is silently discarded (existing ignore behavior is preserved).

**Why this priority**: Without auto-open, incoming PMs from new contacts are invisible — the message is stored in the DB but the treebar shows nothing. This is the second most critical gap for a real-time chat experience. In mIRC, receiving a PM instantly opens a query window.

**Independent Test**: Can be tested by having User A send a PM to User B (who has no prior PM history with A), and verifying that B's treebar immediately shows A with an unread badge without any manual action.

**Acceptance Scenarios**:

1. **Given** a user with no prior PM history with "Dave", **When** Dave sends them a PM, **Then** "Dave" appears at the top of the treebar's Private section with unread badge "1", a toast notification shows, the title bar flashes, and a PM notification sound plays.
2. **Given** a user already in a PM conversation with "Alice" at the top, **When** a new PM arrives from "Dave", **Then** "Dave" moves to the top and "Alice" moves to second position.
3. **Given** a user with "Dave" on their ignore list, **When** Dave sends a PM, **Then** no conversation auto-opens, no notification appears, and the treebar is unchanged.
4. **Given** a user receiving a PM from a new contact, **When** the PM auto-opens the conversation in the treebar, **Then** the PubSub subscription for that PM topic is also established (so future messages arrive correctly).
5. **Given** a user receiving a PM while viewing a different channel, **When** the PM arrives, **Then** the browser notification (if the tab is backgrounded) shows the sender name and a message preview.

---

### User Story 3 - Auto-Add Channels to Auto-Join List (Priority: P3)

A registered user joins #elixir for the first time via `/join #elixir`. The channel is automatically added to their auto-join list. Next time they connect, #elixir is auto-joined along with #lobby and any other channels in the list. If they `/part #elixir`, it is removed from the auto-join list. The auto-join list has a 20-channel limit — if full, the join still works but the channel is not auto-added, and a system message explains why.

Guest users can join channels normally but their auto-join list is not persisted (lost on disconnect).

**Why this priority**: Important for session continuity but lower priority than PM persistence because `/autojoin add #channel` already works manually. This story automates what users currently do manually.

**Independent Test**: Can be tested by having a registered user join a channel, disconnecting, reconnecting, and verifying the channel is auto-joined on connect without manual action.

**Acceptance Scenarios**:

1. **Given** a registered (identified) user, **When** they join #elixir via `/join #elixir`, **Then** #elixir is automatically added to their auto-join list and persisted to the database.
2. **Given** a registered user with #elixir in their auto-join list, **When** they `/part #elixir`, **Then** #elixir is removed from their auto-join list and the change is persisted.
3. **Given** a registered user with 20 channels in their auto-join list (max), **When** they `/join #newchannel`, **Then** the join succeeds but the channel is NOT added to auto-join, and a system message reads "Auto-join list is full (20/20). Use /autojoin remove <channel> to make room."
4. **Given** a user joining #lobby, **When** the join completes, **Then** #lobby is NOT added to auto-join (it is always joined by default).
5. **Given** a registered user with #elixir already in auto-join, **When** they `/part #elixir` then `/join #elixir` again, **Then** no duplicate entry is created in the auto-join list.
6. **Given** a guest (unidentified) user, **When** they join a channel, **Then** no auto-join persistence occurs (no DB writes).
7. **Given** a channel with a key (+k mode), **When** a registered user joins it with the correct key, **Then** the auto-join entry stores both the channel name and the key.
8. **Given** auto-join is executing on connect (channels being joined from the saved list), **When** a channel is auto-joined, **Then** the auto-add logic does NOT fire (prevents circular adds).

---

### Edge Cases

- **PM from self**: If a user somehow has PMs with their own nickname in the database, those conversations are excluded from the restoration list and from auto-open.
- **Hundreds of PM partners**: The restoration query limits results to the 50 most recent PM partners. Older conversations can still be accessed via `/query <nick>`.
- **Ignored user PM**: The ignore check fires before the auto-open logic. If the sender is ignored, no conversation appears and no notification fires.
- **Nick changes**: PM conversations are keyed by the nickname at the time of the message. No retroactive nick updates are applied to the PM conversation list. If a partner changes their nick, both old and new nicks may appear as separate entries.
- **Auto-join circular prevention**: When channels are being joined from the auto-join list during connect, the auto-add logic is suppressed to prevent re-adding channels that are already in the list.
- **Auto-join list at max capacity**: The join command still succeeds. Only the auto-add to the list fails, with a clear system message explaining the limit.
- **Channel with key (+k)**: The auto-join entry stores the key so the channel can be auto-joined on future connects. If the key changes, the stored key becomes stale and the auto-join will fail for that channel (user sees an error message).
- **Restore does not block mount**: PM conversation restoration should not delay the user's ability to start chatting. If the DB query takes time, the mount should proceed and conversations should appear asynchronously.
- **PM conversation ordering**: Conversations are always ordered by most recent message timestamp (newest first), both on restore and when reordered by incoming messages.

## Requirements

### Functional Requirements

- **FR-001**: System MUST restore PM conversation partners from the database for registered (identified) users upon connect, ordered by most recent conversation.
- **FR-002**: System MUST limit restored PM conversations to the 50 most recent partners.
- **FR-003**: System MUST subscribe to PubSub topics for all restored PM conversations so incoming messages are received.
- **FR-004**: System MUST auto-open a new PM conversation in the treebar when a PM arrives from a contact not in the current pm_conversations list.
- **FR-005**: System MUST NOT auto-open PM conversations from users on the recipient's ignore list.
- **FR-006**: System MUST display full notification set (toast, unread badge, title flash, sound, browser notification) when a new PM conversation is auto-opened.
- **FR-007**: System MUST automatically add channels to the auto-join list when a registered user joins a channel via `/join`.
- **FR-008**: System MUST automatically remove channels from the auto-join list when a registered user parts a channel via `/part`.
- **FR-009**: System MUST persist auto-join list changes to the database immediately after add/remove.
- **FR-010**: System MUST NOT add #lobby to the auto-join list (it is always joined by default).
- **FR-011**: System MUST NOT add channels to auto-join during the auto-join execution phase on connect (prevents circular behavior).
- **FR-012**: System MUST handle auto-join list at maximum capacity (20) gracefully — join succeeds but auto-add is skipped with a system message.
- **FR-013**: System MUST NOT auto-add channels or persist auto-join for guest (unidentified) users.
- **FR-014**: System MUST exclude conversations with the user's own nickname from the PM restoration list.
- **FR-015**: System MUST store channel keys (+k) in auto-join entries when joining key-protected channels.
- **FR-016**: PM conversation restoration MUST NOT block the mount process.
- **FR-017**: System MUST include help documentation for PM persistence and auto-join behaviors.

### Key Entities

- **PM Conversation Partner**: A nickname with whom the user has exchanged at least one PM. Retrieved from the `private_messages` table by querying distinct sender/recipient pairs. Key attributes: partner nickname, last message timestamp.
- **Auto-Join Entry**: A channel that should be automatically joined on connect. Stored in `autojoin_list_entries` table. Key attributes: channel name, optional channel key, position order.
- **Session**: Runtime state struct holding `pm_conversations` (list of partner nicks) and `autojoin_list` (map with entries). Modified in-memory and persisted to DB for registered users.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Registered users see all recent PM conversation partners (up to 50) in the treebar within 2 seconds of connecting, without manual action.
- **SC-002**: Incoming PMs from new contacts appear in the treebar with full notifications (badge, toast, sound) within 1 second of message delivery.
- **SC-003**: Channels joined via `/join` appear in the auto-join list and are auto-joined on the next connect, with zero manual configuration required.
- **SC-004**: Users can disconnect and reconnect without losing their conversation context — PM history and channel membership are preserved.
- **SC-005**: The PM restoration process does not add perceptible delay to the chat mount experience.
- **SC-006**: 100% of auto-join list changes (add on join, remove on part) are persisted to the database for registered users.

## Assumptions

- The existing `Queries.list_pm_partners(nickname)` function returns partners sorted by most recent message. If it doesn't return in the expected format, it will need to be modified.
- The existing `restore_pm_conversations/2` in `Helpers.Persistence` already handles the DB query and PubSub subscription. The main gap is ensuring it's called at the right point in the mount lifecycle for identified users.
- The auto-join add/remove logic hooks into the existing `/join` and `/part` command handlers, which are separate Handler modules.
- The `apply_new_pm/3` function is the single entry point for all incoming PM messages and is where the auto-open logic needs to be added.
- Channel auto-add needs a flag (socket assign) to distinguish auto-join execution from user-initiated joins.
