# Chat Deep Flow Backlog

Persistent backlog for chat E2E coverage beyond the first happy-path catalog in
`CHAT_FLOWS.md`.

**Last reviewed:** 2026-05-28

## Purpose

The current Playwright suite proves auth/lifecycle and the main chat shell. It
does not yet prove the full IRC-like product surface. This file maps the next
waves of black-box browser specs needed for slash commands, dialogs, realtime
edge cases, persistence, permissions, and UI micro-journeys.

## Ground Rules

- Strict black-box: no test routes, no DB reset endpoints, no HTTP seeds.
- Every prerequisite is created through browser actions in the spec.
- Use unique nicks/channels for isolation.
- Prefer `data-testid`, then ids, then role/name.
- Chat must not steal focus. Incoming tabs, PMs, notices, invites, perform, and
  autojoin flows should assert indicators/tabs without automatic active-window
  switches unless the user explicitly clicks.
- If a browser spec exposes product behavior that a real user would consider
  broken, pause and ask before weakening assertions.
- Full suite runs are reserved for product-code changes. For E2E-only work,
  run the affected spec file(s) headed with `SLOW_MO=300`, plus TypeScript
  checks when Page Objects change.

## Status Legend

- `done` - already covered by `CHAT_FLOWS.md`
- `todo` - planned but not implemented
- `investigate` - needs UI/selector/product behavior audit before writing
- `block` - intentionally not runnable until a safe black-box strategy exists

## Current Slash Command Coverage Snapshot

Registry currently exposes 58 slash commands. Existing E2E specs directly cover
only the foundation and a small subset of command behavior.

| Command | Current E2E | New backlog area | Notes |
|---------|-------------|------------------|-------|
| `/admin` | partial | M | Existing: server ban and registration closed. Still needs subcommand breadth. |
| `/alias` | none | L | Needs CLI command and dialog coverage. |
| `/announce` | none | M | Admin broadcast, ignore bypass, permission denial. |
| `/autorespond` | none | L | Triggered automation and dialog coverage. |
| `/autojoin` | none | L, P | Manual list plus reconnect execution. |
| `/away` | partial | J | Existing set/clear. Still needs whois and auto-reply effects. |
| `/ban` | none | I | Channel ban, rejoin block, unban. |
| `/bio` | none | J | Whois-visible profile text and clear. |
| `/bot` | none | M | Admin bot lifecycle and bot response flows. |
| `/clear` | none | H | Active-window local clearing. |
| `/clearmotd` | none | H, M | Admin server message cleanup. |
| `/clearwelcome` | none | H | Channel welcome lifecycle. |
| `/cs` | none | K | ChanServ register/access/drop/info. |
| `/deop` | none | I | Role removal and permission effects. |
| `/devoice` | none | I | Voice removal and moderated channel effects. |
| `/help` | partial | G | Existing list. Still needs per-command help and Help Topics menu. |
| `/ignore` | none | J | Filtering, list, typed ignores, expiry. |
| `/invite` | none | I, J | Invite-only channels, invite cards, ignore interaction. |
| `/join` | partial | H, I, P | Existing basic join. Still needs errors, keys, limits, invite-only, autojoin. |
| `/kick` | none | I | Target removal, reason, permissions. |
| `/knock` | none | I | Invite-only request, operator notification, throttle, +K. |
| `/leave` | none | H | Alias for `/part`. |
| `/list` | none | H | Channel list dialog search/sort/join. |
| `/me` | partial | J | Existing action render. Still needs ignore/actions and moderated effects. |
| `/mode` | none | I | Core channel mode matrix. |
| `/motd` | none | H, M | View current server MOTD. |
| `/msg` | partial | D, J, P | Existing PM basic. Still needs ignore, persistence, unread, history. |
| `/mute` | none | I | Channel mute blocks sending. |
| `/nick` | partial | E, J, K | Existing own rename. Still needs collision, registered nick password, remote update. |
| `/notice` | none | J | No-PM delivery semantics. |
| `/notice_routing` | none | J | Current command says notices route to active window; verify UX. |
| `/notify` | none | J, P | Buddy list, online/offline events, persistence. |
| `/ns` | none | K | NickServ lifecycle and ghost. |
| `/op` | none | I | Role grant. |
| `/call` | none | N | P2P audio-call invite, permission setup. |
| `/game` | none | N | P2P game invite and lobby. |
| `/p2p` | none | N | Generic P2P invite and lobby. |
| `/part` | partial | H | Existing basic part. Still needs explicit target and reason broadcast. |
| `/popups` | none | L, O | Custom menu dialog and execution. |
| `/perform` | none | L, P | CRUD plus reconnect execution. |
| `/query` | none | J | PM tab without sending a message. |
| `/quit` | none | H | File disconnect covered; slash quit with reason is not. |
| `/sendfile` | none | N | P2P file-transfer invite and upload UI. |
| `/singleplayer` | none | M, N | Admin-only solo arcade link. |
| `/setmotd` | none | H, M | Admin MOTD set and new-user visibility. |
| `/setwelcome` | none | H | Channel welcome set and clear. |
| `/slow` | none | I | Join throttle wrapper. |
| `/timer` | none | L | Timer create/list/stop/fire. |
| `/topic` | partial | H, I | Existing set. Still needs view, protected topic, remote update. |
| `/transfer` | none | I, K | Channel ownership transfer. |
| `/umode` | none | J | Wallops opt-in/out. |
| `/unban` | none | I | Ban removal. |
| `/unignore` | none | J | Restore filtered messages. |
| `/unmute` | none | I | Channel mute removal. |
| `/voice` | none | I | Role grant. |
| `/wallops` | none | J, M | Operator broadcast to users with +w. |
| `/whois` | none | J | Rich presence/profile/idle output. |
| `/whowas` | none | J | Last-seen lookup after disconnect. |

