# Feature Spec: Channel Configuration
**Coverage today:** 🟡 partial · **Priority:** P2 · **Commands:** /topic, /mode, /slow, /transfer, /setwelcome, /clearwelcome

---

## 1. Overview

Channel Central is the single dialog for inspecting and managing a channel's configuration. It already covers topic editing (General tab) and core mode flags (Modes tab), but three operator-level capabilities have no UI path whatsoever:

- **Join throttle** (`/slow`) — limits how quickly users can join to prevent join-flooding. Maps to IRC mode `+j`.
- **Welcome message** (`/setwelcome` / `/clearwelcome`) — a message shown once per user on join.
- **Ownership transfer** (`/transfer`) — irrevocably hands the `+q` (owner) flag to another channel member.

This spec defines exactly where and how each gap is closed inside the existing Channel Central dialog without adding new dialogs or entry points.

---

## 2. Commands (grounded in handler source)

| Command | Real syntax (from handler) | Required privilege | UI action emitted |
|---|---|---|---|
| `/topic` | `/topic [new topic]` | Operator (if `+t` set); anyone otherwise | `:set_topic` / `:view_topic` |
| `/mode` | `/mode <+/-flags> [params]` | Operator (half-op: `+v`/`-v` only) | `:set_mode` |
| `/slow` | `/slow <seconds>` — `0` disables | Operator | `:set_mode` with `mode_string: "+j"` / `"-j"` |
| `/setwelcome` | `/setwelcome <message>` — no args clears | Operator | `:set_welcome` / `:clear_welcome` |
| `/clearwelcome` | `/clearwelcome` | Operator | `:clear_welcome` |
| `/transfer` | `/transfer <nickname>` | **Owner** (`+q`) only | `:transfer_ownership` |

**Key implementation details from handlers:**

- `slow.ex`: `/slow 0` emits `{:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "-j", params: []}}`. Any positive integer N emits `mode_string: "+j"` with param `"5:N"` (5 joins per N seconds). The handler rejects non-integer and negative values with an inline error.
- `set_welcome.ex`: `/setwelcome` with no args calls `:clear_welcome`, not `:set_welcome`. The two handlers share the same operator check: `channel in context.operator_in`.
- `transfer.ex`: checks `Map.get(context, :owner_in, [])` — distinct from `operator_in`. Emits `:transfer_ownership` with `%{channel: channel, target: nick}`.
- `mode.ex`: half-ops are allowed only `+v`/`-v`; all other flags require full operator.

---

## 3. Current UI state

### What Channel Central already covers

| Tab | Controls present |
|---|---|
| General | Topic field (editable for ops, read-only otherwise); channel info (created, members) |
| Modes | +m, +i, +t, +k, +l checkboxes with apply button |
| Bans | Mask list + Add/Remove |
| Ban Exceptions | Mask list + Add/Remove |
| Invite Exceptions | Mask list + Add/Remove |

### What is missing (no UI path at all)

| Feature | Handler | Gap |
|---|---|---|
| Join throttle (`+j`) | `slow.ex` | Not in Modes tab or anywhere else |
| Welcome message | `set_welcome.ex`, `clear_welcome.ex` | Not in General tab or anywhere else |
| Ownership transfer | `transfer.ex` | Not in any dialog |

---

## 4. UI specification — what to build

All three gaps close inside Channel Central. No new dialogs are introduced.

### 4.1 Entry points

All new controls live inside the existing tabs of the Channel Central dialog (`channel_central_dialog.ex`):

**General tab — two new sections below the existing topic block:**

1. **Welcome Message** — a textarea (multi-line) labeled "Welcome Message:" with a "Save" button and a "Clear" link/button. Visible to all; editable only to ops.
2. **Join Throttle** — a numeric field labeled "Join throttle (seconds):" with a "Apply" button. A value of `0` maps to `/slow 0` (disable). Visible to all; editable only to ops.

**General tab — owner-only danger zone at bottom:**

3. **"Transfer Ownership…"** — a button styled with `variant="destructive"`, visible only when `owner={true}`. Clicking it opens a transfer confirm sub-form (same inline overlay pattern as the existing ban sub-forms).

**Modes tab — no changes.** The `+j` flag is surfaced in the General tab (via `/slow` semantics) rather than as a raw checkbox in Modes, because it requires a numeric parameter and has its own dedicated command.

### 4.2 Layout

#### Updated General tab (ASCII sketch)

