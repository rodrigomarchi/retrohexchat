# Feature Spec: Messaging
**Coverage today:** 🟡 partial · **Priority:** P2 · **Commands:** /me, /msg, /query, /notice, /notice_routing

---

## 1. Overview

RetroHexChat supports five messaging commands that cover the spectrum from plain chat to
action messages, private conversations, and lightweight notices. PMs are already well-served
by existing UI affordances (nicklist and chat context menus expose "Query" and "PM").
The remaining gap is that `/me` (IRC action/emote) and `/notice` have no UI control — they
are command-only today. This spec defines the minimal UI additions to close those gaps.

The guiding principle is restraint: `/me` and `/notice` are low-frequency, power-user
operations. The additions should be discoverable but not prominent.

---

## 2. Commands (grounded in handler source)

| Command | Syntax | Handler result | Key constraints |
|---|---|---|---|
| `/me` | `/me <action>` | `{:ok, :action, %{content: content}}` | Requires an active channel (`active_channel != nil`); action text required; renders as `* YourNick <action>` to all channel members |
| `/msg` | `/msg <nickname> <message>` | `{:ok, :message, %{target: target, content: content}}` | Both nickname and message required; opens/uses a PM conversation tab |
| `/query` | `/query <nickname>` | `{:ok, :ui_action, :open_query, %{nickname: target}}` | Opens a PM tab without sending a message; switches to the tab if it already exists; nickname required |
| `/notice` | `/notice <target> <message>` | `{:ok, :notice, %{target: target, content: content}}` | Target is a nickname or `#channel`; both target and message required; does NOT open a PM window on the recipient's side |
| `/notice_routing` | `/notice_routing` | `{:ok, :ui_action, :notice_routing_show, %{}}` | No arguments; routing is hardcoded to the active window; the handler always returns the `notice_routing_show` ui_action regardless of any arguments passed |

**Rendering notes from handler docs:**
- `/me` action text appears as `* YourNick waves hello` — the asterisk-prefixed third-person form common in IRC.
- `/notice` is a "lightweight" send: the recipient sees the notice in their active window, not in a new PM tab. This is the key distinction from `/msg`.
- `/notice_routing` is informational: it displays (via `notice_routing_show`) that routing is fixed to the active window. There is no user-configurable routing mode.

---

## 3. Current UI state

### Well covered

- **Query / open PM tab:** Nicklist context menu item "Query" invokes `/query <nick>` (open tab, no message). Chat message context menu also exposes this.
- **Send PM with message:** Nicklist context menu item "PM" / "Message" invokes `/msg <nick> <message>` flow.

### Not covered by any UI control

| Gap | Workaround today |
|---|---|
| Send an action/emote (`/me`) | Type `/me <action>` directly in the input box |
| Send a notice to a user or channel (`/notice`) | Type `/notice <target> <message>` directly in the input box |
| Inspect notice routing policy (`/notice_routing`) | Type `/notice_routing` directly in the input box |

There is no button, menu item, or input mode toggle for any of the above.

---

## 4. UI specification — what to build

### 4.1 Entry points

Two new entry points, both minimal:

**A. Emote/Action toggle button in the chat input toolbar**

- Label: `*` (a single asterisk, matching the IRC rendering convention)
- Tooltip: `Send action message (/me)`
- Placement: Inside the chat input area, to the left of the send button (or grouped with any existing formatting controls), visible only when the user is in a channel context (not in server status window or when `active_channel == nil`)
- Behavior: Toggles "action mode" for the current input. When active, the input placeholder changes and the composed text is dispatched as `/me <text>` on send. Toggling off restores normal message mode.
- Keyboard shortcut: None required at this time.

**B. "Send Notice..." item in the nicklist context menu**

- Label: `Send Notice...`
- Placement: In the existing nicklist right-click context menu, after "PM" / "Query", before any destructive items (kick/ban).
- Behavior: Opens an inline mini-composer (see 4.2) pre-filled with the target nickname, allowing the user to type the notice body and send.
- Also available in the chat message context menu (right-click on a nick in a message), same label and position.

**No new entry point for `/notice_routing`:** This command is informational only and the routing policy is not user-configurable. It can remain command-only. An info note in Help is sufficient (see section 6).

---

### 4.2 Layout

#### A. Action mode toggle (input area)

```
+----------------------------------------------------------+
|  [*] [ input field — "What are you doing? (/me mode)" ] |
|                                           [Send]         |
+----------------------------------------------------------+
```

- The `[*]` button is a small square toggle (same size class as other toolbar icons, 16x16).
- When toggled ON, the button appears visually depressed / highlighted (active state via CSS class).
- The input placeholder text changes to: `What are you doing? (/me mode)`
- The rest of the input area is unchanged.
- On send: the composed text is dispatched as `/me <text>`; action mode is automatically reset to OFF after sending (one-shot mode).

Normal mode (default):
```
+----------------------------------------------------------+
|  [ ] [ input field — "Message #channel"               ] |
|                                           [Send]         |
+----------------------------------------------------------+
```

#### B. Notice mini-composer (nicklist context menu flow)

Clicking "Send Notice..." does not open a modal dialog. Instead, it inserts a transient
inline prompt below the nicklist context menu (or uses the main input area in a prefilled
state), following the lightest viable pattern already in the codebase.

Preferred approach — pre-fill the main input area:

```
+----------------------------------------------------------+
| Notice to Alice:                                         |
| [ Check out #project                                ] [X]|
|                                           [Send Notice]  |
+----------------------------------------------------------+
```

- A dismissible label "Notice to <nick>:" appears above (or inline with) the input field.
- The send button label changes to "Send Notice" for the duration.
- Pressing X or Escape cancels notice mode and restores normal input state.
- On send: dispatches `/notice <nick> <text>`; notice mode is cleared.

