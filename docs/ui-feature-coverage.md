# UI Feature Coverage — Commands vs Menus / Context Menus / Dialogs

**Status:** Mapping round (2026-06-04). This document inventories every way a user can
reach each feature: by **slash command**, by **menu bar**, by **context menu** (right-click),
by **toolbar**, and by **dialog**. It then flags where coverage is good and where a feature
is reachable *only* by typing a command (no discoverable UI affordance).

> Goal of the project premise: every feature should be usable **without** memorizing
> commands. A command-only feature is a gap, not a finished feature.

---

## 1. Surfaces inventory (what exists today)

### 1.1 Menu bar (`shell/menu_bar_app.ex`)

Four top-level menus. All except **Help** are disabled until connected.

| Menu | Items |
|------|-------|
| **File** | Disconnect · Admin Console *(admin only)* |
| **View** | Channel List · Toggle Conversations · Toggle Nicklist · Find |
| **Tools** | Address Book · Highlight Words · URL Catcher · Channel Central · Perform · — · Sounds · Flood Protection · Alias Editor · Custom Menus · Auto Respond |
| **Help** | Help Topics · Shortcut Cheatsheet · — · About |

### 1.2 Toolbar (`shell/toolbar_app.ex`)

Three groups. The **Options** dropdown mirrors View + Tools menus (Channel List, Toggle
Conversations, Toggle Nicklist, Find, Address Book, Highlight Words, URL Catcher, Channel
Central, Perform, Sounds, Flood Protection, Alias Editor, Custom Menus, Auto Respond,
Admin Console). Connection group = Connect/Disconnect. Help group = Help Topics.

### 1.3 Context menus (right-click)

| Menu | Trigger | Items |
|------|---------|-------|
| **Nicklist** (`chat/nicklist_context_menu.ex`) | Right-click a user in the nicklist | Query (PM), Whois, Add to Contacts, Set Nick Color (+ inline picker), Ignore/Unignore, P2P Session, Audio Call, Video Call, Send File, Play Game, Kick, Ban, Give Voice (+v), Give Op (+o), custom items |
| **Chat** (`chat/chat_context_menu.ex`) | Right-click a nick / URL / channel name / message in chat | **nick:** PM, Whois, Copy Nick, Ignore, Address Book, Audio/Video Call, Send File, Play Game, Kick, Ban, Voice, Op · **url:** Open Link, Copy URL, Save to URL List · **channel:** Join, Copy Name, Channel Info · **message:** Copy, Reply, Delete (own), Ignore Sender |
| **Conversations** (`chat/conversations_context_menu.ex`) | Right-click a channel/PM tab in the conversations sidebar | Mark as Read, Mute/Unmute *(notification mute)*, Copy Name, Channel Settings *(channel)*, Leave Channel *(channel)*, custom items |

### 1.4 Dialogs (`components/ui/dialogs/` — 25 files; 23 wired into the app, 2 showcase-only)

Settings / tools: Address Book, Channel List, Channel Central, Highlight Words, Perform
(+ Autojoin tab), Sound Settings, Flood Protection, Alias Editor, Custom Menus,
Auto-Respond, URL Catcher, Notify List, Admin Console, Cheatsheet, About.
Flow / confirmation: Kick, Invite, Nick Change, Disconnect Confirm, Delete Confirm,
Paste Confirm. Bots: Bot Management, Bot Form, (Add Command sub-dialog).
Showcase-only (not wired to the app): Channel Dialog, Confirm Dialog.

> **Stale artifacts:** `cover/` still lists `OptionsDialog`, `FavoriteDialog`,
> `OrganizeFavoritesDialog`, `CtcpSettingsDialog`, `IgnoreListDialog`, `LogViewerDialog`.
> None of these exist in `components/ui/dialogs/` anymore — they are old coverage files,
> **not** real features. There is currently **no** unified Options/Preferences dialog.

---

## 2. Coverage matrix — command ↔ UI

Legend: ✅ has it · ➖ N/A (command makes no sense as a menu/dialog) · ❌ missing

### 2.1 Well covered (command **and** discoverable UI) — these are good

