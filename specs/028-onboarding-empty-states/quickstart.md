# Quickstart: Onboarding & Empty States

**Feature**: 028-onboarding-empty-states
**Date**: 2026-02-14

## Prerequisites

- Elixir 1.17+ / OTP 27+
- Phoenix 1.8+ / LiveView 1.0+
- PostgreSQL 16+ (no new migrations needed)
- Node.js (for JS hook + test compilation)

## What This Feature Adds

1. **Welcome Wizard** — A 3-step retro-style wizard dialog in ConnectLive for first-time users
2. **Empty States** — Friendly placeholder messages in 4 empty containers (channel, nicklist, treebar, URL catcher)
3. **Post-Wizard Banner** — A one-time tip banner shown in ChatLive after wizard completion

## Key Files

### New Files

| File | Purpose |
|------|---------|
| `components/wizard_dialog.ex` | Wizard dialog component (3 steps) |
| `live/connect_live/wizard_events.ex` | Wizard event handler (attach_hook pattern) |
| `assets/js/hooks/onboarding_hook.js` | localStorage check + onboarding_complete flag |
| `assets/js/lib/onboarding.js` | Pure logic: localStorage read/write |
| `assets/css/wizard-dialog.css` | Wizard styling |
| `assets/css/empty-state.css` | Shared empty state styling |
| `assets/test/lib/onboarding.test.js` | JS lib tests |
| `assets/test/hooks/onboarding_hook.test.js` | JS hook tests |

### Modified Files

| File | Change |
|------|--------|
| `live/connect_live.ex` | Add wizard_mode assigns, attach OnboardingHook |
| `live/connect_live.html.heex` | Conditionally render wizard or simple form |
| `live/chat_live.ex` | Handle `onboarded` query param, `show_onboarding_tip` assign |
| `live/chat_live.html.heex` | Add onboarding tip banner, empty channel state |
| `components/treebar.ex` | Add empty state block |
| `components/nicklist.ex` | Add empty state block |
| `components/url_catcher_window.ex` | Add empty state block |
| `assets/js/app.js` | Register OnboardingHook |
| `assets/css/app.css` | Import empty-state.css, wizard-dialog.css |
| `chat/help_topics/*.ex` | Add onboarding help topics |

## Architecture Notes

- **No database changes** — onboarding state is localStorage only
- **Wizard lives in ConnectLive** — extends existing connect flow
- **Event hook pattern** — wizard events use `attach_hook` (same as options_events.ex)
- **Hook = wiring, lib = logic** — JS hook delegates to `lib/onboarding.js`
- **Empty states are conditional renders** — `:if` guards on empty assigns, auto-removed by LiveView reactivity

## Testing Strategy

- **Unit tests**: Wizard event handlers, nickname validation, channel selection logic
- **LiveView tests**: Wizard step navigation, empty state rendering, banner display
- **JS lib tests**: `onboarding.js` — localStorage read/write, first-visit detection
- **JS hook tests**: `onboarding_hook.js` — mount behavior, event pushing
- **E2E tests**: Full wizard flow, empty state lifecycle, returning user bypass

## Running

```bash
make server          # Dev server at localhost:4000
# Clear localStorage in browser DevTools to re-trigger wizard
# Or open in incognito/private window
```
