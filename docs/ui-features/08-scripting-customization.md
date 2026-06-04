# Feature Spec: Scripting & Customization

**Coverage today:** Partial (only /timer lacks UI) · **Priority:** P2 · **Commands:** /alias, /autorespond, /popups, /timer

---

## 1. Overview

RetroHexChat exposes four user-facing automation commands that let users script, shortcut, and schedule actions without writing server-side code. Three of the four already have working UI dialogs accessible from the Tools menu and the toolbar Options dropdown. The gap is `/timer`: the backend is fully implemented (TimerManager, parse_timer_args, create/list/stop lifecycle), but there is no dialog to manage timers without typing raw commands. This spec covers the complete feature surface and focuses on what must be built: the Timers dialog.

---

## 2. Commands (grounded in handler source)

All four commands are in category `:config`. Each fires a `:ui_action` result that the LiveView handles.

| Command | Syntax (from handler help/doc) | What it produces |
|---|---|---|
| `/alias` | `/alias [list\|add\|remove]` | No args → `:open_alias_dialog`. `add <name> <expansion>` → `:alias_added`. `remove <name>` → `:alias_removed`. `list` → `:alias_list_display`. |
| `/autorespond` | `/autorespond [list\|add\|remove]` | No args → `:open_autorespond_dialog`. `add <trigger> [#channel] <command>` → `:autorespond_added`. `remove <position>` → `:autorespond_removed`. `list` → `:autorespond_list_display`. |
| `/popups` | `/popups` | Always → `:open_custom_menus_dialog`. No subcommands. |
| `/timer` | See expanded table below | Dispatches `:timer_list`, `:timer_stop`, `:timer_create` ui_actions. |

### /timer subcommands (full)

| Form | Parsed action | Notes |
|---|---|---|
| `/timer <name> <seconds> <command>` | `:timer_create`, type `:once` | One-shot. Fires once after `<seconds>`, then stops. Min 1 s, max 86 400 s (24 h). |
| `/timer <name> repeat <seconds> <command>` | `:timer_create`, type `:repeat` | Repeating. Fires every `<seconds>`. Min 10 s enforced by clamp (clamped silently, not errored). Max 86 400 s. |
| `/timer list` | `:timer_list` | Lists all active timers to the chat window (name, type, interval, command). |
| `/timer stop <name>` | `:timer_stop` | Cancels a running timer by name. |
| `/timer` (no args) | Prints usage help | Not a ui_action; returns `:system` message with the four usage lines. |

Constraints from `TimerManager`:

- Max 5 concurrent timers per session (`@max_timers 5`).
- Timer names: letters, digits, hyphens, underscores only; max 30 characters (`@name_pattern ~r/^[a-zA-Z0-9_-]+$/`).
- One-shot minimum: 1 s. Repeat minimum: 10 s (values below 10 are clamped, not rejected). Maximum: 86 400 s.
- Session-only: timers are stored in the LiveView process and lost on disconnect/reload.
- Timers run in the window that was active at creation time and do not switch the user's current window when they fire.

---

## 3. Current UI state

### /alias — Alias Editor dialog (working)

`RetroHexChatWeb.Components.UI.AliasDialog`. Opened by `/alias` (no args), the "Alias Editor" item in the Tools menu, and the Options dropdown in the toolbar. Displays a scrollable list of `{name, expansion}` pairs with a row-selection model. Inline edit form slides in below the list for Add and Edit. Supports `$1–$9`, `$nick`, `$chan` variable hints. Max 50 aliases. Registered users: persisted. Guests: session-only.

### /autorespond — Auto Respond dialog (working)

`RetroHexChatWeb.Components.UI.AutoRespondDialog`. Opened by `/autorespond` (no args) and the Tools / Options "Auto Respond" item. Two-panel layout: list on the left, inline edit form on the right when editing. Columns: Enable (checkbox), Trigger, Channel, Command. Valid triggers: `on_join`, `on_part`, `on_nick_change`. Optional `#channel` scope. `$nick` variable for the triggering user. Remove takes a 0-based position index.

### /popups — Custom Menus dialog (working)

`RetroHexChatWeb.Components.UI.CustomMenusDialog`. Opened by `/popups` and the Tools / Options "Custom Menus" item. Three-tab layout (Nicklist / Channel / Chat) each backed by `menu_type` filtering. Each tab has a `{label, command}` list with Add/Edit/Remove and an inline form. No subcommands in the handler — the dialog is the only way to manage entries.

