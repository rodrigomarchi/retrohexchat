# Feature Spec: Server Administration
**Coverage today:** 🟡 partial · **Priority:** P3 · **Commands:** /admin (umbrella), /wallops, /announce, /motd, /setmotd, /clearmotd, /singleplayer

## 1. Overview

Server administration covers everything an operator or administrator does to run the
server: inspecting state (users, channels, audit log, TURN, memory), changing settings,
moderating users (ban/kick/mute/rename/role), managing registered nicks and channels
(NickServ/ChanServ admin), broadcasting messages, editing the Message of the Day, and the
factory-reset "nuke". Today nearly all of this is reachable **only by typing commands**.

The one UI affordance that exists is the **Admin Console** dialog — but it is not a set of
structured forms. It is a raw, terminal-style **batch command executor**: you type one or
more slash commands (one per line) and it runs them sequentially, printing green/red output.
It is powerful for provisioning but discoverable to nobody: it assumes the admin already
knows the full `/admin …` syntax tree.

This spec maps the real handler surface and proposes turning the Admin Console into a
**tabbed administration panel** with structured forms — Server Settings, Users, Channels,
MOTD, Broadcast, Audit Log, TURN, and a guarded Danger Zone — while keeping the raw command
box available as one tab for power users. MOTD *viewing* is also surfaced to all users.

Per the project premise (every feature usable without memorizing commands), the command-only
admin surface is a gap, not a finished feature.

## 2. Commands (grounded in handler source)

The `/admin` umbrella (`commands/handlers/admin.ex`) dispatches to nine subcommand modules
under `commands/handlers/admin/`. It rejects non-admins with *"You must be a server
administrator to use this command"* and prints the usage line
`/admin <server|user|channel|ns|cs|debug|log|turn|nuke> <subcommand> [args]` when called bare.

### 2.1 `/admin` subcommand tree

