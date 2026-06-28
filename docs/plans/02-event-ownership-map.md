# Event Ownership Map

Companion artifact for `02-chat-event-routing.md`. Authoritative, code-derived
snapshot of every `handle_event/3` clause currently routed through the linear
hook pipeline (`@event_hook_fns` in `chat_live.ex`). Generated from the
`*_events.ex` modules in
`apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/`.

Use this to drive the migration of each event to its **final owner**: a stateful
component (`phx-target={@myself}`) for local events, or the orchestrator for
truly global events. Regenerate after each batch of migrations.

## Classification legend

- **global** — stays in the orchestrator (`@global_events`). Window-level
  keyboard, navigation between windows, connection/lag, lifecycle/focus,
  channel/PM switching, takeover, PubSub-driven.
- **→ plan NN** — should move into the stateful component owned by that plan.
- **adapter** — compound dispatcher in `chat_live.ex` (`toolbar_action`,
  `switch_tab`, `close_tab`, `*_context_action`) that re-emits a v1 event name;
  keep as a temporary adapter until the emitting component targets `@myself`.

## Owner classification (module granularity)

| Current module | Final owner | Notes |
|---|---|---|
| `connection_events` (`ping`, `lag_update`) | **global** | Connection/heartbeat, orchestrator-level. |
| `keyboard_events` (`window_keydown`, `shortcut_action`) | **global** | Window-level keybindings. |
| `navigation_events` (`window_next/prev/select`, `navigate_to_channel`) | **global** | Window switching. |
| `pm_typing_events` (`tab_focused`, `mute_state_sync`, `pm_typing`, `pm_stop_typing`) | **global** | Lifecycle/focus + typing fan-out. |
| `tip_events` (`tips_state_sync`) | **global** | Client→server preference sync. |
| `menu_toolbar_events` | **global** (adapter via `toolbar_action`) | Menu/toolbar commands fan out to many features; keep adapter, route results. |
| `core_events`: `switch_channel/pm`, `switch_to_status`, `close_channel_tab`, `close_pm_tab`, `channel_dblclick` | **global** (adapter via `switch_tab`/`close_tab`) | Active-context switching is orchestrator state. |
| `core_events`: `send_input`, `input_changed`, `history_navigate`, `tab_complete`, `toggle_action_mode`, `cancel_notice_mode`, `edit_last_message`, `cancel_edit`, `paste_*`, `reply_to_message`, `cancel_reply`, `syntax_tooltip_*` | **→ plan 14/15/16/46** | Composer-owned (input, formatting/reply, autocomplete/syntax, paste confirm). |
| `core_events`: `load_more`, `scroll_to_bottom`, `scroll_to_message_missing`, `scroll_to_reply_parent`, `confirm_delete`, `cancel_delete` | **→ plan 10/12/28** | Message viewport + row + delete confirm. |
| `core_events`: `confirm_nick_change`, `cancel_nick_change`, `update_nick_change_password` | **→ plan 29** | Nick-change dialog. |
| `core_events`: `close_dialog` | **adapter (retire)** | Generic; replace with per-dialog close events (plan 02 task). |
| `search_events` | **→ plan 09** | Search bar. |
| `emoji_events` | **→ plan 17** | Emoji picker (mount on demand). |
| `hover_events` | **→ plan 18** | Hover card. |
| `context_menu_events` (`chat_context_*`, `ctx_chat_*`, `nick_right_click`, `nicklist_dblclick`, `reply_to_message`) | **→ plan 19/21** | Chat + nicklist context menus (adapter via `chat_context_action`/`nicklist_context_action`). |
| `context_menu_events`: `mute_duration_*`, `invite_channel_picker_*` | **→ plan 22/23** | Mute-duration + invite-channel-picker dialogs. |
| `conversations_context_menu_events` | **→ plan 20** | Conversations context menu (adapter via `conversations_context_action`). |
| `conversations_events` | **→ plan 05** | Conversations sidebar. |
| `account_events` | **→ plan 26** | Account dialog. |
| `address_book_events` | **→ plan 31** | Address book (contacts/nick-colors/control). |
| `notify_events` | **→ plan 30** | Notify list. |
| `highlight_events` | **→ plan 41** | Highlight dialog. |
| `channel_central_events` (`cc_*`, `channel_central_tab`) | **→ plan 40** | Channel Central. |
| `channel_list_events` (`channel_list*`, `knock_request_*`) | **→ plan 32/24** | Channel list + knock dialog. |
| `perform_autojoin_events` | **→ plan 35** | Perform/autojoin. |
| `alias_events` | **→ plan 36** | Alias dialog. |
| `custom_menus_events` | **→ plan 37** | Custom menus dialog. |
| `autorespond_events` | **→ plan 38** | Auto-respond dialog. |
| `timer_events` | **→ plan 39** | Timers dialog. |
| `url_catcher_events` | **→ plan 42** | URL catcher. |
| `user_lookup_events` | **→ plan 44/45** | User lookup + result card. |
| `settings_dialogs_events` (`flood_*`, `sound_*`, `toggle_mute`) | **→ plan 33/34** | Flood protection + sound settings. |
| `bot_events` | **→ plan 49/50/51** | Bot management + new bot + add command. |
| `admin_console_events` | **→ plan 52** | Admin console. |
| `invite_events` (`invite_accept`, `invite_ignore`) | **→ plan 47** | Invite dialog/queue. |
| `kick_events` (`kick_dialog_dismiss`) | **→ plan 48** | Kick dialog/queue. |