| Feature | Command | Menu/Toolbar | Context menu | Dialog |
|---------|---------|--------------|--------------|--------|
| Join / browse channels | `/join`, `/list` | View → Channel List | Chat → Join Channel | Channel List |
| Leave channel | `/part`, `/leave` | — | Conversations → Leave | — |
| Private message / query | `/msg`, `/query` | — | Query (PM) | — |
| Whois | `/whois` | — | Whois | (status output) |
| Topic | `/topic` | Tools → Channel Central | Chat → Channel Info | Channel Central (General) |
| Channel modes | `/mode` | Tools → Channel Central | — | Channel Central (Modes) |
| Ban / unban | `/ban`, `/unban` | Tools → Channel Central | Nicklist/Chat → Ban | Channel Central (Bans) |
| Kick | `/kick` | — | Nicklist/Chat → Kick | Kick (incoming notice) |
| Op / Voice (grant) | `/op`, `/voice` | — | Give Op / Give Voice | — |
| Ignore | `/ignore`, `/unignore` | Tools → Address Book | Ignore / Unignore | Address Book (Controls) |
| Contacts | — | Tools → Address Book | Add to Contacts | Address Book (Contacts) |
| Nick colors | — | Tools → Address Book | Set Nick Color | Address Book (Nick Colors) |
| P2P / calls / files | `/p2p`, `/call`, `/sendfile` | — | P2P/Audio/Video/Send File | (invite flow) |
| Games | `/game` | — | Play Game | (invite/lobby) |
| URL capture | — | Tools → URL Catcher | Chat → Save to URL List | URL Catcher |
| Aliases | `/alias` | Tools → Alias Editor | — | Alias Editor |
| Auto-respond | `/autorespond` | Tools → Auto Respond | — | Auto-Respond |
| Perform on connect | `/perform` | Tools → Perform | — | Perform |
| Autojoin | `/autojoin` | Tools → Perform | — | Perform (Autojoin tab) |
| Custom menus / popups | `/popups` | Tools → Custom Menus | — | Custom Menus |
| Highlight words | — | Tools → Highlight Words | — | Highlight Words |
| Sounds | — | Tools → Sounds | — | Sound Settings |
| Flood protection | — | Tools → Flood Protection | — | Flood Protection |
| Disconnect / quit | `/quit` | File → Disconnect | — | Disconnect Confirm |
| Reply / delete / copy msg | — | — | Chat (message) | Delete Confirm |
| Admin suite | `/admin …` | File → Admin Console *(admin)* | — | Admin Console |
| Help / cheatsheet / about | `/help` | Help menu | — | Cheatsheet, About |

### 2.2 Built but **not discoverable** — dialog exists, no menu/toolbar entry ⚠️

These are the highest-value, lowest-effort fixes: the dialog already exists, it just
isn't wired into any menu or toolbar, so today the feature is reachable only by command
(or not at all from the UI).

| Feature | Command | Dialog exists | Entry point today | Gap |
|---------|---------|---------------|-------------------|-----|
| **Notify / buddy list** | `/notify` | `notify_list.ex` ✅ | Programmatic `ui_action` only | ❌ No menu/toolbar item → add to View or Tools |
| **Bot management** | `/bot …` | `bot_management_dialog.ex` ✅ | Programmatic `open_bot_dialog` only | ❌ No menu/toolbar item → add to Tools |

### 2.3 Command-only features — **no menu, no context menu, no dialog** ❌

Ordered roughly by user value.