If the pre-fill approach conflicts with existing input state (e.g., user already has text
typed), a simple confirmation prompt ("Discard current text and send a notice to Alice?")
gates the switch.

---

### 4.3 Interactions and states

#### Action mode toggle

| State | Trigger | Visual | Input behavior |
|---|---|---|---|
| OFF (default) | — | `[*]` button normal | Normal message send |
| ON | Click `[*]` | `[*]` button highlighted; placeholder changes | Send dispatches `/me <text>` |
| Auto-reset | After send in ON state | Returns to OFF | — |
| Disabled | `active_channel == nil` (server window, no channel) | `[*]` button grayed out / hidden | — |
| Error | Action text empty and send attempted | Inline error: "Action message cannot be empty" | Input retains focus |

#### Notice composer

| State | Trigger | Visual |
|---|---|---|
| Idle | — | Normal input area |
| Notice mode | "Send Notice..." clicked | Label shows target; send button relabeled |
| Cancelled | X or Escape pressed | Normal input area restored; typed text discarded |
| Sent | Send button clicked with non-empty text | Notice dispatched; normal input area restored |
| Error — no text | Send clicked with empty body | Inline error: "Notice message cannot be empty" |

---

### 4.4 Control to command mapping

| UI control | Resulting command | Handler module |
|---|---|---|
| `[*]` toggle ON + send "waves hello" | `/me waves hello` | `Handlers.Me` |
| Nicklist > "Send Notice..." > type text > Send Notice | `/notice <nick> <text>` | `Handlers.Notice` |
| Chat msg context menu > "Send Notice..." (same flow) | `/notice <nick> <text>` | `Handlers.Notice` |
| Channel notice: if user prefixes target with `#` manually in notice composer | `/notice #channel <text>` | `Handlers.Notice` |
| `/notice_routing` (command only, no UI) | `notice_routing_show` ui_action | `Handlers.NoticeRouting` |

---

## 5. Permissions and visibility

- **Action toggle (`[*]`):** Visible only when the user is connected and has an active channel. Hidden (or grayed) in the server status window and when `active_channel == nil` (enforced by the same guard already in `Handlers.Me.execute/2`).
- **Send Notice (context menu):** Visible for all connected users. No special role required. Notice delivery is subject to normal channel membership rules (a user cannot notice a channel they are not in, if the server enforces that).
- **Guest users:** If the codebase distinguishes guests from registered users in terms of messaging permissions, those same restrictions apply to these UI controls — the controls are UI wrappers over the same command handlers, which already enforce context constraints.
- **Bots:** Bots that implement the `Handler` behaviour are not affected; these are UI additions to the web layer only.

---

## 6. Help documentation (mandatory)

Per project convention, all features must have corresponding entries in `RetroHexChat.Chat.HelpTopics`.

### Topics to add or update

**New entry — "Action Messages (/me)"** (category: Commands)
- Describe the `* Nick action` rendering.
- Explain the new `[*]` toggle as an alternative to typing `/me` directly.
- Example: `/me waves hello` → `* YourNick waves hello`
- See Also: `/msg`, `/notice`

**New entry — "Notices (/notice)"** (category: Commands)
- Explain that notices appear in the recipient's active window without opening a PM tab.
- Explain that the target can be a nickname or a `#channel`.
- Mention the "Send Notice..." context menu item as a UI shortcut.
- Note that `/notice_routing` shows the current routing policy (always: active window).
- Example: `/notice Alice Check out #project`
- See Also: `/msg`, `/query`, `/me`

**Update existing entry — "Private Messages"** (category: Commands or Features)
- Add a cross-reference to `/notice` as the non-intrusive alternative to `/msg`.
- Mention "Send Notice..." in the context menu list.

**Update "Keyboard Shortcuts" topic** (category: User Interface)
- If a keyboard shortcut is assigned to the action toggle in a future iteration, add it here.
- For now, note that `/me` can be typed directly; no dedicated shortcut exists yet.

---

## 7. Out of scope and open questions

### Out of scope for this spec

- `/notice` targeting a `#channel` via the UI composer (the mini-composer defaults to the nick from context; channel notices remain command-only for now).
- Formatting or color differentiation of received notices vs. regular messages (that is a rendering/theming concern, not a messaging UI concern).
- Configurable notice routing. `Handlers.NoticeRouting` makes clear this is hardcoded: `execute/2` always returns `notice_routing_show` regardless of arguments. There is nothing to configure.
- Autocomplete for the notice target field (though nick autocomplete already exists in the main input and could be reused if the notice mode uses the same input element).
- Mobile / narrow-viewport layout adjustments for the action toggle.

### Honest assessment of priority

`/me` and `/notice` are both low-frequency operations. Power users already type the commands
directly. The UI affordances proposed here are small quality-of-life improvements, not
critical features. It is entirely reasonable to:

- Ship the `[*]` toggle as a single small addition without the notice composer.
- Keep `/notice` command-only indefinitely if the composer adds complexity that outweighs its value.
- Defer both to a later polish pass and focus engineering effort on higher-priority items.

### Open questions

1. Does the existing chat input toolbar have room for a `[*]` toggle, or does it require a toolbar redesign?
2. Should the notice mini-composer reuse the main input element (lighter, avoids two input fields) or render a separate overlay (cleaner separation, more implementation work)?
3. Should "Send Notice..." also appear in a channel's context menu (right-click on channel name in the channel list) to send a notice to the whole channel, or is that too advanced for an initial iteration?
4. What is the desired behavior when the user has unsent text in the input and clicks "Send Notice..." — discard, preserve in a buffer, or block the action?
