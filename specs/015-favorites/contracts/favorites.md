# Contracts: Favorites / Bookmarks

## LiveView Events (Client → Server)

### Add to Favorites

**Event**: `"channel_right_click"`
**Params**: `%{"channel" => channel_name, "x" => x, "y" => y}`
**Behavior**: Opens the treebar context menu at the specified position for the given channel.

**Event**: `"add_to_favorites"`
**Params**: `%{"channel" => channel_name}`
**Behavior**: Closes context menu. If channel already in favorites, opens edit dialog with existing entry pre-filled and a notice. Otherwise opens Add Favorite dialog with channel name pre-filled.

**Event**: `"save_favorite"`
**Params**: `%{"channel_name" => string, "description" => string, "password" => string, "auto_join" => "true"|"false"}`
**Behavior**: Adds or updates favorite entry. Encrypts password if provided. Persists for registered users. Closes Add/Edit dialog.

**Event**: `"close_favorite_dialog"`
**Params**: `%{}`
**Behavior**: Closes the Add/Edit Favorite dialog without saving.

### Favorites Menu Actions

**Event**: `"join_favorite"`
**Params**: `%{"channel" => channel_name}`
**Behavior**: If user is already in the channel, switches to it. Otherwise, joins using saved password (if any). On join failure (wrong key), displays error message.

### Organize Favorites

**Event**: `"open_organize_favorites"`
**Params**: `%{}`
**Behavior**: Opens the Organize Favorites dialog showing all favorites in order.

**Event**: `"close_organize_favorites"`
**Params**: `%{}`
**Behavior**: Closes the Organize Favorites dialog (changes applied immediately, no draft state needed since each action is atomic).

**Event**: `"favorite_select"`
**Params**: `%{"channel" => channel_name}`
**Behavior**: Sets the selected favorite in the Organize dialog.

**Event**: `"favorite_move_up"`
**Params**: `%{}`
**Behavior**: Moves the selected favorite up one position. Persists for registered users.

**Event**: `"favorite_move_down"`
**Params**: `%{}`
**Behavior**: Moves the selected favorite down one position. Persists for registered users.

**Event**: `"favorite_edit"`
**Params**: `%{}`
**Behavior**: Opens the Add/Edit Favorite dialog pre-filled with the selected favorite's values (password field left empty, shows "Password set" placeholder if password exists).

**Event**: `"favorite_remove"`
**Params**: `%{}`
**Behavior**: Removes the selected favorite. Persists for registered users.

### Treebar Context Menu

**Event**: `"close_treebar_context_menu"`
**Params**: `%{}`
**Behavior**: Closes the treebar context menu.

## Socket Assigns

| Assign                         | Type          | Default         | Description                                |
|--------------------------------|---------------|-----------------|--------------------------------------------|
| show_favorite_dialog           | boolean       | false           | Add/Edit Favorite dialog visibility        |
| favorite_dialog_mode           | atom          | nil             | `:add` or `:edit`                          |
| favorite_dialog_channel        | string        | nil             | Pre-filled channel name for dialog         |
| favorite_dialog_data           | map           | nil             | Pre-filled data for edit mode              |
| show_organize_favorites        | boolean       | false           | Organize Favorites dialog visibility       |
| organize_favorites_selected    | string        | nil             | Selected channel_name in organize dialog   |
| treebar_context_menu           | map           | `%{visible: false, x: 0, y: 0, channel: nil}` | Treebar context menu state |

## Component Attrs

### MenuBar (updated)

| Attr              | Type          | Description                               |
|-------------------|---------------|-------------------------------------------|
| favorites         | list          | List of `FavoriteEntry` structs           |
| joined_channels   | list          | List of currently joined channel names    |

### TreebarContextMenu (new)

| Attr    | Type    | Description                             |
|---------|---------|-----------------------------------------|
| visible | boolean | Whether context menu is shown           |
| x       | integer | X position                              |
| y       | integer | Y position                              |
| channel | string  | Target channel name                     |

### FavoriteDialog (new)

| Attr    | Type    | Description                             |
|---------|---------|-----------------------------------------|
| visible | boolean | Whether dialog is shown                 |
| mode    | atom    | `:add` or `:edit`                       |
| channel | string  | Pre-filled channel name                 |
| data    | map     | Pre-filled data (for edit mode)         |

### OrganizeFavoritesDialog (new)

| Attr             | Type    | Description                             |
|------------------|---------|-----------------------------------------|
| visible          | boolean | Whether dialog is shown                 |
| favorites        | list    | List of `FavoriteEntry` structs         |
| selected         | string  | Selected channel_name                   |
