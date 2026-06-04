# Feature Spec: User Lookups

**Coverage today:** partial — **Priority:** P3 — **Commands:** /whois, /whowas

---

## 1. Overview

RetroHexChat supports two user-lookup commands. `/whois` retrieves live presence data for an
online user; `/whowas` retrieves cached data for a user who recently disconnected. Today both
commands produce plain status-text lines appended to the active chat window. There is no
structured result panel, no dedicated dialog for typing a nick, and `/whowas` is entirely absent
from every context menu — users can only reach it by typing the command manually.

This spec covers two improvements:

1. A structured **Lookup Result Card** — a retro-styled dialog that renders whois/whowas fields
   as a labeled table instead of a wall of `* ----` status lines.
2. **Whowas entry points** — a "Last Seen" item in the nicklist and chat context menus (offline
   fallback), plus a standalone "User Lookup" dialog that accepts a free-form nick input and
   dispatches whois or whowas automatically.

---

## 2. Commands (grounded in handler source)

Both handlers live in
`apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/`.

| Command | Syntax | Returns | Notes |
|---------|--------|---------|-------|
| `/whois` | `/whois <nickname>` | Nickname, channels (all + shared subset highlighted), online duration, idle duration, registered (Yes/No), away status + message, bio, contact note, browser+OS client string, screen resolution, language, timezone | Target must be online; secret (+s) channels filtered unless requester is a member; emits `:show_whois_info` ui\_action |
| `/whowas` | `/whowas <nickname>` | Nickname, last-seen time (relative), channels at disconnect, quit message (optional) | ETS cache, 1-hour default TTL (admin-configurable via `whowas_retention_seconds` setting), max 1 000 entries with oldest eviction, cleanup every 10 min; emits `:show_whowas_info` ui\_action |

Field sourcing (from `helpers/whois.ex`):

- **Channels** — all public channels the target is in, from `ChannelRegistry`; secret channels
  only shown when the viewer is also a member.
- **Shared channels** — intersection of target's channels and viewer's own channels.
- **Online for** — `DateTime.diff(now, session.connected_at)` (or presence `joined_at`).
- **Idle for** — `DateTime.diff(now, last_activity_at)`.
- **Registered** — `NickServ.registered?(target)`.
- **Away / Away message** — presence meta `:away` / `:away_message`.
- **Bio** — presence meta `:bio` (fallback: `UserBio.load/1` from DB).
- **Contact note** — viewer's own address-book entry for the target.
- **Client** — browser + OS strings from presence meta.
- **Screen / Language / Timezone** — presence meta fields.
- **Last seen** (whowas) — `TimeFormatter.format_relative(entry.disconnected_at)`.
- **Quit message** (whowas) — stored at disconnect via `WhowasCache.record/3`.

---

## 3. Current UI state

### What exists

- **Nicklist context menu** (`NicklistContextMenu`) — "Whois" item dispatches
  `context_whois` with the clicked nick; no whowas item.
- **Chat context menu** (`ChatContextMenu`, `:nick` type) — "Whois" item dispatches
  `ctx_chat_whois`; no whowas item.
- **Command dispatch** — both `/whois` and `/whowas` are fully registered handlers.
- **Output rendering** — `show_whois_text/2` and `show_whowas_text/2` in
  `ChatLive.Helpers.Whois` emit a sequence of `system_event` lines (plain text, inline with
  chat messages).

### What is missing

- No whowas entry in either context menu.
- No UI for looking up a nick that is not currently visible (e.g. a user who just left).
- No structured result presentation — output is indistinguishable from other status text.

---

## 4. UI specification

### 4.1 Entry points

#### A. Nicklist context menu — existing "Whois" + new "Last Seen"

The current "Whois" item remains unchanged (target is online by definition when right-clicking
the nicklist). A new item is added directly below it:

```
[ Search icon ]  Whois
[ Clock icon  ]  Last Seen (Whowas)
```

Label: **"Last Seen (Whowas)"**
Action: `context_whowas`
phx-value: `nick` (same pattern as `context_whois`)

The item is always rendered; it is never disabled even if the target is online — the handler
already redirects ("X is online, use /whois") which is acceptable UX for the nicklist case.

#### B. Chat context menu — "Whois" + "Last Seen (Whowas)"

In the `:nick` menu type, add immediately after the existing "Whois" item:

```
[ Search icon ]  Whois
[ Clock icon  ]  Last Seen (Whowas)
```

Label: **"Last Seen (Whowas)"**
Action: `ctx_chat_whowas`
phx-value: `nick`