## Adapters in `chat_live.ex` (keep until emitters target `@myself`)

- `toolbar_action` → re-emits `phx-value-action` as a v1 event.
- `switch_tab` / `close_tab` → type-specific `switch_*` / `close_*_tab`.
- `chat_context_action` / `conversations_context_action` /
  `nicklist_context_action` → re-emit `action` as a v1 event.

These satisfy plan 02's "manter adaptador temporario ate todos os componentes
sairem do hook pipeline". Retire each once its emitting component owns the
event locally.

## Raw module → events index

Extracted verbatim from `def handle_event("...")` clauses (see module source
for params/semantics).

- **account_events**: account_auth_change, account_change_nick_submit, account_clear_away, account_clear_bio, account_drop_submit, account_ghost_submit, account_info, account_presence_submit, account_profile_change, account_profile_submit, account_register_submit, account_user_modes_submit, close_account_dialog, open_account_dialog, open_account_identify, open_account_modes, open_account_presence, open_account_profile, open_account_register, toggle_account_away
- **address_book_events**: address_book_tab, close_address_book, contact_add, contact_add_cancel, contact_add_dialog, contact_edit, contact_edit_cancel, contact_edit_dialog, contact_remove, contact_select, control_add_cancel, control_add_confirm, control_add_dialog, control_remove, control_select, nick_color_add_cancel, nick_color_add_dialog, nick_color_edit, nick_color_edit_cancel, nick_color_edit_dialog, nick_color_remove, nick_color_select, nick_palette_pick, toggle_address_book
- **admin_console_events**: admin_console_change_nuke_confirm, admin_console_channel_create, admin_console_channel_cs_access_add, admin_console_channel_cs_access_del, admin_console_channel_cs_access_list, admin_console_channel_cs_drop, admin_console_channel_cs_info, admin_console_channel_cs_transfer, admin_console_channel_delete, admin_console_channel_info, admin_console_channel_purge, admin_console_clear_motd, admin_console_execute_nuke, admin_console_preview_nuke, admin_console_refresh_audit_log, admin_console_refresh_channels, admin_console_refresh_motd, admin_console_refresh_server_settings, admin_console_refresh_turn, admin_console_refresh_users, admin_console_save_server_settings, admin_console_set_motd, admin_console_start_singleplayer, admin_console_tab, admin_console_user_ban, admin_console_user_info, admin_console_user_kick, admin_console_user_mute, admin_console_user_ns_drop, admin_console_user_ns_info, admin_console_user_ns_resetpass, admin_console_user_rename, admin_console_user_role, admin_console_user_unban, admin_console_user_unmute, clear_admin_console, close_admin_console, execute_admin_console, open_admin_console
- **alias_events**: alias_dialog_add, alias_dialog_cancel_edit, alias_dialog_delete, alias_dialog_edit, alias_dialog_save, alias_select, close_alias_dialog, open_alias_dialog
- **autorespond_events**: autorespond_dialog_add, autorespond_dialog_cancel_edit, autorespond_dialog_delete, autorespond_dialog_edit, autorespond_dialog_save, autorespond_select, autorespond_toggle, close_autorespond_dialog, open_autorespond_dialog
- **bot_events**: bot_add_channel, bot_add_command, bot_cancel_edit, bot_delete, bot_dialog_tab, bot_edit_field, bot_remove_channel, bot_remove_command, bot_select, bot_toggle_channel, bot_toggle_enabled, bot_update_cap_config, bot_update_field, close_add_command_dialog, close_bot_dialog, close_new_bot_dialog, create_bot, open_add_command_dialog, open_bot_dialog, open_new_bot_dialog
- **channel_central_events**: cc_add_ban, cc_add_ban_exception, cc_add_invite_exception, cc_apply_modes, cc_apply_throttle, cc_ban_ex_select, cc_ban_select, cc_clear_welcome, cc_close_add_ban, cc_close_add_ban_ex, cc_close_add_invite_ex, cc_close_transfer, cc_cs_access_add, cc_cs_access_change, cc_cs_access_remove, cc_cs_access_select, cc_cs_access_tab, cc_cs_drop, cc_cs_drop_cancel, cc_cs_drop_request, cc_cs_register, cc_invite_ex_select, cc_open_add_ban, cc_open_add_ban_ex, cc_open_add_invite_ex, cc_open_transfer, cc_remove_ban, cc_remove_ban_exception, cc_remove_invite_exception, cc_save_welcome, cc_set_topic, cc_transfer_ownership, channel_central_tab, close_channel_central, open_channel_central
- **channel_list_events**: channel_list, channel_list_filter, channel_list_join, channel_list_knock, channel_list_select, close_channel_list, knock_request_cancel, knock_request_change, knock_request_submit, toggle_channel_list
- **connection_events**: lag_update, ping
- **context_menu_events**: chat_context_menu, close_chat_context_menu, close_context_menu, context_add_contact, context_ban, context_call, context_deop, context_devoice, context_game, context_ignore, context_invite_to_channel, context_kick, context_lobby, context_mute, context_notice, context_op, context_p2p, context_pick_color, context_query, context_sendfile, context_set_nick_color, context_unignore, context_unmute, context_video_call, context_voice, context_whois, context_whowas, ctx_chat_add_contact, ctx_chat_ban, ctx_chat_call, ctx_chat_channel_info, ctx_chat_copy_channel, ctx_chat_copy_message, ctx_chat_copy_nick, ctx_chat_copy_selection, ctx_chat_copy_url, ctx_chat_delete, ctx_chat_deop, ctx_chat_devoice, ctx_chat_game, ctx_chat_ignore, ctx_chat_ignore_sender, ctx_chat_join, ctx_chat_kick, ctx_chat_lobby, ctx_chat_mute, ctx_chat_notice, ctx_chat_op, ctx_chat_open_url, ctx_chat_p2p, ctx_chat_pm, ctx_chat_save_url, ctx_chat_sendfile, ctx_chat_set_color, ctx_chat_unmute, ctx_chat_video_call, ctx_chat_voice, ctx_chat_whois, ctx_chat_whowas, invite_channel_picker_cancel, invite_channel_picker_submit, mute_duration_cancel, mute_duration_submit, nick_right_click, nicklist_dblclick, reply_to_message
- **conversations_context_menu_events**: channel_right_click, close_conversations_context_menu, ctx_conversations_copy_name, ctx_conversations_leave, ctx_conversations_mark_read, ctx_conversations_mute, ctx_conversations_settings, pm_right_click
- **conversations_events**: conversations_browse_all, conversations_join_popular, conversations_toggle_section
- **core_events**: cancel_delete, cancel_edit, cancel_nick_change, cancel_notice_mode, cancel_reply, channel_dblclick, close_channel_tab, close_dialog, close_pm_tab, confirm_delete, confirm_nick_change, ctx_chat_delete, edit_last_message, history_navigate, input_changed, load_more, paste_cancel, paste_lines, paste_send, reply_to_message, scroll_to_bottom, scroll_to_message_missing, scroll_to_reply_parent, send_input, switch_channel, switch_pm, switch_to_status, syntax_tooltip_dismiss, syntax_tooltip_query, tab_complete, toggle_action_mode, update_nick_change_password
- **custom_menus_events**: close_custom_menus_dialog, custom_menu_dialog_add, custom_menu_dialog_cancel_edit, custom_menu_dialog_delete, custom_menu_dialog_edit, custom_menu_dialog_save, custom_menu_execute, custom_menu_select, custom_menus_tab, open_custom_menus_dialog
- **emoji_events**: emoji_category, emoji_search, emoji_select, toggle_emoji_picker
- **highlight_events**: close_highlight_add_dialog, close_highlight_dialog, close_highlight_edit_dialog, highlight_add, highlight_color_pick, highlight_edit, highlight_remove, highlight_select, open_highlight_add_dialog, open_highlight_dialog, open_highlight_edit_dialog
- **hover_events**: channel_click, channel_hover, nick_dblclick, nick_hover, nick_hover_dismiss
- **invite_events**: invite_accept, invite_ignore
- **keyboard_events**: shortcut_action, window_keydown
- **kick_events**: kick_dialog_dismiss
- **menu_toolbar_events**: autocomplete_close, autocomplete_navigate, autocomplete_query, autocomplete_select, autocomplete_select_current, cancel_disconnect, clear_window, confirm_disconnect, disconnect, help_topics, open_search, quit_chat, recent_commands_loaded, restore_session, show_about, show_motd, toggle_cheatsheet, toggle_conversations, toggle_nicklist, toggle_strip_formatting, viewport_info
- **navigation_events**: navigate_to_channel, window_next, window_prev, window_select
- **notify_events**: notify_add, notify_add_cancel, notify_add_dialog, notify_dblclick, notify_edit, notify_edit_cancel, notify_edit_dialog, notify_remove, notify_select, toggle_auto_add_pm, toggle_auto_whois, toggle_notify_list
- **perform_autojoin_events**: autojoin_dialog_add, autojoin_dialog_add_confirm, autojoin_dialog_edit, autojoin_dialog_edit_confirm, autojoin_dialog_remove, autojoin_select, close_autojoin_add_dialog, close_autojoin_edit_dialog, close_perform_add_dialog, close_perform_dialog, close_perform_edit_dialog, open_perform_dialog, perform_dialog_add, perform_dialog_add_confirm, perform_dialog_edit, perform_dialog_edit_confirm, perform_dialog_move_down, perform_dialog_move_up, perform_dialog_remove, perform_dialog_tab, perform_select, perform_toggle_enabled
- **pm_typing_events**: mute_state_sync, pm_stop_typing, pm_typing, tab_focused
- **search_events**: close_search, search_highlight_count, search_input, search_navigate, search_next, search_prev, search_toggle_filter, toggle_search
- **settings_dialogs_events**: close_flood_protection_dialog, close_sound_settings_dialog, flood_reset_defaults, flood_save_settings, open_flood_protection_dialog, open_sound_settings_dialog, sound_flash_toggle, sound_preview, sound_settings_apply, sound_settings_change, sound_settings_ok, toggle_mute
- **timer_events**: close_timers_dialog, open_timers_dialog, timers_dialog_add, timers_dialog_cancel_edit, timers_dialog_change, timers_dialog_edit, timers_dialog_save, timers_dialog_stop, timers_select
- **tip_events**: tips_state_sync
- **url_catcher_events**: close_url_catcher, toggle_url_catcher, url_catcher_filter, url_catcher_search, url_catcher_sort
- **user_lookup_events**: close_lookup_result, close_user_lookup, lookup_result_query, lookup_result_whois, lookup_result_whowas, open_user_lookup, user_lookup_change, user_lookup_whois, user_lookup_whowas

## Regenerate

```sh
cd apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live
for f in *_events.ex; do
  evs=$(rg -o 'def handle_event\("([^"]+)"' -r '$1' "$f" | sort -u | paste -sd', ' -)
  [ -n "$evs" ] && printf -- '- **%s**: %s\n' "$(basename "$f" .ex)" "$evs"
done
```