| Subcommand (real syntax) | Source | What it does |
|--------------------------|--------|--------------|
| `/admin server info` | `admin/server.ex` | Server name/desc, users online, active channels, registered nicks, registration state, BEAM uptime |
| `/admin server settings` | `admin/server.ex` | List all configured `server_settings` (key = value, by whom) |
| `/admin server get <key>` | `admin/server.ex` | Read one setting |
| `/admin server set <key> <value>` | `admin/server.ex` | Set a setting. Valid keys: `server_name`, `server_description`, `welcome_message`, `max_channels`, `registration`, `whowas_retention_seconds`. Validated: `max_channels` > 0 int; `registration` ∈ {`open`,`closed`}; `whowas_retention_seconds` 1–86400 |
| `/admin user list [--search <q>] [--online]` | `admin/user.ex` | Registered-nick list, optional substring search, optional online-only filter |
| `/admin user info <@nick>` | `admin/user.ex` | Registered?, registered/last-seen timestamps, online, identified, admin, server operator |
| `/admin user ban <@nick> [--reason <r>] [--duration <d>]` | `admin/user.ex` | Server ban; duration parsed via `Commands.Duration` (e.g. `30m`, `7d`), else permanent |
| `/admin user unban <@nick>` | `admin/user.ex` | Lift a server ban |
| `/admin user kick <@nick> [--reason <r>]` | `admin/user.ex` | Force-disconnect a user |
| `/admin user mute <@nick> [--duration <d>]` | `admin/user.ex` | Server-wide mute; default permanent |
| `/admin user unmute <@nick>` | `admin/user.ex` | Lift a mute |
| `/admin user rename <old> <new>` | `admin/user.ex` | Force-rename a user |
| `/admin user role <@nick> <role>` | `admin/user.ex` | Set server role. Promoting to `admin` requires the actor be a **root admin** (`:root_admins` env) |
| `/admin user banlist [--search <q>]` | `admin/user.ex` | List active server bans (nick, reason, by, expires/permanent) |
| `/admin channel list [--search <q>]` | `admin/channel.ex` | Active channel processes, member counts, `[registered]` flag |
| `/admin channel info <#chan>` | `admin/channel.ex` | Topic, members+roles, modes, ban count, registration/founder |
| `/admin channel create <#chan>` | `admin/channel.ex` | Create a channel |
| `/admin channel delete <#chan>` | `admin/channel.ex` | Destroy a channel |
| `/admin channel purge <#chan> [--from <@nick>]` | `admin/channel.ex` | Purge channel messages, optionally only from one author |
| `/admin channel banlist <#chan>` | `admin/channel.ex` | List bans for a channel |
| `/admin ns drop <@nick>` | `admin/nick_serv.ex` | Drop a registered nick |
| `/admin ns info <@nick>` | `admin/nick_serv.ex` | NickServ info: registered/last-seen, identified |
| `/admin ns resetpass <@nick> <new_password>` | `admin/nick_serv.ex` | Reset a nick's password |
| `/admin cs drop <#chan>` | `admin/chan_serv.ex` | Drop a registered channel |
| `/admin cs info <#chan>` | `admin/chan_serv.ex` | Founder, registered, topic, modes, access list |
| `/admin cs transfer <#chan> <@nick>` | `admin/chan_serv.ex` | Transfer founder |
| `/admin cs access <#chan>` | `admin/chan_serv.ex` | Show the access list |
| `/admin cs access <#chan> add <level> <@nick>` | `admin/chan_serv.ex` | Grant access at a level |
| `/admin cs access <#chan> del <level> <@nick>` | `admin/chan_serv.ex` | Revoke access |
| `/admin debug connections` | `admin/debug.ex` | Count of active channel processes |
| `/admin debug processes` | `admin/debug.ex` | List channel processes (name + pid) |
| `/admin debug memory` | `admin/debug.ex` | BEAM memory: total, processes, ETS, atoms, binary, code |
| `/admin log [--last <n>] [--user <@nick>]` | `admin/log.ex` | Audit log (default last 20), optional actor filter |
| `/admin turn stats` | `admin/turn.ex` | TURN status, relay IP/port, listeners, active allocations, relay-port usage. Reports *not configured* if `listener_count = 0` |
| `/admin turn allocations` | `admin/turn.ex` | Active TURN allocations (client → relay port) |
| `/admin nuke` | `admin/nuke.ex` | **Preview**: record counts that *would* be destroyed; lists preserved tables (admin_roles, audit_logs, server_bans, server_settings) |
| `/admin nuke --confirm` | `admin/nuke.ex` | **Execute** factory reset — irreversible. "THIS CANNOT BE UNDONE" |

### 2.2 Standalone admin / server commands

| Command (real syntax) | Source | Permission | What it does |
|-----------------------|--------|------------|--------------|
| `/wallops <message>` | `wallops.ex` | server operator **or** admin | Broadcast to users who opted in via `/umode +w`; topic `server:wallops`; replies "Wallops sent." |
| `/announce <message>` | `announce.ex` | admin only | Urgent broadcast to **every** connected user, bypasses ignore filters; topic `server:announcements`; replies "Announcement sent to all users." |
| `/motd` | `motd.ex` | everyone | View the MOTD (also shown on connect). Returns `:show_motd` UI action, or "No MOTD has been set." |
| `/setmotd <text>` | `set_motd.ex` | admin only | Set the MOTD (`Services.Motd.set/2`); replies "MOTD has been updated." |
| `/clearmotd` | `clear_motd.ex` | admin only | Clear the MOTD; replies "MOTD has been cleared." |
| `/singleplayer` | `singleplayer.ex` | admin only, **registered + identified** | Admin debug shortcut: starts a solo arcade session (`Arcade.create_session/1`, `:arcade_session` UI action). Non-admins are told to type `!play` in #games |

## 3. Current UI state

**Admin Console dialog** (`components/ui/dialogs/admin_console_dialog.ex`,
events in `live/chat_live/admin_console_events.ex`):
- A terminal-style **batch command runner**, not a structured admin form. Black panel,
  green monospace output, red lines for errors, a multi-line `<textarea>` ("one per line"),
  a **Run** button, plus **Clear** and **Close**.
