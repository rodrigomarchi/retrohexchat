# LiveView Event Contracts: Options Dialog (021)

**Date**: 2026-02-13
**Branch**: `021-options-dialog`

This feature uses Phoenix LiveView events (not REST endpoints). All interactions flow through `phx-click`, `phx-change`, and `push_event` mechanisms.

## Dialog Lifecycle Events

| Event Name              | Direction    | Params            | Action                                           |
| ----------------------- | ------------ | ----------------- | ------------------------------------------------ |
| `"open_options_dialog"` | Client→Server | `%{}`            | Open dialog, create draft from live settings     |
| `"options_select_panel"` | Client→Server | `%{"panel" => String}` | Switch active panel (connect/messages/display/fonts/colors/keybindings) |
| `"options_apply"`       | Client→Server | `%{}`            | Apply draft → live, persist, keep dialog open    |
| `"options_ok"`          | Client→Server | `%{}`            | Apply draft → live, persist, close dialog        |
| `"close_options_dialog"` | Client→Server | `%{}`           | Discard draft, close dialog                      |

## Display Panel Events

| Event Name                    | Direction    | Params                            | Action                            |
| ----------------------------- | ------------ | --------------------------------- | --------------------------------- |
| `"options_toggle_display"`    | Client→Server | `%{"setting" => String}`         | Toggle boolean in draft.display   |

**Valid `setting` values**: `"show_toolbar"`, `"show_treebar"`, `"show_switchbar"`, `"show_statusbar"`, `"compact_mode"`, `"line_shading"`

## Fonts Panel Events

| Event Name                    | Direction    | Params                                              | Action                         |
| ----------------------------- | ------------ | --------------------------------------------------- | ------------------------------ |
| `"options_change_font"`       | Client→Server | `%{"area" => String, "family" => String, "size" => String}` | Update draft.fonts for area |

**Valid `area` values**: `"chat_messages"`, `"input_box"`, `"nicklist"`, `"treebar"`

## Colors Panel Events

| Event Name                    | Direction    | Params                                    | Action                          |
| ----------------------------- | ------------ | ----------------------------------------- | ------------------------------- |
| `"options_change_color"`      | Client→Server | `%{"slot" => String, "color" => String}` | Update draft.colors for slot    |
| `"options_change_nick_color"` | Client→Server | `%{"index" => String, "color" => String}` | Update draft.colors.nick_palette[index] |

**Valid `slot` values**: `"chat_background"`, `"default_text"`, `"own_messages"`, `"system_messages"`, `"timestamps"`, `"error_messages"`

## Connect Panel Events

| Event Name                    | Direction    | Params                                    | Action                            |
| ----------------------------- | ------------ | ----------------------------------------- | --------------------------------- |
| `"options_change_connect"`    | Client→Server | `%{"setting" => String, "value" => String}` | Update draft.connect setting    |

**Valid `setting` values**: `"auto_reconnect_enabled"`, `"retry_interval"`, `"max_retries"`, `"connection_timeout"`

## IRC Messages Panel Events

| Event Name                    | Direction    | Params                                     | Action                            |
| ----------------------------- | ------------ | ------------------------------------------ | --------------------------------- |
| `"options_change_routing"`    | Client→Server | `%{"type" => String, "value" => String}`  | Update draft.messages routing     |

**Valid `type` values**: `"whois_routing"`, `"notice_routing"`, `"pm_routing"`

## Key Bindings Panel Events

| Event Name                    | Direction    | Params                                                | Action                            |
| ----------------------------- | ------------ | ----------------------------------------------------- | --------------------------------- |
| `"options_select_binding"`    | Client→Server | `%{"action" => String}`                              | Select action for rebinding       |
| `"options_capture_key"`       | Client→Server | `%{"key" => String, "modifiers" => [String]}`        | Capture new key combo for selected action |
| `"options_clear_binding"`     | Client→Server | `%{"action" => String}`                              | Remove binding from action        |
| `"options_reset_bindings"`    | Client→Server | `%{}`                                                 | Reset all to defaults (after confirm) |

## Server→Client Push Events

| Event Name                   | Payload                                          | Hook Target       | Purpose                              |
| ---------------------------- | ------------------------------------------------ | ----------------- | ------------------------------------ |
| `"apply_preferences"`        | `%{styles: %{String => String}}`                 | `OptionsHook`     | Update CSS custom properties         |
| `"reconnect_config"`         | `%{enabled: bool, max_attempts: int, max_delay: int, timeout: int}` | `ReconnectHook` | Update reconnect parameters |

## Keyboard Shortcut Event (modified existing)

The existing `"window_keydown"` event in `keyboard_events.ex` is refactored from hardcoded pattern matching to dynamic lookup:

```
Input:  %{"key" => String, "altKey" => bool, "ctrlKey" => bool, "shiftKey" => bool}
Lookup: socket.assigns.key_bindings (Map of action_id → %{key, modifiers})
Output: Dispatches to the handler function for the matched action_id
```