## Group G - Command Surface, Help, Autocomplete, Validation

| # | Flow | Planned spec file | Priority | Status |
|---|------|-------------------|----------|--------|
| G1 | Unknown command shows `Unknown command: /x. Type /help...` in active message list | `tests/chat-command-surface.spec.ts` | P0 | done |
| G2 | Missing required args show usage for representative commands: `/msg`, `/join`, `/mode`, `/ns`, `/admin` | `tests/chat-command-surface.spec.ts` | P0 | done |
| G3 | `/help join` renders command-specific inline help or system help text | `tests/chat-help-detail.spec.ts` | P1 | done |
| G4 | Help Topics menu opens the full help system without submitting chat input | `tests/chat-help-detail.spec.ts` | P1 | done |
| G5 | Syntax tooltip appears for `/mode ` and tracks argument position while typing | `tests/chat-syntax-tooltip.spec.ts` | P1 | done |
| G6 | Subcommand autocomplete appears for supported subcommand commands: `/ns `, `/cs `, `/perform `, and `/autojoin ` | `tests/chat-autocomplete-advanced.spec.ts` | P1 | done |
| G7 | Selecting command autocomplete fills the input and then argument autocomplete appears for `/msg <nick>` | `tests/chat-autocomplete-advanced.spec.ts` | P1 | done |
| G8 | Autocomplete navigation with ArrowUp/ArrowDown/Tab never sends a chat message | `tests/chat-autocomplete-advanced.spec.ts` | P1 | done |
| G9 | Command history recalls prior non-sensitive commands and skips sensitive NickServ commands | `tests/chat-command-history.spec.ts` | P2 | done |
| G10 | Escape closes autocomplete, syntax tooltip, and history search in the right order | `tests/chat-command-history.spec.ts` | P2 | done |

## Group H - Channels, Server Messages, and Local Window State

| # | Flow | Planned spec file | Priority | Status |
|---|------|-------------------|----------|--------|
| H1 | `/join room` without `#` shows validation error | `tests/chat-channel-errors.spec.ts` | P0 | done |
| H2 | Joining more than the allowed channel count shows a max-channel error without losing current tab | `tests/chat-channel-errors.spec.ts` | P1 | done |
| H3 | `/leave #room bye` works as `/part`, removes the tab, and broadcasts the part reason | `tests/chat-channel-lifecycle.spec.ts` | P1 | done |
| H4 | `/part #other` from `#lobby` removes only `#other` and does not steal focus | `tests/chat-channel-lifecycle.spec.ts` | P1 | done |
| H5 | `/clear` clears only the active window; switching tabs preserves other windows | `tests/chat-channel-lifecycle.spec.ts` | P1 | done |
| H6 | `/topic` with no args prints current topic text | `tests/chat-topic-advanced.spec.ts` | P1 | done |
| H7 | Topic changes are visible in realtime to another user in the channel | `tests/chat-topic-advanced.spec.ts` | P1 | done |
| H8 | `/list` opens channel list dialog, search filters a unique channel, Join button joins it | `tests/chat-channel-list.spec.ts` | P1 | done |
| H9 | `/setwelcome msg` then a new user joins and sees the welcome message once | `tests/chat-channel-welcome.spec.ts` | P1 | done |
| H10 | `/clearwelcome` stops the channel welcome from appearing for later joiners | `tests/chat-channel-welcome.spec.ts` | P1 | done |
| H11 | `/setmotd text`, `/motd`, and new connect show the admin MOTD; cleanup with `/clearmotd` | `tests/chat-server-messages.spec.ts` | P1 | done |
| H12 | `/quit reason` navigates self to `/connect` and other channel members see the quit/left reason | `tests/chat-quit.spec.ts` | P1 | done |

