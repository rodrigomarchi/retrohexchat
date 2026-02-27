# New UI Components — Showcase Completeness Roadmap

## Overview

Building a new frontend with isolated components (Tailwind-only, zero platform CSS).
Every visual element from the current platform must be **reimplemented** as a new
`components/ui/*.ex` component and demonstrated in the showcase.

## Composition Rule

**Only primitives may have dedicated markup.** All composite components MUST be built
by composing existing primitives. This guarantees visual consistency — change a
primitive once, every composite inherits the change.

### Existing Primitives (42 components)

```
Layout/Frame:    window, dialog, card, tabs, fieldset, separator, scroll_area, sheet
Buttons:         button, toggle, toggle_group
Form Controls:   input, textarea, select, checkbox, radio_group, label, slider, switch
Data Display:    table, badge, progress, skeleton, avatar, pagination
Navigation:      breadcrumb, accordion, popover, tooltip
Menus:           menu, dropdown_menu
Feedback:        alert, alert_dialog
Domain:          chat_message, chat_input, nicklist, irc_tabs, toolbar, tree_view
Base:            component, helpers, form
```

---

## Phase 1: New Primitives

These need **dedicated markup** — no existing primitive covers them.

### P-01: `ui/toast.ex` ✅
- **Type:** Primitive
- **Reference:** `components/toast.ex` + `css/patterns/toast.css`
- **Implements:** Floating notification container, variants (success/error/warning/info),
  auto-dismiss timer, positions (top-right, bottom-right, etc.), enter/exit animation
- **Showcase:** `showcase_live/toast_page.ex`

