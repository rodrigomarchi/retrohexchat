# Web Contracts: Perform / Auto-Commands

**Branch**: `009-perform-auto-commands` | **Date**: 2026-02-12

## ChatLive Event Handlers

### Keyboard Shortcuts

| Event             | Params                           | Action                                        |
|-------------------|----------------------------------|-----------------------------------------------|
| `window_keydown`  | `%{"key" => "p", "altKey" => true}` | Toggle Perform dialog                      |

### Dialog Events

| Event                        | Params                            | Action                                      |
|------------------------------|-----------------------------------|---------------------------------------------|
| `open_perform_dialog`        | `%{}`                             | Open Perform dialog (Commands tab)          |
| `close_perform_dialog`       | `%{}`                             | Close dialog + all sub-dialogs              |
| `perform_dialog_tab`         | `%{"tab" => "commands" \| "autojoin"}` | Switch tab                            |
| `perform_select`             | `%{"index" => "0"}`              | Select perform entry by index               |
| `perform_dialog_add`         | `%{}`                             | Open Add sub-dialog                         |
| `close_perform_add_dialog`   | `%{}`                             | Close Add sub-dialog                        |
| `perform_dialog_add_confirm` | `%{"command" => "/join #elixir"}` | Add command to perform list                 |
| `perform_dialog_edit`        | `%{}`                             | Open Edit sub-dialog with selected entry    |
| `close_perform_edit_dialog`  | `%{}`                             | Close Edit sub-dialog                       |
| `perform_dialog_edit_confirm`| `%{"command" => "/join #phoenix"}`| Update selected command                     |
| `perform_dialog_remove`      | `%{}`                             | Remove selected perform entry               |
| `perform_dialog_move_up`     | `%{}`                             | Move selected entry up one position         |
| `perform_dialog_move_down`   | `%{}`                             | Move selected entry down one position       |
| `perform_toggle_enabled`     | `%{}`                             | Toggle enable_on_connect setting            |
| `autojoin_select`            | `%{"channel" => "#elixir"}`      | Select auto-join entry                      |
| `autojoin_dialog_add`        | `%{}`                             | Open auto-join Add sub-dialog               |
| `close_autojoin_add_dialog`  | `%{}`                             | Close auto-join Add sub-dialog              |
| `autojoin_dialog_add_confirm`| `%{"channel" => "#foo", "key" => ""}` | Add channel to auto-join list         |
| `autojoin_dialog_edit`       | `%{}`                             | Open auto-join Edit sub-dialog              |
| `close_autojoin_edit_dialog` | `%{}`                             | Close auto-join Edit sub-dialog             |
| `autojoin_dialog_edit_confirm`| `%{"channel" => "#foo", "key" => "newkey"}` | Update auto-join entry          |
| `autojoin_dialog_remove`     | `%{}`                             | Remove selected auto-join entry             |

### Perform Execution (handle_info)

| Message                          | Action                                              |
|----------------------------------|-----------------------------------------------------|
| `{:execute_perform, index}`      | Execute perform command at index, schedule next      |
| `{:execute_autojoin, index}`     | Join auto-join channel at index, schedule next       |
| `{:execute_rejoin, index}`       | Rejoin previous session channel at index             |

### Session Restoration (handle_event)

| Event                 | Params                                   | Action                                  |
|-----------------------|------------------------------------------|-----------------------------------------|
| `restore_session`     | `%{nickname, channels, perform_list, ...}` | Restore session from localStorage     |

---

## Component: PerformDialog

### Attributes

| Attr                       | Type    | Default   | Description                              |
|----------------------------|---------|-----------|------------------------------------------|
| `visible`                  | boolean | false     | Dialog visibility                        |
| `active_tab`               | string  | "commands"| Active tab: "commands" or "autojoin"     |
| `perform_entries`          | list    | []        | List of PerformEntry structs             |
| `perform_selected`         | integer | nil       | Selected entry index                     |
| `perform_enabled`          | boolean | true      | Enable on connect toggle                 |
| `autojoin_entries`         | list    | []        | List of AutoJoinEntry structs            |
| `autojoin_selected`        | string  | nil       | Selected channel name                    |
| `show_perform_add_dialog`  | boolean | false     | Add command sub-dialog                   |
| `show_perform_edit_dialog` | boolean | false     | Edit command sub-dialog                  |
| `show_autojoin_add_dialog` | boolean | false     | Add channel sub-dialog                   |
| `show_autojoin_edit_dialog`| boolean | false     | Edit channel sub-dialog                  |

---

## JS Hook: ReconnectHook

### Events Received (from LiveView via push_event)

| Event                      | Payload                                    | Action                             |
|----------------------------|--------------------------------------------|------------------------------------|
| `save_reconnect_state`     | `%{nickname, channels, active_channel, ...}` | Save to localStorage            |
| `clear_reconnect_state`    | `%{}`                                      | Remove from localStorage           |
| `intentional_disconnect`   | `%{}`                                      | Set flag, suppress auto-reconnect  |

### Events Sent (to LiveView via pushEvent)

| Event              | Payload                                    | Trigger                              |
|--------------------|--------------------------------------------|--------------------------------------|
| `restore_session`  | `{nickname, channels, perform_list, ...}`  | On successful reconnection           |

### localStorage Keys

| Key                    | Type   | Description                                      |
|------------------------|--------|--------------------------------------------------|
| `rhc_reconnect_state`  | JSON   | Serialized session state for restoration         |
| `rhc_intentional_quit` | string | "true" when user intentionally disconnected      |

---

## Menu Bar Addition

```
Tools
  ├─ ...existing items...
  ├─ Perform                  (phx-click="open_perform_dialog", data-testid="menu-perform")
  └─ ...existing items...
```

---

## Socket Assigns (New)

| Assign                       | Type    | Default                | Description                     |
|------------------------------|---------|------------------------|---------------------------------|
| `show_perform_dialog`        | boolean | false                  | Dialog visibility               |
| `perform_dialog_tab`         | string  | "commands"             | Active dialog tab               |
| `perform_selected`           | integer | nil                    | Selected command index          |
| `show_perform_add_dialog`    | boolean | false                  | Add command sub-dialog          |
| `show_perform_edit_dialog`   | boolean | false                  | Edit command sub-dialog         |
| `autojoin_selected`          | string  | nil                    | Selected auto-join channel      |
| `show_autojoin_add_dialog`   | boolean | false                  | Add channel sub-dialog          |
| `show_autojoin_edit_dialog`  | boolean | false                  | Edit channel sub-dialog         |
| `is_reconnect`               | boolean | false                  | True if this is a reconnection  |
| `reconnect_channels`         | list    | []                     | Channels to rejoin on reconnect |