## Group I - Channel Modes, Privileges, Moderation

| # | Flow | Planned spec file | Priority | Status |
|---|------|-------------------|----------|--------|
| I1 | First user in a unique channel is owner; nicklist exposes the owner role | `tests/chat-channel-roles.spec.ts` | P0 | done |
| I2 | `/op bob`, `/deop bob`, `/voice bob`, `/devoice bob` update bob's nicklist role in realtime | `tests/chat-channel-roles.spec.ts` | P0 | done |
| I3 | Non-operator running `/mode +m` or `/kick` gets permission error | `tests/chat-channel-permissions.spec.ts` | P0 | done |
| I4 | Half-op can voice/devoice but cannot set protected channel modes | `tests/chat-channel-modes.spec.ts` | P1 | done |
| I5 | `/mode +m` blocks unvoiced user messages; `/voice` allows speaking; `/mode -m` restores normal sending | `tests/chat-channel-modes.spec.ts` | P0 | done |
| I6 | `/mode +i` blocks direct join; `/invite bob #room` lets bob join | `tests/chat-channel-modes.spec.ts` | P0 | done |
| I7 | `/invite auto` toggles auto-join-on-invite and does not steal focus unexpectedly | `tests/chat-channel-invite.spec.ts` | P2 | done |
| I8 | `/mode +k secret` requires a key; wrong key fails, right key joins | `tests/chat-channel-modes.spec.ts` | P1 | done |
| I9 | `/mode +l 1` enforces channel limit; removing limit allows join | `tests/chat-channel-modes.spec.ts` | P1 | done |
| I10 | `/mode +t` blocks non-operator topic changes; `/mode -t` allows them again | `tests/chat-channel-modes.spec.ts` | P1 | done |
| I11 | `/ban bob` removes/blocks bob; `/unban bob` allows rejoin | `tests/chat-channel-moderation.spec.ts` | P0 | done |
| I12 | `/kick bob reason` removes bob's channel tab and broadcasts the reason | `tests/chat-channel-moderation.spec.ts` | P0 | done |
| I13 | `/mute bob` blocks bob's channel messages; `/unmute bob` restores sending | `tests/chat-channel-moderation.spec.ts` | P0 | done |
| I14 | `/slow 60` throttles rapid joins and `/slow 0` disables throttle | `tests/chat-channel-modes.spec.ts` | P2 | done |
| I15 | `/knock #room` notifies operators of invite-only channel; repeated knock is throttled | `tests/chat-channel-knock.spec.ts` | P2 | done |
| I16 | `/mode +K` disables knock and `/mode -K` allows knock again | `tests/chat-channel-knock.spec.ts` | P2 | done |
| I17 | `/transfer bob` changes channel ownership and privileges | `tests/chat-channel-transfer.spec.ts` | P1 | done |
| I18 | Channel Central dialog edits modes/key/limit and the slash command output stays consistent | `tests/chat-channel-central.spec.ts` | P2 | done |

## Group J - User Commands, Privacy, Presence

