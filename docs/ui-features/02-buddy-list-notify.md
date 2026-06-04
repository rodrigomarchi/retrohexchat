# Feature Spec: Buddy List (Notify)

**Coverage today:** WARNING dark dialog (built, not wired) · **Priority:** P0 · **Commands:** /notify

---

## 1. Overview

The Notify List (colloquially "Buddy List") lets a user track when specific nicknames connect to or
disconnect from the server. The full feature already exists in the codebase — the domain logic, the
LiveView event handlers, the UI actions, and the dialog component are all built and wired. The only
missing piece is an **entry point**: no menu item, toolbar item, or status bar indicator currently
opens the dialog. Users who do not know about `/notify` cannot discover it at all.

This spec describes what needs to be added to make the Notify List reachable from the normal UI
without touching any backend logic.

---

## 2. Commands (grounded in handler source)

Source: `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/notify.ex`

| Command | Syntax | What it does |
|---------|--------|--------------|
| `/notify` | `/notify` | Opens the Notify List dialog (`ui_action :open_notify_list`) |
| `/notify add` | `/notify add <nickname> [note]` | Adds `nickname` to the notify list with an optional free-text note. Errors: `:self_add`, `:duplicate`, `:list_full` (max 50 entries). |
| `/notify remove` | `/notify remove <nickname>` | Removes `nickname` from the notify list. Error: `:not_found`. |
| `/notify edit` | `/notify edit <nickname> <note>` | Updates the note for an existing entry. Requires both `nickname` and at least one word of `note`. Error: `:not_found`. |
| `/notify list` | `/notify list` | Prints all notify entries to the status message area, one per line, with online/offline status and note (`ui_action :notify_list_display`). |

Validation rules (verbatim from handler):
- `/notify add` with no nickname → error "Usage: /notify add <nickname> [note]"
- `/notify remove` with no nickname → error "Usage: /notify remove <nickname>"
- `/notify edit` with nickname only, no note → error "Usage: /notify edit <nickname> <note>"
- Any other subcommand → error "Unknown /notify subcommand. Use: add, remove, edit, list"

The handler is categorised as `:config`. It is already registered and autocomplete-aware
(subcommands exposed via `syntax_definition/0`).

---

## 3. Current UI state

### What already exists (BUILT)

**Dialog component** — `RetroHexChatWeb.Components.UI.NotifyList`
(`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/notify_list.ex`)

The component is fully implemented and imported in `ChatLive`. It renders:
- A dialog titled "Notify List" with `Icons.icon_btn_bell` in the title bar.
- Two settings checkboxes at the top:
  - "Auto-add PM contacts to notify list" (attr `auto_add_pm`, event `toggle_auto_add_pm`)
  - "Perform WHOIS on notify nicks when they come online" (attr `auto_whois`, event `toggle_auto_whois`)
- A scrollable table (max-height 260 px) with columns: **Nick**, **Status**, **Last Seen**.
  - Each row is clickable (`phx-click={@on_select}`, `phx-value-nickname`).
  - Selected row highlighted with `bg-selection-bg text-selection-fg`.
  - Status cell renders a green dot + "Online" or a grey dot + "Offline".
- Three CRUD buttons below the table: **Add** (`icon_btn_add`), **Edit** (`icon_btn_edit`, disabled
  when nothing selected), **Remove** (`icon_btn_remove`, disabled when nothing selected).
- A **Close** button in the footer.
- **Add sub-form** (`notify_add_sub_form`) — modal overlay, fields: Nickname (maxlength 16,
  required) and Note (maxlength 200, optional). Submit event `notify_add`, cancel event
  `notify_add_cancel`.
- **Edit sub-form** (`notify_edit_sub_form`) — modal overlay, Nickname field is read-only
  (pre-filled from `selected_entry`), Note is editable (pre-filled from `selected_note`).
  Submit event `notify_edit`, cancel event `notify_edit_cancel`.

**Event handlers** — `RetroHexChatWeb.ChatLive.NotifyEvents`
(`apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/notify_events.ex`)

Handles (all via `attach_hook(:notify_events, :handle_event, ...)`):
`toggle_notify_list`, `notify_add`, `notify_remove`, `notify_edit`, `notify_select`,
`notify_add_dialog`, `notify_add_cancel`, `notify_edit_dialog`, `notify_edit_cancel`,
`notify_dblclick` (opens PM if buddy is online), `toggle_auto_whois`, `toggle_auto_add_pm`.

