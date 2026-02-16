# Feature Specification: Notification System

**Feature Branch**: `032-notification-system`
**Created**: 2026-02-15
**Status**: Draft
**Input**: User description: "Notification System for RetroHexChat — unified notification routing, toast popups, browser notifications, favicon badge, notification center, per-channel settings, and Do Not Disturb mode."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Notification Routing and Delivery (Priority: P1)

A user is chatting in #general. Someone mentions their nick in #dev (a channel they are not currently viewing). The system detects this as a notification-worthy event and simultaneously triggers multiple notification channels: the treebar item for #dev shows a red dot badge and increments the unread count, a toast popup appears at the bottom-right showing "Mario in #dev: Hey @YourNick, check this out!" which auto-dismisses after 5 seconds or can be clicked to navigate to #dev, a notification sound plays, and the title bar flashes. If the browser tab is in the background, a native browser notification also appears (if permission was previously granted). The favicon shows a small red dot overlay indicating unread activity.

**Why this priority**: This is the core value proposition — transforming fragmented notification pieces (sound, title flash, badges) into a unified system that routes events through a central dispatcher. Without this, no other notification feature works.

**Independent Test**: Can be fully tested by having two users in different channels, sending a mention, and verifying all notification outputs fire simultaneously. Delivers immediate value by giving users awareness of activity across channels.

**Acceptance Scenarios**:

1. **Given** a user is viewing #general and someone mentions their nick in #dev, **When** the mention message is sent, **Then** the treebar badge for #dev shows a red dot with incremented unread count, a toast popup appears with sender name/channel/message preview, a sound plays, the title flashes, and the favicon shows a red dot overlay.
2. **Given** a user is viewing #dev (the active channel), **When** someone sends a message in #dev, **Then** no toast, sound, title flash, or browser notification fires (the user can already see the message), but the message appears normally in the chat.
3. **Given** a user's browser tab is in the background and browser notification permission has been granted, **When** a notification-worthy event occurs, **Then** a native browser notification appears with the same content as the toast.
4. **Given** a user's browser tab is in the background and browser notification permission has NOT been granted, **When** a notification-worthy event occurs, **Then** only toasts, sounds, title flash, and favicon badge fire — no browser notification prompt appears.
5. **Given** a message triggers both a mention match and a PM notification, **When** the notification system processes it, **Then** only one notification fires (no duplicates).

---

### User Story 2 - Global and Per-Channel Notification Settings (Priority: P2)

A user opens Settings > Notifications. They see global toggles for Sounds enabled, Browser notifications (with a "Request permission" button if not yet granted), and Title flash. Below the global toggles, they see per-channel notification level settings for each channel they have joined: Normal (all messages trigger notifications), Mentions only (only messages containing their nick), or Mute (no notifications). PMs are always set to "Always" and cannot be muted. They also see notification trigger rules: checkboxes for "someone mentions my nick," "I receive a PM," "any message in a channel," and "someone joins/leaves." The user sets #general to "Mentions only" and mutes #music entirely.

**Why this priority**: Without configurable settings, the notification system would be all-or-nothing, quickly becoming annoying in active channels. Per-channel control is essential for a usable notification experience.

**Independent Test**: Can be tested by configuring per-channel settings, then sending messages in various channels and verifying that only the expected notifications fire based on the configured levels.

**Acceptance Scenarios**:

1. **Given** a user opens Settings > Notifications, **When** the panel loads, **Then** they see global toggles (Sounds, Browser notifications, Title flash) and a list of joined channels with Normal/Mentions only/Mute options, plus notification trigger rule checkboxes.
2. **Given** a user sets #general to "Mentions only," **When** a regular message (without their nick) is sent in #general, **Then** no toast, sound, or browser notification fires, but the unread badge still increments.
3. **Given** a user sets #general to "Mentions only," **When** a message containing their nick is sent in #general, **Then** all enabled notification channels fire.
4. **Given** a user mutes #music, **When** any message is sent in #music, **Then** no toast, sound, browser notification, or title flash fires, but the unread badge still increments silently.
5. **Given** a user has PMs set to "Always," **When** they attempt to change the PM notification level, **Then** the option is locked and cannot be changed to Mute.
6. **Given** browser notification permission has not been granted, **When** the user toggles "Browser notifications" on, **Then** the browser's native permission prompt appears. If denied, the toggle reverts to off and a message explains that only toasts will be used.
7. **Given** a registered user configures notification settings, **When** they log in from a different session, **Then** their settings persist (stored server-side).
8. **Given** a guest user configures notification settings, **When** they reload the page, **Then** their settings persist (stored in localStorage).