| # | Flow | Planned spec file | Priority | Status |
|---|------|-------------------|----------|--------|
| J1 | `/query bob` opens a PM tab without sending a message | `tests/chat-user-commands.spec.ts` | P0 | done |
| J2 | `/notice bob text` delivers a notice without opening a PM tab on recipient | `tests/chat-notice.spec.ts` | P0 | done |
| J3 | `/notice #room text` delivers to channel and respects active-window routing | `tests/chat-notice.spec.ts` | P1 | done |
| J4 | `/notice_routing` reports current routing behavior and does not change hidden state unexpectedly | `tests/chat-notice.spec.ts` | P2 | done |
| J5 | `/ignore bob all` hides bob's channel messages, actions, PMs, notices, and invites | `tests/chat-ignore.spec.ts` | P0 | done |
| J6 | Type-specific ignore works: `messages` hides channel text but not PM; `pms` hides PM but not channel text | `tests/chat-ignore.spec.ts` | P1 | done |
| J7 | `/ignore` lists entries and `/unignore bob` restores visibility | `tests/chat-ignore.spec.ts` | P0 | done |
| J8 | `/ignore <ownnick>` shows self-ignore error | `tests/chat-ignore.spec.ts` | P1 | done |
| J9 | Timed ignore expiry emits "no longer ignored" status | `tests/chat-ignore.spec.ts` | P2 | done |
| J10 | `/bio text` appears in another user's `/whois`; `/bio clear` removes it | `tests/chat-whois.spec.ts` | P1 | done |
| J11 | `/whois bob` shows online, idle, registered/identified, shared channels, away, and bio fields | `tests/chat-whois.spec.ts` | P0 | done |
| J12 | `/whois missingNick` shows not-online/not-found message | `tests/chat-whois.spec.ts` | P1 | done |
| J13 | `/away msg` makes other user's `/whois` show away state and auto-reply behavior | `tests/chat-away-advanced.spec.ts` | P1 | done |
| J14 | `/whowas bob` after bob disconnects shows last seen data | `tests/chat-whowas.spec.ts` | P1 | done |
| J15 | `/notify add bob`, bob connects, and notifier sees online/offline status messages | `tests/chat-notify.spec.ts` | P0 | done |
| J16 | `/notify edit/list/remove` updates visible notify list output and Address Book state | `tests/chat-notify.spec.ts` | P1 | done |
| J17 | `/umode +w` opts in to `/wallops`; `/umode -w` opts out | `tests/chat-wallops.spec.ts` | P1 | done |
| J18 | `/wallops msg` reaches only opted-in users and requires appropriate privileges if product enforces them | `tests/chat-wallops.spec.ts` | P1 | done |

## Group K - NickServ and ChanServ

| # | Flow | Planned spec file | Priority | Status |
|---|------|-------------------|----------|--------|
| K1 | `/nick` to an unregistered nick, then `/ns register pw` registers it and `/ns info` reports it | `tests/chat-nickserv.spec.ts` | P0 | done |
| K2 | `/ns identify wrong` fails, retry with correct password succeeds | `tests/chat-nickserv.spec.ts` | P0 | done |
| K3 | `/ns drop wrong` fails, `/ns drop correct` deletes registration | `tests/chat-nickserv.spec.ts` | P1 | done |
| K4 | `/ns ghost nick password` rejects wrong password and disconnects the stale registered session with the correct password | `tests/chat-nickserv.spec.ts` | P1 | done |
| K5 | `/nick registeredNick` opens password dialog and only confirms with correct password | `tests/chat-nickserv.spec.ts` | P0 | done |
| K6 | `/cs register` registers current channel and `/cs info` shows founder | `tests/chat-chanserv.spec.ts` | P0 | done |
| K7 | `/cs aop add bob`, bob rejoins, and auto-operator privilege applies | `tests/chat-chanserv.spec.ts` | P1 | done |
| K8 | `/cs vop add bob`, bob rejoins, and auto-voice privilege applies | `tests/chat-chanserv.spec.ts` | P1 | done |
| K9 | `/cs sop/aop/vop list` displays access list and `/cs ... del` removes entry | `tests/chat-chanserv.spec.ts` | P1 | done |
| K10 | Non-founder cannot `/cs drop`; founder can drop after confirmation path if any | `tests/chat-chanserv.spec.ts` | P1 | done |
| K11 | `/admin ns info/resetpass/drop` changes NickServ state from admin context | `tests/chat-admin-services.spec.ts` | P1 | done |
| K12 | `/admin cs info/access/transfer/drop` changes ChanServ state from admin context | `tests/chat-admin-services.spec.ts` | P1 | done |

## Group L - Config, Scripting, Timers, Custom Menus