### P-02: `ui/context_menu.ex` ✅
- **Type:** Primitive
- **Reference:** `components/context_menu.ex` + `css/patterns/context-menu.css`
- **Implements:** Right-click trigger, dynamic cursor positioning, items with 16x16 icon,
  separators, disabled state, sub-menus, hover highlight (blue #000080 + white text)
- **Showcase:** `showcase_live/context_menu_page.ex`

### P-03: `ui/loading_spinner.ex` ✅
- **Type:** Primitive
- **Reference:** `components/loading_spinner.ex` + `css/layout/loading-spinner.css`
- **Implements:** Retro hourglass animation / progress spinner, size variants
- **Showcase:** `showcase_live/loading_spinner_page.ex`

### P-04: `ui/empty_state.ex` ✅
- **Type:** Primitive
- **Reference:** `css/patterns/empty-state.css`
- **Implements:** Large icon + message + optional action button, centered layout
- **Showcase:** `showcase_live/empty_state_page.ex`

### P-05: `ui/color_picker.ex` ✅
- **Type:** Primitive
- **Reference:** formatting toolbar color grid in `components/formatting_toolbar.ex`
- **Implements:** 4x4 grid (16 IRC colors), selection indicator, preview swatch, retro
  sunken border (shadow-retro-field)
- **Showcase:** `showcase_live/color_picker_page.ex`

### P-06: Scrollbar (Tailwind plugin) ✅
- **Type:** CSS-only (not an Elixir component)
- **Reference:** `css/retro/scrollbar.css`
- **Implements:** `::-webkit-scrollbar` customization in tailwind.config.js plugin,
  retro raised/sunken track and thumb, arrow buttons
- **Showcase:** demonstrated within `showcase_live/scroll_area_page.ex` (new page for
  existing `ui/scroll_area.ex` + scrollbar styling)

---

## Phase 2: Composite Components — Main UI (P1)

All composed from existing + new primitives. **Zero dedicated markup.**

### C-01: `ui/conversations.ex` ✅
- **Composes:** `tree_view` + `badge` + `separator`
- **Reference:** `components/conversations.ex` + `css/pages/conversations.css`
- **Implements:** Collapsible sections (My Channels, Private Messages, Popular Channels),
  channel/PM icons, 6 visual states (normal/unread/highlight/active/muted/disconnected),
  user tree under active channel with role sorting
- **Showcase:** `showcase_live/conversations_page.ex`

### C-02: `ui/hover_card.ex` ✅
- **Composes:** `window` + `badge` + `separator`
- **Reference:** `components/hover_card.ex` + `css/pages/hover-card.css`
- **Implements:** Retro window popup with nick info fields (nick, away, host, online,
  client, channels), role badges (Owner/Op/Half-Op/Voiced), contact/ignore status
- **Showcase:** `showcase_live/hover_card_page.ex`

### C-03: `ui/search_bar.ex` ✅
- **Composes:** `window` + `input` + `button` + `checkbox`
- **Reference:** `components/search_bar.ex` + `css/chat/search.css`
- **Implements:** Floating window: Find input, Prev/Next buttons, result counter,
  filter checkboxes (case sensitive, regex, mentions, history)
- **Showcase:** `showcase_live/search_bar_page.ex`

### C-04: `ui/topic_bar.ex` ✅
- **Composes:** `badge` + simple layout
- **Reference:** `components/topic_bar.ex` + `css/pages/topic-bar.css`
- **Implements:** Channel topic display, mode badges, variants for channel/PM/status
- **Showcase:** `showcase_live/topic_bar_page.ex`

### C-05: `ui/formatting_toolbar.ex` ✅
- **Composes:** `toolbar` + `button` + `color_picker` (P-05) + `tooltip`
- **Reference:** `components/formatting_toolbar.ex` + `css/chat/formatting.css`
- **Implements:** B/I/U buttons, color picker grid, Reverse/Reset/Strip, emoji toggle
- **Showcase:** `showcase_live/formatting_toolbar_page.ex`

### C-06: `ui/emoji_picker.ex` ✅
- **Composes:** `window` + `tabs` + `input` + `scroll_area`
- **Reference:** `components/emoji_picker.ex` + `css/chat/emoji-picker.css`
- **Implements:** Retro window: category tabs, search field, scrollable emoji grid, preview
- **Showcase:** `showcase_live/emoji_picker_page.ex`

### C-07: `ui/autocomplete.ex` ✅
- **Composes:** `scroll_area` + minimal markup
- **Reference:** `components/autocomplete_dropdown.ex` + `css/chat/autocomplete.css`
- **Implements:** Multi-mode dropdown (commands/nicks/channels/subcommands), category
  headers, selected item highlight, keyboard navigation
- **Showcase:** `showcase_live/autocomplete_page.ex`

### C-08: `ui/tab_bar.ex` ✅
- **Composes:** variant of `irc_tabs` or composition of `tabs`
- **Reference:** `components/tab_bar.ex` + `css/chat/tab-bar.css`
- **Implements:** Status + channel + PM tabs, close button (x), unread indicator (bold),
  PM variant (italic), active tab (white bg, hidden bottom border)
- **Showcase:** `showcase_live/tab_bar_page.ex`

### C-09: `ui/reply_bar.ex` ✅
- **Composes:** `button` + flex layout
- **Reference:** `components/reply_compose_bar.ex`
- **Implements:** "Replying to {author}" bar with dismiss button, original message preview
- **Showcase:** `showcase_live/reply_bar_page.ex`

### C-10: `ui/connection_status.ex` ✅
- **Composes:** `alert` + `button` + `loading_spinner` (P-03)
- **Reference:** `components/connection_status.ex` + `css/notifications/connection-status.css`
- **Implements:** Connection banner, states: connected/reconnecting/disconnected,
  fullscreen reconnect overlay
- **Showcase:** `showcase_live/connection_status_page.ex`

---

## Phase 3: Composite Components — Specialized Dialogs (P2)

All use `dialog` as base frame. **Zero dedicated window/border markup.**

### D-01: `ui/confirm_dialog.ex` ✅
- **Composes:** `dialog` + `button`
- **Reference:** `disconnect_confirm_dialog.ex`, `delete_confirm_dialog.ex`, etc.
- **Implements:** Reusable confirmation: warning icon, message text, action + cancel
  buttons. Serves as base for ALL confirm dialogs.
- **Showcase:** `showcase_live/confirm_dialog_page.ex`

### D-02: `ui/options_dialog.ex` ✅
- **Composes:** `dialog` + `tree_view` + `tabs` + form controls
- **Reference:** `components/options_dialog.ex` + `css/dialogs/options.css`
- **Implements:** Tree-view nav (left) + settings panel (right), multiple panels
  (Display, Sounds, etc.)
- **Showcase:** `showcase_live/options_dialog_page.ex`

### D-03: `ui/channel_dialog.ex` ✅
- **Composes:** `dialog` + `tabs` + `table` + `button` + form controls
- **Reference:** `components/channel_central_dialog.ex`
- **Implements:** Tabs: General/Modes/Bans/Ban Exceptions/Invite Exceptions,
  tables with selection, Add/Remove/Edit buttons
- **Showcase:** `showcase_live/channel_dialog_page.ex`

### D-04: `ui/address_book.ex` ✅
- **Composes:** `dialog` + `table` + `button` + `color_picker` (P-05)
- **Reference:** `components/address_book_dialog.ex`
- **Implements:** Contact table, color grid, Add/Edit/Remove buttons
- **Showcase:** `showcase_live/address_book_page.ex`

### D-05: `ui/about_dialog.ex` ✅
- **Composes:** `dialog` + `separator`
- **Reference:** `components/about_dialog.ex` + `css/dialogs/about.css`
- **Implements:** Logo, version, credits
- **Showcase:** `showcase_live/about_dialog_page.ex`

### D-06: `ui/channel_list.ex` ✅
- **Composes:** `dialog` + `table` + `input` + `button`
- **Reference:** `components/channel_list_dialog.ex`
- **Implements:** Channel table (name/users/topic), search input, Join button
- **Showcase:** `showcase_live/channel_list_page.ex`

### D-07: `ui/highlight_dialog.ex` ✅
- **Composes:** `dialog` + `table` + `color_picker` (P-05) + `button` + `input`
- **Reference:** `components/highlight_dialog.ex` + `css/dialogs/highlight.css`
- **Implements:** Word list with color assignments, Add/Edit/Remove
- **Showcase:** `showcase_live/highlight_dialog_page.ex`

### D-08: `ui/config_form.ex` ✅
- **Composes:** `dialog` + `table` + `button` + form controls
- **Reference:** alias/perform/flood/ctcp/sound dialogs
- **Implements:** Generic config pattern: list (left) + edit form (right).
  Reusable base for Alias, Perform, Flood Protection, CTCP, Sound Settings.
- **Showcase:** `showcase_live/config_form_page.ex`

---

## Phase 4: Composite Components — Specialized (P3)

### S-01: `ui/p2p_lobby.ex` ✅
- **Composes:** `window` + `button` + `progress` + `badge`
- **Reference:** `components/p2p_lobby.ex` + `css/p2p/p2p-lobby.css`
- **Implements:** P2P connection setup, status diagram, connection buttons
- **Showcase:** `showcase_live/p2p_lobby_page.ex`

### S-02: `ui/media_controls.ex` ✅
- **Composes:** `toolbar` + `button` + `badge`
- **Reference:** `css/p2p/media-call.css`
- **Implements:** Mute/unmute, camera on/off, volume, end call
- **Showcase:** `showcase_live/media_controls_page.ex`

### S-03: `ui/file_transfer.ex` ✅
- **Composes:** `progress` + `button` + `badge`
- **Reference:** `css/p2p/file-transfer.css`
- **Implements:** File name, percentage, speed, cancel button
- **Showcase:** `showcase_live/file_transfer_page.ex`

### S-04: `ui/bot_manager.ex` ✅
- **Composes:** `dialog` + `table` + `button` + form controls
- **Reference:** `components/bot_management_dialog.ex` + `css/dialogs/bot-management.css`
- **Implements:** Bot list, creation/edit form
- **Showcase:** `showcase_live/bot_manager_page.ex`

### S-05: `ui/admin_console.ex` ✅
- **Composes:** `dialog` + `input` + `scroll_area`
- **Reference:** `components/admin_console_dialog.ex` + `css/dialogs/admin-console.css`
- **Implements:** Terminal-like interface with server commands
- **Showcase:** `showcase_live/admin_console_page.ex`

### S-06: `ui/chat_layout.ex` ✅
- **Composes:** `conversations` + `tab_bar` + `chat_message` + `nicklist` + `toolbar`
  + `chat_input` + `status_bar` (existing showcase) + `topic_bar` + `formatting_toolbar`
- **Reference:** `chat_live.ex` MDI layout
- **Implements:** Full MDI composition: sidebar + tab bar + chat area + nicklist +
  status bar + input area
- **Showcase:** `showcase_live/chat_layout_page.ex`

---

## Summary

| Phase | Type | Count | Nature |
|-------|------|-------|--------|
| 1 | New Primitives | 6 | Dedicated Tailwind markup |
| 2 | Main UI Composites | 10 | Pure composition of primitives |
| 3 | Dialog Composites | 8 | Composed using `dialog` as base |
| 4 | Specialized Composites | 6 | Pure composition of primitives |
| **Total** | | **30** | **6 new markup + 24 pure composition** |

### Per-component checklist
- [ ] Create `components/ui/<name>.ex` with `@spec` on all public functions
- [ ] Create `showcase_live/<name>_page.ex` with mock data
- [ ] Add route in `router.ex`
- [ ] Add nav entry in `showcase_helpers.ex` (`@nav_items` + `@nav_icon_map`)
- [ ] Visual comparison against platform reference
- [ ] Confirm zero platform CSS imports
- [ ] Confirm composites use ONLY existing primitives (no dedicated markup)

### Execution order
1. **Phase 1 first** — primitives must exist before composites can use them
2. **Phases 2-4 in any order** — all composites depend only on primitives