| Feature | Command | Why it needs UI | Suggested home |
|---------|---------|-----------------|----------------|
| **NickServ (register / identify / ghost / drop)** | `/ns …` | Account registration & login is core; new users can't discover it | A "Register / Identify" dialog; entry in File or a status-bar account widget |
| **ChanServ (register / access / drop)** | `/cs …` | Channel ownership & access lists have no UI | Channel Central tab, or ChanServ dialog |
| **Away status** | `/away` | Common, toggled often | Status-bar toggle + File/Tools menu item + dialog for message |
| **Edit your bio** | `/bio` | Profile field, set-and-forget; invisible today | Field in an account/profile dialog |
| **Notify list (entry point)** | `/notify` | See 2.2 | — |
| **Timers / scheduled commands** | `/timer` | Power feature, totally hidden | Tools → Timers dialog |
| **User modes (+w wallops)** | `/umode` | No way to toggle wallops visually | Tools/account dialog checkbox |
| **Send invite** | `/invite` | Invite **dialog is receive-only**; you can't send one from UI | Nicklist context → Invite to channel |
| **Knock** (request invite to +i) | `/knock` | No UI affordance | Channel List → Knock button |
| **Notice** | `/notice` | — | (low priority — command acceptable) |
| **Whowas** | `/whowas` | Lookup recently-left users | Nicklist/Address Book lookup |
| **MOTD** | `/motd` | Re-view server MOTD | Help menu → MOTD |
| **Slow mode** | `/slow` | Channel moderation | Channel Central (Modes) |
| **Transfer ownership** | `/transfer` | Destructive, deserves a confirm dialog | Channel Central / ChanServ |
| **Clear window** | `/clear` | Trivial, expected in a menu | Edit menu → Clear |
| **Change nickname** | `/nick` | Nick Change dialog only appears mid-flow; no "Change Nick…" launcher | File/account menu → Change Nick |

### 2.4 Moderation context-menu gaps (partial coverage) ⚠️

The nicklist/chat context menus grant power but can't revoke it, and channel-level mute
is missing entirely:

| Action | In context menu? | Note |
|--------|------------------|------|
| Give Op `/op` | ✅ | |
| **Remove Op** `/deop` | ❌ | Grant-only; no revoke item |
| Give Voice `/voice` | ✅ | |
| **Remove Voice** `/devoice` | ❌ | Grant-only; no revoke item |
| **Channel mute** `/mute`, `/unmute` | ❌ | Only **notification** mute exists in Conversations menu — easy to confuse with moderation mute |

---

## 3. Structural observations

1. **No "Edit" menu.** Clear/Copy/Find don't have a natural home. `Find` currently lives
   under *View*; `/clear` has no menu item at all. An Edit menu would be the conventional
   home and would absorb `/clear`.

2. **No unified Options/Preferences dialog.** Settings are spread across ~8 separate Tools
   dialogs (Sounds, Flood Protection, Highlight, Alias, Custom Menus, Auto Respond,
   Address Book, Perform). This is faithful to the mIRC-era model and is arguably fine,
   but there is no single "Options" entry — and stale `cover/` files imply one once
   existed. Decide explicitly: keep the scattered model (and delete the stale artifacts)
   or introduce a tabbed Options shell.

3. **Account/identity has the weakest UI.** `/ns`, `/cs`, `/nick`, `/away`, `/bio`,
   `/umode` together form the "who am I / am I logged in" surface, and **none** of them
   have a discoverable launcher. For a chat app this is the most impactful cluster to
   address — likely a small account widget in the status bar + a Register/Identify dialog.

4. **Two finished dialogs are dark** (Notify List, Bot Management). Wiring them into a
   menu is the cheapest win in this whole document.

5. **Context menus are grant-only for moderation.** Add the inverse items (deop, devoice,
   unmute) so ops aren't forced back to the command line to undo an action.

---

## 4. Recommended priority for the next round

| Priority | Work | Effort |
|----------|------|--------|
| **P0** | Wire **Notify List** and **Bot Management** into Tools menu + toolbar | Trivial (dialogs exist) |
| **P0** | Account widget / dialog for `/ns` register+identify, `/away`, `/nick`, `/bio`, `/umode` | Medium — biggest UX gain |
| **P1** | Add **Edit** menu with Clear / Copy / Find; move Find out of View | Small |
| **P1** | Context-menu inverse moderation: deop, devoice, channel mute/unmute | Small |
| **P1** | "Invite to channel" in nicklist context menu (sending side) | Small |
| **P2** | Timers dialog (`/timer`), Slow/Knock surfaced in Channel List/Central | Medium |
| **P2** | Decide on unified Options shell vs. scattered dialogs; delete stale `cover/` artifacts | Small–Medium |
| **P3** | MOTD/Whowas surfacing; ChanServ access UI | Medium |

> **Help-doc reminder:** every new entry point added above must also get a Help topic in
> `Chat.HelpTopics` (Commands / Features / User Interface category) and a cross-reference,
> per the project premise.

---

## 5. Feature groups — command composition