| # | Flow | Planned spec file | Priority | Status |
|---|------|-------------------|----------|--------|
| L1 | `/alias add hi /me says hi`, `/hi`, `/alias list`, `/alias remove hi` | `tests/chat-alias.spec.ts` | P0 | done |
| L2 | Alias variables `$1`, `$nick`, `$chan`, and `$$` expand correctly | `tests/chat-alias.spec.ts` | P1 | done |
| L3 | Alias recursion limit shows error instead of freezing UI | `tests/chat-alias.spec.ts` | P1 | done |
| L4 | Alias expansion rejects command chaining characters | `tests/chat-alias.spec.ts` | P1 | done |
| L5 | `/alias` opens Alias dialog; add/edit/remove through dialog mirrors slash output | `tests/chat-alias-dialog.spec.ts` | P2 | done |
| L6 | `/perform add /join #x`, list/move/remove/clear all update command output | `tests/chat-perform.spec.ts` | P0 | done |
| L7 | Perform entries execute on reconnect and do not steal active-window focus | `tests/chat-perform.spec.ts` | P0 | done |
| L8 | Sensitive perform command display is masked and disallowed commands are rejected | `tests/chat-perform.spec.ts` | P1 | done |
| L9 | `/autojoin add/list/remove/clear` works and invalid channel names are rejected | `tests/chat-autojoin.spec.ts` | P0 | done |
| L10 | Joining a unique channel auto-adds it to autojoin; part removes it | `tests/chat-autojoin.spec.ts` | P1 | done |
| L11 | Autojoin entries execute on reconnect without stealing focus | `tests/chat-autojoin.spec.ts` | P0 | done |
| L12 | `/autorespond add on_join #room /notice $nick hi` fires when another user joins | `tests/chat-autorespond.spec.ts` | P1 | done |
| L13 | Autorespond `on_part` and `on_nick_change` fire with `$nick` expansion | `tests/chat-autorespond.spec.ts` | P2 | done |
| L14 | Autorespond list/remove and invalid chaining behavior | `tests/chat-autorespond.spec.ts` | P1 | done |
| L15 | `/timer once 1 /me timed` fires once, then disappears from `/timer list` | `tests/chat-timer.spec.ts` | P1 | done |
| L16 | `/timer stop name` cancels before firing; missing timer shows error | `tests/chat-timer.spec.ts` | P1 | done |
| L17 | Repeating timer minimum/clamp notice appears and can be stopped | `tests/chat-timer.spec.ts` | P2 | done |
| L18 | `/popups` opens custom menus dialog; custom nick/channel menu item executes command | `tests/chat-custom-menus.spec.ts` | P2 | done |

## Group M - Admin, Server Operations, Bots

| # | Flow | Planned spec file | Priority | Status |
|---|------|-------------------|----------|--------|
| M1 | Non-admin `/admin server info` shows permission error | `tests/chat-admin-extended.spec.ts` | P0 | done |
| M2 | Admin `/admin server info/get/settings` displays server data | `tests/chat-admin-extended.spec.ts` | P1 | done |
| M3 | Admin server setting validation: invalid `registration`, invalid `max_channels`, restore originals in `finally` | `tests/chat-admin-extended.spec.ts` | P1 | done |
| M4 | `/admin user list --search`, `info`, `banlist` display expected rows | `tests/chat-admin-users.spec.ts` | P1 | done |
| M5 | `/admin user kick` force-disconnects target with reason; target can reconnect | `tests/chat-admin-users.spec.ts` | P0 | done |
| M6 | `/admin user mute` blocks all target sends; `/admin user unmute` restores sends | `tests/chat-admin-users.spec.ts` | P0 | done |
| M7 | `/admin user rename old new` updates target session and other users' nicklists | `tests/chat-admin-users.spec.ts` | P1 | done |
| M8 | `/admin user role` validates root-admin restriction and non-admin promotion denial | `tests/chat-admin-users.spec.ts` | P2 | done |
| M9 | `/admin channel create/info/list/banlist/delete` over unique channels | `tests/chat-admin-channels.spec.ts` | P1 | done |
| M10 | `/admin channel purge #room --from bob` removes bob's visible history only | `tests/chat-admin-channels.spec.ts` | P2 | done |
| M11 | `/admin debug memory/processes/connections`, `/admin log --last`, `/admin turn stats` render without crashing | `tests/chat-admin-diagnostics.spec.ts` | P2 | done |
| M12 | `/admin nuke` without `--confirm` shows destructive confirmation/help only | `tests/chat-admin-nuke.spec.ts` | P2 | done |
| M13 | `/admin nuke --confirm` is not run in shared E2E DB until an isolated manual profile exists | `tests/chat-admin-nuke.spec.ts` | P2 | block |
| M14 | Non-admin `/bot` shows bot list, admin `/bot` opens management dialog | `tests/chat-bots.spec.ts` | P1 | done |
| M15 | Admin creates a unique bot, joins it to a unique channel, and sees bot in nicklist | `tests/chat-bots.spec.ts` | P1 | done |
| M16 | Bot custom command add/list/invoke/delete works through slash command | `tests/chat-bots.spec.ts` | P1 | done |
| M17 | Bot enable/disable/destroy changes response behavior and cleans up unique bot | `tests/chat-bots.spec.ts` | P2 | done |
| M18 | `/announce text` broadcasts to every connected user and bypasses ignore filters | `tests/chat-announce.spec.ts` | P1 | done |
| M19 | Regular user `/announce`, `/setmotd`, `/clearmotd`, `/singleplayer` show permission errors | `tests/chat-admin-permissions.spec.ts` | P1 | done |
| M20 | Admin `/singleplayer` emits a usable solo arcade link/card | `tests/chat-singleplayer.spec.ts` | P2 | done |

