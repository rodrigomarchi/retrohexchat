# Category AC: Notification System

**Priority**: Red (Critical — unified notification management)
**Dependencies**: AB (Visual Feedback) for unread badge rendering, Z2 (Contextual Tips) for toast component, O (Sounds & Notifications) for sound infrastructure
**Existing**: AC1 title flash (title_flash_hook.js), AC2 sound system (sound_hook.js)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AC1 | Title bar flash | Existing | Browser title alternates with activity indicator when tab is in background |
| AC2 | Sound system | Existing | Web Audio API synthesized sounds with 14 named sounds, respects mute from localStorage |
| AC3 | Notification routing to treebar | New | Event routing logic that decides when to update AB7's unread badges based on message type and channel |
| AC4 | Toast notification popup | New | retro design system mini-window popup for events like PM received, mentioned (reuses Z15 toast component) |
| AC5 | Browser notifications | New | Request permission + send native browser Notification API notifications when tab is in background |
| AC6 | Favicon badge | New | Red dot overlay on favicon via canvas when there are unread notifications |
| AC7 | Notification center | New | Panel listing recent notifications in reverse chronological order with mark-as-read |
| AC8 | Global notification settings | New | Toggles: sounds on/off, browser notifications on/off, title flash on/off |
| AC9 | Per-channel notification settings | New | Per channel: Normal (all) / Mentions only / Mute — stored in user preferences |
| AC10 | Notification trigger rules | New | Configure what triggers notifications: mentions, PMs, any message, join/part |
| AC11 | Do Not Disturb mode | New | DND suppresses all toasts, sounds, and browser notifications; badges still accumulate |

## Dependencies Detail

- AC1 (existing) provides title flash infrastructure — already toggles title on background tab activity
- AC2 (existing) provides complete sound generation via Web Audio API with 14 sounds and mute support
- AC3 (routing) decides WHEN to update badges — delegates the visual rendering to AB7 (Unread indicators)
- AC4 (toast popup) reuses the toast component created by Z15 (Contextual Tips)
- AC5 (browser notifications) requires Notification API permission request flow
- AC6 (favicon badge) uses canvas to dynamically modify the favicon
- AC8-AC10 (settings) integrate into U (Options Dialog) settings infrastructure

## Technical Notes

- Existing title_flash_hook.js alternates browser title between original and activity indicator on non-active channels
- Existing sound_hook.js uses Web Audio API with 14 synthesized sounds, respects localStorage mute setting
- Notification routing: centralized GenServer or module that receives events and dispatches to notification channels
- Toast notifications: reuse Z15 component, retro design system mini-window at bottom-right, stacked, auto-dismiss after 5s, max 3 visible
- Browser Notification API: request permission in Settings, fall back to toast-only if denied
- Favicon badge: create canvas, draw existing favicon, overlay red dot, update link[rel=icon] href
- Notification center: dropdown panel from bell icon in toolbar, lists last 50 notifications
- Per-channel settings: stored in user preferences (DB for registered, localStorage for guests)
- DND mode: global flag that short-circuits all notification output (but still tracks unreads)

---

## Spec Command

```
/speckit.specify "Notification System for RetroHexChat.

PROBLEM: The application has sound playback and title flash capabilities but lacks a unified notification system. There is no way to receive visual popup notifications for events, no browser native notifications when the tab is in background, no favicon badge to indicate unread activity, and no centralized way to configure notification preferences per channel. Users cannot set different notification levels for different channels (e.g., mute a noisy channel but get all notifications for PMs). There is no Do Not Disturb mode. The notification experience is fragmented rather than being a cohesive system.

EXISTING CONTEXT: (1) title_flash_hook.js alternates the browser title between the original title and an activity indicator when the tab is in the background, stopping when the user returns. (2) sound_hook.js uses the Web Audio API to generate synthesized notification sounds from a catalog of 14 named sounds (beep, ding_low, ding_high, chime variants, alert, buzz, click, ring, notify, blip, whoosh, none), respecting a mute setting stored in localStorage. (3) Category AB provides unread badge rendering in the treebar (AB7) — this category provides the routing logic that decides when to update those badges. (4) Category Z2 provides a reusable toast component (Z15) — this category reuses it for notification popups.

USER JOURNEY — NOTIFICATION CHANNELS: A user is chatting in #general. Someone mentions their nick in #dev (a channel they are not currently viewing). Several things happen simultaneously: (1) The treebar item for #dev shows a red dot badge and the unread count increments (via AB7's rendering, triggered by this category's routing logic). (2) A toast popup appears at the bottom-right: 'Mario in #dev: Hey @YourNick, check this out!' — it auto-dismisses after 5 seconds or the user clicks it to switch to #dev. (3) If the browser tab is in the background, a native browser notification appears with the same content. (4) The title bar flashes. (5) A notification sound plays. (6) The favicon shows a small red dot overlay.

USER JOURNEY — NOTIFICATION SETTINGS: The user opens Settings > Notifications. Global toggles: Sounds enabled (checkbox), Browser notifications (checkbox with 'Request permission' button if not yet granted), Title flash (checkbox). Below, per-channel settings: #general: Normal / Mentions only / Mute. #dev: Normal / Mentions only / Mute. PMs: Always (cannot mute). They set #general to 'Mentions only' — now only messages containing their nick trigger notifications from that channel. They mute #music entirely.

Notification trigger rules: Notify when — someone mentions my nick (checked), I receive a PM (checked), any message in a channel (unchecked), someone joins/leaves (unchecked).

They enable Do Not Disturb mode — all toasts, sounds, and browser notifications stop, but unread badges still accumulate silently.

USER JOURNEY — NOTIFICATION CENTER: The user clicks a bell icon in the toolbar. A panel opens showing recent notifications in reverse chronological order: '2 min ago — Mario mentioned you in #dev', '5 min ago — PM from Alice: Hey!'. Each entry is clickable to navigate to the relevant channel/PM. A 'Mark all as read' button clears all badges.

ACTORS: All notification features are available to any connected user. Notification preferences persist for registered users (DB) and in localStorage for guests. Browser notification permission is managed by the browser.

EDGE CASES: If the browser denies notification permission, fall back gracefully to toasts only — do not repeatedly ask. If many notifications arrive simultaneously (e.g., reconnecting after being offline), batch them into a summary toast: '15 new messages in 3 channels'. If the user has the channel active/focused, do not trigger toasts or sounds (they can already see the messages). The favicon badge must persist across SPA navigations. If sound playback fails (autoplay policy), silently skip. DND mode must survive page reloads. Per-channel settings for channels the user leaves should be cleaned up.

NEGATIVE REQUIREMENTS: Browser notifications must NOT be requested on page load — only after the user explicitly enables them in Settings. Notifications must NOT reveal message content if the user has configured privacy mode (show 'New message in #channel' instead). Sound notifications must NOT play when muted or in DND mode. The notification system must NOT create duplicate notifications — if a message triggers both a mention and a PM notification, only one should fire. Toast notifications must NOT exceed 3 visible at once.

SCOPE: In scope — notification routing logic to treebar badges (using AB7's rendering), toast notification popups (using Z15's component), browser native notifications with permission flow, favicon badge, notification center panel, global notification settings, per-channel settings (normal/mentions/mute), notification trigger rules, Do Not Disturb mode. Out of scope — push notifications (service worker/mobile), email notifications, notification sound customization (that is Cat O), notification scheduling."
```
