# Feature Spec: Bots

**Coverage today:** ⚠️ dark dialog (built, not wired) · **Priority:** P0 · **Commands:** `/bot`

---

## 1. Overview

RetroHexChat supports server-side bots with pluggable capabilities (greeter, mention response, custom commands, dice, moderation, trivia, scheduler, RSS, arcade). Bots are persisted in PostgreSQL and run as supervised OTP processes (`RetroHexChat.Bots.Server` under `RetroHexChat.Bots.Supervisor`).

The full Bot Management UI — main dialog, New Bot sub-dialog, Add Command sub-dialog — already exists as LiveView component code. The missing piece is **wiring**: no menu item, no toolbar button, and no `"open_bot_dialog"` toolbar action route causes the dialog to open via the UI. Admins currently reach it only by typing `/bot` in the chat input, which issues a `{:ok, :ui_action, :open_bot_dialog, %{}}` result that the existing `UiActions.Bots` module handles. Regular users typing `/bot` get a text bot list instead.

---

## 2. Commands (grounded in handler source)

All subcommands are implemented in `RetroHexChat.Commands.Handlers.Bot` (`bot.ex`).

| Subcommand | Full syntax | What it does | Who can run it |
|---|---|---|---|
| _(none)_ | `/bot` | Opens Bot Management dialog (admin/oper); shows text bot list (everyone else) | All users |
| `create` | `/bot create <name> [description]` | Creates a bot with the given name and optional description; starts its OTP process; default capabilities: mention, greeter, custom_commands, help | Admin / server operator |
| `destroy` | `/bot destroy <name>` | Stops and permanently deletes a bot | Admin / server operator |
| `list` | `/bot list` | Prints all bots with ON/OFF status and description to chat | All users |
| `info` | `/bot info <name>` | Prints bot details: nickname, status, prefix, cooldown, created_by, channel count, command count, description, live uptime stats if process running | All users |
| `join` | `/bot join <bot> <channel>` | Adds a channel config entry and notifies the running process to join; `#` prefix auto-added if omitted | Admin / server operator |
| `part` | `/bot part <bot> <channel>` | Removes channel config and notifies running process to part | Admin / server operator |
| `enable` | `/bot enable <bot>` | Sets `enabled: true` in DB and notifies running process | Admin / server operator |
| `disable` | `/bot disable <bot>` | Sets `enabled: false` in DB and notifies running process | Admin / server operator |
| `set` | `/bot set <bot> <key> <value>` | Updates a named setting (see settings table below) | Admin / server operator |
| `commands` | `/bot commands <bot>` | Prints all custom commands for a bot: `<prefix><botname> <trigger> — <description or response> [disabled]` | All users |
| `addcmd` | `/bot addcmd <bot> <trigger> <response>` | Adds a custom command trigger→response; live-reloads into running process | Admin / server operator |
| `delcmd` | `/bot delcmd <bot> <trigger>` | Removes a custom command; live-reloads into running process | Admin / server operator |
| `help` | `/bot help` | Prints inline help summary to chat | All users |

### `/bot set` key reference

| Key | Valid values | Affects |
|---|---|---|
| `prefix` | any string | `command_prefix` field |
| `cooldown` | integer (ms) | `cooldown_ms` field |
| `description` | any string | `description` field |
| `greeting` | string or `none` | `greeter` capability `greeting` |
| `farewell` | string or `none` | `greeter` capability `farewell` |
| `mention_response` | string | `mention` capability `response` |
| `dice_max_dice` | 1–1000 | `dice` capability |
| `dice_max_sides` | 2–10000 | `dice` capability |
| `dice_default` | notation string | `dice` capability |
| `mod_words` | comma-separated list | `moderation` capability `blocked_words` |
| `mod_action` | `warn` \| `mute` \| `kick` | `moderation` capability |
| `mod_spam` | 2–100 | `moderation` capability |
| `mod_flood` | 2–100 | `moderation` capability |
| `mod_warn` | string | `moderation` capability `warn_message` |
| `trivia_category` | string | `trivia` capability |
| `trivia_time` | 5–300 | `trivia` capability `time_limit_sec` |
| `trivia_questions` | 1–50 | `trivia` capability `questions_per_round` |
| `trivia_points` | 1–1000 | `trivia` capability `points_per_answer` |
| `sched_max` | 1–50 | `scheduler` capability `max_schedules` |
| `sched_min_interval` | 1–1440 | `scheduler` capability `min_interval_min` |
| `rss_interval` | 5–1440 | `rss` capability `poll_interval_min` |
| `rss_max_feeds` | 1–20 | `rss` capability |
| `rss_max_items` | 1–10 | `rss` capability `max_items_per_poll` |
| `arcade_enabled` | `true`/`1`/`yes`/`on` or `false`/`0`/`no`/`off` | `arcade` capability presence |

