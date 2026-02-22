# Quickstart: 014 Sounds & Notifications

**Branch**: `014-sounds-notifications`

## Prerequisites

```bash
git checkout 014-sounds-notifications
make setup  # if first time
```

## Key Files to Create/Modify

### New Files (Domain Layer — `apps/retro_hex_chat/`)

| File | Purpose |
|------|---------|
| `lib/retro_hex_chat/chat/sound_settings.ex` | Domain module: new(), getters/setters, save/load, catalog |
| `lib/retro_hex_chat/chat/schemas/sound_setting.ex` | Ecto schema for `sound_settings` table |
| `priv/repo/migrations/TIMESTAMP_create_sound_settings.exs` | DB migration |
| `test/retro_hex_chat/chat/sound_settings_test.exs` | Unit tests for domain module |

### New Files (Web Layer — `apps/retro_hex_chat_web/`)

| File | Purpose |
|------|---------|
| `lib/retro_hex_chat_web/components/sound_settings_dialog.ex` | 2000s-erad Sounds dialog component |
| `assets/js/hooks/title_flash_hook.js` | JS hook for document.title alternation |
| `test/retro_hex_chat_web/live/sound_settings_test.exs` | LiveView tests for dialog |
| `test/retro_hex_chat_web/live/typing_indicator_test.exs` | LiveView tests for typing |
| `test/retro_hex_chat_web/live/visual_notifications_test.exs` | LiveView tests for flash/title |

### Modified Files

| File | Changes |
|------|---------|
| `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex` | Add `sound_settings` field + getter/setter |
| `apps/retro_hex_chat_web/assets/js/hooks/sound_hook.js` | Expand sound catalog, receive sound name instead of type |
| `apps/retro_hex_chat_web/assets/js/app.js` | Register `TitleFlashHook` |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex` | Dialog events, typing events, sound dispatch, flash logic |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/menu_bar.ex` | Add "Sounds" menu item to Tools menu |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/status_bar.ex` | Add mute toggle button |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar.ex` | Add `flash_channels` support (reuse `tree-highlight` CSS class) |
| `apps/retro_hex_chat_web/assets/css/layout.css` | Typing indicator styles, mute icon styles |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` | Add help topics for Sounds, Mute, Typing |

## Implementation Order

1. **Domain layer first**: SoundSettings module + schema + migration + Session integration
2. **Sound hook expansion**: Extend JS sound catalog with 14 named sounds
3. **Sound dispatch refactor**: Replace hardcoded `"mention"`/`"pm"` types with per-event lookup
4. **Sounds dialog**: Component + chat_live event handlers (open/close/change/apply/ok/cancel/preview)
5. **Mute toggle**: Status bar button + existing localStorage integration
6. **Visual flash**: Extend treebar flash gating per-event + title flash hook
7. **Typing indicator**: JS debounce → LiveView event → PubSub broadcast → receiver display
8. **Help topics**: Add documentation for all new features

## Validation

```bash
# Step 1: Compile
mix compile --warnings-as-errors

# Step 2: Run in parallel
mix format --check-formatted
mix credo --strict
mix test --include e2e
mix dialyzer
```

## Architecture Decisions

- **JSONB over normalized rows**: Sound settings stored as JSONB for simplicity and atomic load/save
- **Programmatic sounds**: Web Audio API synthesis, no audio files to bundle
- **Existing PubSub for typing**: Reuse `pm:#{sorted_nicks}` topic, no new infrastructure
- **CSS animation for treebar flash**: Reuse existing `tree-highlight` / `tree-flash` keyframes
- **JS hook for title flash**: Only way to manipulate `document.title` dynamically
- **Draft pattern for dialog**: Socket assign holds unsaved changes until OK/Apply