---

### User Story 3 - Do Not Disturb Mode (Priority: P3)

A user enables Do Not Disturb (DND) mode via a toggle in Settings > Notifications or a quick-access button in the toolbar. When DND is active, all toasts, sounds, title flashes, and browser notifications stop completely. However, unread badges continue to accumulate silently so the user can catch up later. A visual indicator in the toolbar shows that DND is active. DND mode survives page reloads.

**Why this priority**: DND is a critical usability feature that lets users focus without being interrupted, while still being able to catch up on missed activity later. It builds on the routing system (P1) and settings (P2).

**Independent Test**: Can be tested by enabling DND, sending multiple messages/mentions, and verifying that no audible or visual interruptions occur while badges still accumulate.

**Acceptance Scenarios**:

1. **Given** a user enables DND mode, **When** someone mentions their nick in any channel, **Then** no toast, sound, title flash, or browser notification fires.
2. **Given** DND mode is active, **When** messages arrive in various channels, **Then** treebar unread badges still increment normally.
3. **Given** DND mode is active, **When** the user reloads the page, **Then** DND mode remains active.
4. **Given** DND mode is active, **When** the user disables DND, **Then** notifications resume for new events (no retroactive notifications for messages received during DND).
5. **Given** DND mode is active, **When** the user looks at the toolbar, **Then** a visual indicator (e.g., a moon icon or "DND" label) is visible.

---

### User Story 4 - Favicon Badge (Priority: P4)

When there are unread notifications (mentions or PMs), the browser favicon displays a small red dot overlay. The badge persists across in-app navigations. When all notifications are read or cleared, the favicon returns to its normal state.

**Why this priority**: The favicon badge provides at-a-glance unread awareness even when the user is in a different browser tab, complementing browser notifications.

**Independent Test**: Can be tested by sending a mention, switching to another browser tab, and verifying the favicon shows a red dot, then clearing the notification and verifying it disappears.

**Acceptance Scenarios**:

1. **Given** no unread notifications exist, **When** the user views the browser tab icon, **Then** the normal favicon is displayed.
2. **Given** a mention or PM arrives in a non-active channel, **When** the user views the browser tab icon, **Then** the favicon shows a red dot overlay.
3. **Given** the favicon shows a red dot, **When** the user reads all unread messages (navigates to the channels), **Then** the favicon returns to normal.
4. **Given** the favicon shows a red dot, **When** the user navigates between channels within the app, **Then** the red dot persists until all notifications are cleared.

---

### User Story 5 - Notification Center (Priority: P5)

A user clicks a bell icon in the toolbar. A panel opens showing recent notifications in reverse chronological order, e.g., "2 min ago — Mario mentioned you in #dev," "5 min ago — PM from Alice: Hey!" Each entry is clickable to navigate to the relevant channel or PM. A "Mark all as read" button clears all badges and notification entries. The notification center shows a badge count on the bell icon when there are unread notifications.

**Why this priority**: The notification center provides a central place to review and act on missed activity, completing the notification experience. It depends on the routing system and settings being in place.

**Independent Test**: Can be tested by generating several notifications, opening the notification center, verifying entries appear in order, clicking entries to navigate, and using "Mark all as read."

**Acceptance Scenarios**:

1. **Given** the user has received 3 notifications (2 mentions, 1 PM), **When** they click the bell icon in the toolbar, **Then** a panel opens showing all 3 notifications in reverse chronological order with relative timestamps.
2. **Given** the notification center is open, **When** the user clicks a notification entry, **Then** the app navigates to the relevant channel/PM and that notification is marked as read.
3. **Given** the notification center shows multiple entries, **When** the user clicks "Mark all as read," **Then** all entries are cleared, all treebar badges reset, and the bell icon badge disappears.
4. **Given** there are 5 unread notifications, **When** the user views the toolbar, **Then** the bell icon shows a badge with the count "5."
5. **Given** the notification center has no entries, **When** the user opens it, **Then** an empty state message is displayed (e.g., "No notifications").