---

## 3. Current UI state

### What already exists

**`RetroHexChatWeb.Components.UI.BotManagementDialog`** (`bot_management_dialog.ex`) — fully implemented:

- Split-pane layout: 180px left panel (bot list + New/Delete buttons) and flexible right detail panel
- Left panel: scrollable `<ul>` with one `<li>` per bot; selected item highlighted; "New" and "Delete" buttons visible only to admins; "New" emits `open_new_bot_dialog`, "Delete" emits `bot_delete` with `phx-value-name`
- Right panel empty state: "Select a bot to view details" when `@selected == nil`
- Right panel with bot selected: five-tab layout (`bot-tabs`) with tab switching via `bot_dialog_tab` event:
  - **General tab** — name, nickname, prefix (monospace), enabled/disabled status (green/red), capability badge list (pill tags), runtime statistics (messages, commands, uptime) when `@stats` present
  - **Capabilities tab** — `capabilities_tab/1` sub-component: one `<fieldset>` per capability key in `bot.capabilities`; each fieldset shows capability display name, enabled/disabled status with toggle button (emits `bot_toggle_capability`), and sorted key–value config rows; no inline editing of config values in the current component (read-only display)
  - **Channels tab** — table of channel configs (channel name, status); admin row has "Remove" inline link (emits `bot_remove_channel`); add-channel form with text input + "Add" button (emits `bot_add_channel`)
  - **Commands tab** — table of custom commands (trigger monospace, response truncated); admin row has "Remove" link (emits `bot_remove_command`); "Add" button opens `open_add_command_dialog`
  - **Events tab** — scrollable log of recent bot events with timestamp + message; empty state "No recent events"; events sourced from `Queries.list_event_logs/2` (limit 50, loaded on `bot_select`)
- Footer: single "Close" button emitting `@on_close`
- Icon: `Icons.icon_dialog_bot_management` (header) and `Icons.icon_btn_bot_management` (left panel label)

**`RetroHexChatWeb.Components.UI.BotFormDialog`** (`bot_form_dialog.ex`) — fully implemented:

- `new_bot_dialog/1`: fields — Name (required), Nickname, Description, Command Prefix (default `!`), Cooldown in seconds (default `3`); capability checkboxes in a 2-column grid: Mention Response, Greeter, Custom Commands, Help, Dice, Moderation, Trivia, Scheduler, RSS; submits `create_bot`; Cancel emits `@on_close`
- `add_command_dialog/1`: fields — Trigger (required, placeholder `!hello`), Response (required, placeholder `Hello, {nick}!`), Description (optional); hint text explains `{nick}` and `{channel}` interpolation variables; submits `bot_add_command`; Cancel emits `@on_close`

**`RetroHexChatWeb.ChatLive.BotEvents`** (`bot_events.ex`) — fully implemented, handles:
`open_bot_dialog`, `close_bot_dialog`, `bot_select`, `bot_dialog_tab`, `bot_toggle_enabled`, `bot_delete`, `open_new_bot_dialog`, `close_new_bot_dialog`, `create_bot`, `bot_add_channel`, `bot_remove_channel`, `bot_add_command`, `bot_remove_command`, `open_add_command_dialog`, `close_add_command_dialog`, `bot_edit_field`, `bot_cancel_edit`, `bot_update_field`, `bot_toggle_capability`, `bot_update_cap_config`, `bot_toggle_channel`