#### C. "User Lookup" standalone dialog

A small dialog, accessible via:

- **Menu bar** — User menu > "User Lookup..." (new item, below existing user-related items)
- **Keyboard shortcut** — suggested: Ctrl+Shift+W (open question, see §7)

The dialog contains:

- Title bar: **"User Lookup"** (with search icon)
- A single text input: placeholder **"Enter nickname..."**, auto-focused on open
- Two action buttons: **"Whois"** (primary) and **"Last Seen"** (secondary)
- A **"Close"** button

Clicking "Whois" dispatches `/whois <nick>` and closes the dialog.
Clicking "Last Seen" dispatches `/whowas <nick>` and closes the dialog.
Enter key in the input defaults to "Whois".

This dialog does not display results itself — it dispatches to the result card (§4.2) via the
same ui\_action pipeline that the commands already use.

#### D. Result card — replaces inline status text for both whois and whowas

The `:show_whois_info` and `:show_whowas_info` ui\_actions currently call
`show_whois_text/2` / `show_whowas_text/2` which append status lines. The new flow emits the
same data into a **Lookup Result Card dialog** instead.

The inline text path remains as a fallback for headless/test contexts and can be toggled via a
socket assign `whois_output_mode: :card | :text` (default `:card`).

---

### 4.2 Layout

#### Lookup Result Card — Whois

```
+-----------------------------------------------+
| [Search] Whois: CoolNick               [X]    |
+-----------------------------------------------+
| Nickname       CoolNick                       |
| Channels       #general, #retro               |
| Shared         #general                       |
| Online for     2h 14m                         |
| Idle for       3m 22s                         |
| Registered     Yes                            |
| Away           Be right back                  |
| Bio            Loves retro UX.                |
| Contact note   Met at the LAN party.          |
| Client         Firefox 126 — Windows 11       |
| Screen         1920x1080                      |
| Language       en-US                          |
| Timezone       UTC-3                          |
+-----------------------------------------------+
| [Whowas]   [Query (PM)]             [Close]   |
+-----------------------------------------------+
```

