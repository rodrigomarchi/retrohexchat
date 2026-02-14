# Quickstart: Contextual Tips & Progressive Disclosure

**Feature**: 029-contextual-tips | **Date**: 2026-02-14

## Prerequisites

- RetroHexChat dev environment running (`make server`)
- Branch `029-contextual-tips` checked out

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  LiveView (ChatLive)                                    │
│                                                         │
│  core_events.ex ──push_event("tip_trigger")──┐         │
│  helpers/channel.ex ─────────────────────────┤         │
│  pubsub_handlers/messages.ex ────────────────┤         │
│  command_dispatch.ex ────────────────────────┤         │
│                                              ▼         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  ContextualTipsHook (JS)                         │  │
│  │                                                  │  │
│  │  ┌─────────┐   ┌──────────┐   ┌──────────────┐  │  │
│  │  │ tips.js  │   │ toast.js │   │ localStorage │  │  │
│  │  │ (state)  │──▶│  (DOM)   │   │  (persist)   │  │  │
│  │  └─────────┘   └──────────┘   └──────────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  options_events.ex ──push_event("tips_toggle")──────┘  │
│                                                         │
│  toast.ex ── function component (mount point)           │
└─────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Server event** (message sent, channel joined, PM received, highlight detected, /help used) → LiveView pushes `tip_trigger` event to JS hook
2. **JS hook** receives trigger → checks `tips.js` for state (seen? suppressed? preempted?)
3. If tip should show → added to queue → `toast.js` creates DOM element
4. Toast displayed → auto-dismiss timer starts (8s)
5. User dismisses or timer fires → `tips.js` marks tip as seen in localStorage
6. Queue processes next tip after 2s gap
7. **Idle timer** (client-only) → fires after 30s of no interaction → triggers `idle_help` tip

## Key Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| State storage | localStorage only | Works for both guests and registered users; no DB migration needed |
| Toast rendering | JS DOM manipulation (hook) | Avoids server round-trips for purely client-side state |
| Trigger mechanism | `push_event` from existing handlers | Minimal intrusion — one line per trigger point |
| Dialog detection | DOM query for `.dialog-overlay` | Simple, reliable, no server coupling |
| Settings sync | `push_event` ↔ `pushEvent` | Options dialog reads state from hook on open |

## File Map

| File | Purpose | Layer |
|------|---------|-------|
| `assets/js/lib/tips.js` | Tip state logic, localStorage | Pure logic |
| `assets/js/lib/toast.js` | Toast DOM creation | Pure logic |
| `assets/js/hooks/contextual_tips_hook.js` | Event wiring, timers | Hook (wiring) |
| `assets/css/toast.css` | Toast positioning, animations | CSS Layer 4 |
| `lib/.../components/toast.ex` | Mount point component | Elixir |
| `lib/.../live/chat_live/tip_events.ex` | `tips_state_sync` handler | Elixir |
| `lib/.../live/chat_live/core_events.ex` | Add `tip_trigger` push (first_message) | Elixir (modified) |
| `lib/.../live/chat_live/helpers/channel.ex` | Add `tip_trigger` push (first_join) | Elixir (modified) |
| `lib/.../live/chat_live/pubsub_handlers/messages.ex` | Add `tip_trigger` push (first_pm, first_highlight) | Elixir (modified) |
| `lib/.../live/chat_live/command_dispatch.ex` | Add `tip_trigger` push (help_used) | Elixir (modified) |
| `lib/.../live/chat_live/options_events.ex` | Add tips toggle handler | Elixir (modified) |
| `lib/.../components/options_dialog.ex` | Add tips checkbox | Elixir (modified) |
| `lib/.../chat/help_topics.ex` | Add "Contextual Tips" help topic | Elixir (modified) |

## Testing Strategy

| Test File | Tests | Framework |
|-----------|-------|-----------|
| `test/lib/tips.test.js` | `isSuppressed`, `markTipSeen`, `shouldShowTip`, `markPreempted`, localStorage error handling | Vitest + jsdom |
| `test/lib/toast.test.js` | `createToastElement` structure, checkbox presence, button callbacks | Vitest + jsdom |
| `test/hooks/contextual_tips_hook.test.js` | `handleEvent` wiring, queue behavior, idle timer, dialog detection | Vitest + jsdom |
| `test/.../tip_events_test.exs` | `tips_state_sync` handler, `tips_toggle` propagation | ExUnit (LiveView) |
| `test/.../chat_live_test.exs` | Tip trigger pushes from existing handlers | ExUnit (integration) |
