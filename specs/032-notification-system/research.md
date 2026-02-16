# Research: Notification System

**Branch**: `032-notification-system` | **Date**: 2026-02-15

## R1: Notification Dispatcher Architecture

**Decision**: Implement a client-side `NotificationDispatcher` in `assets/js/lib/notification_dispatcher.js` that receives a single `push_event("notify", payload)` from the server and fans out to all notification channels (toast, sound, title flash, browser notification, favicon badge, notification center).

**Rationale**: The server already determines *what* events matter (mentions, PMs, channel messages) and pushes events to the client. The routing decision (which notification channels to activate) depends heavily on client-side state: tab visibility, browser notification permission, DND mode, privacy mode. A client-side dispatcher avoids unnecessary round-trips and keeps the server lean.

**Alternatives considered**:
- Server-side dispatcher with multiple `push_event` calls per notification — rejected because it duplicates logic and increases message volume
- Separate hooks per notification type — rejected because it fragments the routing logic and makes DND/dedup harder

## R2: Notification Preferences Storage

**Decision**: Add a `notifications` key to the existing `UserPreferences` map (7th category alongside display, fonts, colors, connect, messages, key_bindings). Store in `message_settings` JSONB column (no new migration needed). For guests, mirror to localStorage under `retro_hex_chat_notification_prefs`.

**Rationale**: The existing `UserPreferences` module already manages 6 preference categories with in-memory CRUD + DB persistence. Adding a 7th follows the established pattern. Using the existing `message_settings` column avoids a new migration since notification settings are semantically related to message handling. The `muted_channels` list is already in `message_settings`.

**Alternatives considered**:
- New `notification_settings` JSONB column — rejected because it requires a new migration and the existing `message_settings` column is semantically appropriate
- Separate schema like `SoundSetting` — rejected because it fragments preferences further; the goal is to unify notification configuration
- New dedicated table — rejected for same fragmentation reason

**Note**: Per-channel notification levels will replace the simpler `muted_channels` list. The levels are: `"normal"`, `"mentions_only"`, `"mute"`. This is a superset of the current binary mute.

## R3: Browser Notification API Permission Flow

**Decision**: Use the standard `Notification.requestPermission()` API, triggered only from the Settings > Notifications panel when the user explicitly enables browser notifications. Store permission state in the notification preferences. Never auto-request on page load.

**Rationale**: Modern browsers (Chrome, Firefox, Safari) all support the Notifications API. Permission can be `"default"`, `"granted"`, or `"denied"`. The spec explicitly forbids requesting on page load, and browsers increasingly block unsolicited permission requests anyway.

**Alternatives considered**:
- Service Worker push notifications — explicitly out of scope per spec
- Requesting permission on first mention/PM — rejected because spec says "only after user explicitly enables in Settings"

## R4: Favicon Badge Implementation

**Decision**: Use a canvas-based approach in `assets/js/lib/favicon_badge.js`. Load the current favicon into an Image, draw it on a canvas, draw a red circle overlay at bottom-right, and set the `<link rel="icon">` href to the canvas data URL. Restore original on clear.

**Rationale**: This is the standard technique for dynamic favicon badges (used by Gmail, Slack, Discord). No external libraries needed. Works across all modern browsers. The favicon must be referenced via a `<link>` tag in the layout (currently missing — needs to be added).

**Alternatives considered**:
- Pre-made favicon variants (normal + badge) — rejected because it's inflexible and requires multiple icon files
- Third-party library (e.g., Favico.js) — rejected; the implementation is straightforward enough to do in ~50 lines

## R5: Toast Stacking (Max 3)

**Decision**: Extend the existing toast infrastructure to support multiple simultaneous toasts (max 3). Create a `NotificationToastHook` that manages a visible queue separate from the existing `ContextualTipsHook`. Notification toasts reuse `toast.js` DOM builders but have their own container and queue logic.

**Rationale**: The existing `ContextualTipsHook` manages contextual tips with single-toast display and checkbox functionality. Notification toasts are a different concern: they need stacking (up to 3), click-to-navigate, and no checkbox. Sharing the DOM builder library (`toast.js`) while having a separate hook avoids coupling the two systems.

**Alternatives considered**:
- Extending ContextualTipsHook to handle both — rejected because it would make the hook overly complex and mix two concerns
- Pure server-rendered toasts via LiveView — rejected because toast timing, stacking, and dismissal are inherently client-side concerns

## R6: Notification Center Panel

**Decision**: Implement as a dropdown panel anchored to the bell icon in the toolbar, similar to how context menus work. Server assigns hold notification entries (max 50, FIFO). The panel is a LiveView component rendered conditionally.

**Rationale**: Notification entries need to be clickable (navigate to channel/PM), which requires server interaction. Storing entries in socket assigns keeps them session-scoped and ephemeral. A dropdown panel is the standard UX pattern for notification centers.

**Alternatives considered**:
- Separate LiveView route/page — rejected; too heavy for a simple list
- Client-side only (localStorage) — rejected because entries need to trigger navigation via LiveView events

## R7: Do Not Disturb Persistence

**Decision**: DND state is stored as a boolean in notification preferences. For registered users, persisted in DB via `UserPreferences.save/2`. For guests, stored in localStorage. The client reads DND state on mount and the dispatcher checks it before firing any notification.

**Rationale**: DND must survive page reloads per spec. Using the same persistence mechanism as other notification preferences keeps things consistent.

**Alternatives considered**:
- localStorage only (even for registered users) — rejected because it wouldn't persist across devices/sessions
- Server-side timer with auto-disable — out of scope; DND is a simple toggle

## R8: Mention Detection Integration

**Decision**: Reuse the existing `Highlight.check/4` function which already detects nickname mentions and custom highlight words. The notification dispatcher receives a `highlighted` flag in the event payload (already set by `maybe_highlight/2` in session.ex). This flag determines whether to notify for "mentions only" channels.

**Rationale**: Mention detection is already implemented and battle-tested. The `highlighted` field is already present in message payloads. No new detection logic needed.

**Alternatives considered**:
- Separate mention detection for notifications — rejected; duplicates existing logic
- Client-side mention detection — rejected; the server already has this information