The relationship is **not** 1 command : 1 dialog. Most user-facing *features* are composed
of several commands (and often a multi-tab dialog), while some commands are "umbrella"
dispatchers with many subcommands. This section regroups the **58 registered commands**
into **17 feature groups** and gives a single coverage verdict per feature.

> **Umbrella commands** (one command, many subcommands — verified in handler source):
> `/ns` (register · identify · ghost · drop · info), `/cs` (register · drop · info · sop ·
> aop · vop · access), `/bot` (create · destroy · list · info · join · part · enable ·
> disable · set · commands · addcmd · delcmd), `/admin` (server · user · channel · ns · cs ·
> debug · log · turn · nuke), `/alias`, `/perform`, `/autojoin`, `/notify`, `/timer`
> (add · remove · list · stop). These look like one command but *are* a whole feature.

Verdict legend: ✅ complete (command + discoverable UI) · 🟡 partial (some members lack UI)
· ⚠️ dark dialog (UI built but no menu/toolbar entry) · ❌ command-only (no UI launcher).

| # | Feature | Member commands | Primary UI surface | Verdict |
|---|---------|-----------------|--------------------|---------|
| 1 | **Identity, Account & Presence** | `ns`, `nick`, `away`, `bio`, `umode` | Nick Change dialog (only mid-`/nick` flow) | ❌ No launcher — the biggest gap |
| 2 | **Messaging** | `me`, `msg`, `query`, `notice`, `notice_routing` | Nicklist/Chat context → PM | 🟡 PM covered; `me`/`notice` command-only |
| 3 | **Channel membership** | `join`, `part`, `leave`, `list`, `knock`, `invite` | Channel List dialog · Chat ctx → Join · Conversations ctx → Leave | 🟡 `knock` & invite-*send* command-only |
| 4 | **Channel configuration** | `topic`, `mode`, `slow`, `transfer`, `setwelcome`, `clearwelcome` | Channel Central (General + Modes tabs) | 🟡 `slow`/`transfer`/welcome command-only |
| 5 | **Channel moderation** | `kick`, `ban`, `unban`, `mute`, `unmute`, `op`, `deop`, `voice`, `devoice` | Nicklist/Chat ctx (kick/ban/op/voice) · Channel Central (Bans) | 🟡 Grant-only; `deop`/`devoice`/`mute`/`unmute` no ctx item |
| 6 | **ChanServ (channel registration)** | `cs` | — (only `/admin cs …` via Admin Console) | ❌ Command-only for normal users |
| 7 | **User lookups** | `whois`, `whowas` | Nicklist/Chat context → Whois | 🟡 `whowas` command-only |
| 8 | **Ignore / blocking** | `ignore`, `unignore` | Context Ignore/Unignore · Address Book (Controls) | ✅ Complete |
| 9 | **Buddy list / notify** | `notify` | Notify List dialog | ⚠️ Dark — no menu/toolbar entry |
| 10 | **P2P & media** | `p2p`, `call`, `sendfile`, `game` | Nicklist/Chat ctx (P2P/Audio/Video/Send File/Play Game) | ✅ Complete |
| 11 | **Connect automation** | `perform`, `autojoin` | Tools → Perform (2 tabs) | ✅ Complete |
| 12 | **Scripting & customization** | `alias`, `autorespond`, `popups`, `timer` | Tools → Alias Editor · Auto Respond · Custom Menus | 🟡 `timer` has no UI |
| 13 | **Bots** | `bot` | Bot Management dialog (+ Bot Form, Add Command) | ⚠️ Dark — no menu/toolbar entry |
| 14 | **Window & display** | `clear` | — (no Edit menu) | ❌ Command-only |
| 15 | **Server administration** | `admin`, `wallops`, `announce`, `setmotd`, `clearmotd`, `motd`, `singleplayer` | File → Admin Console *(admin)* | 🟡 `wallops`/`announce`/`motd`/`singleplayer` command-only |
| 16 | **Connection & session** | `quit` | File → Disconnect · toolbar · Disconnect Confirm | ✅ Complete |
| 17 | **Help & reference** | `help` | Help menu · Help Topics page · Cheatsheet | ✅ Complete |

### 5.1 UI-only features (have UI, intentionally have **no** command)

