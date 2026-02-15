# Feature Specification: Status Bar & Loading States

**Feature Branch**: `031-statusbar-loading-states`
**Created**: 2026-02-14
**Status**: Draft
**Input**: User description: "Status Bar & Loading States for RetroHexChat — enhanced status bar with lag indicator, connection states, clock, loading states for content areas, and connection banners for brief disconnections."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Enhanced Status Bar with Lag & Clock (Priority: P1)

A connected user sees a rich status bar at the bottom of the screen divided into three sections. The left section displays the active channel name and user count (e.g., "#general — 15 users"). The center section shows the current connection state with a colored indicator: connected (green), disconnected (red), or reconnecting (with countdown). The right section displays the measured round-trip latency (e.g., "Lag: 45ms") and a local clock (e.g., "14:32").

The lag value updates automatically at regular intervals (every 30-60 seconds) and changes color based on thresholds: normal (under 200ms), warning/yellow (200-499ms), critical/red (500ms+). If a lag measurement times out, the display shows "Lag: ?" instead of a stale number.

**Why this priority**: The status bar is always visible and gives users continuous awareness of their connection quality and time. It is the foundation for all other connection-related feedback in this feature.

**Independent Test**: Can be fully tested by connecting a user, observing the three status bar sections, and verifying that lag measurements update periodically and the clock ticks in real time.

**Acceptance Scenarios**:

1. **Given** a user is connected to a channel with 15 members, **When** the status bar renders, **Then** the left section shows "#channel-name — 15 users", the center shows a green "Connected" indicator, and the right shows a lag value and current local time.
2. **Given** a user is connected, **When** the lag measurement completes with a round-trip of 250ms, **Then** the lag display shows "Lag: 250ms" in a warning color (yellow).
3. **Given** a user is connected, **When** the lag measurement completes with a round-trip of 600ms, **Then** the lag display shows "Lag: 600ms" in a critical color (red).
4. **Given** a user is connected, **When** a lag measurement does not receive a response within a reasonable timeout, **Then** the lag display shows "Lag: ?" or "Lag: Timeout".
5. **Given** a user is connected, **When** 1 minute passes, **Then** the clock value in the status bar has updated to reflect the current local time.
6. **Given** a user is connected, **When** the status bar updates with new lag or clock values, **Then** the layout does not shift or cause visual glitches.

---

### User Story 2 - Connection Banners for Brief Disconnections (Priority: P2)

When a user loses their connection after having been connected, a colored banner appears at the top of the chat area. The banner shows a red disconnection message with a countdown timer (e.g., "Disconnected — Reconnecting in 5s..."). Once the connection is restored, the banner turns green with a success message (e.g., "Reconnected!") and automatically fades out after 3 seconds.

This banner is designed for brief interruptions and complements the existing full-screen reconnect overlay which handles extended disconnections. The banner does not appear for very brief disconnections (under 1 second) to avoid visual flicker, and does not appear during the initial page load (only after a connection has been established and then lost).

**Why this priority**: Connection loss is disorienting. A banner provides immediate, non-blocking feedback about what is happening and when to expect recovery, without the heavy-handedness of a full overlay.

**Independent Test**: Can be tested by simulating a brief network interruption after a user is connected, verifying the red banner appears (not instantly — only after 1 second), verifying the countdown ticks, and verifying the green success banner appears and fades after reconnection.

**Acceptance Scenarios**:

1. **Given** a user has an established connection, **When** the connection drops for more than 1 second, **Then** a red banner appears at the top of the chat area showing a disconnection message with a countdown.
2. **Given** a disconnection banner is visible, **When** the connection is restored, **Then** the banner changes to a green success message and fades out after 3 seconds.
3. **Given** a user has an established connection, **When** the connection drops for less than 1 second and recovers, **Then** no banner is shown.
4. **Given** a user is loading the page for the first time (no prior established connection), **When** the initial connection is being established, **Then** no disconnection banner is shown.
5. **Given** a disconnection banner is visible, **When** the user switches channels or types a message, **Then** the banner does not block any user interaction.
6. **Given** a disconnection lasts long enough for the existing full reconnect overlay to appear, **When** the overlay is shown, **Then** the banner is hidden or not duplicated — only one feedback mechanism is active at a time.

---

### User Story 3 - Connection Progress Indicator (Priority: P3)

During the initial connection sequence, users see a step-by-step progress indicator showing what the system is doing. Each step shows its status: completed (checkmark) or in progress (spinner/hourglass). Steps include DNS resolution, connecting to the server, and waiting for a server response. This replaces a blank screen during the connection phase.

**Why this priority**: Initial connection only happens once per session, but a blank screen during this phase creates a poor first impression and anxiety about whether the application is working.

**Independent Test**: Can be tested by observing the connection sequence on a fresh page load and verifying each step transitions from "in progress" to "completed" as the connection progresses.

**Acceptance Scenarios**:

1. **Given** a user opens the application, **When** the connection sequence begins, **Then** a progress indicator appears showing the first step as "in progress".
2. **Given** the connection sequence is underway, **When** a step completes, **Then** that step shows a checkmark and the next step begins.
3. **Given** all connection steps complete successfully, **When** the user is fully connected, **Then** the progress indicator disappears and the normal chat interface is shown.
4. **Given** a connection step takes longer than 30 seconds, **When** the timeout is reached, **Then** a retry option is shown to the user.

---

### User Story 4 - Channel History Loading Spinner (Priority: P4)

When a user switches to a channel that needs to load message history, a spinner appears centered in the chat area with a descriptive message (e.g., "Loading messages..."). The spinner disappears when messages appear. If the user switches channels rapidly, the loading state updates to reflect the most recently selected channel, cancelling the previous load.

**Why this priority**: Channel switching is a frequent action. A spinner prevents user confusion about blank chat areas and confirms the system is working.

**Independent Test**: Can be tested by switching to a channel with message history and verifying the spinner appears, then disappears when messages load.

**Acceptance Scenarios**:

1. **Given** a user clicks on a channel that has not yet loaded its message history, **When** the channel is selected, **Then** a spinner with "Loading messages..." appears centered in the chat area.
2. **Given** a channel is loading messages, **When** the messages finish loading, **Then** the spinner disappears and messages are displayed.
3. **Given** a channel is loading messages, **When** the user rapidly switches to a different channel, **Then** the spinner updates to show loading for the new channel and the previous load is cancelled.
4. **Given** a channel is loading messages, **When** 30 seconds pass without messages appearing, **Then** a retry option is shown.
5. **Given** a channel is loading messages, **When** the user types in the input area or clicks other UI elements, **Then** the spinner does not block these interactions.

---

### User Story 5 - Channel List Loading Progress Bar (Priority: P5)

When the full channel list is being fetched, a progress bar shows the loading status with a count of channels found so far (e.g., "Fetching channels... 1,247 found"). The progress bar grows as more channels are discovered.

**Why this priority**: The channel list fetch is an infrequent but potentially long operation. Progress feedback prevents the user from thinking the system is frozen.

**Independent Test**: Can be tested by triggering a channel list fetch and verifying the progress bar appears with an updating count.

**Acceptance Scenarios**:

1. **Given** a user requests the full channel list, **When** the fetch begins, **Then** a progress bar appears with an initial message and count starting at 0.
2. **Given** the channel list is being fetched, **When** new channels are received, **Then** the count updates and the progress bar grows.
3. **Given** the channel list fetch completes, **When** all channels are received, **Then** the progress bar disappears and the full list is displayed.
4. **Given** the channel list is being fetched, **When** 30 seconds pass without completion, **Then** a retry option is shown.

---

### Edge Cases

- What happens when the lag measurement response never arrives? Display "Lag: ?" or "Lag: Timeout" instead of a stale value.
- What happens if the connection drops and reconnects multiple times in quick succession? The banner should debounce — only show for disconnections lasting more than 1 second, and each reconnection resets the banner state.
- What happens if the user switches channels very rapidly while history is loading? Only the most recent channel's loading state should be active; previous loads are cancelled.
- What happens if the clock's timezone changes (e.g., user travels)? The clock uses the browser's local time, which auto-adjusts.
- What happens if the connection drops during channel history loading? The loading spinner should transition to show the disconnection state, and loading resumes after reconnection.
- What happens if the status bar content is too wide for the screen? Text should truncate gracefully (e.g., channel name ellipsis) without causing layout shifts.

## Requirements *(mandatory)*

### Functional Requirements

**Status Bar — Lag Indicator**

- **FR-001**: System MUST measure round-trip latency between the client and server at regular intervals (every 30-60 seconds).
- **FR-002**: System MUST display the measured latency value in the status bar right section (e.g., "Lag: 45ms").
- **FR-003**: System MUST color-code the lag display: normal (under 200ms), warning/yellow (200-499ms), critical/red (500ms and above).
- **FR-004**: System MUST display "Lag: ?" or "Lag: Timeout" when a measurement does not receive a response within a reasonable period.
- **FR-005**: Lag measurement MUST NOT create excessive network traffic — intervals must be no shorter than 30 seconds.

**Status Bar — Connection State**

- **FR-006**: System MUST display the current connection state in the status bar center section using one of four states: Connected, Disconnected, Reconnecting (with countdown), and Connecting.
- **FR-007**: Each connection state MUST have a distinct visual indicator (color-coded icon/symbol).
- **FR-008**: The Reconnecting state MUST display a countdown timer showing seconds until the next reconnection attempt.

**Status Bar — Clock**

- **FR-009**: System MUST display the current local time in the status bar right section in HH:MM format.
- **FR-010**: The clock MUST update every minute to reflect the current time.
- **FR-011**: The clock MUST use the user's local browser timezone.

**Status Bar — General**

- **FR-012**: Status bar updates MUST NOT cause layout shifts or visual glitches.
- **FR-013**: The status bar left section MUST continue to display the active channel name and user count.

**Connection Banners**