## Group N - P2P, File, Call, Game

| # | Flow | Planned spec file | Priority | Status |
|---|------|-------------------|----------|--------|
| N1 | Unidentified user `/p2p bob`, `/call bob`, `/sendfile bob`, `/game bob` shows identify-required errors | `tests/chat-p2p-errors.spec.ts` | P0 | done |
| N2 | Registered identified user cannot P2P/call/sendfile/game self | `tests/chat-p2p-errors.spec.ts` | P1 | done |
| N3 | Target not registered shows "not registered" error | `tests/chat-p2p-errors.spec.ts` | P1 | done |
| N4 | `/p2p bob` creates PM invite cards for sender and receiver; both can open the lobby and closing the lobby ends the session | `tests/chat-p2p-invite.spec.ts` | P1 | done |
| N5 | `/call bob` creates audio-call lobby/session with browser permissions mocked by Playwright context | `tests/chat-p2p-call.spec.ts` | P2 | done |
| N6 | `/sendfile bob` creates file-transfer session and upload UI accepts a small temp file | `tests/chat-p2p-file.spec.ts` | P2 | done |
| N7 | `/game bob` creates game invite and lobby; selecting a game starts shared game shell | `tests/chat-p2p-game.spec.ts` | P2 | done |
| N8 | P2P action decline clears consent state from both lobbies without stealing chat focus | `tests/chat-p2p-invite.spec.ts` | P2 | done |

## Group O - Chat UI Micro-Journeys

| # | Flow | Planned spec file | Priority | Status |
|---|------|-------------------|----------|--------|
| O1 | Emoji picker opens, searches, inserts emoji, and closes | `tests/chat-emoji.spec.ts` | P1 | done |
| O2 | Italic/underline/reverse/reset/color formatting buttons insert correct IRC control codes | `tests/chat-formatting-advanced.spec.ts` | P1 | done |
| O3 | Strip formatting toggle affects rendered outbound/inbound formatted text | `tests/chat-formatting-advanced.spec.ts` | P2 | done |
| O4 | Multi-line paste triggers paste confirmation dialog; send/cancel paths behave correctly | `tests/chat-paste.spec.ts` | P1 | done |
| O5 | Flood warning appears for large paste and sequential paste send preserves message order | `tests/chat-paste.spec.ts` | P2 | done |
| O6 | Search bar opens, highlights matches, next/prev navigate, invalid regex shows error | `tests/chat-search.spec.ts` | P1 | done |
| O7 | Search options case-sensitive/regex/my-mentions/history persist while search stays open | `tests/chat-search.spec.ts` | P2 | done |
| O8 | Reply via message context menu creates reply bar; send includes reply block; dismiss cancels | `tests/chat-message-actions.spec.ts` | P1 | done |
| O9 | Edit last own message with ArrowUp; submit edit updates message and shows edited tag | `tests/chat-message-actions.spec.ts` | P1 | done |
| O10 | Delete own message marks deleted placeholder for both users | `tests/chat-message-actions.spec.ts` | P1 | done |
| O11 | Retry failed pending message path appears when channel send is rejected by mode/mute | `tests/chat-message-actions.spec.ts` | P2 | done |
| O12 | Nicklist context menu: query, whois, ignore/unignore, op/voice actions are visible and execute | `tests/chat-context-menus.spec.ts` | P1 | done |
| O13 | Conversation context menu: mark-read, mute toggle, copy name, leave/channel settings | `tests/chat-context-menus.spec.ts` | P2 | done |
| O14 | Hover card over nick shows registered/away/idle/shared channel information | `tests/chat-hover-card.spec.ts` | P2 | done |
| O15 | URL catcher records links from chat, search filters, preview title updates if available | `tests/chat-url-catcher.spec.ts` | P2 | done |
| O16 | Address Book dialog add/edit/remove contact, notify, nick color, and control entries | `tests/chat-address-book.spec.ts` | P2 | done |
| O17 | Custom nick color applies to message nick rendering in chat | `tests/chat-address-book.spec.ts` | P2 | done |
| O18 | Keyboard shortcuts switch windows, open cheatsheet, open address book, and never submit text accidentally | `tests/chat-keyboard.spec.ts` | P1 | done |
| O19 | Mute toggle in status bar affects client audio state and survives rerender | `tests/chat-statusbar.spec.ts` | P2 | done |