**UI actions** — `RetroHexChatWeb.ChatLive.UiActions.Notify`
(`apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_actions/notify.ex`)

Handles: `:open_notify_list` (sets `show_notify_list: true`), `:notify_add`, `:notify_remove`,
`:notify_edit`, `:notify_list_display` (prints entries to status area).

**Socket assigns** (initialised in `ChatLive.mount/3`):
`show_notify_list: false`, `notify_selected: nil`, `show_notify_add_dialog: false`,
`show_notify_edit_dialog: false`, `selected_notify_note: ""`, `notify_debounce_timers: %{}`.

### What is missing (THE GAP)

The `MenuBarApp` (`components/ui/shell/menu_bar_app.ex`) has no "Notify List" item.
The `ToolbarApp` (`components/ui/shell/toolbar_app.ex`) Options dropdown has no "Notify List" item.
The `StatusBarApp` (`components/ui/shell/status_bar_app.ex`) has no buddy/notify indicator zone.

There is no `toolbar_action` handler path for `toggle_notify_list` — only the direct phx-event
`toggle_notify_list` handled by `NotifyEvents` exists.

The `/notify` command opens the dialog via command dispatch, but that path is invisible to users
who have not discovered it.

---

## 4. UI specification — what to build

### 4.1 Entry points

#### Already wired
- `/notify` command → opens dialog (works today via `ui_action :open_notify_list`).

#### To add

**A. View menu — `MenuBarApp`**

Add a "Notify List" item to the **View** menu, between "Toggle Nicklist" and "Find":

```
View
  Channel List
  Toggle Conversations
  Toggle Nicklist
> Notify List          <-- NEW (icon: icon_btn_bell or icon_tab_notify)
  Find
```

Exact label: `dgettext("ui", "Notify List")`
Action string: `"toggle_notify_list"`
Icon function: `:icon_tab_notify` (14x14, matches usage in HelpTopics)

**B. Options dropdown — `ToolbarApp`**

Add "Notify List" to the View section of the Options dropdown, at the same relative position:

```
Options dropdown
  Channel List
  Toggle Conversations
  Toggle Nicklist
> Notify List          <-- NEW
  Find
  ─────────────────
  Address Book
  ...
```

Exact label: `dgettext("ui", "Notify List")`
Action string: `"toggle_notify_list"`
Icon function: `:icon_tab_notify`

**C. Status bar buddy indicator — `StatusBarApp`**

Add a new Zone between the channel info field (Zone 2) and the lag field (Zone 3). Display a
compact online-buddy count badge when one or more buddies are online. Clicking it fires
`toggle_notify_list`.

- Zero buddies online: no badge shown (or badge hidden to not clutter the bar).
- N buddies online: shows `icon_btn_bell` + count, e.g. "2" in a small badge.
- Tooltip: "N buddy online" / "N buddies online".
- Hidden on mobile (same `hidden md:flex` pattern as lag and clock zones).

This indicator requires passing two new attrs to `StatusBarApp`:
- `online_buddy_count` (integer, default 0)
- `on_notify_toggle` (event callback, default nil)

The count is derived from `session.notify_list.entries` filtered by `entry.online == true`; this
computation belongs in the ChatLive render assigns, not in the status bar component.

**D. `toolbar_action` routing**

`ChatLive.handle_event("toolbar_action", %{"action" => "toggle_notify_list"}, socket)` must be
routed. Verify that `toggle_notify_list` is already handled by `NotifyEvents` (it is — line 27).
The `toolbar_action` dispatcher in `ChatLive` must include `"toggle_notify_list"` in its
pass-through list, or the existing hook chain must cover it. Confirm during implementation.

### 4.2 Layout

The dialog as built. ASCII wireframe for reference:

```
+--[ Notify List ]--[x]------------------+
|  [x] Auto-add PM contacts to notify    |
|  [x] Perform WHOIS when they come on   |
|                                         |
|  Nick        Status      Last Seen      |
|  ─────────── ─────────── ────────────  |
|  Alice       • Online    —             |
|  Bob         o Offline   2h ago        |
|  Carol       o Offline   3d ago        |
|                                         |
|  [+ Add]  [Edit]  [- Remove]           |
|                                         |
+─────────────────────────────────────────+
|                            [x Close]   |
+─────────────────────────────────────────+
```

