# Feature Spec: Channel Membership

**Coverage today:** 🟡 partial · **Priority:** P1 · **Commands:** /join, /part, /leave, /list, /knock, /invite

---

## 1. Overview

Channel membership covers how users discover, enter, and leave channels, and how access is managed for restricted channels. The core join/part/list flows have UI today. Two gaps remain:

1. **Send-invite UI** — `/invite <nick> [#channel]` dispatches the existing `send_invite` ui_action but there is no surface that lets an op trigger it without typing the command. The `InviteDialog` (`ui/dialogs/invite_dialog.ex`) is receive-only: it shows inbound invites with "Join" / "Ignore" and has no send path.

2. **Knock UI** — `/knock #channel [message]` dispatches the `knock_channel` ui_action but there is no surface that triggers it. Users who encounter a `+i` channel in the Channel List have no discoverable way to request access.

Both gaps mean features are command-line only, with zero discoverability from the GUI.

---

## 2. Commands (grounded in handler source)

| Command | Syntax | Notes |
|---------|--------|-------|
| `/join` | `/join #channel [password]` | Creates channel if it does not exist. Max 50-char name, no spaces, must start with `#`. Limited to `max_channels` (default 10). Password required when channel has `+k` mode. Returns `{:ok, :join, channel_name, password}`. |
| `/part` | `/part [#channel] [message]` | Leaves current channel if no `#channel` arg. First token treated as message when it does not start with `#`. Returns `{:ok, :part, channel_name, message}`. |
| `/leave` | `/leave [#channel] [message]` | Alias of `/part` — identical behaviour. |
| `/list` | `/list` | Opens the Channel List dialog via `{:ok, :ui_action, :open_channel_list, %{}}`. No server-side filtering; filtering is client-side in the dialog. |
| `/knock` | `/knock #channel [message]` | Requests access to a `+i` channel. Dispatches `{:ok, :ui_action, :knock_channel, %{channel: channel_name, message: message}}`. Optional message is delivered to channel operators. |
| `/invite` | `/invite <nickname> [#channel]` | Invites a user to a channel. Dispatches `{:ok, :ui_action, :send_invite, %{target: nickname, channel: channel}}`. Defaults to active channel when no `#channel` arg. `/invite auto` toggles `auto_join_on_invite` on the session. |

---

## 3. Current UI state

| Surface | What it does | Status |
|---------|-------------|--------|
| Channel List dialog (`ui/dialogs/channel_list.ex`) | Lists public channels; search/filter; "Join" button on selected row | Exists |
| Chat context menu (`ui/chat/chat_context_menu.ex`) | "Join #channel" on a channel mention in chat | Exists (not audited here) |
| Conversations context menu (`ui/chat/conversations_context_menu.ex`) | "Leave Channel" — action `ctx_conversations_leave` | Exists |
| Invite dialog (`ui/dialogs/invite_dialog.ex`) | Receive-only: shows inbound invites with "Join" / "Ignore" per card | Exists — **receive only** |
| Invite send UI | No button, menu item, or dialog to trigger `/invite` from the GUI | **MISSING** |
| Knock UI | No button or dialog to trigger `/knock` from the GUI | **MISSING** |
| Channel List — invite-only indicator | `+i` channels are not visually distinguished; no "Knock" affordance | **MISSING** |

The `send_invite` ui_action is fully implemented in `ChatLive.UiActions.Invite` and performs all server-side validation (op check, +i mode check, target not already in channel, target online). It just has no GUI entry point.

---

## 4. UI specification — what to build

### 4.1 Entry points

#### 4.1.1 Send-Invite — nicklist context menu (op-only)

Add one new item to the op actions section of `NicklistContextMenu` (`ui/chat/nicklist_context_menu.ex`), visible only when `@viewer_is_op && !@is_target_self`:

```
Invite to Channel...    [icon: icon_dialog_invite]
action: "context_invite_to_channel"
phx-value-nick: @target_nick
```

The item sits at the top of the op section, before "Kick". Clicking it opens a lightweight channel-picker dialog (see §4.2.1). The dialog calls the existing `send_invite` ui_action — no new backend logic required.

Label: **"Invite to Channel..."** (trailing ellipsis signals a follow-up dialog, matching Windows 98 conventions).

#### 4.1.2 Knock — Channel List dialog

When a channel row has `+i` mode set, the Channel List "Join" button is replaced by a "Request Access..." button for that selection. Additionally, an inline badge/tag is shown in the channel name cell.

