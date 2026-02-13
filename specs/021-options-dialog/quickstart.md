# Quickstart: Options Dialog (021)

**Date**: 2026-02-13
**Branch**: `021-options-dialog`

## Overview

Centralized Options dialog (Alt+O) with tree-view navigation and 6 settings panels: Connect, IRC Messages, Display, Fonts, Colors, Key Bindings. Persists preferences for registered users. Uses CSS custom properties for real-time font/color application.

## Architecture Summary

```
Domain Layer (retro_hex_chat)
├── Chat.UserPreferences     — In-memory CRUD + save/load persistence
├── Chat.KeyBindings         — Default bindings, validation, lookup, conflict detection
├── Chat.Schemas.UserPreference — Ecto schema (user_preferences table, 6 JSONB columns)
└── Accounts.Session         — Extended with user_preferences field

Web Layer (retro_hex_chat_web)
├── Components.OptionsDialog — Main dialog (tree-view + 6 panels + OK/Cancel/Apply)
├── ChatLive.OptionsEvents   — LiveView event handler module (attach_hook)
├── ChatLive.KeyboardEvents  — Refactored: dynamic lookup instead of hardcoded patterns
├── JS Hooks
│   ├── OptionsHook          — Apply CSS custom properties to :root
│   └── KeyBindingCaptureHook — Capture key combos in Key Bindings panel
└── CSS
    ├── layout.css           — CSS custom properties for fonts + display toggles
    ├── chat.css             — CSS custom properties for colors
    └── components.css       — CSS custom properties for nicklist/treebar fonts
```

## Key Files to Modify

| File | Changes |
| ---- | ------- |
| `Session` | Add `user_preferences` field (map), getter/setter |
| `load_persisted_data/2` | Add `UserPreferences.load(nick)` call |
| `ChatLive` assign_defaults | Add `show_toolbar: true`, `show_switchbar: true`, `show_statusbar: true`, `compact_mode: false`, `line_shading: false`, `key_bindings: KeyBindings.defaults()`, `show_options_dialog: false`, `options_panel: "display"`, `options_draft: nil` |
| `ChatLive` attach_all_hooks | Add `{:options_events, &ChatLive.OptionsEvents.handle_event/3}` |
| `chat_live.html.heex` | Wrap toolbar/tab-bar/status-bar in `:if` conditionals, add `OptionsDialog` component, add `compact-mode`/`line-shading` CSS classes, add `id="options-hook" phx-hook="OptionsHook"` |
| `keyboard_events.ex` | Refactor from pattern matching to dynamic lookup via `key_bindings` assign |
| `menu_bar.ex` | Add "Options..." item in Tools menu |
| `menu_toolbar_events.ex` | Replace no-op `settings` handler with `open_options_dialog` |
| `toolbar.ex` | Wire Settings button to `open_options_dialog` |
| `reconnect_hook.js` | Accept `reconnect_config` push_event, use dynamic params |
| `layout.css` | Add CSS custom properties for all customizable values |
| `chat.css` | Replace hardcoded colors/fonts with `var()` references |
| `components.css` | Replace hardcoded fonts with `var()` references |
| `help_topics.ex` | Add topics for Options dialog and keyboard shortcuts update |

## New Files

| File | Purpose |
| ---- | ------- |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/user_preferences.ex` | Domain module: new/0, getters, setters, save/2, load/1 |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/key_bindings.ex` | Key bindings: defaults/0, validate/1, find_action/2, conflict?/3, reserved?/1 |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/user_preference.ex` | Ecto schema (6 JSONB columns) |
| `apps/retro_hex_chat/priv/repo/migrations/NNNN_create_user_preferences.exs` | Migration |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/options_dialog.ex` | Options dialog component |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/options_events.ex` | LiveView event handlers |
| `apps/retro_hex_chat_web/assets/js/hooks/options_hook.js` | CSS custom property updater |
| `apps/retro_hex_chat_web/assets/js/hooks/key_binding_capture_hook.js` | Key capture for bindings panel |

## Phased Implementation

### Phase 1: Foundation (Domain + Migration + Session)
- UserPreferences domain module with in-memory CRUD
- KeyBindings module with defaults and validation
- Ecto schema + migration
- Session extension + load_persisted_data integration

### Phase 2: US1 — Dialog Shell + Display Panel
- OptionsDialog component (tree-view + panel switching + OK/Cancel/Apply)
- Display panel (6 toggles)
- ChatLive integration (assigns, events, template conditionals)
- Line shading CSS + compact mode CSS
- Menu bar + toolbar wiring

### Phase 3: US2 — Fonts Panel
- CSS custom properties introduction for all font values
- Fonts panel UI (4 areas × family + size selects)
- Live preview within dialog
- OptionsHook JS for applying font changes
- Scroll position preservation after font change

### Phase 4: US3 — Colors Panel
- CSS custom properties for all color values
- Colors panel UI (6 slots + 16 nick palette)
- 24-color picker grid component
- OptionsHook extension for color changes

### Phase 5: US4 — Connect Panel
- Connect panel UI (4 settings with validation)
- ReconnectHook.js modification to accept dynamic config
- push_event integration on mount + apply

### Phase 6: US5 — IRC Messages Panel
- Messages panel UI (3 routing selects)
- notice_routing sync with existing table
- Whois/PM routing integration with ChatLive message handlers

### Phase 7: US6 — Key Bindings Panel
- KeyBindingCaptureHook JS
- Key Bindings panel UI (action list, capture mode, conflict warnings)
- keyboard_events.ex refactor to dynamic lookup
- Reset to defaults with confirmation
- Browser-reserved shortcut rejection

### Phase 8: Help + Polish
- Help topics (feature-options-dialog, keyboard shortcuts update)
- E2E tests
- data-testid attributes
- Linter verification

## Running Tests

```bash
# Domain tests
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/user_preferences_test.exs
mix test apps/retro_hex_chat/test/retro_hex_chat/chat/key_bindings_test.exs

# Web tests
mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_options_test.exs

# E2E tests
mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live_options_e2e_test.exs

# Full suite
make test.all
make lint
```

## Key Design Patterns

1. **Draft state** (matches SoundSettingsDialog): Open copies live→draft, edits modify draft only, Apply/OK writes draft→live+persist, Cancel discards draft.
2. **CSS custom properties** (new pattern): Server pushes style map → JS hook sets `:root` properties → CSS `var()` references update everywhere.
3. **Dynamic key bindings** (new pattern): Runtime lookup map replaces compile-time pattern matching. Same `"window_keydown"` event, different dispatch mechanism.
4. **JSONB persistence** (matches SoundSettings): Atom keys ↔ string keys conversion on save/load boundary.
