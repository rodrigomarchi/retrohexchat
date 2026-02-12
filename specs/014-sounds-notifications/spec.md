# Feature Specification: Sounds & Notifications

**Feature Branch**: `014-sounds-notifications`
**Created**: 2026-02-12
**Status**: Draft
**Input**: User description: "Sounds & Notifications for RetroHexChat — per-event sound configuration, global mute toggle, visual flash/blink for treebar and title bar, PM typing indicator, sounds configuration dialog."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Per-Event Sound Configuration (Priority: P1)

A user wants to control which sounds play for different chat events. They open the Sounds configuration dialog (accessible from the Settings menu) and see a list of all event types: message, PM, highlight, join, part, kick, connect, disconnect, buddy online, buddy offline. Each event type has a dropdown to select from a set of available built-in sounds or "None" to disable sound for that event. The user assigns different sounds to different events based on their preference — for example, a subtle tone for regular messages and a more attention-grabbing alert for highlights and PMs. Changes take effect immediately and persist for registered users.

**Why this priority**: Sound customization is the core value proposition. The existing system plays hardcoded sounds for only 3 events. Giving users per-event control with a wider set of events (including connect, disconnect, buddy online/offline, part, kick) is the foundation upon which mute and other features build.

**Independent Test**: Can be fully tested by opening the Sounds dialog, changing sound assignments for each event type, triggering each event, and verifying the correct sound plays. Delivers immediate value by letting users tailor their audio experience.

**Acceptance Scenarios**:

1. **Given** a user opens the Sounds configuration dialog, **When** they view the event list, **Then** they see all 10 event types with their current sound assignments displayed in dropdowns.
2. **Given** a user selects a new sound for the "highlight" event, **When** they trigger a highlight (someone mentions their nick in a channel), **Then** the newly selected sound plays instead of the previous one.
3. **Given** a user sets "None" for the "join" event, **When** another user joins a channel, **Then** no sound plays for that event.
4. **Given** a registered user configures sound preferences, **When** they reconnect later, **Then** their sound preferences are restored from their saved settings.
5. **Given** a guest user configures sound preferences, **When** they remain connected, **Then** their preferences are applied for the duration of the session.
6. **Given** a user opens the Sounds dialog, **When** they click a "Preview" button next to a sound dropdown, **Then** the selected sound plays immediately so the user can hear it before committing.
7. **Given** a user changes several sound assignments in the dialog, **When** they click Cancel, **Then** all changes are discarded and the previous sound assignments remain active.
8. **Given** a user changes sound assignments and clicks Apply, **When** they continue making more changes and then click Cancel, **Then** only the changes made after Apply are discarded; the Apply'd changes persist.

---

### User Story 2 - Global Mute Toggle (Priority: P2)

A user is in a meeting or quiet environment and wants to silence all sounds at once without changing their per-event configuration. They click a mute button in the status bar area. The mute icon updates to show the muted state (e.g., a speaker icon with a strike-through). All event sounds stop playing immediately. When the meeting ends, they click the mute button again to unmute. All their per-event sound settings resume as configured. The mute state persists across page reloads.

**Why this priority**: Mute is a critical quality-of-life feature that works hand-in-hand with sound configuration. Without mute, users in quiet environments would need to individually disable every event sound and re-enable them later.

**Independent Test**: Can be fully tested by toggling the mute button, triggering various events, and verifying no sounds play while muted. After unmuting, sounds resume. Reload the page and verify mute state persists.

**Acceptance Scenarios**:

1. **Given** sounds are not muted, **When** the user clicks the mute button, **Then** the mute icon changes to indicate muted state and no sounds play for any event.
2. **Given** sounds are muted, **When** the user clicks the mute button again, **Then** the mute icon changes to indicate unmuted state and sounds resume according to per-event settings.
3. **Given** sounds are muted, **When** the user reloads the page, **Then** the muted state is preserved and the mute icon shows muted.
4. **Given** sounds are muted, **When** a highlight event occurs, **Then** no sound plays but the visual notification (treebar flash, title bar activity) still works.

---

### User Story 3 - Visual Activity Indicators (Priority: P3)

