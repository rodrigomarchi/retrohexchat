# Quickstart: Address Book (003)

**Branch**: `003-address-book`

## Prerequisites

```bash
# Ensure you're on the feature branch
git checkout 003-address-book

# Ensure deps and DB are up to date
make setup
```

## Key Files to Modify

### Domain Layer (`apps/retro_hex_chat/`)

**New files**:
- `lib/retro_hex_chat/accounts/contact.ex` — Contact struct
- `lib/retro_hex_chat/accounts/contact_list.ex` — ContactList context (CRUD + persistence)
- `lib/retro_hex_chat/accounts/contact_entry.ex` — Ecto schema
- `lib/retro_hex_chat/accounts/nick_color.ex` — NickColor struct
- `lib/retro_hex_chat/accounts/nick_colors.ex` — NickColors context (CRUD + persistence)
- `lib/retro_hex_chat/accounts/nick_color_entry.ex` — Ecto schema
- `priv/repo/migrations/TIMESTAMP_create_address_book_tables.exs` — Migration

**Modified files**:
- `lib/retro_hex_chat/accounts/session.ex` — Add contacts + nick_colors fields

### Web Layer (`apps/retro_hex_chat_web/`)

**New files**:
- `lib/retro_hex_chat_web/components/address_book_dialog.ex` — Tabbed dialog component
- `assets/js/hooks/address_book_hook.js` — Double-click and tab interaction support

**Modified files**:
- `lib/retro_hex_chat_web/live/chat_live.ex` — New assigns, event handlers, nick_color_fn
- `lib/retro_hex_chat_web/components/context_menu.ex` — Add "Add to Contacts" + "Set Nick Color"
- `lib/retro_hex_chat_web/components/toolbar.ex` — Add Address Book icon/button
- `lib/retro_hex_chat_web/components/menu_bar.ex` — Add Tools > Address Book menu item
- `lib/retro_hex_chat_web/components/chat_message.ex` — Use nick_color_fn assign
- `lib/retro_hex_chat_web/components/nicklist.ex` — Use nick_color_fn assign
- `lib/retro_hex_chat_web/components/notify_list_window.ex` — Use nick_color_fn assign
- `assets/js/app.js` — Register AddressBookHook

### Test Files

**New test files**:
- `test/retro_hex_chat/accounts/contact_test.exs`
- `test/retro_hex_chat/accounts/contact_list_test.exs`
- `test/retro_hex_chat/accounts/nick_color_test.exs`
- `test/retro_hex_chat/accounts/nick_colors_test.exs`
- `test/retro_hex_chat_web/live/address_book_test.exs` — LiveView tests

## Development Workflow

```bash
# Run all tests (excludes E2E)
make test

# Run specific test file
mix test apps/retro_hex_chat/test/retro_hex_chat/accounts/contact_list_test.exs

# Run linters
make lint

# Start dev server
make server
# Visit http://localhost:4000, connect, press Alt+B
```

## Architecture Reference

```
Feature flow:
  Alt+B / toolbar click / menu click
    → ChatLive handle_event("toggle_address_book")
      → assigns: show_address_book, address_book_tab
        → AddressBookDialog component
          → Contacts tab: ContactList context ↔ Session.contacts
          → Notify tab: existing NotifyList context ↔ Session.notify_list
          → Nick Colors tab: NickColors context ↔ Session.nick_colors
          → Control tab: placeholder (pending Cat F)

Nick color override flow:
  NickColors.color_for(nick_colors, nickname)
    → returns custom hex if override exists
    → returns nil if no override
  ChatLive builds nick_color_fn:
    fn nickname -> NickColors.color_for(...) || hash_color(nickname) end
  Passed to: ChatMessage, Nicklist, NotifyListWindow, ContextMenu, AddressBookDialog
```