- **FR-014**: System MUST display a red disconnection banner at the top of the chat area when the connection drops after having been established, but only after the disconnection persists for more than 1 second.
- **FR-015**: The disconnection banner MUST show a countdown timer indicating seconds until the next reconnection attempt.
- **FR-016**: System MUST display a green reconnection success banner when the connection is restored, which auto-fades after 3 seconds.
- **FR-017**: The disconnection banner MUST NOT appear during the initial page load (before the first successful connection).
- **FR-018**: The banner MUST NOT overlap with or duplicate the existing full-screen reconnect overlay — the banner handles brief interruptions, the overlay handles extended disconnections.
- **FR-019**: Banners MUST NOT block user interactions (typing, switching channels, clicking UI elements).

**Loading States — Connection Progress**

- **FR-020**: System MUST display a step-by-step progress indicator during the initial connection sequence.
- **FR-021**: Each connection step MUST show its current status: completed (checkmark) or in progress (spinner/hourglass).
- **FR-022**: If any connection step exceeds 30 seconds, the system MUST display a retry option.

**Loading States — Channel History**

- **FR-023**: System MUST display a centered spinner with descriptive text (e.g., "Loading messages...") when a channel's message history is being loaded.
- **FR-024**: The spinner MUST disappear when messages are displayed.
- **FR-025**: When the user switches channels rapidly during a history load, the system MUST cancel the previous load and show loading state for the new channel.
- **FR-026**: If history loading exceeds 30 seconds, the system MUST display a retry option.
- **FR-027**: The loading spinner MUST NOT block user interactions.

**Loading States — Channel List**

- **FR-028**: System MUST display a progress bar when fetching the full channel list.
- **FR-029**: The progress bar MUST show a running count of channels found so far.
- **FR-030**: If the channel list fetch exceeds 30 seconds, the system MUST display a retry option.

### Key Entities

- **Connection State**: Represents the current state of the user's connection. States: Connecting, Connected, Disconnected, Reconnecting. Includes metadata such as reconnect countdown and attempt number.
- **Lag Measurement**: A periodic round-trip time measurement between client and server. Attributes: value (milliseconds or timeout), timestamp, severity level (normal/warning/critical).
- **Loading State**: Represents an in-progress content loading operation. Types: connection progress, channel history, channel list. Attributes: type, status (loading/complete/timeout), progress count (for channel list), associated channel (for history).
- **Connection Banner**: A transient notification about connection state changes. Attributes: type (disconnected/reconnected), countdown value, visibility state, fade timer.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can see their current connection latency at all times while connected, with the lag value refreshing at least once per minute.
- **SC-002**: Users can distinguish between 4 connection states (connecting, connected, disconnected, reconnecting) at a glance via distinct visual indicators in the status bar.
- **SC-003**: Users see the current local time in the status bar, accurate to the minute.
- **SC-004**: When a brief disconnection occurs (1-10 seconds), users see a non-blocking banner within 1 second of the disconnection persisting, providing reconnection countdown information.
- **SC-005**: When reconnected after a brief disconnection, users see a success confirmation that auto-dismisses within 3 seconds.
- **SC-006**: During initial connection, users see step-by-step progress rather than a blank screen, with each step completing visually.
- **SC-007**: When switching channels, users see a loading indicator within 200ms if history is not immediately available, preventing blank chat areas.
- **SC-008**: During channel list fetching, users see a growing count of channels found, preventing the impression of a frozen interface.
- **SC-009**: All loading indicators and banners are non-blocking — users can continue typing, switching channels, and interacting with the interface at all times during loading operations.
- **SC-010**: Status bar updates occur without any layout shifts or visual jumps.

## Assumptions

- The existing status bar layout can be extended to accommodate the new lag and clock sections without a complete redesign.
- The existing reconnect overlay (reconnect_hook.js) will remain as-is for extended disconnections; the new banner is an additional, complementary mechanism for brief interruptions.
- The threshold between "banner" (brief interruption) and "full overlay" (extended disconnection) is determined by the existing overlay's activation logic — the banner appears first and the overlay takes over if the disconnection persists.
- Lag is measured via a simple ping/pong mechanism between client and server — the server echoes a client-sent timestamp.
- The connection progress steps (DNS, connecting, waiting) are conceptual representations of the connection sequence, not necessarily tied to actual network-layer events (since the browser/framework handles the real connection).
- The channel list progress bar count increments as batches of channels are received, not individually.
- The lag measurement interval defaults to 30 seconds; this is not user-configurable (per scope exclusion).

## Scope

### In Scope

- Status bar lag display with color thresholds (normal/warning/critical)
- Detailed connection state indicators (4 states: connecting, connected, disconnected, reconnecting)
- Status bar clock (local time, HH:MM format)
- Connection progress indicator with steps during initial connection
- Channel history loading spinner
- Channel list loading progress bar with count
- Disconnection/reconnection banners for brief interruptions

### Out of Scope

- Network speed test
- Connection quality graph or historical lag data
- Status bar customization (layout is fixed)
- Modifying the existing full-screen reconnect overlay behavior
- User-configurable lag measurement intervals
- Server-side latency monitoring or logging