These are configuration/view surfaces; the absence of a slash command is by design, not a
gap. Listed so the command↔feature mapping is complete in both directions.

| Feature | UI surface | Command? |
|---------|-----------|----------|
| Contacts & nick colors | Tools → Address Book (Contacts, Nick Colors tabs) | none (companion to `/ignore`) |
| Highlight words | Tools → Highlight Words | none |
| Sound settings | Tools → Sounds | none |
| Flood protection | Tools → Flood Protection | none |
| URL catcher | Tools → URL Catcher · Chat ctx → Save to URL List | none |
| Find / search in buffer | View → Find | none |
| Layout toggles | View → Channel List / Conversations / Nicklist | none |
| About | Help → About · logo click | none |

### 5.2 Coverage scoreboard (by feature, not by command)

Of the **17 command-backed features**:

- ✅ **Complete — 5:** Ignore · P2P & Media · Connect Automation · Connection & Session · Help
- 🟡 **Partial — 7:** Messaging · Channel Membership · Channel Configuration · Channel Moderation · User Lookups · Scripting · Server Administration
- ❌ **Command-only (no launcher) — 3:** Identity/Account/Presence · ChanServ · Window/Display
- ⚠️ **Dark dialog (built, not wired) — 2:** Buddy List/Notify · Bots

The 9 features that are 🟡/❌/⚠️ are exactly the backlog driving §4's priority table. The
single highest-leverage move remains **Feature 1 (Identity/Account/Presence)**: five
commands, ~7 NickServ subcommands, and the entire login/registration journey, with no UI
launcher at all.

> **Per-feature specs:** each of the 12 features needing UI work now has a dedicated
> implementation spec in [`ui-features/`](ui-features/README.md) — grounded in handler
> source, with layouts, control→command mappings, and help-doc requirements.

---

## 6. Audit trail (verification, 2026-06-04)

This document was re-verified against primary sources (not agent summaries) before
publishing. Evidence:

- **Commands** — ground truth is `commands/registry.ex`: **58 registered keys**
  (`leave` is an alias for `part`; `p2p`, `call`, `sendfile`, `game` all present). The
  matrix in §2 was reconciled against this list, so no command in the tables is invented.
- **Menu bar** — read in full from `shell/menu_bar_app.ex`. Confirmed: only
  **File / View / Tools / Help**; **no Edit menu**; `/clear` and "Change Nick" have no
  item. Matches §1.1 exactly.
- **Toolbar** — read in full from `shell/toolbar_app.ex`. Options dropdown mirrors
  View+Tools; no Notify, no Bot. Matches §1.2.
- **Context menus** — read in full from `nicklist_context_menu.ex`,
  `conversations_context_menu.ex`, `chat_context_menu.ex`. Confirmed **grant-only**
  moderation (op/voice present; **deop/devoice/unmute absent**), and that the
  conversations "Mute" is notification-only (`is_muted` toggle). Matches §2.4.
- **Dark dialogs** — grep confirmed **no** `phx-click`/`phx-value-action` anywhere wires
  `toggle_notify_list` (except the dialog's own close) or `open_bot_dialog`. Both are
  reached only via the `/notify` and `/bot` commands (internal `ui_action` dispatch).
  Matches §2.2.
- **Command-only negatives** — grep across `*.heex`/`*.ex` (excluding command handlers,
  help content, tests, showcase) found **zero UI triggers** for `away`, `bio`, `timer`,
  `umode`, `knock`, `whowas`, `motd`, `ns`, `cs`, `nick`-launcher, `clear`. `/ns` and
  `/cs` surface only as inline help nudges that tell the user to *type* the command.
  Matches §2.3.
- **Stale artifacts** — `options_dialog`, `favorite_dialog`, `organize_favorites_dialog`,
  `ctcp_settings_dialog`, `ignore_list_dialog`, `log_viewer_dialog` have **0**
  non-showcase references; `channel_dialog` and `confirm_dialog` have **0** uses in
  `live/app`. Confirmed showcase/dead. Matches §1.4 + §3.2.

**Corrections applied during audit:** dialog count revised from "24 live" to "25 files /
23 wired" (§1.4). No claim in §2–§4 required retraction.