**`RetroHexChatWeb.ChatLive.UiActions.Bots`** (`ui_actions/bots.ex`) — `open_bot_dialog` action routed in `UiActionHandlers` via `@bot_actions`

**`RetroHexChatWeb.Live.ChatLive`** (`chat_live.ex`) — dialog components imported (lines 76–77), all bot assigns initialized in defaults (lines 786–795), `BotEvents.handle_event/3` registered in hook pipeline (lines 534, 586)

### The missing piece

The `MenuBarApp` Tools menu has no "Bot Management" entry. No toolbar button emits `"open_bot_dialog"`. The dialog is mounted in the template but has no trigger accessible from the UI — only reachable via `/bot` command typed in chat by an admin.

---

## 4. UI specification — what to build

### 4.1 Entry points

Two entry points must be added. Both are admin-only (rendered with `:if={@is_admin}`).

**A. Tools menu entry**

In `RetroHexChatWeb.Components.UI.MenuBarApp`, inside the Tools menu `<.menu_dropdown>`, after the existing `<.context_menu_separator />` and before "Sounds":

```
<.menu_item
  :if={@is_admin}
  icon_fn={:icon_btn_bot_management}
  label={dgettext("ui", "Bot Management")}
  action="open_bot_dialog"
  on_action={@on_action}
/>
```

The separator already present before "Sounds" visually groups the automation tools (Address Book, Highlight Words, URL Catcher, Channel Central, Perform) from the settings dialogs below. Bot Management should be placed just above that separator, after "Auto Respond" — so the final Tools menu order becomes:

1. Address Book
2. Highlight Words
3. URL Catcher
4. Channel Central
5. Perform
6. _(separator)_
7. Sounds
8. Flood Protection
9. Alias Editor
10. Custom Menus
11. Auto Respond
12. **Bot Management** ← new, admin only, above second separator or appended after Auto Respond
13. _(separator)_ ← optional, to visually isolate Bot Management if deemed noisy

Exact position is "after Auto Respond, before or with a separator before Sounds group" — implementer should match the aesthetic grouping of the existing menu.

**B. Wiring in `toolbar_action` dispatch**

No additional code required. The `toolbar_action` handler in `ChatLive` already dispatches any action string to `dispatch_to_hooks/3`, and `BotEvents.handle_event("open_bot_dialog", ...)` is already in the hook pipeline. Adding the menu item with `action="open_bot_dialog"` is sufficient.

### 4.2 Layout

The dialog is already built. This section documents it accurately for reference and confirms what is sufficient.

```
+-----------------------------------------------+
| [bot icon] Bot Management           [x close] |
+-------------------------------+---------------+
| Bots                          |               |
| +---------------------------+ |  (no bot      |
| | GreeterBot          [sel] | |   selected)   |
| | ModBot                    | |               |
| | TriviaBot                 | |  "Select a    |
| |                           | |   bot to      |
| +---------------------------+ |   view        |
| [New] [Delete]                |   details"    |
+-------------------------------+---------------+
                                                 |
   (with bot selected, right panel shows tabs)  |
   +---------------------------------------------+
   | General | Capabilities | Channels | Commands | Events |
   +---------------------------------------------+
   | Name:        GreeterBot                      |
   | Nickname:    GreeterBot                      |
   | Prefix:      !                               |
   | Status:      Enabled  (green)                |
   | ---                                          |
   | Capabilities: [Mention] [Greeter] [Custom]   |
   | ---                                          |
   | Statistics: Messages: 42  Commands: 7        |
   |             Uptime: N/A                      |
   +---------------------------------------------+
| [✓ Close]                                      |
+-----------------------------------------------+
```

Max width: `max-w-2xl`. Min body height: `400px`. Right panel right-side height: `360px` on md+.