Add sub-dialog (modal overlay):
```
+--[ Add Notify Entry ]--[x]---+
|  Nickname: [____________]    |
|  Note:     [____________]    |
|         [OK]  [Cancel]       |
+──────────────────────────────+
```

Edit sub-dialog (modal overlay):
```
+--[ Edit Notify Entry ]--[x]--+
|  Nickname: [Alice     ] (RO) |
|  Note:     [Works on  ]      |
|         [OK]  [Cancel]       |
+──────────────────────────────+
```

All of the above already exist in the component. No layout changes are needed.

### 4.3 Interactions and states

**Empty state**
When `entries == []`, the table body is empty. The Add button remains enabled. Edit and Remove
are disabled (no selection possible). No explicit empty-state illustration is required — the empty
table communicates the state adequately.

**Online vs offline rendering**
- Online: green filled circle (`bg-success`) + "Online" text in Status cell.
- Offline: grey filled circle (`bg-muted-foreground`) + "Offline" text, muted foreground colour.
Both are rendered by the existing private `online_status/1` component.

**Add flow**
1. User clicks Add button → `notify_add_dialog` event → `show_notify_add_dialog: true`.
2. Add sub-dialog appears as modal overlay (locks parent dialog via `lock={@show_add_dialog || @show_edit_dialog}`).
3. User fills in Nickname (required, maxlength 16) and optional Note.
4. Submit → `notify_add` event → domain call `NotifyList.add_entry/4`.
5. On success: entry added, `show_notify_add_dialog: false`, status message "Added X to notify list".
6. Newly added entry is immediately synced against live presence (`sync_entry_online/2`).
7. Error cases produce status messages; dialog stays open on `:list_full`/`:duplicate`/`:self_add`.

**Edit flow**
1. User selects a row → `notify_select` event → `notify_selected` set.
2. User clicks Edit → `notify_edit_dialog` event → `show_notify_edit_dialog: true`.
3. Edit sub-dialog appears; Nickname is read-only, Note is pre-filled.
4. Submit → `notify_edit` event → `NotifyList.update_note/3`.
5. On success: `show_notify_edit_dialog: false`, status message "Updated note for X".

**Remove flow**
1. User selects a row, clicks Remove → `notify_remove` event with `phx-value-nickname`.
2. Domain call `NotifyList.remove_entry/2`; on success `notify_selected` cleared, debounce timer
   for that nick cancelled via `cancel_notify_timer/2`.

**Double-click**
`notify_dblclick` — if the target entry is online, opens a PM conversation with that nick
(`open_pm_conversation/2`). If offline, no-op.

**Notifications when a buddy comes online**
Handled by `PubSub` presence events (already wired in `pubsub_handlers/presence.ex`). When the
online status of an entry changes, the dialog re-renders automatically because it reads from
`session.notify_list` in assigns. The status bar buddy count badge updates the same way.

**Persistence**
For registered users: `maybe_persist_notify_list/2` is called after every mutating operation,
persisting the notify list to the database. For guests: session-only, lost on disconnect.

**Auto-Whois toggle**
When enabled, the server performs a WHOIS on a buddy when they come online. Persisted as
`session.notify_list.settings.auto_whois`.

**Auto-add PM contacts toggle**
When enabled, starting a PM with someone auto-adds them to the notify list. Persisted as
`session.notify_list.settings.auto_add_pm` (checked via `NotifyList.auto_add_pm?/1`).

### 4.4 Control to command mapping

| Dialog control | Event fired | Equivalent `/notify` invocation |
|----------------|-------------|--------------------------------|
| Add button | `notify_add_dialog` then `notify_add` form submit | `/notify add <nick> [note]` |
| Edit button | `notify_edit_dialog` then `notify_edit` form submit | `/notify edit <nick> <note>` |
| Remove button | `notify_remove` | `/notify remove <nick>` |
| (no UI equivalent) | — | `/notify list` (prints to status area) |
| (no UI equivalent) | — | `/notify` (opens dialog, same as menu item) |
| View menu "Notify List" | `toggle_notify_list` | `/notify` |
| Status bar buddy badge | `toggle_notify_list` | `/notify` |