### /timer — No UI (the gap)

The handler (`RetroHexChat.Commands.Handlers.Timer`) and `RetroHexChat.Chat.TimerManager` are fully implemented. `/timer list`, `/timer stop <name>`, and `/timer <name> [repeat] <seconds> <command>` all work via the command bar. There is no menu item, no toolbar entry, and no dialog component. Users who do not know the command syntax have no way to discover or manage timers.

---

## 4. UI specification — what to build

### 4.1 Entry points

Add a "Timers" item in two places, following the exact same pattern as the three existing scripting items:

**Tools menu** (`menu_bar_app.ex`, after the "Auto Respond" item):

```
icon_fn: :icon_btn_timers
label: "Timers"
action: "open_timers_dialog"
```

**Toolbar Options dropdown** (`toolbar_app.ex`, after the "Auto Respond" dropdown_item):

```
icon_fn: :icon_btn_timers
label: "Timers"
action: "open_timers_dialog"
```

The `/timer` command with no args should also fire `{:ok, :ui_action, :open_timers_dialog, %{}}` instead of printing usage (mirrors the `/alias` and `/autorespond` no-args behavior). This requires a one-line change in the handler's `execute([], _context)` clause.

Label is exactly **"Timers"** in both locations.

### 4.2 Layout — Timers dialog

Module: `RetroHexChatWeb.Components.UI.TimersDialog`

The dialog follows the same two-panel pattern as AliasDialog: list at top, inline Add/Edit form panel below when active, action buttons below the list.

```
+-----------------------------------------------------+
| [icon] Timers                              [X close] |
+-----------------------------------------------------+
| Name         | Every | Repeat | Next Fire  | Command |
|--------------|-------|--------|------------|---------|
| remind       | 1800s |  no    | 0:27:14    | /me ... |
| heartbeat    |  600s |  yes   | 0:09:52    | /me ... |
|  (empty state: "No active timers. Click Add to      |
|   schedule one.")                                    |
+-----------------------------------------------------+
| [Add]  [Edit]  [Stop]                               |
+-----------------------------------------------------+
|  +-- Add / Edit form (visible when editing) ------+ |
|  | Name: [__________________] (disabled on edit)  | |
|  | Repeat: [ ] Repeating timer                    | |
|  | Seconds: [______] (1–86400; min 10 if repeat)  | |
|  | Command: [________________________________]    | |
|  | [error message if any]                          | |
|  | [Save]  [Cancel]                                | |
|  +------------------------------------------------+ |
+-----------------------------------------------------+
|                                    [Close]           |
+-----------------------------------------------------+
```

List columns:

| Column | Source |
|---|---|
| Name | `timer.name` |
| Every | `timer.interval` displayed as `Ns` |
| Repeat | "yes" / "no" from `timer.type == :repeat` |
| Next Fire | Countdown to next fire (mm:ss or hh:mm:ss), updated server-push or on open |
| Command | `timer.command`, truncated with ellipsis |

Row selection follows the same highlight pattern (`bg-selection-bg text-selection-fg`) as the other scripting dialogs.

### 4.3 Interactions & states

**Empty state**
When `timers == []`, the list body shows a centered message: "No active timers. Click Add to schedule one." (matches the alias dialog empty state pattern).

**Add flow**
1. User clicks Add. Edit form slides in. All fields blank. Name field enabled.
2. User fills Name, toggles Repeat checkbox, enters Seconds, enters Command.
3. Seconds field label changes to "Seconds (min 10)" when Repeat is checked.
4. User clicks Save. Form submits → fires `/timer <name> [repeat] <seconds> <command>` via `:timer_create` ui_action.
5. On success: form closes, new row appears in list.
6. On error: inline error message shown inside form (name invalid, limit reached, interval out of range).

**Edit flow**
1. User selects a row, clicks Edit. Edit form slides in. Fields pre-populated from selected timer. Name field disabled (names are immutable; to rename, stop and recreate).
2. User adjusts Seconds or Command. Save fires a stop of the old name then a create with the same name.
3. Cancel dismisses form, selection retained.

**Stop flow**
1. User selects a row, clicks Stop (not "Remove" — matches the command name `/timer stop`). Confirm is not required (timers are session-only and trivially recreated).
2. Row removed from list immediately. If it was the selected row, selection clears.