### 4.3 Interactions & states

**Empty state (no bots)**
Left panel list is empty; right panel shows "Select a bot to view details". Admin sees active "New" button and disabled "Delete" button.

**Creating a bot**
Admin clicks "New" → `new_bot_dialog` opens. Admin fills Name (required), optionally Nickname, Description, Prefix (default `!`), Cooldown seconds (default `3`), and checks desired capability checkboxes. Submit fires `create_bot` event → `BotEvents` calls `Queries.create_bot/1` + `Supervisor.start_bot/1` → dialog closes, bot list refreshes, system message posted to chat: `[BotService] Bot '<name>' created.`

On validation error (e.g. duplicate name): error system message posted; `new_bot_dialog` remains open.

**Deleting a bot**
Admin selects bot in list, clicks "Delete". No confirmation dialog exists currently — the button fires `bot_delete` immediately. **To build:** a confirmation prompt should be interposed before deletion (inline confirmation or a small confirm dialog). On confirm → `Lifecycle.destroy_bot/1` → bot list refreshes, right panel clears, system message: `[BotService] Bot '<name>' destroyed.`

**Enabling / disabling a bot**
Currently done only via `/bot enable <name>` and `/bot disable <name>` commands. The dialog General tab shows status (green/red text) but has no toggle control. **To build:** add an Enable/Disable toggle button on the General tab that emits `bot_toggle_enabled` with `phx-value-name={@selected.name}`. This event is already handled in `BotEvents`.

**Capability toggles**
Capabilities tab has per-capability Enable/Disable link buttons (emit `bot_toggle_capability`). Already wired. Toggling restarts the bot OTP process to pick up new config.

**Channel management**
Channels tab: "Add" form with `#channel` text input + "Add" button (emits `bot_add_channel`). Per-row "Remove" link (emits `bot_remove_channel`). `#` prefix is auto-added by `BotEvents.ensure_hash/1`. No separate confirmation for removal.

**Command management**
Commands tab: "Add" button opens `add_command_dialog`. Per-row "Remove" link fires `bot_remove_command` immediately. Commands are live-reloaded into the running bot process without restart.

**Events tab**
Read-only log of the last 50 events for the selected bot, sourced via `Queries.list_event_logs/2`. Loaded on `bot_select`, not live-updating. Refresh on re-select.

**Tab persistence**
Active tab stored in `bot_dialog_tab` socket assign (atom). Selecting a different bot resets to `:general`.

### 4.4 Control → command mapping

| Dialog control | LiveView event | Equivalent `/bot` command |
|---|---|---|
| "New" button → Create form submit | `create_bot` | `/bot create <name> [description]` |
| "Delete" button | `bot_delete` | `/bot destroy <name>` |
| Enable/Disable button (General tab, **to build**) | `bot_toggle_enabled` | `/bot enable <name>` / `/bot disable <name>` |
| Capability toggle button (Capabilities tab) | `bot_toggle_capability` | `/bot set <bot> <cap_key> ...` (indirect) |
| Capability config save (Capabilities tab) | `bot_update_cap_config` | `/bot set <bot> <key> <value>` |
| "Add" channel form (Channels tab) | `bot_add_channel` | `/bot join <bot> <channel>` |
| "Remove" channel link (Channels tab) | `bot_remove_channel` | `/bot part <bot> <channel>` |
| "Add" command → Add Command dialog submit | `bot_add_command` | `/bot addcmd <bot> <trigger> <response>` |
| "Remove" command link (Commands tab) | `bot_remove_command` | `/bot delcmd <bot> <trigger>` |
| Tab click | `bot_dialog_tab` | — |
| Bot list item click | `bot_select` | `/bot info <name>` (read) |
| "Close" footer button | `close_bot_dialog` | — |
| Tools menu "Bot Management" (**to build**) | `toolbar_action` → `open_bot_dialog` | `/bot` (admin) |

---

## 5. Permissions & visibility