```
+------------------------------------------------------+
|  [channel icon]  #lobby                              |
|  Created: 2024-01-15        Members: 42              |
+------------------------------------------------------+
 ─────────────────────────────────────────────────────
  Topic:
  [__________________________________________________]
  Set by alice on 2024-06-01
  [Save Topic]

 ─────────────────────────────────────────────────────
  Welcome Message:
  [__________________________________________________]
  [__________________________________________________]   <- textarea, 3 rows
  [__________________________________________________]
  Shown once to each user on join. Leave blank to disable.
  [Save Welcome]   [Clear Welcome]                       <- ops only; read-only otherwise

 ─────────────────────────────────────────────────────
  Join Throttle:
  Seconds: [____]   (0 = disabled; currently: 30s)
  [Apply Throttle]                                       <- ops only; read-only otherwise

 ─────────────────────────────────────────────────────
  [Transfer Ownership…]                                  <- owner (+q) only, destructive
+------------------------------------------------------+
```

#### Transfer ownership confirm sub-form (same overlay pattern as ban add)

```
+------------------------------------+
| [title bar] Transfer Ownership     |
|------------------------------------|
|  Transfer ownership of #lobby to:  |
|  Nick: [__________________________]|
|                                    |
|  WARNING: This cannot be undone.   |
|  You will be demoted to operator.  |
|                                    |
|  [OK]  [Cancel]                    |
+------------------------------------+
```

The sub-form follows the exact same pattern as `ban_add_sub_form/1`: a `fixed inset-0 z-modal-above` overlay, `bg-surface shadow-retro-window`, `bg-title-bar` title bar, `phx-submit` form, `<.input>` for the nick field, and `<.button>` OK/Cancel pair.

### 4.3 Interactions & states

**Welcome Message:**

- Non-ops: textarea rendered with `disabled` attribute; "Save Welcome" / "Clear Welcome" buttons absent. Read-only note shown: "You must be a channel operator to edit the welcome message."
- Ops: textarea enabled. "Save Welcome" submits `cc_save_welcome` event with `%{"message" => text}`. If text is blank, the event handler treats it as clear (mirrors `set_welcome.ex` behaviour: no-args = clear).
- "Clear Welcome" button submits `cc_clear_welcome` event (no payload needed beyond channel context).
- After save or clear: dialog remains open; a status flash or inline confirmation line is shown.
- When welcome is currently set: textarea is pre-populated with the existing message. When none is set: placeholder text "No welcome message set."

**Join Throttle:**

- Non-ops: input rendered `disabled`; current value displayed (e.g., "30" or "0 (disabled)"). Read-only note shown.
- Ops: numeric `<input type="number" min="0">` (HTML native, not UI primitive, per project conventions for sub-forms). Value `0` disables; any positive integer sets the throttle.
- "Apply Throttle" button submits `cc_apply_throttle` event with `%{"seconds" => value}`.
- Client-side: the field accepts only non-negative integers; the LiveView handler validates server-side and returns an error message if invalid.
- When `+j` is active: field shows current seconds value. When not active: field shows `0`.

**Transfer Ownership:**

- Button visible only when `owner={true}` assign is truthy (parallel to `operator` assign pattern already used throughout the dialog).
- Clicking fires `cc_open_transfer` event, which sets `show_transfer_dialog: true` in socket assigns.
- The sub-form `transfer_confirm_sub_form/1` renders when `@show_transfer_dialog` is true (same `:if` guard used by the ban sub-forms).
- "OK" submits `cc_transfer_ownership` with `%{"nickname" => nick}`. The LiveView handler calls the `:transfer_ownership` UI action then closes the dialog.
- "Cancel" fires `cc_close_transfer`, setting `show_transfer_dialog: false`.
- Nick field is validated non-empty on submit; if empty, the form shows an inline error.
- The dialog `lock` attribute (already used in the component) must include `@show_transfer_dialog` alongside the existing ban sub-form conditions.

### 4.4 Control → command mapping

| UI control | LiveView event | UI action dispatched | Underlying command |
|---|---|---|---|
| Save Welcome button | `cc_save_welcome` | `:set_welcome` | `/setwelcome <message>` |
| Clear Welcome button | `cc_clear_welcome` | `:clear_welcome` | `/clearwelcome` |
| Apply Throttle button | `cc_apply_throttle` | `:set_mode` `+j "5:N"` or `-j` | `/slow <seconds>` |
| Transfer Ownership OK | `cc_transfer_ownership` | `:transfer_ownership` | `/transfer <nick>` |
| Transfer Ownership Cancel | `cc_close_transfer` | (none) | (none) |