A user has multiple channels and PM conversations open. While viewing one channel, a new message arrives in another channel. The treebar entry for that channel visually flashes or pulses to draw attention. If the browser tab is not focused, the browser title bar alternates between the default title and a notification message (e.g., "* New activity - RetroHexChat"). When the user switches to the channel with new activity, the flashing stops immediately. The same behavior applies for PM conversations. Visual flashing can be enabled or disabled per event type in the Sounds configuration dialog (a "Flash" checkbox next to each event's sound dropdown).

**Why this priority**: Visual indicators complement audio notifications and are essential for users who mute sounds. They provide awareness of activity across multiple conversations without requiring the user to constantly check each one.

**Independent Test**: Can be fully tested by sending messages to non-active channels/PMs and verifying treebar entries flash. Switch to the active channel and verify flashing stops. Test with browser tab unfocused to verify title bar alternation.

**Acceptance Scenarios**:

1. **Given** the user is viewing channel #general, **When** a new message arrives in channel #random, **Then** the #random entry in the treebar flashes/pulses visually.
2. **Given** the treebar entry for #random is flashing, **When** the user clicks on #random to switch to it, **Then** the flashing stops immediately.
3. **Given** the browser tab is not focused and a new message arrives in any channel, **When** the title bar is checked, **Then** it alternates between the default title and an activity indicator.
4. **Given** the browser tab regains focus and the user is viewing the channel with new activity, **When** the tab becomes active, **Then** the title bar returns to normal.
5. **Given** a user has disabled the "Flash" option for "join" events in settings, **When** a user joins a non-active channel, **Then** no treebar flash occurs for that event.
6. **Given** a PM arrives from a user not currently being viewed, **When** the treebar is checked, **Then** the PM entry flashes/pulses.

---

### User Story 4 - PM Typing Indicator (Priority: P4)

A user is in a PM conversation with another user. When the other user starts typing a message, a subtle "Alice is typing..." indicator appears below the message area in the PM view. The indicator disappears after a few seconds of inactivity (the other user stopped typing) or when the other user sends their message. If both users are typing simultaneously, both see each other's typing indicators. The typing indicator only appears in PM conversations, not in channels.

**Why this priority**: Typing indicators are a modern chat expectation that improves the conversational flow in PMs. It's lower priority because it requires real-time bidirectional communication and only applies to PM conversations.

**Independent Test**: Can be fully tested by having two users in a PM conversation. User A types in the input field, User B sees "Alice is typing..." appear. User A stops typing, the indicator disappears after a timeout. User A sends the message, the indicator disappears immediately.

**Acceptance Scenarios**:

1. **Given** User A and User B are in a PM conversation, **When** User A starts typing, **Then** User B sees "Alice is typing..." below the message area within 1-2 seconds.
2. **Given** the typing indicator is showing for User A, **When** User A stops typing for 5 seconds, **Then** the typing indicator disappears from User B's view.
3. **Given** the typing indicator is showing for User A, **When** User A sends their message, **Then** the typing indicator disappears immediately from User B's view.
4. **Given** both User A and User B are typing simultaneously, **When** they check each other's views, **Then** both see the other's typing indicator.
5. **Given** User A types and then deletes all text without sending, **When** the typing timeout expires, **Then** the typing indicator disappears (no false "typed then deleted" leak).
6. **Given** User A and User B are in a channel conversation (not PM), **When** User A types, **Then** no typing indicator is shown to anyone in the channel.
7. **Given** User A has User B on their ignore list, **When** User B types in a PM, **Then** User A does not see the typing indicator.

---

### Edge Cases

- **Multiple simultaneous notifications**: If messages arrive in several channels at once, all affected treebar entries flash independently.
- **Rapid channel switching**: If the user switches channels while flash animation is in progress, the animation stops immediately for the old channel.
- **Sound playback overlap**: If multiple events trigger sounds in rapid succession, the system handles them gracefully (sounds may overlap but should not cause errors or queue indefinitely).
- **Browser tab unfocused during mute**: Title bar activity indicators still work even when sounds are muted (visual indicators are independent of mute state).
- **Disconnection during typing**: If a user disconnects while their typing indicator is showing, the indicator disappears within the normal timeout period.
- **PM with self**: No typing indicator is shown if a user somehow initiates a PM with themselves.
- **Sound dialog while sounds play**: Opening or closing the sounds dialog does not interrupt currently playing sounds.
- **Default sounds**: New users (or users who never configured sounds) get sensible default sound assignments for all events.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a Sounds configuration dialog accessible from the Settings menu, listing all 10 event types: message, PM, highlight, join, part, kick, connect, disconnect, buddy online, buddy offline.
- **FR-002**: Each event type in the Sounds dialog MUST have a dropdown to select from a catalog of 12+ built-in sounds (with variations such as Ding Low/High, Chime Short/Long) or "None" to disable.
- **FR-003**: Each event type in the Sounds dialog MUST have a "Flash" toggle to enable/disable visual flash for that event type.
- **FR-004**: The Sounds dialog MUST include a "Preview" button for each event so users can hear the selected sound before applying.
- **FR-005**: The Sounds dialog MUST use OK/Cancel/Apply buttons following the Windows 98 convention: OK saves changes and closes the dialog, Apply saves changes and keeps the dialog open, Cancel discards unsaved changes and closes the dialog. Sound preferences take effect upon OK or Apply (no restart or page reload required).
- **FR-006**: Sound preferences MUST persist across sessions for registered users.
- **FR-007**: Sound preferences MUST be held in memory for guest users during their session.
- **FR-008**: System MUST provide a global mute toggle accessible in the status bar area.
- **FR-009**: The mute toggle MUST display a clear visual indicator of the current mute state (muted vs. unmuted icon).
- **FR-010**: When muted, no event sounds MUST play regardless of per-event configuration.
- **FR-011**: Mute state MUST persist across page reloads.
- **FR-012**: Visual notifications (treebar flash, title bar) MUST NOT be affected by the mute state.
- **FR-013**: System MUST flash/pulse the treebar entry for any channel or PM that receives activity while not actively viewed, according to per-event flash settings.
- **FR-014**: Treebar flashing MUST stop immediately when the user switches to the affected channel or PM.
- **FR-015**: When the browser tab is unfocused and new activity arrives, the browser title bar MUST alternate between the default title and an activity notification message.
- **FR-016**: Title bar alternation MUST stop when the browser tab regains focus and the user is viewing the active conversation.
- **FR-017**: System MUST show a typing indicator ("NickName is typing...") in PM conversations when the other user is actively typing.
- **FR-018**: The typing indicator MUST appear within 1-2 seconds of the other user starting to type.
- **FR-019**: The typing indicator MUST disappear after 5 seconds of typing inactivity.
- **FR-020**: The typing indicator MUST disappear immediately when the other user sends their message.
- **FR-021**: Typing indicators MUST NOT appear in channel conversations (PM only).
- **FR-022**: The typing indicator MUST NOT reveal what the user is typing — only that they are typing.
- **FR-023**: If both users in a PM are typing simultaneously, both MUST see each other's typing indicators.
- **FR-024**: System MUST provide sensible default sound assignments for all event types for new users.
- **FR-025**: System MUST play connect and disconnect sounds when the user establishes or loses connection to the server.
- **FR-026**: Typing indicators MUST NOT be shown if the typing user is on the viewer's ignore list.

### Key Entities

- **Sound Preference**: A per-user mapping of event type to selected sound name (or "None") and flash enabled/disabled. One entry per event type per user. Registered users' preferences persist; guest preferences are session-scoped.
- **Mute State**: A per-user boolean flag indicating whether all sounds are silenced. Persists across page reloads via local browser storage.
- **Typing State**: A transient, in-memory indicator that a user is currently typing in a specific PM conversation. Not persisted. Expires after a short timeout.

## Clarifications

### Session 2026-02-12

- Q: What built-in sounds should be available in the sound catalog? → A: Large catalog (~12+ sounds) including variations (e.g., Ding Low/High, Chime Short/Long) for maximum customization.
- Q: How should the Sounds dialog handle saving changes? → A: OK/Cancel/Apply — classic Windows 98 pattern. OK saves & closes, Apply saves & keeps open, Cancel reverts.

## Assumptions

- The application provides a large fixed catalog of ~12+ built-in sounds with variations (e.g., Ding Low, Ding High, Chime Short, Chime Long, Beep, Buzz, Alert, Click, Ring, Notify, Blip, Whoosh). Users cannot upload custom sounds.
- The set of available sounds is the same for all users and all event types. Sounds are generated programmatically or bundled as small audio assets.
- Default sound assignments follow a pattern similar to classic mIRC: subtle sounds for common events (message, join), more prominent sounds for important events (PM, highlight).
- The typing indicator uses a simple "is typing" boolean signal broadcast over the existing real-time infrastructure. No throttle is needed beyond the natural input debounce — the indicator is sent when the user starts typing and a timeout handles cessation.
- Buddy online/offline events refer to the existing contact/address book system (feature 003). Sound plays when a user in the buddy list comes online or goes offline.
- The "Flash" per-event toggle defaults to enabled for PM, highlight, and buddy online events, and disabled for others.
- Title bar alternation uses a standard interval (e.g., every 1-2 seconds) and includes a generic message rather than revealing message content.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can configure sound preferences for all 10 event types within 30 seconds using the Sounds dialog.
- **SC-002**: Toggling mute silences all sounds within 1 second, and unmuting restores sounds immediately.
- **SC-003**: Mute state persists correctly across 100% of page reloads.
- **SC-004**: Visual activity indicators (treebar flash) appear within 1 second of a new event in a non-active channel or PM.
- **SC-005**: Treebar flashing stops within 500ms of switching to the affected channel or PM.
- **SC-006**: Title bar alternation activates within 2 seconds of an event arriving while the browser tab is unfocused.
- **SC-007**: Typing indicator appears within 2 seconds of the other user starting to type in a PM.
- **SC-008**: Typing indicator disappears within 1 second of the other user sending their message.
- **SC-009**: Sound preferences for registered users persist correctly across sessions with zero data loss.
- **SC-010**: All 10 event types trigger the correct configured sound (or no sound if set to "None") with 100% accuracy.