---

### User Story 6 - Privacy Mode for Notifications (Priority: P6)

A user enables privacy mode in notification settings. When active, toast popups and browser notifications show generic content like "New message in #dev" instead of revealing the actual message content or sender name. This prevents sensitive information from appearing in notifications visible to others who might see the user's screen.

**Why this priority**: Privacy mode is a refinement that protects sensitive information in shared environments. It builds on the core notification delivery system.

**Independent Test**: Can be tested by enabling privacy mode, sending a mention, and verifying that the toast and browser notification show generic content without message preview.

**Acceptance Scenarios**:

1. **Given** privacy mode is enabled, **When** a mention notification fires, **Then** the toast shows "New message in #channel" without message content or sender name.
2. **Given** privacy mode is enabled, **When** a browser notification fires, **Then** it shows "New message in #channel" without message content or sender name.
3. **Given** privacy mode is disabled, **When** a notification fires, **Then** the toast shows the full sender name, channel, and message preview.

---

### Edge Cases

- **Batch notifications on reconnect**: If many notifications arrive simultaneously (e.g., after reconnecting from being offline), the system batches them into a summary toast: "15 new messages in 3 channels" instead of showing individual toasts.
- **Toast queue limit**: No more than 3 toasts may be visible at once. Additional notifications are queued and shown as existing toasts dismiss.
- **Browser permission denied**: If the browser denies notification permission, the system falls back to toasts only and does not repeatedly prompt. The Settings toggle reflects the denied state.
- **Sound autoplay policy**: If sound playback fails due to browser autoplay policies, the system silently skips the sound without error messages.
- **Channel leave cleanup**: When a user leaves a channel, their per-channel notification settings for that channel are removed.
- **Favicon persistence**: The favicon red dot must persist across in-app navigations (SPA route changes) until cleared.
- **DND page reload persistence**: DND mode must survive page reloads (stored in localStorage for guests, server-side for registered users).
- **Browser notifications not requested on load**: The browser notification permission prompt must never appear on page load — only when the user explicitly enables browser notifications in Settings.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a central notification dispatcher that routes events to multiple notification channels (treebar badges, toasts, sounds, title flash, browser notifications, favicon badge) based on event type and user settings.
- **FR-002**: System MUST support three per-channel notification levels: Normal (all messages), Mentions only (messages containing the user's nick), and Mute (no notifications).
- **FR-003**: System MUST treat PMs as "Always" notification level that cannot be muted by the user.
- **FR-004**: System MUST provide global toggles for: sounds enabled, browser notifications, and title flash.
- **FR-005**: System MUST provide notification trigger rule checkboxes: mentions, PMs, any channel message, joins/leaves.
- **FR-006**: System MUST suppress all toasts, sounds, and browser notifications when the user has the notification's target channel actively focused.
- **FR-007**: System MUST deduplicate notifications — if an event matches multiple trigger rules (e.g., both a mention and a PM), only one notification fires.
- **FR-008**: System MUST limit visible toasts to a maximum of 3, queuing additional notifications.
- **FR-009**: Toast notifications MUST auto-dismiss after 5 seconds and be clickable to navigate to the source channel/PM.
- **FR-010**: System MUST provide Do Not Disturb mode that suppresses all toasts, sounds, title flashes, and browser notifications while allowing unread badges to accumulate.
- **FR-011**: DND mode MUST survive page reloads.
- **FR-012**: System MUST display a favicon red dot overlay when unread notifications exist, persisting across in-app navigations.
- **FR-013**: System MUST provide a notification center accessible via a bell icon in the toolbar, showing recent notifications in reverse chronological order with relative timestamps.
- **FR-014**: Notification center entries MUST be clickable to navigate to the relevant channel/PM.
- **FR-015**: System MUST provide a "Mark all as read" action in the notification center that clears all badges and notification entries.
- **FR-016**: System MUST request browser notification permission ONLY when the user explicitly enables browser notifications in Settings — never on page load.
- **FR-017**: If browser notification permission is denied, system MUST fall back to toasts only and not re-prompt.
- **FR-018**: System MUST batch notifications on reconnect into a summary toast (e.g., "15 new messages in 3 channels") when many arrive simultaneously.
- **FR-019**: System MUST provide a privacy mode that replaces notification content with generic messages (e.g., "New message in #channel") for toasts and browser notifications.
- **FR-020**: System MUST persist notification preferences server-side for registered users and in localStorage for guests.
- **FR-021**: System MUST clean up per-channel notification settings when a user leaves a channel.
- **FR-022**: System MUST display a badge count on the notification center bell icon showing the number of unread notifications.
- **FR-023**: System MUST show a visual DND indicator in the toolbar when Do Not Disturb is active.
- **FR-024**: System MUST silently skip sound playback if it fails due to browser autoplay policy restrictions.

### Key Entities

- **Notification Event**: A unit of notification activity — contains the event type (mention, PM, channel message, join/leave), source channel/PM, sender, message preview, and timestamp. Ephemeral (not persisted to database).
- **Notification Preferences**: A user's global and per-channel notification configuration — includes global toggles (sounds, browser notifications, title flash), per-channel levels (normal/mentions/mute), trigger rules, DND state, and privacy mode. Persisted server-side for registered users, localStorage for guests.
- **Notification Entry**: A record in the notification center — contains the notification event details plus read/unread status and relative timestamp. Kept in-memory per session (not persisted to database).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users receive coordinated notifications across all enabled channels (badge, toast, sound, title flash, browser notification, favicon) within 1 second of the triggering event.
- **SC-002**: Users can configure per-channel notification levels and have them take effect immediately — setting a channel to "Mentions only" results in zero non-mention notifications from that channel.
- **SC-003**: Enabling Do Not Disturb stops 100% of audible and visual interruptions (toasts, sounds, title flash, browser notifications) while unread badges continue to accumulate.
- **SC-004**: Users can review and act on all missed notifications from the notification center, with each entry navigating to the correct channel/PM on click.
- **SC-005**: No more than 3 toast notifications are visible simultaneously under any conditions, including burst scenarios.
- **SC-006**: Browser notification permission is requested zero times without explicit user action in Settings.
- **SC-007**: Privacy mode completely hides message content and sender names from all visible notifications (toasts and browser notifications).
- **SC-008**: Notification preferences persist across page reloads for both registered users and guests.

## Assumptions

- The existing toast component (Z15) supports stacking and dismissal behavior, or can be extended to support a maximum of 3 visible toasts with queuing.
- The existing treebar badge rendering (AB7) can be triggered by the new notification routing logic without modification to AB7's rendering code.
- The existing sound_hook.js and title_flash_hook.js can be orchestrated by the notification dispatcher via LiveView push_event calls.
- Notification entries in the notification center are kept in-memory per session and do not need to survive server restarts or session changes — this is acceptable for a chat application where notifications are ephemeral.
- The favicon badge is implemented as a canvas-drawn overlay on the existing favicon, which is a standard browser technique.
- A reasonable maximum for notification center entries is 50 most recent, with older entries being dropped (FIFO).

## Scope

### In Scope
- Notification routing logic to treebar badges (using AB7's rendering)
- Toast notification popups (using Z15's component)
- Browser native notifications with permission flow
- Favicon badge with red dot overlay
- Notification center panel with bell icon in toolbar
- Global notification settings (sounds, browser notifications, title flash)
- Per-channel notification levels (Normal / Mentions only / Mute)
- Notification trigger rules (mentions, PMs, channel messages, joins/leaves)
- Do Not Disturb mode with persistence and visual indicator
- Privacy mode for notification content
- Notification batching on reconnect

### Out of Scope
- Push notifications (service worker / mobile)
- Email notifications
- Notification sound customization (that is Category O)
- Notification scheduling
- Desktop app notifications (Electron/Tauri)
- Message threading or notification grouping by conversation
