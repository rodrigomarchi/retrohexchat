# Feature Specification: Flood Protection

**Feature Branch**: `013-flood-protection`
**Created**: 2026-02-12
**Status**: Draft
**Input**: User description: "Flood Protection for RetroHexChat — user-configurable flood thresholds, CTCP flood protection, auto-ignore on flood, anti-spam duplicate detection"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Anti-Spam Duplicate Detection (Priority: P1)

A user is in a channel where another user is sending the same message repeatedly, staying just under the existing rate limit but still being disruptive. The system detects that the same message (exact or near-exact duplicate) has been sent by the same sender 3 or more times within a 10-second window to the same target (channel or PM). The receiving user's client automatically blocks further duplicates from that sender, and the blocked messages are silently dropped — other users in the channel are not affected.

The sender receives a system message: "Your message was blocked (duplicate message detected)." This feedback is only visible to the sender. Other users see nothing — duplicates are simply not displayed.

**Why this priority**: Duplicate message spam is the most common and visible form of abuse that existing rate limits do not catch. This delivers immediate, tangible protection with minimal configuration needed.

**Independent Test**: Can be fully tested by having one user send the same message 3+ times in 10 seconds to a channel and verifying that the receiving user stops seeing duplicates after the threshold is hit, while the sender sees a block notification.

**Acceptance Scenarios**:

1. **Given** a user is in a channel, **When** another user sends the exact same message 3 times within 10 seconds to that channel, **Then** the 3rd and subsequent identical messages are not displayed to the receiving user
2. **Given** a user sends 2 identical messages within 10 seconds, **When** they send a 3rd identical message, **Then** the sender sees a system message "Your message was blocked (duplicate message detected)"
3. **Given** a user sends the same message to 2 different channels, **When** both sends occur within 10 seconds, **Then** neither message is blocked because they target different destinations
4. **Given** a system message or service notification is repeated, **When** it arrives at the user's client, **Then** it is never subject to spam detection and is always displayed

---

### User Story 2 - Auto-Ignore on Flood (Priority: P2)

When a user continues to flood despite duplicate detection (or floods with varied messages), the auto-ignore mechanism activates. After a configurable threshold of messages from the same sender within a time window is exceeded (default: 10 messages in 15 seconds), the flooding user is automatically added to the receiving user's ignore list for a configurable duration (default: 5 minutes).

A system message appears to the receiving user: "* SpamBot has been auto-ignored for flooding (5 minutes)." The ignored user receives no notification that they have been auto-ignored. After the timeout expires, the auto-ignore is automatically removed and messages from that user are displayed again.

**Why this priority**: Auto-ignore provides escalated protection when duplicate detection alone is insufficient. It leverages the existing ignore system, extending it with timed, automatic entries.

**Independent Test**: Can be fully tested by simulating a user sending more than 10 messages in 15 seconds and verifying the sender is auto-ignored for 5 minutes, then automatically un-ignored.

**Acceptance Scenarios**:

1. **Given** a user is in a channel with default flood settings, **When** another user sends more than 10 messages within 15 seconds, **Then** the flooding user is automatically added to the receiving user's ignore list for 5 minutes and a system message is displayed
2. **Given** a user has been auto-ignored, **When** 5 minutes elapse, **Then** the auto-ignore is automatically removed and messages from that user are visible again
3. **Given** a user has been auto-ignored, **When** the receiving user manually removes the ignore before the timer expires, **Then** the auto-ignore does not re-trigger immediately (a cooldown period of at least 60 seconds applies)
4. **Given** a user is auto-ignored, **When** the auto-ignore is active, **Then** the ignored user receives no notification that they have been auto-ignored

---

### User Story 3 - CTCP Flood Protection (Priority: P3)

A user receiving excessive CTCP requests (VERSION, PING, TIME, FINGER) from one or more sources finds that the system automatically limits CTCP replies. The receiving client sends at most 2 CTCP replies per 10-second window, regardless of how many requests arrive. Excess requests are silently dropped without sending a reply. This prevents the user's client from being used as a flood amplifier.

**Why this priority**: CTCP flooding is a known attack vector in chat systems. While existing CTCP rate limiting protects the sender side (limiting outgoing requests), this protects the receiver side (limiting outgoing replies to incoming requests).

**Independent Test**: Can be fully tested by sending 5+ CTCP requests to a user within 10 seconds and verifying that only the first 2 receive replies.