```
[icon: icon_dialog_invite]  (lock/invite badge on channel name cell)
Footer button label (when +i selected): "Request Access..."
action: opens Knock dialog (see §4.2.2)
```

Label: **"Request Access..."**

Alternative entry point: users may also type `/knock` directly; this path already works. The Channel List is the primary discoverability surface.

#### 4.1.3 Knock — standalone (for channels not yet visible in list)

Keep `/knock` working as a raw command for power users who already know the channel name. No additional GUI entry point needed for this case.

---

### 4.2 Layout

#### 4.2.1 Invite Channel Picker dialog

A small modal dialog, composited from existing `Dialog`, `Input` (or `Select`), and `Button` primitives.

```
+--------------------------------------------------+
| [icon] Invite to Channel               [X]       |
+--------------------------------------------------+
| Inviting: Alice                                  |
|                                                  |
| Channel:  [ #lobby              v ]              |
|           (dropdown of channels viewer is in)    |
|                                                  |
+--------------------------------------------------+
|  [icon] Send Invite      [icon] Cancel           |
+--------------------------------------------------+
```

- Title: "Invite to Channel"
- Target nickname shown as read-only text (pre-filled from right-click target)
- Channel selector: dropdown (`<select>`) listing only channels the viewer is currently a member of; active channel pre-selected
- Footer: "Send Invite" (primary) + "Cancel" (outline)
- On submit: dispatches `send_invite` ui_action with `%{target: nick, channel: selected_channel}`

#### 4.2.2 Knock Request dialog

A small modal dialog.

```
+--------------------------------------------------+
| [icon] Request Channel Access          [X]       |
+--------------------------------------------------+
| Channel: #private                                |
|                                                  |
| Message (optional):                              |
| +----------------------------------------------+ |
| | Hey, can I join?                             | |
| +----------------------------------------------+ |
|   Max 200 characters                             |
+--------------------------------------------------+
|  [icon] Send Request     [icon] Cancel           |
+--------------------------------------------------+
```

- Title: "Request Channel Access"
- Channel shown as read-only text (pre-filled from Channel List selection or `/knock` parse)
- Message: optional `<textarea>`, max 200 characters, placeholder "Leave a message for the channel operators (optional)"
- Character counter below textarea
- Footer: "Send Request" (primary) + "Cancel" (outline)
- On submit: dispatches `knock_channel` ui_action with `%{channel: channel, message: message_or_nil}`

#### 4.2.3 Channel List — invite-only indicator

Add a small lock badge to the channel name cell when `ch.modes` includes `+i` (requires channel data to carry modes):

```
| #private  [+i]  |  3  |  Members only          |
```

The `[+i]` badge is a short `<span>` styled as a pill tag using existing Tailwind classes. When a `+i` row is selected, the footer "Join" button is replaced by "Request Access...".

---

### 4.3 Interactions and states

#### Invite Channel Picker

| State | Behaviour |
|-------|-----------|
| Opened with no channels joined | Dropdown empty; "Send Invite" disabled; helper text "You must be in a channel to invite someone" |
| Channel selected, submit | Calls `send_invite`; dialog closes on success; system message "* Inviting Alice to #private" appears in chat |
| Target already in channel (server error) | Dialog stays open; error shown inline below channel selector |
| Viewer not an op (server error) | Dialog stays open; error shown inline |
| Network / unknown error | Dialog stays open; generic error shown inline |

#### Knock Request dialog

| State | Behaviour |
|-------|-----------|
| Opened from Channel List | Channel field pre-filled; message empty |
| Message exceeds 200 chars | Character counter turns red; "Send Request" disabled |
| Submit success | Dialog closes; system message "* Knock sent to #private" in chat (or the current channel if no active channel) |
| Channel not found / not +i (handler error) | Dialog stays open; error shown inline |

#### Channel List — +i rows

| State | Behaviour |
|-------|-----------|
| `+i` channel selected | Footer shows "Request Access..." instead of "Join" |
| Non-`+i` channel selected | Footer shows "Join" as today |
| Already a member of the `+i` channel | Footer shows "Join" (join still works as normal; the user already has access) |

---

### 4.4 Control to command mapping