**Repeat toggle**
Unchecked = one-shot (`:once`). Checked = repeating (`:repeat`). When toggled to checked, if current Seconds value is below 10, the field is visually flagged (border-red) and the hint "min 10s for repeating timers" appears. Save is blocked until resolved.

**Max timer limit**
When 5 timers are already active, the Add button is disabled and a note below the list reads: "Maximum 5 timers active. Stop one to add another." The limit comes from `TimerManager.@max_timers`.

**Running state**
The Next Fire column is informational. It does not need live countdown — it may show the raw remaining seconds on dialog open, updated only when the dialog is re-opened or a timer fires.

**Stopped-timer row (future)**
Out of scope for initial implementation. All rows in the list are active timers; stopped timers are removed.

### 4.4 Control → command mapping

| UI action | Resulting /timer call | ui_action atom |
|---|---|---|
| Save (Add, one-shot) | `/timer <name> <seconds> <command>` | `:timer_create` with `type: :once` |
| Save (Add, repeat) | `/timer <name> repeat <seconds> <command>` | `:timer_create` with `type: :repeat` |
| Save (Edit) | stop old + create new (same name) | `:timer_stop` then `:timer_create` |
| Stop button | `/timer stop <name>` | `:timer_stop` |
| Open dialog | (list read from socket assigns) | `:open_timers_dialog` |
| `/timer` (no args) | (opens dialog, no command issued) | `:open_timers_dialog` |

The dialog reads timer state from socket assigns (the LiveView already tracks active timers as a map keyed by name). No new GenServer or ETS is required.

---

## 5. Permissions & visibility

- The Tools menu and toolbar Options dropdown items are already guarded by `disabled={!@connected}`. The "Timers" item inherits this guard — it is only visible and clickable when the user is connected.
- There is no role restriction on timers; any connected user (registered or guest) may use them.
- The max-5-timers limit is per session (LiveView process), not per user account, so no database enforcement is needed.
- Timers are session-only and do not persist across reconnects. The dialog should display a note: "Timers are session-only and will be lost on disconnect."

---

## 6. Help documentation (mandatory)

A new topic must be added to `RetroHexChat.Chat.HelpTopics` under the "Commands" category:

**Topic:** `"Timers"`
**Category:** Commands
**Content should cover:**
- What timers do (schedule a command to run after a delay or on an interval).
- One-shot syntax: `/timer <name> <seconds> <command>` — example: `/timer remind 1800 /me reminds everyone: standup in 30 minutes`.
- Repeating syntax: `/timer <name> repeat <seconds> <command>` — example: `/timer heartbeat repeat 600 /me is still here`.
- List: `/timer list`.
- Stop: `/timer stop <name>`.
- Limits: max 5 timers, names alphanumeric/hyphen/underscore up to 30 chars, min 1 s one-shot, min 10 s repeat, max 86 400 s.
- Session-only note.
- How to open the dialog: Tools menu > Timers, toolbar Options > Timers, or `/timer` with no arguments.

**See Also** cross-references to add:
- From the Timers topic: link to "Alias Editor" and "Auto Respond" topics.
- From the "Alias Editor" topic: add "Timers" to its See Also list.
- From the "Auto Respond" topic: add "Timers" to its See Also list.

---

## 7. Out of scope / open questions

**Out of scope for initial implementation:**
- Pausing/resuming a timer (start/stop is sufficient).
- Persisting timers across reconnects (session-only is the current model; persistence would require a new DB schema).
- Per-channel timer scope (timers already run in the window active at creation; no UI control for this).
- Import/export of timer definitions.
- Drag-to-reorder (no ordering concept in the current map-keyed model).

**Open questions:**
1. Should the Edit flow (stop + recreate) be atomic from the user's perspective, or should stop failure surface an error? The current `:timer_stop` path returns immediately, but if the name does not exist the LiveView may silently no-op.
2. Should `/timer` with no args open the dialog (matching `/alias` and `/autorespond` behavior) or keep printing usage? The spec recommends opening the dialog, but this is a behavior change that should be confirmed.
3. Next Fire column: is a static "remaining seconds at open" display acceptable, or is a live countdown required? A live countdown would need a `push_event` or periodic `Process.send_after` from the LiveView tick.
4. Icon: `:icon_btn_timers` does not yet exist in the Icons system. A clock or stopwatch icon in the appropriate submodule (`Icons.Tools` or `Icons.Alerts`) must be added before the menu items can render.