---

## 5. Permissions & visibility

| Control | Visible to | Editable / clickable by |
|---|---|---|
| Topic field | All members | Operator (or anyone if `+t` not set) |
| Modes tab (all flags) | All members (read-only for non-ops) | Operator |
| Welcome Message | All members (read-only for non-ops) | Operator (`channel in context.operator_in`) |
| Join Throttle | All members (read-only for non-ops) | Operator (`channel in context.operator_in`) |
| Transfer Ownership button | **Owner only** — hidden if `owner={false}` | Owner (`channel in context.owner_in`) |

The `channel_central_dialog` component currently receives `operator` as a boolean assign. A new `owner` boolean assign must be added (default `false`) and threaded from the LiveView that renders the dialog, analogous to how `operator` is already threaded. The LiveView derives `owner` from `context.owner_in` containing the current channel.

---

## 6. Help documentation (mandatory)

Three new help topics must be added to `RetroHexChat.Chat.HelpTopics` (exact module/file TBD by implementer — follow the existing pattern of per-file modules like `channel_modes.ex`):

### Topic 1: Welcome Message

```
id: "channel-welcome-message"
title: "Channel Welcome Message"
category: "Channels"
keywords: ["welcome", "welcome message", "join message", "setwelcome", "clearwelcome"]
icon: :icon_megaphone
description: "Set a message that is shown once to each user when they join your channel."
```

Content must explain:
- How to set via `/setwelcome <message>` or Channel Central > General tab
- How to clear via `/clearwelcome` or Channel Central > General tab "Clear Welcome" button
- That the message is shown once per user per join (not a persistent pin)
- Operator privilege required

### Topic 2: Join Throttle

If not already covered sufficiently — `channel_modes.ex` already has `mode-j` with `id: "mode-j"`. Augment that existing topic's description to mention the `/slow` command and the Channel Central UI control, rather than adding a duplicate topic.

### Topic 3: Ownership Transfer

```
id: "channel-transfer-ownership"
title: "Transfer Channel Ownership"
category: "Channels"
keywords: ["transfer", "ownership", "owner", "transfer ownership", "new owner"]
icon: :icon_role_owner
description: "Pass the channel owner (+q) flag to another member. You are demoted to operator."
```

Content must explain:
- The action is permanent and cannot be undone from the UI
- The new owner gains `+q`; the previous owner is demoted to `+o`
- How to use via `/transfer <nickname>` or Channel Central > General tab > "Transfer Ownership…" button
- Owner privilege required

### Cross-references to add

- The existing `channel-permissions` topic should reference `channel-transfer-ownership` in its "See Also" list.
- The existing `mode-j` topic should reference `/slow` command in its description.
- The new `channel-welcome-message` topic should reference `channel-modes-overview` as "See Also."

---

## 7. Out of scope / open questions

**Out of scope for this spec:**

- Displaying the current welcome message to non-op members (read-only textarea is sufficient; a dedicated preview UI is not needed).
- Persisting welcome message across server restarts — that is a backend concern handled by the existing channel state layer.
- `/mode +j` raw checkbox in the Modes tab — `/slow` via the General tab is the intended UX path.
- Any changes to the Bans, Ban Exceptions, or Invite Exceptions tabs.
- Half-op privilege path for any of the three new controls (half-ops cannot set welcome, slow, or transfer).

**Open questions:**

1. **Welcome message source of truth**: where is the welcome message stored (ETS, DB, channel GenServer state)? The spec assumes the LiveView already has access to it via assigns; the data-loading path is for the implementer to confirm.
2. **Throttle value display**: when `+j` is active, what format does the channel state expose — raw `"5:30"` string or parsed `{joins, seconds}`? The UI needs only the seconds component. Implementer should confirm the assigns shape.
3. **Owner assign derivation**: confirm that `owner_in` is available on the LiveView socket context in the same way `operator_in` is. If not, it may need to be added to the context map.
4. **Transfer nick validation**: should the UI validate that the target nick is currently in the channel (rejecting an unknown nick before dispatching)? The handler does not enforce this — it emits the UI action unconditionally. A pre-dispatch member list check would improve UX.
5. **Welcome character limit**: is there a server-enforced maximum length for welcome messages? If so, the textarea should render `maxlength` and show a character counter.
