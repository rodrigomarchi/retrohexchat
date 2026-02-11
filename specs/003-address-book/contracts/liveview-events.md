# LiveView Event Contracts: Address Book (003)

**Date**: 2026-02-11

This project uses Phoenix LiveView — there are no REST endpoints. All user interactions are LiveView events handled in `ChatLive`.

## Dialog Management Events

### `toggle_address_book`
**Trigger**: Alt+B shortcut, toolbar icon click, menu bar item
**Params**: none
**Effect**: Toggles `show_address_book` assign. Closes any open sub-dialogs when closing.

### `address_book_tab`
**Trigger**: Tab header click
**Params**: `%{"tab" => "contacts" | "notify" | "nick_colors" | "control"}`
**Effect**: Sets `address_book_tab` assign. Closes any open sub-dialogs for the previous tab.

## Contacts Tab Events

### `contact_add_dialog`
**Trigger**: "Add" button in Contacts tab
**Params**: none
**Effect**: Opens add contact dialog (`show_contact_add_dialog: true`)

### `contact_add_cancel`
**Trigger**: Cancel button in add dialog
**Params**: none
**Effect**: Closes add dialog (`show_contact_add_dialog: false`)

### `contact_add`
**Trigger**: Form submit in add dialog
**Params**: `%{"nickname" => String, "note" => String}`
**Effect**: Calls `ContactList.add_entry/3`. On success: updates session, closes dialog, persists async. On error: shows status message.
**Errors**: `:self_add`, `:duplicate`, `:list_full`, `:invalid_nickname`

### `contact_edit_dialog`
**Trigger**: "Edit" button in Contacts tab
**Params**: none (uses selected contact)
**Effect**: Opens edit dialog pre-filled with current note (`show_contact_edit_dialog: true`)

### `contact_edit_cancel`
**Trigger**: Cancel button in edit dialog
**Params**: none
**Effect**: Closes edit dialog (`show_contact_edit_dialog: false`)

### `contact_edit`
**Trigger**: Form submit in edit dialog
**Params**: `%{"note" => String}`
**Effect**: Calls `ContactList.update_note/3`. Updates session, closes dialog, persists async.

### `contact_remove`
**Trigger**: "Remove" button in Contacts tab
**Params**: none (uses selected contact)
**Effect**: Calls `ContactList.remove_entry/2`. Updates session, persists async.

### `contact_select`
**Trigger**: Row click in contacts table
**Params**: `%{"nickname" => String}`
**Effect**: Sets `contacts_selected` assign for button enable/disable state.

## Nick Colors Tab Events

### `nick_color_add_dialog`
**Trigger**: "Add" button in Nick Colors tab
**Params**: none
**Effect**: Opens add dialog (`show_nick_color_add_dialog: true`)

### `nick_color_add_cancel`
**Trigger**: Cancel button in add dialog
**Params**: none
**Effect**: Closes add dialog (`show_nick_color_add_dialog: false`)

### `nick_color_add`
**Trigger**: Form submit in add dialog
**Params**: `%{"nickname" => String, "color_index" => String (integer)}`
**Effect**: Calls `NickColors.add_entry/3`. On success: updates session, closes dialog, persists async, rebuilds nick_color_fn. On error: shows status message.
**Errors**: `:duplicate`, `:list_full`, `:invalid_nickname`, `:invalid_color`

### `nick_color_edit_dialog`
**Trigger**: "Edit" button in Nick Colors tab
**Params**: none (uses selected entry)
**Effect**: Opens edit dialog with current color pre-selected (`show_nick_color_edit_dialog: true`)

### `nick_color_edit_cancel`
**Trigger**: Cancel button in edit dialog
**Params**: none
**Effect**: Closes edit dialog (`show_nick_color_edit_dialog: false`)

### `nick_color_edit`
**Trigger**: Form submit in edit dialog
**Params**: `%{"color_index" => String (integer)}`
**Effect**: Calls `NickColors.update_color/3`. Updates session, closes dialog, persists async, rebuilds nick_color_fn.

### `nick_color_remove`
**Trigger**: "Remove" button in Nick Colors tab
**Params**: none (uses selected entry)
**Effect**: Calls `NickColors.remove_entry/2`. Updates session, persists async, rebuilds nick_color_fn.

### `nick_color_select`
**Trigger**: Row click in nick colors table
**Params**: `%{"nickname" => String}`
**Effect**: Sets `nick_colors_selected` assign.

## Context Menu Events (new)

### `context_add_contact`
**Trigger**: "Add to Contacts" context menu item
**Params**: none (uses `context_menu.target_nick`)
**Effect**: Calls `ContactList.add_entry/3` with target nick. On success: status message. On error: status message. Closes context menu.

### `context_set_nick_color`
**Trigger**: "Set Nick Color" context menu item
**Params**: none (uses `context_menu.target_nick`)
**Effect**: Shows inline color picker at context menu position (`show_context_color_picker: true`).

### `context_pick_color`
**Trigger**: Color swatch click in context color picker
**Params**: `%{"color_index" => String (integer)}`
**Effect**: Calls `NickColors.add_or_update/3` with target nick and color. Updates session, persists async, rebuilds nick_color_fn. Closes picker and context menu.

## Keyboard Events

### `window_keydown` (extended)
**Trigger**: Any key press at window level
**New handling**: When `key == "b" && altKey == true` → toggle Address Book dialog.

## Notify Tab Events

The Notify tab reuses the existing notify list events already handled in ChatLive:
- `notify_add_dialog`, `notify_add_cancel`, `notify_add`
- `notify_edit_dialog`, `notify_edit_cancel`, `notify_edit`
- `notify_remove`, `notify_select`
- `toggle_auto_whois`

No new events needed — the Address Book Notify tab renders the same controls with the same event names.