- Lines are trimmed; blanks and `#`-comments are skipped. Each line is parsed and dispatched
  through the normal command pipeline with `is_admin: true`. **Context flows between lines**
  (e.g. `/join #x` then `/cs register` operates on `#x`) — it doubles as a provisioning tool.
- Reachable from **File → Admin Console** (admin-only) and the toolbar **Options** dropdown.
  Gated by `ServerRoles.admin?` **or** `server_operator?`.

**Everything else has no dedicated UI:**
- **MOTD viewing** (`/motd`) renders as a status message (`push_status_message(.., :motd)`),
  not a dialog. There is no Help/menu entry to view it; users only see it auto-shown on
  connect (`maybe_show_motd/1`).
- **MOTD editing** (`/setmotd`, `/clearmotd`) — command-only.
- **Broadcasts** (`/wallops`, `/announce`) — command-only. Inbound messages *are* rendered
  (`pubsub_handlers/server_messages.ex`), but there is no composer to send them.
- **`/singleplayer`** — command-only admin debug shortcut (the public path is `!play` in #games).

## 4. UI specification — what to build

### 4.1 Entry points

- **File → "Admin Console…"** — already present (admin-only). Reuse it; the dialog becomes
  tabbed (below). Keep the toolbar **Options → "Admin Console"** entry pointing at the same dialog.
- Within the dialog, structured **tabs** (exact labels):
  - **"Server Settings"** — server info + editable settings
  - **"Users"** — user table with moderation actions
  - **"Channels"** — channel table with admin actions
  - **"MOTD"** — view + set/clear the Message of the Day
  - **"Broadcast"** — compose `/wallops` and `/announce`
  - **"Audit Log"** — read-only audit log viewer
  - **"TURN"** — read-only TURN stats + allocations
  - **"Danger Zone"** — nuke (factory reset) with confirmation
  - **"Console"** — the existing raw batch command box (power-user escape hatch)
- **MOTD viewing for everyone** — add **Help → "Message of the Day"** (always enabled, like
  the other Help items). It runs `/motd` and shows the result. No admin gating on viewing.

### 4.2 Layout

A tabbed Admin Console that augments (does not delete) the raw command box. ASCII wireframe:

```
+--------------------------------------------------------------+
|  [admin] Admin Console                                  [X]  |
+--------------------------------------------------------------+
| Server Settings | Users | Channels | MOTD | Broadcast |      |
| Audit Log | TURN | Danger Zone | Console                     |
+--------------------------------------------------------------+
|  -- Server Settings tab --                                   |
|  Server name        [ RetroHexChat              ]            |
|  Description        [ ...                        ]            |
|  Welcome message    [ ...                        ]            |
|  Max channels       [ 100 ]                                  |
|  Registration       ( ) open   ( ) closed                   |
|  Whowas retention   [ 3600 ] seconds (1-86400)              |
|                                       [ Save settings ]      |
|  ----------------------------------------------------------  |
|  Info: 12 users online · 5 channels · 30 nicks · up 2d 4h   |
+--------------------------------------------------------------+

  -- Users tab --
  Search [______]  [x] Online only        [ Refresh ]
  +--------------------------------------------------------+
  | Nick      | Online | Ident | Role   | Actions          |
  | @alice    |  yes   |  yes  | admin  | Info Ban Kick … |
  | @bob      |  no    |  no   | user   | Info Ban Mute … |
  +--------------------------------------------------------+
  Ban list ▸ (active server bans, with Unban)

  -- MOTD tab --
  Current MOTD:
  +--------------------------------------------------------+
  | Welcome to RetroHexChat!                               |
  +--------------------------------------------------------+
  New MOTD [ textarea............................. ]
                     [ Set MOTD ]   [ Clear MOTD ]

  -- Broadcast tab --
  ( ) Wallops  — only users with +w     ( ) Announce — everyone
  Message [ textarea............................. ]
                                          [ Send broadcast ]

  -- Audit Log tab --  (read-only)        Last [20] User [____] [Refresh]
  +--------------------------------------------------------+
  | [2026-06-04 12:00:00] alice user.ban → user:bob (…)   |
  +--------------------------------------------------------+

  -- TURN tab --  (read-only, auto from /admin turn)
  Status: running · Relay 10.0.0.1 · Listeners 4 · Allocs 3/250

  -- Danger Zone tab --
  NUKE PREVIEW — 412 records will be destroyed.
  Preserved: admin_roles, audit_logs, server_bans, server_settings
  [ type the server name to confirm: ____ ]   [ NUKE EVERYTHING ]
```

### 4.3 Interactions & states

- **Admin-only gating** — the dialog open event already rejects non-admins
  ("Admin Console is restricted to server administrators"). Tabs that call admin-only
  commands stay gated. **Note:** the current open-gate also admits *server operators*; the
  Broadcast tab must split `/wallops` (operator-or-admin) from `/announce` (admin-only), and
  the Danger Zone / settings tabs are **admin-only** even if an operator opened the dialog.
- **Destructive confirmations** —
  - Ban / kick / mute / rename / drop / channel delete / channel purge: inline confirm
    ("Ban @bob? Reason: ___ Duration: ___") before dispatching.
  - **Nuke**: two-stage exactly as the handler — show the **preview** first (`/admin nuke`),
    then require typing the server name (or an explicit checkbox) to enable the
    **NUKE EVERYTHING** button, which dispatches `/admin nuke --confirm`. Surface
    "THIS CANNOT BE UNDONE".
- **Live vs static data** — Users / Channels / Audit Log / TURN are **snapshot** reads with a
  **Refresh** button (the handlers return point-in-time text; no streaming). Broadcasts and
  MOTD writes show the handler's success/error line inline. Settings form pre-fills from
  `/admin server settings` / `server info`.
- **Result surface** — each structured action runs the underlying command and shows its
  green success / red error line in a small results strip per tab (reusing the console's
  status styling), so behavior matches the existing batch runner.
- **Singleplayer** — out of the structured tabs; expose as a small **"Start solo arcade (debug)"**
  button on the Server Settings tab (admin-only). It dispatches `/singleplayer` and inherits
  the registered+identified requirement (show the handler's error inline if unmet).

### 4.4 Control → command mapping

| Tab / control | Dispatches |
|---------------|-----------|
| Server Settings → "Save settings" | `/admin server set <key> <value>` per changed field |
| Server Settings → info strip | `/admin server info`, `/admin server settings` (read) |
| Server Settings → "Start solo arcade (debug)" | `/singleplayer` |
| Users → table load / Search / Online only | `/admin user list [--search q] [--online]` |
| Users → row "Info" | `/admin user info <@nick>` |
| Users → row "Ban" (with reason/duration) | `/admin user ban <@nick> [--reason r] [--duration d]` |
| Users → "Unban" | `/admin user unban <@nick>` |
| Users → "Kick" | `/admin user kick <@nick> [--reason r]` |
| Users → "Mute" / "Unmute" | `/admin user mute <@nick> [--duration d]` / `/admin user unmute <@nick>` |
| Users → "Rename" | `/admin user rename <old> <new>` |
| Users → "Role" | `/admin user role <@nick> <role>` |
| Users → Ban list panel | `/admin user banlist [--search q]` |
| Users → NickServ actions | `/admin ns drop\|info\|resetpass <@nick> [pw]` |
| Channels → table load / Search | `/admin channel list [--search q]` |
| Channels → row "Info" | `/admin channel info <#chan>` |
| Channels → "Create" / "Delete" | `/admin channel create\|delete <#chan>` |
| Channels → "Purge" | `/admin channel purge <#chan> [--from @nick]` |
| Channels → ChanServ actions | `/admin cs drop\|info\|transfer\|access …` |
| MOTD → "Set MOTD" | `/setmotd <text>` |
| MOTD → "Clear MOTD" | `/clearmotd` |
| MOTD → current MOTD view (+ Help entry) | `/motd` |
| Broadcast → Wallops + "Send" | `/wallops <message>` |
| Broadcast → Announce + "Send" | `/announce <message>` |
| Audit Log → Refresh (Last / User) | `/admin log [--last n] [--user @nick]` |
| TURN → Refresh | `/admin turn stats`, `/admin turn allocations` |
| Danger Zone → preview (on tab open) | `/admin nuke` |
| Danger Zone → "NUKE EVERYTHING" | `/admin nuke --confirm` |
| Console tab (unchanged) | raw batch dispatch (any of the above, one per line) |

## 5. Permissions & visibility

- **Admin / root-admin gating**:
  - `/admin …`, `/announce`, `/setmotd`, `/clearmotd`, `/singleplayer` require **admin**
    (`ServerRoles.admin?`).
  - `/wallops` requires **server operator or admin** (`is_admin` or `is_server_operator`).
  - Promoting a user to **admin** via `/admin user role @x admin` requires the actor be a
    **root admin** (`:root_admins` application env) — the Role control must surface this and
    hide/disable the `admin` option for non-root admins.
  - The **nuke** preserves admin infrastructure (admin_roles, audit_logs, server_bans,
    server_settings); the Danger Zone copy must say so.
- **MOTD viewing for all** — `/motd` and the proposed **Help → "Message of the Day"** entry
  are available to **every** connected user (no gating). Only editing is admin-only.
- The Admin Console menu/toolbar entries remain hidden/disabled for non-admins (current
  behavior); within the dialog, operator-only sessions see Broadcast (wallops) but
  admin-only tabs are disabled.

## 6. Help documentation (mandatory)

Per project premise, add/update topics in `Chat.HelpTopics`
(`apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`):

- **Commands category**: ensure topics for `/admin` (with the full subcommand tree),
  `/wallops`, `/announce`, `/motd`, `/setmotd`, `/clearmotd`, `/singleplayer` (the handler
  `help/0` and `syntax_definition/0` blocks supply syntax + examples to mirror).
- **User Interface category**: a **"Admin Console"** topic describing the tabbed panel
  (Server Settings, Users, Channels, MOTD, Broadcast, Audit Log, TURN, Danger Zone, Console)
  and the admin-only gating; a **"Message of the Day"** topic explaining the Help entry and
  that MOTD is shown on connect.
- **Features category**: a **"Server Broadcasts"** topic explaining wallops (opt-in via
  `/umode +w`) vs announce (everyone, bypasses ignore).
- **Keyboard Shortcuts**: update if a shortcut is assigned to open the Admin Console.
- **See Also**: cross-link Admin Console ↔ MOTD ↔ Server Broadcasts ↔ user modes (`+w`).

## 7. Out of scope / open questions

- **How much is genuinely new UI?** The existing Admin Console already covers *all* of the
  `/admin …` tree and the standalone commands via the raw batch box — so this spec is mostly
  a **discoverability / usability** upgrade (structured forms), not new capability. Decide
  whether to (a) fully replace the raw box with tabs, (b) add tabs alongside it (recommended:
  keep "Console" as one tab), or (c) ship only the highest-value tabs (MOTD, Broadcast,
  Users) and leave the rest to the Console.
- **Genuinely new affordances** (no command equivalent today): the **Help → "Message of the
  Day"** menu entry for non-admins, and a possible MOTD *dialog* rather than a status-line
  render. These are the clearest net-new UI.
- **Operator vs admin split** — the current dialog open-gate admits server operators; confirm
  whether operators should see the structured Admin Console at all, or only a Broadcast-limited
  view. The handlers already enforce per-command permission regardless.
- **Live data** — handlers return formatted text snapshots, not structured data. A polished
  table UI (Users/Channels/Audit/TURN) may want new domain query functions returning maps
  instead of parsing the text output. Flag as a backend follow-up; the minimal version can
  render the text blocks the commands already produce.
- **Nuke confirmation UX** — exact confirmation gesture (type server name vs checkbox vs
  hold-to-confirm) is an open design question; the two-stage preview → `--confirm` flow is fixed.
- **`/singleplayer`** is an admin debug shortcut; surfacing it in the admin UI is a
  nice-to-have, not required (public arcade entry is `!play` in #games, covered elsewhere).