- Fields with no value are omitted entirely (same logic as today's text output).
- "Channels" row: channel names that are also "Shared" are rendered with a subtle highlight
  (e.g. bold or a different nick-color class) within the same cell, rather than using a
  separate "Shared" row when all channels are shared.
- "Shared" row only appears when there is a non-empty proper subset.
- The **[Whowas]** footer button dispatches `/whowas <nick>` for convenience — the user may
  want to see historical data without closing and re-opening.
- The **[Query (PM)]** footer button opens a PM tab with the target nick.

#### Lookup Result Card — Whowas

```
+-----------------------------------------------+
| [Clock] Last Seen: CoolNick            [X]    |
+-----------------------------------------------+
| Nickname       CoolNick                       |
| Last seen      3 minutes ago                  |
| Channels       #general, #retro               |
| Quit message   Later!                         |
+-----------------------------------------------+
| [Whois]                             [Close]   |
+-----------------------------------------------+
```

- "Quit message" row omitted if nil.
- The **[Whois]** footer button is only enabled if the target happens to be back online;
  otherwise disabled with tooltip "User is offline".
- The result card is a standard retro dialog (uses the existing `dialog.ex` primitive),
  width approximately 340px, non-modal (does not block chat interaction).

#### User Lookup dialog (entry point C)

```
+-----------------------------------------------+
| [Search] User Lookup                   [X]    |
+-----------------------------------------------+
|   Nickname: [_________________________]       |
|                                               |
|   [Whois]          [Last Seen]   [Cancel]     |
+-----------------------------------------------+
```

Width: ~320px. Auto-focus on the input field.

---

### 4.3 Interactions and states

| State | Whois card behavior | Whowas card behavior |
|-------|--------------------|-----------------------|
| Target is online | Full card shown | Card shown with redirect notice: "X is online — use Whois for live info." [Whois] button enabled |
| Target is offline | Card shows "X is not online." with [Last Seen] button as primary CTA | Full whowas card shown |
| Whowas cache miss | n/a | "No recent data for X." message in card body; all fields blank |
| Cache entry expired (TTL elapsed but cleanup not yet run) | n/a | `WhowasCache.lookup/1` returns `{:error, :not_found}` after inline TTL check — treated as cache miss |
| Self-lookup | Whois card shown (handler uses `session.connected_at` / `last_activity_at` directly) | Not meaningful; if `/whowas self` dispatched and self is online, redirect notice shown |
| Secret channel membership | Channel visible in card only if viewer is also a member (existing filtering logic preserved) | Channels stored at disconnect time, no secret filtering needed post-disconnect |
| Card already open | Re-opening (e.g. second context-menu click) replaces current card content in-place; no duplicate dialogs | Same |

---

### 4.4 Control to command mapping

| User action | Event / action string | Handler / result |
|-------------|----------------------|-----------------|
| Nicklist right-click > "Whois" | `context_whois` (existing) | `:show_whois_info` → result card |
| Nicklist right-click > "Last Seen (Whowas)" | `context_whowas` (new) | `:show_whowas_info` → result card |
| Chat right-click > "Whois" | `ctx_chat_whois` (existing) | `:show_whois_info` → result card |
| Chat right-click > "Last Seen (Whowas)" | `ctx_chat_whowas` (new) | `:show_whowas_info` → result card |
| User Lookup dialog > [Whois] | `user_lookup_whois` (new) | `:show_whois_info` → result card + close dialog |
| User Lookup dialog > [Last Seen] | `user_lookup_whowas` (new) | `:show_whowas_info` → result card + close dialog |
| Result card > [Whowas] (from whois card) | internal button click | `:show_whowas_info` → card content replaced |
| Result card > [Whois] (from whowas card) | internal button click | `:show_whois_info` → card content replaced |
| Result card > [Query (PM)] | internal button click | `open_pm_conversation/2` |
| `/whois <nick>` typed in input | existing command dispatch | `:show_whois_info` → result card |
| `/whowas <nick>` typed in input | existing command dispatch | `:show_whowas_info` → result card |

---

## 5. Permissions and visibility

- **Guest users** (unregistered) — may run `/whois` and see results. The "Registered: No"
  field applies to the target, not the viewer.
- **Whowas** — available to all authenticated users. No role restriction.
- **Secret channel filtering** — already implemented in `get_user_channels/2`; the result card
  must not bypass it (pass data from the existing helper, do not re-query independently).
- **Contact note** — only shown when the viewer has an address-book entry for the target;
  never shown to other users.
- **Bio** — shown if the target has set one; respects the existing `UserBio.load/1` visibility
  (all users can see any registered user's bio).
- **Admin** — no special whois data beyond what regular users see; admin audit features are
  separate.

---

## 6. Help documentation (mandatory)

Add or update the following topics in
`apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`:

| Topic ID | Category | Title | Content summary |
|----------|----------|-------|-----------------|
| `cmd-whois` | Commands | /whois — User Info | Syntax `/whois <nickname>`, all returned fields, note about online requirement, pointer to /whowas |
| `cmd-whowas` | Commands | /whowas — Last Seen | Syntax `/whowas <nickname>`, fields returned, 1-hour cache, max 1 000 entries, redirect when online |
| `feature-user-lookup` | Features | User Lookup Dialog | How to open (menu + shortcut), how to use Whois vs Last Seen buttons |

Update cross-references:

- `cmd-whois` "See Also": add `cmd-whowas`, `feature-user-lookup`
- `cmd-whowas` "See Also": add `cmd-whois`, `feature-user-lookup`
- Keyboard Shortcuts topic: add the User Lookup shortcut once finalised (see §7)
- Context Menus topic (if it exists): mention the new "Last Seen (Whowas)" item

---

## 7. Out of scope / open questions

- **Keyboard shortcut for User Lookup dialog** — Ctrl+Shift+W is a candidate but may conflict
  with browser "close tab" on some platforms. Confirm before implementing; if conflicting,
  consider Ctrl+Shift+U.
- **Pagination / history** — WhowasCache stores one entry per nick (keyed by lowercase nick,
  last-write wins). Showing multiple past sessions is not in scope.
- **Admin TTL UI** — the `whowas_retention_seconds` setting is already admin-configurable via
  the Services panel. No new admin UI needed; document the setting key in help.
- **Whois for offline nick via result card** — when [Whois] is clicked from a whowas card and
  the user is still offline, the card should show the "not online" state rather than silently
  doing nothing. Exact copy TBD.
- **Auto-whois integration** — the Notify List "Auto-Whois" toggle already triggers
  `push_whois_info/2` on join events. Whether auto-whois should open the result card or
  continue as status text is deferred; defaulting to status text for auto-whois is acceptable.
- **Whowas for the viewer themselves** — semantically odd; a redirect notice ("You are online")
  is sufficient, no special casing needed.
- **Result card position** — floated near the cursor (like context menus) vs. centered modal.
  Recommend centered, non-modal, consistent with channel-list dialog pattern.