## Group P - Persistence, Reconnect, History, No-Focus-Steal

| # | Flow | Planned spec file | Priority | Status |
|---|------|-------------------|----------|--------|
| P1 | Registered user's PM partners restore on reconnect ordered by most recent message | `tests/chat-persistence.spec.ts` | P0 | done |
| P2 | Guest user's PM partners do not persist after reconnect | `tests/chat-persistence.spec.ts` | P1 | done |
| P3 | Incoming PM opens/updates tab indicator but does not auto-switch active tab | `tests/chat-no-focus-steal.spec.ts` | P0 | done |
| P4 | Incoming channel message updates unread indicator but does not auto-switch active tab | `tests/chat-no-focus-steal.spec.ts` | P0 | done |
| P5 | Perform and autojoin execution on reconnect create tabs without stealing current focus | `tests/chat-perform.spec.ts`, `tests/chat-autojoin.spec.ts` | P0 | done |
| P6 | Registered aliases, perform list, autojoin list, ignore list, notify list, and nick colors persist across reconnect | `tests/chat-settings-persistence.spec.ts` | P1 | done |
| P7 | Guest aliases/perform/autojoin/ignore/notify are session-only | `tests/chat-settings-persistence.spec.ts` | P2 | done |
| P8 | Browser reload keeps current chat session and reconnects LiveView cleanly | `tests/chat-reconnect.spec.ts` | P1 | done |
| P9 | Connection loss/reconnect UI transitions through disabled input/reconnect button without losing typed draft | `tests/chat-reconnect.spec.ts` | P2 | done |
| P10 | Message pagination/scroll loader loads older channel/PM history without duplicate messages | `tests/chat-history-pagination.spec.ts` | P2 | done |
| P11 | Idle time shown in `/whois` increases with inactivity and resets after message/command | `tests/chat-idle.spec.ts` | P2 | done |
| P12 | Typing indicator appears in PM recipient tab and clears after timeout or send | `tests/chat-typing-indicator.spec.ts` | P1 | done |

## Suggested Implementation Order

1. P0 command and channel safety: G1-G2, I2-I6, I11-I13, J1-J7.
2. Services and persistence: K1-K6, P1-P6.
3. Config automation: L1-L14.
4. Admin and server operations: M1-M12, M14-M19.
5. P2P/game/file and UI micro-journeys: N, O, remaining P.

## Notes for Spec Authors

- Prefer one focused spec file per group, but split high-risk multi-context
  flows when setup gets too heavy.
- Admin specs must restore modified global settings in `finally`.
- Avoid long timer waits. Use the minimum product-supported interval and assert
  visible system messages.
- For destructive admin paths, validate the non-confirming/permission/error
  path first. The confirmed `/admin nuke --confirm` flow remains blocked until
  there is a separate disposable environment that still satisfies black-box
  constraints.
- P2P audio/file/game flows may need browser permissions, temporary files, and
  extra Playwright context setup. Keep those in dedicated files so normal chat
  command specs stay fast.