Bot management is restricted to **server administrators and server operators** (`ServerRoles.admin?/2` or `ServerRoles.server_operator?/2`, checked against `session.nickname` + `session.identified`).

- The "New" and "Delete" buttons in the left panel are rendered only when `@is_admin == true` (`:if={@is_admin}` guards in `BotManagementDialog`)
- The "Remove" links in Channels and Commands tabs are similarly gated by `@is_admin`
- The capability toggle buttons are gated by `@is_admin`
- The "Add" channel form is gated by `@is_admin`
- `BotEvents.handle_event("open_bot_dialog", ...)` checks `admin?(session)` and returns an error message if not admin
- `UiActions.Bots.handle_ui_action/3` for `:open_bot_dialog` checks `admin?(session)` identically
- The proposed Tools menu entry should be wrapped in `:if={@is_admin}` so non-admin users do not see it

Read-only access (list bots, view info, view commands) is available to all users via `/bot list`, `/bot info <name>`, and `/bot commands <name>` commands.

---

## 6. Help documentation (mandatory)

The help system already has a "Bots" category with 8 topics in `RetroHexChat.Chat.HelpTopics.Bots`:

| Topic ID | Title |
|---|---|
| `botservice` | BotService Overview |
| `bot-command` | /bot Command Reference |
| `bot-custom-commands` | Bot Custom Commands |
| `bot-dice` | Bot Dice Capability |
| `bot-trivia` | Bot Trivia Capability |
| `bot-scheduler` | Bot Scheduler Capability |
| `bot-rss` | Bot RSS Capability |
| `bot-moderation` | Bot Moderation Capability |

When wiring the entry point, the following help updates must accompany the change:

1. **`botservice` topic** — add a note that Bot Management is accessible from Tools > Bot Management (admin only) as well as via `/bot`
2. **`bot-command` topic** — confirm the description already references the dialog; update if it currently implies command-only access
3. **User Interface category** (wherever that lives) — add a topic or sub-section describing the Bot Management dialog tabs (General, Capabilities, Channels, Commands, Events)
4. **Keyboard Shortcuts topic** — no new keyboard shortcuts are introduced by this change; no update required

---

## 7. Out of scope / open questions

**Out of scope for this wiring task:**

- Inline editing of bot settings (prefix, cooldown, description) in the General tab — `bot_edit_field` / `bot_update_field` events exist in `BotEvents` but no editing UI is rendered in the current `BotManagementDialog` component
- Inline editing of capability config values in the Capabilities tab — config fields are read-only display; `bot_update_cap_config` event exists but no form is rendered
- Per-channel enable/disable toggle in the Channels tab — `bot_toggle_channel` event exists in `BotEvents` but no toggle control is rendered
- Toolbar icon button (as opposed to the menu item) — the app toolbar currently has no bot icon slot; adding one is a separate scope decision
- The `arcade` capability — referenced in `/bot set arcade_enabled` and `apply_setting/3` but not listed in the `new_bot_dialog` capability checkboxes; this inconsistency is pre-existing and out of scope

**Open questions:**

1. Should "Delete" show a confirmation prompt? Currently it destroys immediately on click. Recommend yes — needs a confirm step before `bot_delete` fires.
2. Should the Tools menu entry be visible to non-admins but disabled (greyed out), or fully hidden (`:if={@is_admin}`)? The current pattern for Admin Console in the File menu uses `:if={@is_admin}` (fully hidden); Bot Management should follow the same convention.
3. The `new_bot_dialog` capability checkboxes have no defaults checked. Should "mention", "greeter", "custom_commands", and "help" be pre-checked to match the defaults used by `/bot create` (which always includes all four)? This is a UX consistency gap.
4. The Events tab loads 50 events on `bot_select` but does not live-update. Should a "Refresh" button be added, or should it subscribe to PubSub events while the dialog is open?
5. Bot nicknames share the namespace with human user nicknames. Should the New Bot form validate that the chosen nickname is not already taken, or is this handled only at the DB/OTP level?
