# Quickstart: Status Bar & Loading States

**Feature**: 031-statusbar-loading-states
**Date**: 2026-02-15

## Prerequisites

- Elixir 1.17+ / OTP 27+ installed
- Node.js 18+ for asset compilation
- PostgreSQL running (existing database, no new migrations)
- Project dependencies installed (`mix deps.get && npm install --prefix apps/retro_hex_chat_web/assets`)

## Development Setup

```bash
# Ensure you're on the feature branch
git checkout 031-statusbar-loading-states

# Start the dev server
make server
# Visit http://localhost:4000
```

## Implementation Order

### Phase 1: Status Bar Enhancement (P1)

1. **Lib modules first** (testable logic):
   - `assets/js/lib/lag.js` — ping/pong timing calculation
   - `assets/js/lib/clock.js` — time formatting (HH:MM)

2. **JS tests**:
   - `assets/test/lib/lag.test.js`
   - `assets/test/lib/clock.test.js`

3. **Hooks** (wiring only):
   - `assets/js/hooks/lag_hook.js` — sends pings, receives pongs, pushes lag_update
   - `assets/js/hooks/clock_hook.js` — updates DOM every 30s

4. **Hook tests**:
   - `assets/test/hooks/lag_hook.test.js`
   - `assets/test/hooks/clock_hook.test.js`

5. **Server-side**:
   - `connection.ex` helper — handle_event for ping/pong/lag_update
   - Modify `status_bar.ex` — add lag, clock, connection_state attrs + sections
   - Modify `chat_live.ex` — new assigns, register hooks
   - CSS: update `shell.css` for 3-section layout

6. **Elixir tests**:
   - `status_bar_test.exs` — component rendering with new fields
   - `chat_live_test.exs` — ping/pong event handling

### Phase 2: Connection Banners (P2)

1. `assets/js/lib/connection_banner.js` — state machine logic
2. `assets/test/lib/connection_banner.test.js`
3. `assets/js/hooks/connection_banner_hook.js` — DOM wiring
4. `assets/test/hooks/connection_banner_hook.test.js`
5. `connection_banner.ex` — Elixir component
6. `connection-banner.css` — styles
7. `connection_banner_test.exs`

### Phase 3: Loading States (P3-P5)

1. `loading_spinner.ex` + `loading-spinner.css` — reusable spinner
2. `connection_progress.ex` + `connection-progress.css` — connection steps
3. Modify `chat_live.ex` — loading_channel assign
4. Modify `channel_list_live.ex` — async loading with progress
5. Tests for all components

### Phase 4: Help Topics & Polish

1. Update `help_topics.ex` — add Status Bar, Lag Indicator, Connection States topics
2. Final integration testing (E2E)

## Validation

```bash
# Compile first
mix compile --warnings-as-errors

# Then run all checks in parallel
mix format --check-formatted
mix credo --strict
make lint.js
make lint.css
npm test --prefix apps/retro_hex_chat_web/assets
mix test --include e2e
mix dialyzer
```

## Key Files to Understand

| File | Purpose |
|------|---------|
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/status_bar.ex` | Existing status bar component (will be enhanced) |
| `apps/retro_hex_chat_web/assets/js/hooks/reconnect_hook.js` | Existing reconnect overlay (must coexist with new banner) |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` | Main LiveView (new assigns + event handlers) |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` | Template (status bar rendering, banner placement) |
| `apps/retro_hex_chat_web/assets/css/shell.css` | Status bar CSS (needs 3-section layout) |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/channel_list_live.ex` | Channel list (needs async loading) |