**Acceptance Scenarios**:

1. **Given** a user has CTCP enabled with default settings, **When** they receive 5 CTCP requests within 10 seconds, **Then** only the first 2 requests receive replies and the remaining 3 are silently dropped
2. **Given** a user has CTCP reply limiting active, **When** 10 seconds pass after the last reply, **Then** the reply counter resets and new requests can receive replies
3. **Given** a user has customized their CTCP reply limit to 4 per 10 seconds, **When** they receive 6 CTCP requests in 10 seconds, **Then** only the first 4 receive replies

---

### User Story 4 - Flood Protection Settings Dialog (Priority: P4)

Users can customize all flood protection parameters through a configuration dialog accessible from the settings menu. The dialog presents all configurable thresholds with sensible defaults. Settings persist across sessions for registered users and remain in memory for guests.

Configurable settings include: message flood threshold (messages per time window), time window duration, auto-ignore duration, CTCP reply limit and window, and spam detection threshold (duplicate count and window). Each setting displays its current value and default, with the ability to reset to defaults.

**Why this priority**: While sensible defaults make the system work out of the box for most users, power users need the ability to fine-tune thresholds to match their tolerance and usage patterns.

**Independent Test**: Can be fully tested by opening the settings dialog, modifying each threshold, verifying changes persist after page reload (for registered users), and confirming the modified thresholds are applied in flood detection.

**Acceptance Scenarios**:

1. **Given** a registered user opens the flood protection settings dialog, **When** they change the auto-ignore duration to 10 minutes and save, **Then** the new value is persisted and used for subsequent auto-ignore events
2. **Given** a guest user modifies flood protection settings, **When** they remain connected, **Then** the settings are applied; **When** they disconnect, **Then** the settings revert to defaults
3. **Given** a user opens the settings dialog, **When** they click "Reset to Defaults", **Then** all flood protection settings return to their default values
4. **Given** a user has never changed flood protection settings, **When** flood protection activates, **Then** it uses the default values (10 messages/15 seconds for flood, 3 duplicates/10 seconds for spam, 5-minute auto-ignore, 2 CTCP replies/10 seconds)

---

### Edge Cases

- **Own messages rate-limited**: When a user's own messages are blocked by the existing rate limiter (5 msgs/sec), this must NOT trigger the auto-ignore mechanism against themselves. The existing rate limit and flood protection are separate systems.
- **Manual un-ignore with cooldown**: If a user manually removes an auto-ignore entry before the timer expires, a cooldown period of at least 60 seconds prevents the auto-ignore from immediately re-triggering for the same sender.
- **Different target exemption**: Identical messages sent to different channels or different PM recipients are not counted together for duplicate detection. Each target maintains its own duplicate tracking.
- **System message exemption**: Messages from the system (join/part/quit notifications, server notices, service bot messages) are never subject to flood or spam detection.
- **Session boundary**: Flood counters and duplicate tracking reset when a user disconnects and reconnects. Auto-ignore entries that have been persisted (registered users) survive reconnection until their timer expires.
- **Ignore list interaction**: If a user is already on the manual ignore list, auto-ignore does not create a duplicate entry. If the existing ignore has no expiration, auto-ignore does not override it.
- **Tracker memory bounds**: Flood and duplicate trackers track at most 50 distinct senders per user. When the cap is reached, the oldest sender entry is evicted. This prevents unbounded memory growth in busy channels while retaining tracking for recent, relevant senders.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST detect duplicate messages from the same sender to the same target (channel or PM) within a configurable time window (default: 10 seconds) and block display after a configurable threshold (default: 3 identical messages)
- **FR-002**: System MUST provide feedback to the sender when their message is blocked as a duplicate, via a system message visible only to the sender: "Your message was blocked (duplicate message detected)"
- **FR-003**: System MUST automatically add a flooding user to the receiving user's ignore list when the flood threshold is exceeded (default: 10 messages in 15 seconds from the same sender)
- **FR-004**: Auto-ignore entries MUST have a configurable duration (default: 5 minutes) and be automatically removed when the timer expires
- **FR-005**: System MUST NOT notify the auto-ignored user that they have been ignored
- **FR-006**: System MUST enforce a cooldown period (minimum 60 seconds) after a manual un-ignore to prevent immediate re-triggering of auto-ignore for the same sender
- **FR-007**: System MUST limit outgoing CTCP replies to a configurable maximum per time window (default: 2 replies per 10 seconds), silently dropping excess requests
- **FR-008**: System MUST provide a settings dialog for users to configure all flood protection thresholds: message flood threshold, time window, auto-ignore duration, CTCP reply limit and window, and spam detection threshold and window
- **FR-009**: Flood protection settings MUST persist across sessions for registered users and remain in memory for guest users
- **FR-010**: System MUST exempt system messages, server notices, and service bot messages from all flood and spam detection
- **FR-011**: Duplicate detection MUST track messages per sender-target pair — identical messages sent to different targets MUST NOT be counted together
- **FR-012**: System MUST NOT block messages that merely contain similar words — only exact duplicate messages within the time window trigger spam detection
- **FR-013**: Auto-ignore MUST NOT trigger for a user's own messages being rate-limited by the existing rate limiter
- **FR-014**: If a user is already on the manual ignore list (without expiration), auto-ignore MUST NOT create a duplicate entry or override the existing one
- **FR-015**: System MUST display a system message to the receiving user when auto-ignore activates, in the format: "* {nickname} has been auto-ignored for flooding ({duration})"
- **FR-016**: System MUST include flood protection help topics in the Help system, covering commands, settings, and behavior
- **FR-017**: Flood and duplicate trackers MUST track at most 50 distinct senders per user, evicting the oldest entries when the cap is reached