---

## 5. Permissions and visibility

- **Guests**: full access to the dialog and all CRUD operations during the session. The notify list
  is not persisted between sessions for guests.
- **Registered users**: full access; list persisted to the database.
- **Connected-only**: the View menu and toolbar Options dropdown are disabled (`connected=false`)
  when the user is not connected to a server — consistent with all other View and Tools items in
  `MenuBarApp`. The status bar buddy badge should not render when `connected=false`.
- No admin-only restriction. All users can maintain a notify list.
- The `/notify` command follows the same connected-only gate as other commands.

---

## 6. Help documentation (mandatory)

### Already exists (no changes needed)

- `"cmd-notify"` topic in `HelpTopics.Commands` — id `"cmd-notify"`, title `"/notify"`,
  category `"Contacts & Notify"`, keywords `["notify", "buddy", "friend", "watch"]`,
  icon `:icon_tab_notify`. Covers all subcommands.
- `"feature-notify-list"` topic in `HelpTopics.Features` — title "Notify List (Buddy List)",
  category `"Contacts & Notify"`.
- Additional topics in the `"Contacts & Notify"` category covering Address Book integration.
- Category `"Contacts & Notify"` registered in `HelpTopics` with icon `:icon_dialog_address_book`
  (line 42 of `help_topics.ex`).

### To add / update

1. **Update `"feature-notify-list"` body** — mention the new View menu entry point and the status
   bar buddy badge so the UI description stays accurate. No structural change needed; just augment
   the description sentences.

2. **Update the "User Interface" category topic** (if one exists) — add a cross-reference to the
   Notify List as reachable from View > Notify List.

3. **Update the keyboard shortcuts topic** — if a keyboard shortcut is assigned to
   `toggle_notify_list` in future (currently none), add it here.

4. **Cross-reference** — the `"cmd-notify"` topic should have a "See Also" entry pointing to
   `"feature-notify-list"`, and vice versa. Verify these links exist; add if missing.

No new top-level topics are needed — the feature is already fully documented at the command and
feature level.

---

## 7. Out of scope / open questions

### Out of scope for this wiring task

- Any changes to `NotifyList` domain logic (add/remove/edit/WHOIS already work).
- Changes to the dialog layout or sub-form fields.
- Persistence layer changes (already handled by `maybe_persist_notify_list/2`).
- Notification sound when a buddy comes online (separate feature, tracked elsewhere).
- Keyboard shortcut for opening the Notify List (can be added in a follow-up).
- E2E Playwright tests (the existing liveview feature tests in `notify_events_test.exs` cover the
  event layer; E2E tests for the menu entry point can be added after wiring).

### Open questions

1. **Status bar badge threshold** — should the badge be hidden when zero buddies are online, or
   should it always show (as a persistent affordance to open the dialog)? Recommendation: hide
   when zero to keep the status bar clean, show the View menu item always as the persistent
   affordance.

2. **Icon for menu/toolbar** — `:icon_tab_notify` is used in HelpTopics. Confirm this icon exists
   in `Icons.Communication` or another submodule before wiring. Alternative: `:icon_btn_bell`
   (used in the dialog title bar, definitely exists).

3. **`toolbar_action` routing** — the `toggle_notify_list` phx-event is handled by
   `NotifyEvents`. The `toolbar_action` compound event dispatcher in `ChatLive` dispatches to
   `handle_event/3` chains. Verify that passing `action="toggle_notify_list"` through
   `toolbar_action` will reach `NotifyEvents` correctly, or whether a direct phx-click
   (`phx-click="toggle_notify_list"`) should be used instead (as `toggle_conversations` and
   `toggle_nicklist` do in `MenuToolbarEvents`).

4. **`toggle_notify_list` in `MenuToolbarEvents`** — `toggle_notify_list` is currently only in
   `NotifyEvents`, not in `MenuToolbarEvents`. Since the menu/toolbar fires `toolbar_action` which
   dispatches via the hook chain, confirm whether adding the action to `MenuToolbarEvents` is
   cleaner, or whether relying on the existing `NotifyEvents` catch is sufficient.
