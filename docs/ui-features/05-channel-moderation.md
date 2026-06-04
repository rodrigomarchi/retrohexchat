# Feature Spec: Channel Moderation
**Coverage today:** 🟡 partial (grant-only) · **Priority:** P1 · **Commands:** /kick, /ban, /unban, /mute, /unmute, /op, /deop, /voice, /devoice

## 1. Overview

RetroHexChat ships a full set of channel-moderation slash commands, but the
point-and-click surface (the nicklist and chat context menus) only exposes the
**grant / destructive** half of them. From the menus an operator can Kick, Ban,
Give Op (+o), and Give Voice (+v) a user — but there is no menu item to **Remove
Op** (`/deop`), **Remove Voice** (`/devoice`), or **Mute / Unmute** a user at the
channel level (`/mute`, `/unmute`). The only way to reverse op/voice or to mute
without typing is through the command line.

Note: the "Mute" item that already exists in the conversations context menu is a
**notification** mute (silence pings for a conversation), not a moderation mute.
It does not call `/mute` and is out of scope here except to avoid label
collisions.

This spec closes the gap by making the op/voice menu items **status-aware**
(toggle between grant and remove based on the target's current role) and adding
channel **Mute / Unmute** entries, with a duration sub-prompt for timed mute (and
optionally ban). Ban/unban already have a managed surface in the Channel Central
"Bans" tab; that surface stays, and the context-menu Ban gains a paired Unban
path only where it makes sense (see §3).

## 2. Commands (grounded in handler source)

All rows below are quoted from the handler modules under
`apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/`. The "Required level"
column reflects the `require_*` guard each handler runs in `execute/2`.

| Command | Syntax (from handler) | What it does | Required level |
|---------|-----------------------|--------------|----------------|
| `/kick` | `/kick <nickname> [reason]` | Remove a user from the channel with an optional reason; they can rejoin unless also banned. Emits `:ui_action, :kick_user, %{channel, target, reason}`. | operator **or** half-operator (`require_kick_privilege`) |
| `/ban` | `/ban <nickname> [reason]` | Permanently block a user from the channel; persists until removed with `/mode -b`. Emits `:ui_action, :ban_user, %{channel, target, reason}`. | operator (`require_operator`) |
| `/unban` | `/unban <nickname>` | Remove a ban from a user, allowing them to rejoin. Emits `:ui_action, :unban_user, %{channel, target}`. | operator (`require_operator`) |
| `/mute` | `/mute <nickname> [duration]` | Channel-level mute: muted user cannot send messages. `duration` parsed via `Commands.Duration.parse/1`; omit for permanent. Emits `:ui_action, :channel_mute_user, %{channel, target, duration}`. | operator (`require_operator`) |
| `/unmute` | `/unmute <nickname>` | Remove a channel-level mute. Emits `:ui_action, :channel_unmute_user, %{channel, target}`. | operator (`require_operator`) |
| `/op` | `/op <nickname>` | Give channel operator status. Shortcut for `/mode +o`. Emits `:ui_action, :set_mode, %{channel, mode_string: "+o", params: [nick]}`. | operator (`require_operator`) |
| `/deop` | `/deop <nickname>` | Remove channel operator status. Shortcut for `/mode -o`. Emits `:ui_action, :set_mode, %{channel, mode_string: "-o", params: [nick]}`. | operator (`require_operator`) |
| `/voice` | `/voice <nickname>` | Give voice status. Shortcut for `/mode +v`. Emits `:ui_action, :set_mode, %{channel, mode_string: "+v", params: [nick]}`. | half-operator or above (`require_half_op_or_above`) |
| `/devoice` | `/devoice <nickname>` | Remove voice status. Shortcut for `/mode -v`. Emits `:ui_action, :set_mode, %{channel, mode_string: "-v", params: [nick]}`. | half-operator or above (`require_half_op_or_above`) |

**Duration details (real):**

- `/mute` is the only timed command in this set. The handler does
  `duration = Duration.parse(List.first(rest))`, so the second positional token is
  the duration. The handler help string documents the accepted forms:
  `"Duration: 30s, 5m, 1h, 1d. Omit for permanent."` Examples shipped in the
  handler: `/mute troll` and `/mute troll 30m`.
- `/ban` takes `[reason]` (free text joined from `rest`), **not** a duration —
  its help says the ban "persists until removed with `/mode -b`." There is no
  timed-ban argument in the handler today. Any "duration for ban" idea in §4 is
  therefore explicitly an **open question**, not a grounded feature.
- `/kick` takes `[reason]` (free text), no duration.
- `/op`, `/deop`, `/voice`, `/devoice`, `/unban`, `/unmute` take a nickname only.

## 3. Current UI state

### Nicklist context menu
`components/ui/chat/nicklist_context_menu.ex`. The operator section is gated by
`@viewer_is_op && !@is_target_self` and renders exactly four items:

- `context_kick` → "Kick" (`icon_dialog_kick`)
- `context_ban` → "Ban" (`icon_ban`)
- `context_voice` → "Give Voice (+v)" (`icon_role_voiced`)
- `context_op` → "Give Op (+o)" (`icon_role_operator`)

### Chat context menu (nick type)
`components/ui/chat/chat_context_menu.ex`, `nick_menu_items/1`. Same gating
(`@viewer_is_op && !@is_target_self`), same four items with `ctx_chat_` prefixes:

- `ctx_chat_kick` → "Kick"
- `ctx_chat_ban` → "Ban"
- `ctx_chat_voice` → "Give Voice (+v)"
- `ctx_chat_op` → "Give Op (+o)"

### Missing from both menus
- **Remove Op** (`/deop`) — no item.
- **Remove Voice** (`/devoice`) — no item.
- **Mute** (`/mute`) — no item (the existing "Mute" elsewhere is notification mute).
- **Unmute** (`/unmute`) — no item.
- **Unban** (`/unban`) from the context menu — no item (see Channel Central note).

The menus are **grant-only**: an operator can promote/voice but cannot demote or
de-voice, and cannot mute, without typing a command.

### Channel Central — Bans tab
`components/ui/dialogs/channel_central_dialog.ex` already provides a managed
ban surface in the "Bans" tab (`list_tab`): a table of ban masks with Add / Remove
buttons (`on_ban_add` opens the `ban_add_sub_form` collecting a `nickname`/hostmask;
`on_ban_remove` removes the selected row; gated on `@operator`). **Ban and unban
are therefore already covered** through this dialog, so the context-menu work for
ban/unban is optional polish rather than the core gap. Channel Central does **not**
cover op/voice/mute, which is why those belong in the context menus.

## 4. UI specification — what to build

The goal is the smallest change that makes moderation reversible from the menu:
status-aware op/voice items plus channel mute/unmute, sharing the existing
`on_action` dispatch and `phx-value-nick` plumbing.

### 4.1 Entry points

Add the inverse / missing actions to **both** the nicklist context menu and the
chat (`:nick`) context menu, inside the existing operator-gated section. Each
op/voice item becomes a single status-aware slot that renders either the grant or
the remove variant based on the target's current channel role:

- **Op slot** — show "Give Op (+o)" (`context_op` / `ctx_chat_op`) when the target
  is **not** an op; show "Remove Op (-o)" (`context_deop` / `ctx_chat_deop`) when
  the target **is** an op.
- **Voice slot** — show "Give Voice (+v)" (`context_voice` / `ctx_chat_voice`) when
  the target is **not** voiced; show "Remove Voice (-v)" (`context_devoice` /
  `ctx_chat_devoice`) when the target **is** voiced.
- **Mute slot** — new. Show "Mute" (`context_mute` / `ctx_chat_mute`) when the
  target is not channel-muted; show "Unmute" (`context_unmute` / `ctx_chat_unmute`)
  when the target is muted. Label as "Mute (channel)" / "Unmute (channel)" if there
  is any risk of confusion with notification mute in the same surface.

This requires new attrs on both menu components describing the target's current
status, e.g. `is_target_op`, `is_target_voiced`, `is_target_muted` (booleans,
default `false`). The parent LiveView already knows each nick's role from the
nicklist member data and supplies them.

For mute (and, if pursued, timed ban) add an optional **duration sub-prompt**: a
small Win98-style sub-dialog matching the existing `ban_add_sub_form` pattern in
Channel Central, collecting a duration token (`30s`, `5m`, `1h`, `1d`, or blank =
permanent) before dispatching. If no sub-prompt is shown, Mute dispatches with an
empty/blank duration (permanent), matching `/mute <nick>` with no second arg.

### 4.2 Layout

The moderation section renders inside the existing operator separator block. Items
are status-aware: each slot shows exactly one label at a time. ASCII sketch of the
operator section after the change (target is currently an op, voiced, not muted):

```
------------------------------------   (separator, viewer_is_op && !self)
  [kick icon]   Kick
  [ban icon]    Ban
  [voice icon]  Remove Voice (-v)      <- devoice, because target is voiced
  [op icon]     Remove Op (-o)         <- deop, because target is op
  [mute icon]   Mute (channel)         <- mute, because target not muted
------------------------------------
```

For a plain (non-op, non-voiced, muted) target the same slots render:

```
------------------------------------
  [kick icon]   Kick
  [ban icon]    Ban
  [voice icon]  Give Voice (+v)
  [op icon]     Give Op (+o)
  [mute icon]   Unmute (channel)
------------------------------------
```

Icons: reuse `icon_role_operator` (op slot), `icon_role_voiced` (voice slot),
`icon_dialog_kick` (kick), `icon_ban` (ban). The mute slot needs an icon — reuse an
existing mute/silence glyph from the appropriate `Icons.*` submodule (Media or
Communication) or add one per the SVG Architecture rules in CLAUDE.md (NO inline
SVG). Order within the section: Kick, Ban, Voice slot, Op slot, Mute slot — keeping
the existing destructive-first ordering and appending mute at the end.

Optional mute duration sub-prompt (mirrors `ban_add_sub_form`):

```
+-- Mute user: troll ----------[x]--+
|  Duration: [ 30m            ]      |
|  (blank = permanent; 30s/5m/1h/1d) |
|                    [ OK ] [Cancel] |
+------------------------------------+
```

### 4.3 Interactions & states

- **Status-aware visibility:** each slot reads the target's current role. Op slot
  ↔ `/op` vs `/deop`; voice slot ↔ `/voice` vs `/devoice`; mute slot ↔ `/mute` vs
  `/unmute`. Only one label per slot is rendered at a time (mirror the existing
  ignore/unignore pattern that already uses `if @is_target_ignored`).
- **Destructive confirmation:** Kick and Ban remain destructive. Keep current
  behavior (no spec change), or — if a confirmation step is desired — gate them
  behind a small confirm dialog. Deop/devoice/unmute are reversible and need **no**
  confirmation. Mute is reversible; no confirmation required, but it may open the
  duration sub-prompt.
- **Duration entry (mute):** clicking Mute either (a) dispatches immediately with
  blank duration = permanent, or (b) opens the duration sub-prompt. Choose (b) for
  parity with the handler's `[duration]` capability; submit sends the token to the
  `/mute` mapping below. Unmute never prompts.
- **Self-target:** never render the moderation section for the viewer's own row
  (existing `!@is_target_self` guard already enforces this).
- **Reason for kick/ban:** unchanged from today — the menu dispatches without a
  reason (the handler accepts a missing reason); a reason sub-prompt is out of
  scope.

### 4.4 Control → command mapping

| Menu control (label) | Action value (nicklist / chat) | Slash command dispatched | Notes |
|----------------------|--------------------------------|--------------------------|-------|
| Kick | `context_kick` / `ctx_chat_kick` | `/kick <nick>` | existing; reason optional, not collected in menu |
| Ban | `context_ban` / `ctx_chat_ban` | `/ban <nick>` | existing; op-only |
| Unban (optional, if added) | `context_unban` / `ctx_chat_unban` | `/unban <nick>` | shown only if target is banned; otherwise managed via Channel Central Bans tab |
| Give Voice (+v) | `context_voice` / `ctx_chat_voice` | `/voice <nick>` | shown when target not voiced |
| Remove Voice (-v) | `context_devoice` / `ctx_chat_devoice` | `/devoice <nick>` | NEW; shown when target voiced |
| Give Op (+o) | `context_op` / `ctx_chat_op` | `/op <nick>` | shown when target not op |
| Remove Op (-o) | `context_deop` / `ctx_chat_deop` | `/deop <nick>` | NEW; shown when target op |
| Mute (channel) | `context_mute` / `ctx_chat_mute` | `/mute <nick> [duration]` | NEW; optional duration sub-prompt |
| Unmute (channel) | `context_unmute` / `ctx_chat_unmute` | `/unmute <nick>` | NEW; shown when target muted |

All actions flow through the existing single `on_action` callback with
`phx-value-nick={@target_nick}`; the duration sub-prompt adds a
`phx-value-duration` (or a form field `duration`) for mute only.

## 5. Permissions & visibility

- **Section gating:** the whole moderation section stays hidden for non-ops.
  Today both menus gate on `@viewer_is_op`. Note the handlers are finer-grained:
  - `/kick` and `/voice` / `/devoice` require **half-operator or above**.
  - `/op` / `/deop` / `/ban` / `/unban` / `/mute` / `/unmute` require **full operator**.
  - If the UI ever distinguishes half-op viewers, the voice/devoice/kick items
    should appear for half-ops while op/ban/mute remain op-only. Today the menu has
    only `viewer_is_op`; either keep op-only gating (simplest, matches current
    behavior) or thread a `viewer_is_half_op` attr to expose voice/kick to half-ops.
    Recommended: keep current op-only gating for v1 and note the half-op refinement
    as follow-up (the server still enforces the real guard, so no privilege is
    leaked either way).
- **Never on self:** the section never renders for the viewer's own row
  (`!@is_target_self`), so a user cannot deop/mute themselves from the menu.
- **Server is source of truth:** the handlers re-check privilege on execute
  (`require_operator` / `require_half_op_or_above`), so a hidden or stale menu item
  can never bypass authorization — the UI gating is convenience, not security.

## 6. Help documentation (mandatory)

Per CLAUDE.md "Help System (mandatory)", every new feature ships help docs in
`RetroHexChat.Chat.HelpTopics`
(`apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`):

- Ensure each command has a Commands-category topic: `/kick`, `/ban`, `/unban`,
  `/mute`, `/unmute`, `/op`, `/deop`, `/voice`, `/devoice`. Source the syntax and
  description strings from each handler's `help/0` (already quoted in §2) so the
  help text and the handler stay in sync.
- Add or update a User-Interface-category topic describing the status-aware
  moderation items in the nicklist and chat context menus (which items appear, when
  they toggle between grant/remove, and the mute duration sub-prompt).
- Update the "Keyboard Shortcuts" topic only if shortcuts are added (none planned).
- Add "See Also" cross-references between the moderation command topics and the
  context-menu UI topic, and between `/mute`↔`/unmute`, `/op`↔`/deop`,
  `/voice`↔`/devoice`, `/ban`↔`/unban`.

## 7. Out of scope / open questions

- **Timed ban.** The `/ban` handler accepts `[reason]`, not a duration; there is no
  timed-ban path today. A ban duration sub-prompt is **out of scope** unless the
  handler is first extended. Open question: do we want timed bans, and if so via a
  new handler arg or a scheduled `/mode -b`?
- **Kick/ban reason capture in the menu.** Handlers accept an optional reason, but
  the current menus dispatch without one. Collecting a reason via sub-prompt is a
  possible enhancement, not part of this gap.
- **Half-op viewers.** Current menus only know `viewer_is_op`. Exposing
  voice/devoice/kick to half-ops (which the handlers allow) needs a new viewer attr;
  deferred to follow-up (§5).
- **Notification mute vs channel mute label collision.** Need a final decision on
  whether the channel-mute item is labeled "Mute (channel)" everywhere or only in
  surfaces that also show notification mute, to avoid user confusion.
- **Where does target role come from for status-aware labels?** Confirm the
  nicklist member struct exposes op/voice/mute flags to the menu components; if the
  muted flag is not currently broadcast to the client, that plumbing is a
  prerequisite for the Mute/Unmute toggle.