### Key Entities

- **Flood Protection Settings**: Per-user configuration containing all threshold values (message flood threshold, flood time window, auto-ignore duration, CTCP reply limit, CTCP reply window, spam duplicate threshold, spam time window). Owned by a single user. Persists for registered users, in-memory for guests.
- **Auto-Ignore Entry**: A timed ignore list entry created automatically by the flood protection system. References the ignore list. Has an expiration timestamp and is automatically removed on expiry. Distinguished from manual ignore entries to support the cooldown mechanism.
- **Flood Tracker**: Per-user in-memory state that tracks incoming message counts per sender within the flood time window. Tracks at most 50 distinct senders simultaneously, evicting the oldest entries when the cap is reached. Resets on session disconnect. Used to determine when the flood threshold is exceeded.
- **Duplicate Tracker**: Per-user in-memory state that tracks recent message content per sender-target pair within the spam time window. Shares the 50-sender cap with the Flood Tracker. Resets on session disconnect. Used to detect exact duplicate messages.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users experiencing duplicate message spam see no more than the configured threshold number of identical messages (default: 3) from the same sender within any 10-second window
- **SC-002**: Auto-ignore activates within 1 second of the flood threshold being exceeded, and the user sees a notification confirming the action
- **SC-003**: Auto-ignored users are automatically un-ignored within 5 seconds of the configured duration expiring
- **SC-004**: CTCP reply flooding is eliminated — no more than the configured limit of replies (default: 2) are sent per 10-second window regardless of incoming request volume
- **SC-005**: Users can configure all flood protection settings in under 1 minute through the settings dialog
- **SC-006**: Flood protection operates with zero false positives on system messages — no system message is ever blocked by flood or spam detection
- **SC-007**: Settings changes take effect immediately without requiring reconnection or page reload
- **SC-008**: Registered users' flood protection settings persist correctly across disconnection and reconnection

## Clarifications

### Session 2026-02-12

- Q: Maximum number of distinct senders tracked per user in flood/duplicate trackers? → A: 50 senders, evicting oldest entries when cap is reached.

## Assumptions

- The existing ignore list system (006-ignore-system) supports timed entries with expiration — this is confirmed by the `expires_at` field in `IgnoreEntry`.
- Flood detection runs entirely on the receiving user's client (LiveView process), consistent with how the ignore system currently filters messages at the receiver side.
- The sender-side "blocked duplicate" notification is sent via the existing PubSub `"user:#{nickname}"` topic as a system-level message.
- "Near-exact duplicate" in the original description is interpreted as "exact duplicate" for implementation simplicity and to avoid false positives, consistent with the negative requirement that similar-but-different messages must not be blocked.
- The existing CTCP rate limiting on the sender side (3 requests per 30 seconds per target) remains unchanged; this feature adds receiver-side reply limiting as a complementary protection.
- Default values are chosen to balance protection with usability: aggressive enough to stop obvious flooding, lenient enough to not interfere with normal conversation patterns.