| UI action | Dispatched ui_action | Handler module |
|-----------|----------------------|----------------|
| Nicklist ctx "Invite to Channel..." → channel picker → "Send Invite" | `:send_invite` `%{target: nick, channel: channel}` | `ChatLive.UiActions.Invite.handle_ui_action/3` |
| Channel List "Request Access..." → knock dialog → "Send Request" | `:knock_channel` `%{channel: channel, message: message}` | (knock_channel ui_action handler — must be verified/created) |
| Existing: InviteDialog "Join" | `invite_accept` event | `ChatLive` (existing) |
| Existing: InviteDialog "Ignore" | `invite_ignore` event | `ChatLive` (existing) |
| Existing: ConversationsContextMenu "Leave Channel" | `ctx_conversations_leave` | `ChatLive.ConversationsContextMenuEvents` |

Note: The `knock_channel` ui_action is dispatched by the `/knock` handler but its LiveView handler (`handle_ui_action(socket, :knock_channel, ...)`) must be verified to exist. If it does not exist, it must be created as part of this feature.

---

## 5. Permissions and visibility

### Invite

- The "Invite to Channel..." nicklist menu item is shown only when `@viewer_is_op && !@is_target_self` — consistent with the existing op section gate.
- The server-side `send_invite` ui_action already enforces the operator check and returns `{:error, "* You are not a channel operator"}` if the viewer lacks the role. The UI gate is a usability convenience only; the server is authoritative.
- The `/invite` command (typed directly) is available to anyone; the server rejects non-ops. This spec does not change command-line behaviour.

### Knock

- "Request Access..." in the Channel List and the `/knock` command are available to all users (no role restriction).
- Operators of the target channel receive the knock notice. The channel must have `+i` mode for the knock to be meaningful, but the server does not reject knocks to non-`+i` channels (check handler source for exact behaviour).
- A user who is already a member of the channel should not see "Request Access..." — the Channel List should show "Join" for channels the viewer is already in (or a disabled "Already joined" state if that is cleaner).

---

## 6. Help documentation (mandatory)

All topics go in `RetroHexChat.Chat.HelpTopics` (`apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`).

### New / updated topics required

| Topic key | Category | Content |
|-----------|----------|---------|
| `invite_send` | Commands | Explain `/invite <nick> [#channel]`, the "Invite to Channel..." nicklist menu item, op-only restriction, and the `/invite auto` toggle. |
| `knock` | Commands | Explain `/knock #channel [message]`, when to use it (invite-only channels), the "Request Access..." button in Channel List, and that operators see the request. |
| `channel_list` | Features | Update to mention the `+i` badge and "Request Access..." button added in this feature. |
| `invite_receive` | Features | Update "See Also" to cross-reference `invite_send`. |

### Cross-references to update

- `invite_receive` topic: add "See Also: invite_send, knock"
- `join` topic: add "See Also: knock, invite_send" (for restricted channels)
- `channel_modes` topic (if exists): reference `+i` and its UI implications

---

## 7. Out of scope / open questions

### Out of scope

- Changing the receive-side `InviteDialog` behaviour — it is not being modified.
- Adding "Invite to Channel..." anywhere other than the nicklist context menu (e.g. chat context menu, conversations context menu) — single entry point is sufficient for P1.
- Batch invite (inviting multiple users at once).
- Surfacing knock notices to operators in the UI — that is a notification/alert feature, separate from membership UI.
- `/invite auto` toggle — already accessible via command; no GUI toggle planned in this spec.

### Open questions

1. **`knock_channel` ui_action handler** — does `ChatLive.UiActions.Knock` (or equivalent) exist? The handler dispatches `{:ok, :ui_action, :knock_channel, %{}}` but the LiveView handler must be confirmed. If missing, its implementation is in scope for this feature ticket.

2. **Channel List modes data** — the `ch` struct in `ChannelList` currently carries `:name`, `:user_count`, `:topic`. Does it carry `:modes` or a parsed `modes_detail`? If not, the Channel List data-fetching layer must be extended to include invite-only status so the `+i` badge and button swap can be rendered.

3. **Knock target not in Channel List** — if a user knows a `+i` channel name but it does not appear in the public list, the only path is `/knock` typed directly. A "Knock on a channel..." option in the Channel List footer (disabled state with a text field) is one option; leave for a follow-up.

4. **Error feedback placement** — the spec calls for inline errors inside the dialogs. Confirm this matches the existing error pattern used in other dialogs (e.g. alias dialog, autorespond dialog) before implementation.

5. **Icon choice for Knock** — `icon_dialog_invite` is proposed for both invite send and knock. A distinct "door knock" or "request" icon may be preferable for knock. Confirm with design before implementation.
