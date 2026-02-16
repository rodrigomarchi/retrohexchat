# Quickstart: Notification System

**Branch**: `032-notification-system` | **Date**: 2026-02-15

## Overview

Unified notification system that routes chat events (mentions, PMs, channel messages, joins/leaves) through a central dispatcher to multiple notification channels: treebar badges, toast popups, sounds, title flash, browser notifications, favicon badge, and a notification center.

## Prerequisites

- Existing codebase on `main` branch with features up to 031
- PostgreSQL running with existing `user_preferences` table
- No new migrations required — extends existing `message_settings` JSONB column

## Architecture Summary

```text
┌─────────────────────────────────────────────────────────┐
│ Server (Elixir)                                         │
│                                                         │
│  PubSub Event → ChatLive handle_info                    │
│    → NotificationRouter.should_notify?/3                │
│    → Build payload + add to notification_entries         │
│    → push_event("notify", payload)                      │
│                                                         │
│  NotificationPreferences (domain module)                │
│    → CRUD for notification settings                     │
│    → Per-channel levels (normal/mentions/mute)          │
│    → Extends UserPreferences                            │
│                                                         │
└──────────────────────┬──────────────────────────────────┘
                       │ push_event("notify", ...)
                       ▼
┌─────────────────────────────────────────────────────────┐
│ Client (JavaScript)                                     │
│                                                         │
│  NotificationDispatcherHook                             │
│    → receives "notify" event                            │
│    → checks DND, active channel, channel level          │
│    → fans out to:                                       │
│      ├── notification_toast.js (max 3 visible)          │
│      ├── sound.js (existing, via SoundHook)             │
│      ├── title_flash.js (existing, via TitleFlashHook)  │
│      ├── browser_notification.js (Notification API)     │
│      ├── favicon_badge.js (canvas overlay)              │
│      └── notification center badge (DOM update)         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Key Files to Create

### Domain Layer (`apps/retro_hex_chat/lib/retro_hex_chat/chat/`)

| File | Purpose |
|------|---------|
| `notification_preferences.ex` | In-memory CRUD for notification settings, defaults, validation |
| `notification_router.ex` | Pure function: given event + preferences → should_notify? + notification type |

### Web Layer (`apps/retro_hex_chat_web/`)

| File | Purpose |
|------|---------|
| `live/chat_live/helpers/notifications.ex` | Notification event handling in ChatLive (build payload, push_event) |
| `live/chat_live/event_handlers/notification_events.ex` | Handle notification-related client events (toggle_dnd, mark_all_read, etc.) |
| `components/notification_center.ex` | Notification center dropdown panel component |
| `components/notifications_panel.ex` | Settings > Notifications panel for options dialog |

### JavaScript (`apps/retro_hex_chat_web/assets/js/`)

| File | Purpose |
|------|---------|
| `lib/notification_dispatcher.js` | Core routing logic: receives event, checks prefs, fans out |
| `lib/notification_toast.js` | Toast queue management (max 3 visible), click-to-navigate |
| `lib/browser_notification.js` | Notification API wrapper: permission, show, fallback |
| `lib/favicon_badge.js` | Canvas-based favicon overlay |
| `lib/notification_prefs.js` | localStorage read/write for guest notification preferences |
| `hooks/notification_dispatcher_hook.js` | LiveView hook wiring for notification dispatcher |

### CSS (`apps/retro_hex_chat_web/assets/css/`)

| File | Purpose |
|------|---------|
| `notification-center.css` | Notification center dropdown panel styling |

### Tests

| File | Purpose |
|------|---------|
| `test/retro_hex_chat/chat/notification_preferences_test.exs` | Unit tests for preferences CRUD |
| `test/retro_hex_chat/chat/notification_router_test.exs` | Unit tests for routing decisions |
| `test/retro_hex_chat_web/live/chat_live/notification_test.exs` | LiveView integration tests |
| `assets/test/lib/notification_dispatcher.test.js` | JS unit tests for dispatcher logic |
| `assets/test/lib/notification_toast.test.js` | JS unit tests for toast queue |
| `assets/test/lib/browser_notification.test.js` | JS unit tests for browser notification wrapper |
| `assets/test/lib/favicon_badge.test.js` | JS unit tests for favicon badge |
| `assets/test/hooks/notification_dispatcher_hook.test.js` | JS hook wiring tests |

## Implementation Order

1. **NotificationPreferences** — domain module with defaults, CRUD, validation
2. **NotificationRouter** — pure routing logic (should_notify? given event + prefs)
3. **Notification helpers** — server-side event building + push_event in ChatLive
4. **NotificationDispatcher** (JS lib) — client-side fan-out logic
5. **NotificationToast** (JS lib) — toast queue with max 3
6. **BrowserNotification** (JS lib) — Notification API wrapper
7. **FaviconBadge** (JS lib) — canvas overlay
8. **NotificationDispatcherHook** — LiveView hook wiring
9. **Settings panel** — Notifications tab in options dialog
10. **Notification center** — bell icon + dropdown panel
11. **DND mode** — toolbar toggle + persistence
12. **Help topics** — documentation in help system

## Development Commands

```bash
# Run all checks (same as CI)
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
make lint.js
make lint.css
npm test --prefix apps/retro_hex_chat_web/assets
mix test --include e2e
mix dialyzer
```
