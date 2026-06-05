# E2E Test Catalog

Single source of truth for the browser-level Playwright suite.

**Last reviewed:** 2026-06-05

## Current Coverage

- **201 spec files** under `e2e/tests/`.
- **345 Playwright `test()` cases**.
- **Auth/lifecycle:** 17 mapped flows, all done.
- **Chat foundation:** 25 mapped flows, all done.
- **Chat extended coverage:** 303 mapped flows, 302 done, 1 intentionally blocked.
- **Open todo/investigate items in this catalog:** none. Planned backlog lives in `TEST_BACKLOG.md`.
- **Blocked item:** M13, confirmed `/admin nuke --confirm`, until a disposable isolated E2E profile exists.

## UI Features Browser Regression

| # | Flow | Spec file | Features | Status |
|---|------|-----------|----------|--------|
| UI1 | Account dialog covers drop/re-register, profile bio, presence away state, wallops user mode, and Whois bio output | `tests/chat-ui-features-shell.spec.ts` | 01, 10 | done |
| UI2 | Notify List opens from View; Bot Management is hidden from regular users and opens for admin users | `tests/chat-ui-features-shell.spec.ts` | 02, 03 | done |
| UI3 | Edit menu preserves Clear/Copy/Find behavior through menu entry points | `tests/chat-ui-features-shell.spec.ts` | 04 | done |
| UI4 | Action toggle and Send Notice composer send through the real chat input | `tests/chat-ui-features-shell.spec.ts` | 07 | done |
| UI5 | Timers dialog opens from Tools and bare `/timer`, validates repeat intervals, saves once timers, and stops timers | `tests/chat-ui-features-shell.spec.ts` | 08 | done |
| UI6 | User Lookup dialog and result cards cover Whois, Query, and Whowas flows | `tests/chat-ui-features-shell.spec.ts` | 10 | done |
| UI7 | Channel nick context menu performs voice/devoice/op/deop/mute/unmute and blocks/restores target sends | `tests/chat-ui-features-channel.spec.ts` | 05 | done |
| UI8 | Invite picker invites from a joined channel; Channel List knock request sends real knock flow | `tests/chat-ui-features-channel.spec.ts` | 06 | done |
| UI9 | Channel Central applies welcome message, join throttle, and ownership transfer | `tests/chat-ui-features-channel.spec.ts` | 09 | done |
| UI10 | Channel Central registration tab performs ChanServ register and AOP add/remove | `tests/chat-ui-features-channel.spec.ts` | 11 | done |
| UI11 | Admin Console tabs cover safe server settings, users, channels, MOTD, broadcast, audit log, TURN, danger preview, and raw console paths | `tests/chat-ui-features-admin.spec.ts` | 12 | done |

## Operating Rules

- Strict black-box: no test-only routes, no DB reset endpoints, no HTTP seeds, no backdoors.
- Every prerequisite must be created through browser actions inside the spec.
- Use unique nicknames, channels, bot names, messages, and settings per run.
- Selectors: `data-testid` first, then stable `id`, then role/name. Never Tailwind classes.
- Page Object Model lives in `e2e/pages/*.ts`; specs should read like scenarios.
- Chat never steals focus. Incoming PMs, channel messages, invites, perform/autojoin, and reconnect flows should use indicators/tabs until the user clicks.
- If a focused browser spec exposes product behavior a real user would consider broken, fix product behavior or explicitly decide otherwise before weakening the assertion.
- For E2E-only changes, run the focused spec and TypeScript checks if Page Objects changed.
- For product code changes, run the focused E2E spec and `make ci`.

## Run Commands

Run focused Playwright commands from `e2e/`.

```bash
make e2e.install
make e2e.db.setup
SLOW_MO=300 npx playwright test tests/<spec>.spec.ts --headed
npx tsc --noEmit
make ci
```

## Status Legend

- `done` - implemented and passing.
- `block` - intentionally not runnable until a safe black-box strategy exists.

## Auth And Lifecycle

| # | Flow | Spec file | Status |
|---|------|-----------|--------|
| A | Brand-new user registers a nickname and lands on `/chat` | `tests/connect-flow.spec.ts` | done |
| B | Register a nick, disconnect, reconnect with correct password lands on `/chat` | `tests/returning-user.spec.ts` | done |
| C1 | Empty nickname keeps Connect disabled | `tests/nickname-validation.spec.ts` | done |
| C2 | Nickname longer than 16 chars shows inline error | `tests/nickname-validation.spec.ts` | done |
| C3 | Nickname containing a space shows inline error | `tests/nickname-validation.spec.ts` | done |
| C4 | Nickname starting with a digit shows inline error | `tests/nickname-validation.spec.ts` | done |
| D | Returning user wrong password shows error; retry with correct password works | `tests/returning-user.spec.ts` | done |
| E | Register step password mismatch shows inline error | `tests/register-validation.spec.ts` | done |
| F | Register step short password shows inline error | `tests/register-validation.spec.ts` | done |
| G | Back button returns from register/password to nickname | `tests/navigation.spec.ts` | done |
| H | Direct `/chat` access without session bounces to `/connect` | `tests/chat-guard.spec.ts` | done |
| I | `/connect?reason=expired` surfaces session expired message | `tests/disconnect-reason.spec.ts` | done |
| J | `/connect?reason=disconnected` surfaces session ended message | `tests/disconnect-reason.spec.ts` | done |
| K | Same nickname from second context force-disconnects first context | `tests/multi-tab-takeover.spec.ts` | done |
| L | Logged-in user disconnects via UI and lands on `/connect` | `tests/logout.spec.ts` | done |
| M | Admin bans user with `/admin user ban` and victim is force-disconnected | `tests/admin-ban.spec.ts` | done |
| N | Admin closes registration; new user sees registration closed; spec restores open | `tests/admin-registration-closed.spec.ts` | done |

## Chat Foundation

| # | Flow | Spec file | Status |
|---|------|-----------|--------|
| A1 | Type and send a message via Enter; it appears in the message list | `tests/chat-send.spec.ts` | done |
| A1b | Send button click submits the message and resets input | `tests/chat-send.spec.ts` | done |
| A2 | Send button reflects textarea content: disabled, enabled, disabled | `tests/chat-send.spec.ts` | done |
| A3 | Character counter shows `<count>/1000` while typing | `tests/chat-send.spec.ts` | done |
| A4 | `/me dance` renders action-style line containing the nick | `tests/chat-commands-basic.spec.ts` | done |
| A5 | Status tab reveals the server welcome banner | `tests/chat-welcome.spec.ts` | done |
| B1 | A sends message; B sees it in real time in same channel | `tests/chat-multiuser.spec.ts` | done |
| B2 | B joins `#lobby`; A sees join system message | `tests/chat-multiuser.spec.ts` | done |
| B3 | B disconnects; A sees left system message | `tests/chat-multiuser.spec.ts` | done |
| B4 | Nicklist updates when another user joins | `tests/chat-multiuser.spec.ts` | done |
| C1 | `/join #room` creates tab and switches to it | `tests/chat-channels.spec.ts` | done |
| C2 | Switching tabs preserves message history | `tests/chat-channels.spec.ts` | done |
| C3 | Close-tab button removes a channel tab | `tests/chat-channels.spec.ts` | done |
| C4 | `/part #room` leaves channel and removes tab | `tests/chat-channels.spec.ts` | done |
| C5 | `/topic My new topic` updates visible topic bar | `tests/chat-channels.spec.ts` | done |
| D1 | `/msg <bob> hi` opens sender PM tab without focus steal | `tests/chat-pm.spec.ts` | done |
| D2 | Recipient sees PM in tab labeled with sender nick | `tests/chat-pm.spec.ts` | done |
| D3 | PM reply updates other user's PM tab | `tests/chat-pm.spec.ts` | done |
| D4 | Closing PM tab removes it from tablist | `tests/chat-pm.spec.ts` | done |
| E1 | `/nick newname` confirms dialog and updates own nicklist entry | `tests/chat-identity.spec.ts` | done |
| E2 | `/away At lunch` and `/away` emit set/clear status messages | `tests/chat-identity.spec.ts` | done |
| F1 | `/help` lists available commands in active message list | `tests/chat-help.spec.ts` | done |
| F2 | Bold formatting button inserts IRC bold control code | `tests/chat-formatting.spec.ts` | done |
| F3 | Typing `@` shows nickname autocomplete dropdown | `tests/chat-autocomplete.spec.ts` | done |
| F4 | Typing `/jo` shows command autocomplete dropdown | `tests/chat-autocomplete.spec.ts` | done |

## G - Command Surface, Help, Autocomplete, Validation

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| G1 | Unknown command shows helpful unknown-command message | `tests/chat-command-surface.spec.ts` | P0 | done |
| G2 | Missing args show usage for `/msg`, `/join`, `/mode`, `/ns`, `/admin` | `tests/chat-command-surface.spec.ts` | P0 | done |
| G3 | `/help join` renders command-specific help | `tests/chat-help-detail.spec.ts` | P1 | done |
| G4 | Help Topics menu opens full help system without submitting chat input | `tests/chat-help-detail.spec.ts` | P1 | done |
| G5 | Syntax tooltip appears for `/mode` and tracks argument position | `tests/chat-syntax-tooltip.spec.ts` | P1 | done |
| G6 | Subcommand autocomplete appears for `/ns`, `/cs`, `/perform`, `/autojoin` | `tests/chat-autocomplete-advanced.spec.ts` | P1 | done |
| G7 | Selecting `/msg` autocomplete fills input and then nick autocomplete appears | `tests/chat-autocomplete-advanced.spec.ts` | P1 | done |
| G8 | Autocomplete navigation never sends a chat message | `tests/chat-autocomplete-advanced.spec.ts` | P1 | done |
| G9 | Command history recalls non-sensitive commands and skips sensitive NickServ commands | `tests/chat-command-history.spec.ts` | P2 | done |
| G10 | Escape closes autocomplete, syntax tooltip, and history search in order | `tests/chat-command-history.spec.ts` | P2 | done |

## H - Channels, Server Messages, Local Window State

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| H1 | `/join room` without `#` shows validation error | `tests/chat-channel-errors.spec.ts` | P0 | done |
| H2 | Joining over channel limit shows max-channel error without losing tab | `tests/chat-channel-errors.spec.ts` | P1 | done |
| H3 | `/leave #room bye` works as `/part`, removes tab, broadcasts reason | `tests/chat-channel-lifecycle.spec.ts` | P1 | done |
| H4 | `/part #other` from `#lobby` removes only `#other` and does not steal focus | `tests/chat-channel-lifecycle.spec.ts` | P1 | done |
| H5 | `/clear` clears only active window; other windows preserve history | `tests/chat-channel-lifecycle.spec.ts` | P1 | done |
| H6 | `/topic` with no args prints current topic | `tests/chat-topic-advanced.spec.ts` | P1 | done |
| H7 | Topic changes are visible in realtime to another user | `tests/chat-topic-advanced.spec.ts` | P1 | done |
| H8 | `/list` opens channel list; search and Join work | `tests/chat-channel-list.spec.ts` | P1 | done |
| H9 | `/setwelcome` shows welcome once for a later joiner | `tests/chat-channel-welcome.spec.ts` | P1 | done |
| H10 | `/clearwelcome` stops welcome for later joiners | `tests/chat-channel-welcome.spec.ts` | P1 | done |
| H11 | `/setmotd`, `/motd`, new connect, and `/clearmotd` work | `tests/chat-server-messages.spec.ts` | P1 | done |
| H12 | `/quit reason` disconnects self and broadcasts reason to channel | `tests/chat-quit.spec.ts` | P1 | done |

## I - Channel Modes, Privileges, Moderation

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| I1 | First user in unique channel is owner | `tests/chat-channel-roles.spec.ts` | P0 | done |
| I2 | `/op`, `/deop`, `/voice`, `/devoice` update role in realtime | `tests/chat-channel-roles.spec.ts` | P0 | done |
| I3 | Non-operator `/mode +m` or `/kick` gets permission error | `tests/chat-channel-permissions.spec.ts` | P0 | done |
| I4 | Half-op can voice/devoice but cannot set protected modes | `tests/chat-channel-modes.spec.ts` | P1 | done |
| I5 | Moderated channel blocks unvoiced user; voice restores; `-m` restores normal | `tests/chat-channel-modes.spec.ts` | P0 | done |
| I6 | Invite-only channel blocks direct join; `/invite` allows join | `tests/chat-channel-modes.spec.ts` | P0 | done |
| I7 | `/invite auto` toggles auto-join-on-invite without focus steal | `tests/chat-channel-invite.spec.ts` | P2 | done |
| I8 | Keyed channel requires correct key | `tests/chat-channel-modes.spec.ts` | P1 | done |
| I9 | Channel limit is enforced and removing it allows join | `tests/chat-channel-modes.spec.ts` | P1 | done |
| I10 | Protected topic blocks non-op topic changes; `-t` restores | `tests/chat-channel-modes.spec.ts` | P1 | done |
| I11 | `/ban bob` removes/blocks; `/unban bob` allows rejoin | `tests/chat-channel-moderation.spec.ts` | P0 | done |
| I12 | `/kick bob reason` removes tab and broadcasts reason | `tests/chat-channel-moderation.spec.ts` | P0 | done |
| I13 | `/mute bob` blocks channel messages; `/unmute bob` restores | `tests/chat-channel-moderation.spec.ts` | P0 | done |
| I14 | `/slow 60` throttles rapid joins; `/slow 0` disables | `tests/chat-channel-modes.spec.ts` | P2 | done |
| I15 | `/knock` notifies operators and repeated knock throttles | `tests/chat-channel-knock.spec.ts` | P2 | done |
| I16 | `/mode +K` disables knock; `-K` allows it again | `tests/chat-channel-knock.spec.ts` | P2 | done |
| I17 | `/transfer bob` changes ownership and privileges | `tests/chat-channel-transfer.spec.ts` | P1 | done |
| I18 | Channel Central edits modes/key/limit consistently with slash output | `tests/chat-channel-central.spec.ts` | P2 | done |

## J - User Commands, Privacy, Presence

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| J1 | `/query bob` opens PM tab without sending a message | `tests/chat-user-commands.spec.ts` | P0 | done |
| J2 | `/notice bob text` delivers notice without opening PM tab | `tests/chat-notice.spec.ts` | P0 | done |
| J3 | `/notice #room text` delivers to channel and respects routing | `tests/chat-notice.spec.ts` | P1 | done |
| J4 | `/notice_routing` reports current routing behavior | `tests/chat-notice.spec.ts` | P2 | done |
| J5 | `/ignore bob all` hides channel messages, actions, PMs, notices, invites | `tests/chat-ignore.spec.ts` | P0 | done |
| J6 | Type-specific ignore separates channel messages from PMs | `tests/chat-ignore.spec.ts` | P1 | done |
| J7 | `/ignore` lists entries and `/unignore bob` restores visibility | `tests/chat-ignore.spec.ts` | P0 | done |
| J8 | `/ignore <ownnick>` shows self-ignore error | `tests/chat-ignore.spec.ts` | P1 | done |
| J9 | Timed ignore expiry emits status | `tests/chat-ignore.spec.ts` | P2 | done |
| J10 | `/bio text` appears in another user's `/whois`; `/bio clear` removes it | `tests/chat-whois.spec.ts` | P1 | done |
| J11 | `/whois bob` shows online, idle, registered, shared channels, away, bio | `tests/chat-whois.spec.ts` | P0 | done |
| J12 | `/whois missingNick` shows not-online/not-found message | `tests/chat-whois.spec.ts` | P1 | done |
| J13 | `/away msg` affects `/whois` and PM auto-reply behavior | `tests/chat-away-advanced.spec.ts` | P1 | done |
| J14 | `/whowas bob` after disconnect shows last-seen data | `tests/chat-whowas.spec.ts` | P1 | done |
| J15 | `/notify add bob` shows online/offline status messages | `tests/chat-notify.spec.ts` | P0 | done |
| J16 | `/notify edit/list/remove` updates output and Address Book state | `tests/chat-notify.spec.ts` | P1 | done |
| J17 | `/umode +w` opts in to wallops; `-w` opts out | `tests/chat-wallops.spec.ts` | P1 | done |
| J18 | `/wallops msg` reaches opted-in users and enforces privileges | `tests/chat-wallops.spec.ts` | P1 | done |
| J19 | Notify List opens from the View menu and status-bar online buddy badge | `tests/chat-notify.spec.ts` | P0 | done |

## K - NickServ And ChanServ

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| K1 | `/nick`, `/ns register`, `/ns info` registration lifecycle | `tests/chat-nickserv.spec.ts` | P0 | done |
| K2 | `/ns identify wrong` fails; correct password succeeds | `tests/chat-nickserv.spec.ts` | P0 | done |
| K3 | `/ns drop wrong` fails; correct password deletes registration | `tests/chat-nickserv.spec.ts` | P1 | done |
| K4 | `/ns ghost` rejects wrong password and disconnects stale session with correct password | `tests/chat-nickserv.spec.ts` | P1 | done |
| K5 | `/nick registeredNick` opens password dialog and confirms only with correct password | `tests/chat-nickserv.spec.ts` | P0 | done |
| K6 | `/cs register` registers channel and `/cs info` shows founder | `tests/chat-chanserv.spec.ts` | P0 | done |
| K7 | `/cs aop add bob` auto-ops bob on rejoin | `tests/chat-chanserv.spec.ts` | P1 | done |
| K8 | `/cs vop add bob` auto-voices bob on rejoin | `tests/chat-chanserv.spec.ts` | P1 | done |
| K9 | `/cs sop/aop/vop list` displays access and `del` removes entry | `tests/chat-chanserv.spec.ts` | P1 | done |
| K10 | Non-founder cannot `/cs drop`; founder can drop | `tests/chat-chanserv.spec.ts` | P1 | done |
| K11 | `/admin ns info/resetpass/drop` changes NickServ state | `tests/chat-admin-services.spec.ts` | P1 | done |
| K12 | `/admin cs info/access/transfer/drop` changes ChanServ state | `tests/chat-admin-services.spec.ts` | P1 | done |

## L - Config, Scripting, Timers, Custom Menus

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| L1 | `/alias add`, invoke, list, remove | `tests/chat-alias.spec.ts` | P0 | done |
| L2 | Alias variables `$1`, `$nick`, `$chan`, `$$` expand correctly | `tests/chat-alias.spec.ts` | P1 | done |
| L3 | Alias recursion limit errors instead of freezing UI | `tests/chat-alias.spec.ts` | P1 | done |
| L4 | Alias expansion rejects command chaining characters | `tests/chat-alias.spec.ts` | P1 | done |
| L5 | Alias dialog add/edit/remove mirrors slash output | `tests/chat-alias-dialog.spec.ts` | P2 | done |
| L6 | `/perform add/list/move/remove/clear` updates output | `tests/chat-perform.spec.ts` | P0 | done |
| L7 | Perform entries execute on reconnect without focus steal | `tests/chat-perform.spec.ts` | P0 | done |
| L8 | Sensitive perform command display is masked and disallowed commands rejected | `tests/chat-perform.spec.ts` | P1 | done |
| L9 | `/autojoin add/list/remove/clear` and invalid channel errors | `tests/chat-autojoin.spec.ts` | P0 | done |
| L10 | Joining channel auto-adds to autojoin; part removes it | `tests/chat-autojoin.spec.ts` | P1 | done |
| L11 | Autojoin entries execute on reconnect without focus steal | `tests/chat-autojoin.spec.ts` | P0 | done |
| L12 | Autorespond `on_join` fires with variable expansion | `tests/chat-autorespond.spec.ts` | P1 | done |
| L13 | Autorespond `on_part` and `on_nick_change` fire | `tests/chat-autorespond.spec.ts` | P2 | done |
| L14 | Autorespond list/remove and invalid chaining behavior | `tests/chat-autorespond.spec.ts` | P1 | done |
| L15 | `/timer once` fires once then disappears from list | `tests/chat-timer.spec.ts` | P1 | done |
| L16 | `/timer stop` cancels; missing timer errors | `tests/chat-timer.spec.ts` | P1 | done |
| L17 | Repeating timer clamp notice appears and can be stopped | `tests/chat-timer.spec.ts` | P2 | done |
| L18 | `/popups` custom menu dialog and custom menu execution | `tests/chat-custom-menus.spec.ts` | P2 | done |

## M - Admin, Server Operations, Bots

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| M1 | Non-admin `/admin server info` shows permission error | `tests/chat-admin-extended.spec.ts` | P0 | done |
| M2 | Admin server info/get/settings displays server data | `tests/chat-admin-extended.spec.ts` | P1 | done |
| M3 | Admin server setting validation and restore in `finally` | `tests/chat-admin-extended.spec.ts` | P1 | done |
| M4 | `/admin user list --search`, info, banlist display rows | `tests/chat-admin-users.spec.ts` | P1 | done |
| M5 | `/admin user kick` force-disconnects target; target can reconnect | `tests/chat-admin-users.spec.ts` | P0 | done |
| M6 | `/admin user mute/unmute` blocks and restores target sends | `tests/chat-admin-users.spec.ts` | P0 | done |
| M7 | `/admin user rename` updates target session and nicklists | `tests/chat-admin-users.spec.ts` | P1 | done |
| M8 | `/admin user role` validates root restriction and promotion denial | `tests/chat-admin-users.spec.ts` | P2 | done |
| M9 | `/admin channel create/info/list/banlist/delete` over unique channels | `tests/chat-admin-channels.spec.ts` | P1 | done |
| M10 | `/admin channel purge #room --from bob` removes bob's visible history only | `tests/chat-admin-channels.spec.ts` | P2 | done |
| M11 | Admin diagnostics render without crashing | `tests/chat-admin-diagnostics.spec.ts` | P2 | done |
| M12 | `/admin nuke` without confirm shows destructive confirmation/help only | `tests/chat-admin-nuke.spec.ts` | P2 | done |
| M13 | `/admin nuke --confirm` in disposable isolated E2E profile | `tests/chat-admin-nuke.spec.ts` | P2 | block |
| M14 | Non-admin `/bot` shows list; admin `/bot` opens management dialog | `tests/chat-bots.spec.ts` | P1 | done |
| M15 | Admin creates bot, joins unique channel, sees bot in nicklist | `tests/chat-bots.spec.ts` | P1 | done |
| M16 | Bot custom command add/list/invoke/delete works | `tests/chat-bots.spec.ts` | P1 | done |
| M17 | Bot enable/disable/destroy changes response behavior and cleans up | `tests/chat-bots.spec.ts` | P2 | done |
| M18 | `/announce` broadcasts to connected users and bypasses ignore | `tests/chat-announce.spec.ts` | P1 | done |
| M19 | Regular user admin-only commands show permission errors | `tests/chat-admin-permissions.spec.ts` | P1 | done |
| M20 | Admin `/singleplayer` emits usable solo arcade link/card | `tests/chat-singleplayer.spec.ts` | P2 | done |

## N - P2P, File, Call, Game

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| N1 | Unidentified user P2P/call/sendfile/game shows identify-required errors | `tests/chat-p2p-errors.spec.ts` | P0 | done |
| N2 | Registered identified user cannot P2P/call/sendfile/game self | `tests/chat-p2p-errors.spec.ts` | P1 | done |
| N3 | Target not registered shows not-registered error | `tests/chat-p2p-errors.spec.ts` | P1 | done |
| N4 | `/p2p bob` creates PM invite cards and both users can open lobby | `tests/chat-p2p-invite.spec.ts` | P1 | done |
| N5 | `/call bob` creates audio-call lobby/session with mocked permissions | `tests/chat-p2p-call.spec.ts` | P2 | done |
| N6 | `/sendfile bob` creates file-transfer session and upload accepts temp file | `tests/chat-p2p-file.spec.ts` | P2 | done |
| N7 | `/game bob` creates invite/lobby and starts shared game shell | `tests/chat-p2p-game.spec.ts` | P2 | done |
| N8 | P2P decline clears consent from both lobbies without chat focus steal | `tests/chat-p2p-invite.spec.ts` | P2 | done |

## O - Chat UI Micro-Journeys

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| O1 | Emoji picker opens, searches, inserts emoji, closes | `tests/chat-emoji.spec.ts` | P1 | done |
| O2 | Formatting buttons insert expected IRC control codes | `tests/chat-formatting-advanced.spec.ts` | P1 | done |
| O3 | Strip formatting toggle affects rendered formatted text | `tests/chat-formatting-advanced.spec.ts` | P2 | done |
| O4 | Multi-line paste confirmation send/cancel paths | `tests/chat-paste.spec.ts` | P1 | done |
| O5 | Large paste flood warning and sequential send order | `tests/chat-paste.spec.ts` | P2 | done |
| O6 | Search opens, highlights, navigates, invalid regex errors | `tests/chat-search.spec.ts` | P1 | done |
| O7 | Search options persist while search stays open | `tests/chat-search.spec.ts` | P2 | done |
| O8 | Reply context menu creates reply bar; send includes reply block; dismiss cancels | `tests/chat-message-actions.spec.ts` | P1 | done |
| O9 | Edit last own message with ArrowUp; submit edit updates message | `tests/chat-message-actions.spec.ts` | P1 | done |
| O10 | Delete own message marks deleted placeholder for both users | `tests/chat-message-actions.spec.ts` | P1 | done |
| O11 | Retry failed pending message appears when send rejected by mode/mute | `tests/chat-message-actions.spec.ts` | P2 | done |
| O12 | Nicklist context menu query/whois/ignore/op/voice actions | `tests/chat-context-menus.spec.ts` | P1 | done |
| O13 | Conversation context menu mark-read, mute, copy, leave/settings | `tests/chat-context-menus.spec.ts` | P2 | done |
| O14 | Hover card shows registered/away/idle/shared channel info | `tests/chat-hover-card.spec.ts` | P2 | done |
| O15 | URL catcher records links, search filters, preview updates | `tests/chat-url-catcher.spec.ts` | P2 | done |
| O16 | Address Book add/edit/remove contact, notify, color, control entries | `tests/chat-address-book.spec.ts` | P2 | done |
| O17 | Custom nick color applies to chat nick rendering | `tests/chat-address-book.spec.ts` | P2 | done |
| O18 | Keyboard shortcuts switch windows/open dialogs without accidental submit | `tests/chat-keyboard.spec.ts` | P1 | done |
| O19 | Status bar mute toggle affects client state and survives rerender | `tests/chat-statusbar.spec.ts` | P2 | done |

## P - Persistence, Reconnect, History, No-Focus-Steal

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| P1 | Registered PM partners restore on reconnect ordered by recency | `tests/chat-persistence.spec.ts` | P0 | done |
| P2 | Guest PM partners do not persist after reconnect | `tests/chat-persistence.spec.ts` | P1 | done |
| P3 | Incoming PM marks indicator without switching active tab | `tests/chat-no-focus-steal.spec.ts` | P0 | done |
| P4 | Incoming channel message marks unread without switching active tab | `tests/chat-no-focus-steal.spec.ts` | P0 | done |
| P5 | Perform/autojoin on reconnect create tabs without focus steal | `tests/chat-perform.spec.ts`, `tests/chat-autojoin.spec.ts` | P0 | done |
| P6 | Registered aliases/perform/autojoin/ignore/notify/colors persist | `tests/chat-settings-persistence.spec.ts` | P1 | done |
| P7 | Guest aliases/perform/autojoin/ignore/notify are session-only | `tests/chat-settings-persistence.spec.ts` | P2 | done |
| P8 | Browser reload keeps chat session and reconnects LiveView cleanly | `tests/chat-reconnect.spec.ts` | P1 | done |
| P9 | Reconnect UI disables input and preserves typed draft | `tests/chat-reconnect.spec.ts` | P2 | done |
| P10 | Scroll loader loads older channel/PM history without duplicates | `tests/chat-history-pagination.spec.ts` | P2 | done |
| P11 | `/whois` idle increases and resets after command/message | `tests/chat-idle.spec.ts` | P2 | done |
| P12 | PM typing indicator appears and clears after timeout or send | `tests/chat-typing-indicator.spec.ts` | P1 | done |

## Backlog Q - Catalog, Help, Parser, And Command Surface

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| Q1 | `/help` output includes every registered command and no stale command names | `tests/chat-command-registry.spec.ts` | P1 | done |
| Q2 | `/help <command>` renders detailed inline help for every registered command | `tests/chat-command-registry.spec.ts` | P1 | done |
| Q3 | Inline command help deep links render full Help Topics pages | `tests/chat-command-registry.spec.ts` | P1 | done |
| Q4 | Command autocomplete exposes every registered command grouped by category | `tests/chat-command-registry.spec.ts` | P2 | done |
| Q5 | Slash commands are case-insensitive for channel, PM, and service handlers | `tests/chat-command-parser.spec.ts` | P1 | done |
| Q6 | Leading/trailing whitespace around commands and args keeps dispatch behavior | `tests/chat-command-parser.spec.ts` | P1 | done |
| Q7 | Bare slash inputs show helpful errors without changing active tab state | `tests/chat-command-parser.spec.ts` | P2 | done |
| Q8 | Free-text command args preserve punctuation, repeated spaces, unicode, and IRC formatting | `tests/chat-command-parser.spec.ts` | P2 | done |
| Q9 | Sensitive command names/args are omitted from local command history | `tests/chat-command-history-sensitive.spec.ts` | P1 | done |
| Q10 | Recent-command autocomplete ranks safe commands without leaking sensitive commands | `tests/chat-command-history-sensitive.spec.ts` | P2 | done |

## Backlog R/Y - Security, Safety, And Rendering Additions

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| R1 | Chat message HTML/script content renders escaped and never executes | `tests/chat-security-escaping.spec.ts` | P0 | done |
| R2 | Topic, welcome, MOTD, away, bio, alias expansion, bot response, and autorespond output escape HTML/script content | `tests/chat-security-escaping.spec.ts` | P0 | done |
| R3 | Unsafe URL schemes such as `javascript:` and `data:` are not rendered as clickable links | `tests/chat-security-links.spec.ts` | P0 | done |
| R4 | Long unbroken words and very long URLs stay inside the desktop chat layout | `tests/chat-message-rendering.spec.ts` | P2 | done |
| R5 | Unicode, emoji, combining marks, and non-Latin text survive send, reload, edit, search, and visible copy flows | `tests/chat-unicode.spec.ts` | P2 | done |
| R6 | Message input enforces the 1000-character limit for typing, paste, Send button, and Enter submit | `tests/chat-input-limits.spec.ts` | P1 | done |
| R7 | Paste confirmation disables Send above max line count and Cancel restores input focus | `tests/chat-paste-limits.spec.ts` | P1 | done |
| R8 | Flood Protection settings affect rapid paste behavior and Reset Defaults restores effective defaults | `tests/chat-flood-protection.spec.ts` | P1 | done |
| R9 | P2P command rate-limit and failed send errors leave no stale pending messages or disabled input | `tests/chat-rate-limit.spec.ts` | P2 | done |
| R10 | Empty message edit opens delete confirmation and cancel restores normal input state | `tests/chat-message-edit-delete-edges.spec.ts` | P1 | done |
| Y10 | Reciprocal autorespond notice rules fire once and do not loop | `tests/chat-autorespond-loop.spec.ts` | P0 | done |

## Backlog S - Message Lifecycle Additions

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| S1 | Non-author cannot edit or delete another user's channel message | `tests/chat-message-permissions.spec.ts` | P0 | done |
| S2 | PM messages support reply, edit, delete, and deleted placeholders | `tests/chat-pm-message-actions.spec.ts` | P1 | done |
| S3 | Reply preview updates when the parent message is edited | `tests/chat-message-reply-edges.spec.ts` | P1 | done |
| S4 | Reply preview shows deleted state when the parent message is deleted | `tests/chat-message-reply-edges.spec.ts` | P1 | done |
| S5 | Reply parent link scrolls to and highlights a loaded parent message | `tests/chat-message-reply-edges.spec.ts` | P2 | done |
| S6 | Reply parent link reports clearly when the parent is only in older unloaded history | `tests/chat-message-reply-history.spec.ts` | P2 | done |
| S7 | Search history mode highlights matches that become available after scroll pagination | `tests/chat-search-history.spec.ts` | P2 | done |
| S8 | Search Next/Prev scrolls the active highlighted result into view and preserves active highlight | `tests/chat-search-navigation.spec.ts` | P2 | done |
| S9 | Search closes on channel, PM, and Status switches while preserving the last query for reopening | `tests/chat-search-window-state.spec.ts` | P2 | done |
| S10 | Failed pending message retry succeeds after removing the blocking channel mode | `tests/chat-message-retry.spec.ts` | P1 | done |
| S11 | Failed pending message can be deleted without leaving retry/orphan UI behind | `tests/chat-message-retry.spec.ts` | P2 | done |
| S12 | Message timestamps use detected browser timezone with the current default `dd/mm HH:MM` format | `tests/chat-timestamps.spec.ts` | P2 | done |

## Backlog T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| T1 | File/View/Tools/Help menu items open the same shell surfaces as keyboard equivalents where both exist | `tests/chat-menu-toolbar-parity.spec.ts` | P1 | done |
| T2 | Menus keep chat input focus and intentional dialog inputs own focus | `tests/chat-menu-focus.spec.ts` | P1 | done |
| T3 | About dialog opens from Help menu and app logo, closes cleanly, and restores chat input focus | `tests/chat-about-dialog.spec.ts` | P2 | done |
| T4 | View menu toggles conversations, nicklist, channel list, and search without losing active tab or unread state | `tests/chat-view-menu.spec.ts` | P1 | done |
| T5 | Tools menu opens Address Book, Highlights, URL Catcher, Channel Central, Perform, Sound, Flood Protection, Alias, Custom Menus, and Autorespond | `tests/chat-tools-menu.spec.ts` | P1 | done |
| T6 | Escape closes only the topmost dialog/menu layer and preserves underlying state | `tests/chat-dialog-keyboard.spec.ts` | P1 | done |
| T7 | Enter submits primary sub-dialog action and Escape/cancel paths discard drafts | `tests/chat-dialog-keyboard.spec.ts` | P2 | done |
| T8 | Tab focus stays inside major modal dialogs | `tests/chat-dialog-keyboard.spec.ts` | P2 | done |
| T9 | Window switch shortcuts skip Status and cycle channels/PMs in stable order | `tests/chat-window-shortcuts.spec.ts` | P1 | done |
| T10 | Shortcut cheatsheet opens from Help menu and shortcut, lists active bindings, and does not submit draft input | `tests/chat-cheatsheet.spec.ts` | P2 | done |
| T11 | Dialog title close, cancel buttons, and backdrop paths close major dialogs consistently | `tests/chat-dialog-close.spec.ts` | P2 | done |
| T12 | Reconnect state disables destructive shell menus while keeping Help accessible and preserving draft input | `tests/chat-reconnect-shell.spec.ts` | P1 | done |

## Backlog U - Dialog CRUD And Settings Depth

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| U1 | Highlight dialog adds, edits, removes a word/color and matching inbound messages render highlighted | `tests/chat-highlights.spec.ts` | P1 | done |
| U2 | Highlight settings persist for registered users and remain session-only for guests after reload | `tests/chat-highlights-persistence.spec.ts` | P2 | done |
| U3 | Sound Settings OK/Apply/Cancel/Preview persists only intended settings | `tests/chat-sound-settings.spec.ts` | P2 | done |
| U4 | Sound mute/status-bar setting and Sound Settings preview stay in sync across rerenders/reconnect | `tests/chat-sound-settings.spec.ts` | P2 | done |
| U5 | Flood Protection save/reset/cancel paths update effective paste flood behavior only when intended | `tests/chat-flood-protection.spec.ts` | P1 | done |
| U6 | Perform dialog edit/move/toggle-enabled paths mirror slash command behavior and reconnect execution | `tests/chat-perform-dialog.spec.ts` | P1 | done |
| U7 | Autojoin dialog add/edit/remove paths mirror slash command behavior and reconnect execution | `tests/chat-perform-dialog.spec.ts` | P1 | done |
| U8 | Autorespond dialog add/edit/toggle/delete validates fields and mirrors slash list output | `tests/chat-autorespond-dialog.spec.ts` | P1 | done |
| U9 | Custom Menus dialog validates duplicate labels, empty command, command chaining, and tab-specific menu types | `tests/chat-custom-menus-dialog.spec.ts` | P1 | done |
| U10 | Alias dialog validates duplicate aliases, empty expansion, recursion warning, and cancel/discard behavior | `tests/chat-alias-dialog-edges.spec.ts` | P1 | done |
| U11 | Notify List dialog auto-WHOIS and auto-add-PM settings affect later online/PM behavior | `tests/chat-notify-settings.spec.ts` | P1 | done |
| U12 | Address Book contact notes surface in hover card and whois output | `tests/chat-address-book-contacts.spec.ts` | P2 | done |
| U13 | Address Book nick color edit/delete immediately updates existing chat rows and future rows | `tests/chat-address-book-colors.spec.ts` | P2 | done |
| U14 | Control-list entries from Address Book match `/ignore` filtering behavior by type | `tests/chat-address-book-control.spec.ts` | P1 | done |
| U15 | Channel Central ban exception and invite exception add/remove flows affect join/ban behavior | `tests/chat-channel-central-exceptions.spec.ts` | P1 | done |
| U16 | Channel Central topic/mode edits stay in sync with slash command output after dialog close/reopen | `tests/chat-channel-central-sync.spec.ts` | P2 | done |

## Backlog V - Conversations, Tabs, Unread, Mute, And No-Focus-Steal Depth

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| V1 | Conversation sidebar section collapse/expand state survives rerenders and does not affect active tab | `tests/chat-conversations-sidebar.spec.ts` | P2 | done |
| V2 | Popular channel item joins/switches channel through browser UI without command typing | `tests/chat-conversations-sidebar.spec.ts` | P2 | done |
| V3 | Browse all channels from conversations sidebar opens the channel list and preserves the previous filter search | `tests/chat-conversations-sidebar.spec.ts` | P2 | done |
| V4 | Conversation context menu Mark Read clears unread indicators in the tab bar and conversations sidebar without switching focus | `tests/chat-conversation-unread.spec.ts` | P1 | done |
| V5 | Muted channels and PM conversations suppress sound/title flash while keeping visual unread indicators | `tests/chat-conversation-mute.spec.ts` | P1 | done |
| V6 | Copy name from the conversations context menu writes channel and PM targets to the clipboard | `tests/chat-conversation-context-clipboard.spec.ts` | P2 | done |
| V7 | Leave from the conversations context menu removes only the targeted inactive or active channel | `tests/chat-conversation-context-leave.spec.ts` | P1 | done |
| V8 | Channel Settings from the conversations context menu opens Channel Central for the targeted channel, not the active channel | `tests/chat-conversation-context-settings.spec.ts` | P1 | done |
| V9 | Closing unread channel and PM tabs clears stale unread state before the conversation is reopened | `tests/chat-tab-unread-edges.spec.ts` | P2 | done |
| V10 | Incoming PM and typing from an ignored user do not create unread indicators, typing UI, or title flash | `tests/chat-ignore-notifications.spec.ts` | P1 | done |
| V11 | Incoming invite from an ignored user does not open invite UI or steal focus | `tests/chat-ignore-notifications.spec.ts` | P1 | done |
| V12 | Multiple simultaneous PM unread counts update independently and reset only when each PM is opened | `tests/chat-pm-unread-multiple.spec.ts` | P1 | done |

## Backlog W - Presence, Identity, Nick Changes, Whois/Whowas

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| W1 | Remote nick change updates nicklist, existing PM tab labels, conversations sidebar PM item, future channel attribution, and future PM routing | `tests/chat-nick-change-realtime.spec.ts` | P1 | done |
| W2 | Nick collision shows an error without opening takeover flow and both users keep their channel membership | `tests/chat-nick-change-edges.spec.ts` | P1 | done |
| W3 | Registered nick password dialog Cancel keeps the old nickname, active channel, and usable chat input | `tests/chat-nickserv-dialog-edges.spec.ts` | P1 | done |
| W4 | NickServ register/drop changes are reflected by another user's `/whois Registered:` output without reconnect | `tests/chat-nickserv-whois-realtime.spec.ts` | P2 | done |
| W5 | `/whowas` for an online nick points users to `/whois` for current info instead of stale/offline lookup | `tests/chat-whowas-edges.spec.ts` | P2 | done |
| W6 | `/whowas` records expire after the configured retention period using the public admin setting | `tests/chat-whowas-edges.spec.ts` | P3 | done |
| W7 | Away auto-reply fires once per sender, resets after clearing away, and fires again after a new away message | `tests/chat-away-edges.spec.ts` | P1 | done |
| W8 | Away state immediately updates already-open channel nicklists and nicklist hover cards | `tests/chat-away-edges.spec.ts` | P2 | done |
| W9 | Notify auto-WHOIS emits online notification plus WHOIS registration detail when a watched user connects | `tests/chat-notify-settings.spec.ts` | P1 | done |
| W10 | Notify auto-add-PM adds first PM partners and persists the entry across registered-user reconnect | `tests/chat-notify-settings.spec.ts` | P1 | done |
| W11 | Passive tab switching, dialog open/close, and nicklist hover do not reset the observed idle timer | `tests/chat-idle-passive.spec.ts` | P2 | done |

## Backlog X - Channel Modes, Services, Permissions, Persistence Edges

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| X1 | Combined `+imntkl` channel modes survive Channel Central reopen and render in channel mode output | `tests/chat-channel-mode-matrix.spec.ts` | P1 | done |
| X2 | `/mode -k` and `/mode -l` clear Channel Central state and remove join restrictions | `tests/chat-channel-mode-matrix.spec.ts` | P1 | done |
| X3 | Wildcard ban masks block matching nicks, spare non-matching nicks, and allow rejoin after unban | `tests/chat-channel-ban-masks.spec.ts` | P2 | done |
| X4 | Matching ban exception hostmask overrides a wildcard ban, and removal restores the ban | `tests/chat-channel-ban-exceptions.spec.ts` | P1 | done |
| X5 | Matching invite exception hostmask allows invite-only join, and removal restores the restriction | `tests/chat-channel-invite-exceptions.spec.ts` | P1 | done |
| X6 | ChanServ registered channel access survives an empty channel and later founder/member rejoins | `tests/chat-chanserv-persistence.spec.ts` | P1 | done |
| X7 | Admin-transferred founder controls future ChanServ access after empty-channel rejoin | `tests/chat-chanserv-transfer-persistence.spec.ts` | P1 | done |
| X8 | SOP/AOP/VOP hierarchy controls automatic roles and access-management permissions | `tests/chat-chanserv-access-hierarchy.spec.ts` | P2 | done |
| X9 | Non-founder access mutations fail clearly and leave AOP/VOP state unchanged | `tests/chat-chanserv-permission-edges.spec.ts` | P1 | done |
| X10 | Admin channel delete removes open tabs and sends after deletion target the fallback channel | `tests/chat-admin-channel-destructive.spec.ts` | P1 | done |
| X11 | Admin channel purge removes visible history from already-open clients in realtime | `tests/chat-admin-channel-purge-realtime.spec.ts` | P2 | done |
| X12 | Server bans block reconnect and stale-session `/chat` access until admin unban restores login | `tests/chat-admin-ban-persistence.spec.ts` | P1 | done |
| X13 | Server mutes survive disconnect/reconnect and block sends until admin unmute restores sending | `tests/chat-admin-user-mute-persistence.spec.ts` | P1 | done |
| X14 | Server operator role appears after reconnect and grants operator-only command/menu access | `tests/chat-admin-role-persistence.spec.ts` | P2 | done |
| X15 | Admin audit log shows actor, target, action, and persisted reason for user ban entries | `tests/chat-admin-audit-log.spec.ts` | P1 | done |

## Backlog Y - Bot And Automation Edges

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| Y1 | Duplicate bot name/nickname creation attempts show field-specific errors and leave one bot list row | `tests/chat-bot-edges.spec.ts` | P1 | done |
| Y2 | Bot join/part across two channels updates each nicklist and `/bot info` channel count | `tests/chat-bot-channel-membership.spec.ts` | P1 | done |
| Y3 | Bot custom command variables and HTML-like special characters render as escaped text | `tests/chat-bot-custom-command-edges.spec.ts` | P1 | done |
| Y4 | Disabled bot state persists across Bot Management reopen and operator reconnect | `tests/chat-bot-persistence.spec.ts` | P2 | done |
| Y5 | Timers execute in the window active at creation even when another tab is active at fire time | `tests/chat-timer-window-context.spec.ts` | P1 | done |
| Y6 | Timer-fired `/query` opens a PM tab without switching away from the user's active tab | `tests/chat-timer-window-context.spec.ts` | P1 | done |
| Y7 | A timer whose creation window disappears reports an error, removes itself, and does not deliver to another tab | `tests/chat-timer-error-edges.spec.ts` | P2 | done |
| Y8 | Perform reconnect continues later entries after an earlier command reports an error | `tests/chat-perform-error-edges.spec.ts` | P1 | done |
| Y9 | Auto-join reconnect continues later channels after an earlier key-protected channel fails | `tests/chat-autojoin-error-edges.spec.ts` | P1 | done |
| Y11 | Alias commands expand inside timer, perform reconnect, and autorespond trigger flows | `tests/chat-automation-composition.spec.ts` | P2 | done |
| Y12 | Rapid nick change plus immediate channel message leaves no stale old nick tab, nicklist row, or attribution | `tests/chat-realtime-race-edges.spec.ts` | P2 | done |

## Backlog Z - P2P, File, Call, Game, And Arcade

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| Z1 | P2P, call, sendfile, and game commands reject registered targets who are currently offline | `tests/chat-p2p-availability.spec.ts` | P1 | done |
| Z2 | P2P invite ignores suppress target PM invite card, status notification, title flash, and message-only ignores still allow P2P invite delivery | `tests/chat-p2p-ignore.spec.ts` | P1 | done |
| Z3 | Closing a pending P2P invite notifies both chats, closes the sender lobby, and leaves stale invite links in an ended state | `tests/chat-p2p-expiry-cancel.spec.ts` | P2 | done |
| Z4 | Double-clicking P2P lobby Accept/Decline settles each action once without duplicate feedback or stale media state | `tests/chat-p2p-idempotency.spec.ts` | P1 | done |
| Z5 | Closing one open P2P lobby closes that popup, updates the peer lobby to ended state, and preserves both main chat tabs | `tests/chat-p2p-session-lifecycle.spec.ts` | P1 | done |
| Z6 | Denied microphone permission during `/call` shows actionable browser-permission guidance once and leaves PM chat usable | `tests/chat-p2p-call-permissions.spec.ts` | P1 | done |
| Z7 | Video-call mute and camera toggles update local controls and remote muted/camera-off indicators | `tests/chat-p2p-call-controls.spec.ts` | P2 | done |
| Z8 | File-transfer cancellation before receiver accept and after transfer start keeps both lobby panels visible with cancelled status | `tests/chat-p2p-file-cancel.spec.ts` | P1 | done |
| Z9 | File-transfer validation rejects blocked extensions and oversized files locally without creating a receiver offer | `tests/chat-p2p-file-limits.spec.ts` | P1 | done |
| Z10 | Game lobby leave and game-selection decline return both peers to the expected chat/lobby state without focus steal | `tests/chat-p2p-game-lifecycle.spec.ts` | P2 | done |
| Z11 | Hex Pong peer canvas paints and changes after start, proving shared state frames arrive beyond the lobby shell | `tests/chat-p2p-game-state.spec.ts` | P2 | done |
| Z12 | Solo arcade link opens the solo lobby, starts a playable external arcade window, returns to completed state, and leaves chat usable | `tests/chat-singleplayer-arcade.spec.ts` | P2 | done |

## Backlog AA - Reconnect, Multi-Context, Browser State, And Destructive Safety

| # | Flow | Spec file | Priority | Status |
|---|------|-----------|----------|--------|
| AA1 | Browser offline/online during an active PM preserves the PM draft, selected PM tab, existing unread PM badge, and typing indicator state | `tests/chat-reconnect-window-state.spec.ts` | P1 | done |
| AA2 | Browser offline/online with an unsaved Alias Editor draft preserves the dialog inputs and can save/run the alias after reconnect | `tests/chat-reconnect-dialog-state.spec.ts` | P2 | done |
| AA3 | Browser offline/online while a P2P lobby is open keeps both peers usable, preserves the invite session, and can transition into file transfer | `tests/chat-reconnect-p2p.spec.ts` | P2 | done |
| AA4 | Same-nick multi-context takeover redirects the source with unsaved draft/dialog state and leaves the new chat session usable without inherited local state | `tests/multi-tab-takeover-edges.spec.ts` | P1 | done |
| AA5 | Admin kick while a target browser is offline redirects on reconnect but allows later login, while admin ban blocks reconnect until unban | `tests/chat-admin-reconnect-edges.spec.ts` | P1 | done |
| AA6 | Closed registration blocks brand-new nick registration while existing registered users can still authenticate | `tests/admin-registration-closed-edges.spec.ts` | P1 | done |
| AA7 | Closed registration keeps same-nick takeover password-gated: wrong password does not displace the source, correct password performs normal takeover | `tests/admin-registration-closed-edges.spec.ts` | P2 | done |
| AA8 | Mute state stored in browser localStorage survives reload in the same context, suppresses sound preview, and does not leak to an isolated browser context | `tests/chat-local-storage-isolation.spec.ts` | P2 | done |

## Intentional Block

| # | Reason |
|---|--------|
| M13 | Confirmed `/admin nuke --confirm` is destructive. Keep only the non-confirming help/confirmation path in the shared E2E DB until a separate disposable E2E profile exists and still satisfies strict black-box constraints. |

## Page Objects

| Page Object | Status | Purpose |
|-------------|--------|---------|
| `pages/ConnectPage.ts` | done | Connect/register/auth flows and `uniqueNickname()` helper |
| `pages/ChatPage.ts` | active | Chat shell locators and shared high-level actions |
| `pages/P2PLobbyPage.ts` | active | P2P lobby, media, and file-transfer controls |
| `pages/GameSessionPage.ts` | active | Shared game lobby/canvas lifecycle checks |
| `pages/SoloArcadePage.ts` | active | Solo arcade lobby and external game-window lifecycle checks |

## Notable Product Fixes Found By E2E

- Send button was permanently disabled because the client character counter did not sync button state.
- `/help` text referenced F1 even though the full help system is menu-driven; copy was corrected.
- PM unread indicators now use the same PM key shape as conversations/tabs.
- Reconnect UI hook is mounted in the app shell and preserves typed drafts across disconnect/reconnect.
- History pagination for channel and PM windows now loads older rows in chronological order without duplicate messages.
- Reply preview updates now reinsert complete stream items and survive parent edit/delete.
- PM edit/delete events now preserve edited/deleted metadata in the rendered stream.
- Slash command parsing now trims leading whitespace, handles bare slash input, and preserves free-text argument spacing.
- Command autocomplete now groups registered commands by category and keeps the complete registry visible for an empty `/` trigger.
- Sensitive NickServ-style commands are excluded from browser history and recent-command ranking, including PM and automation variants.
- Message rows now allow the content grid item to shrink and wrap long unbroken text inside the chat layout.
- Cancelling a blocked multi-line paste now returns focus to the chat input.
- Reply parent navigation now resolves current LiveView message DOM ids and runs through the mounted message-list hook.
- Reply parent navigation now reports when an older parent is not currently loaded instead of silently doing nothing.
- Search highlights now reapply when paginated messages enter the DOM, and history-mode counts avoid double-counting loaded matches.
- Search result navigation now scrolls the containing message row and chat auto-scroll ignores internal highlight DOM mutations.
- Switching to Status now clears the visible search UI just like channel and PM switches.
- Failed temporary `pending_*` channel messages can now be removed from the local stream through Delete.
- Chat message timestamps now have a stable `data-testid` for timezone/format coverage.
- Channel List menu action now opens as well as closes the dialog.
- Search opened from View now focuses the search input.
- Chat input draft is synced to LiveView so unrelated rerenders do not clear typed text.
- Dialog focus and close paths now restore focus and keep server-side state in sync for title close, backdrop, Escape, and cancel flows.
- Help menu now exposes Shortcut Cheatsheet.
- Reconnect UI disables destructive File/View/Tools menus while keeping Help accessible.
- Highlight dialog color picker now accepts the shared color-picker `index` payload and stores the selected IRC color.
- Sound Settings now renders domain sound values with human labels, sends selected sounds to LiveView, and avoids sticky client-side select labels that outlive Cancel/reopen.
- Flood Protection dialog now unmounts when closed so canceled numeric edits do not survive in hidden browser input state.
- Perform dialog now wires Auto-Join tab selection/actions to `autojoin_*` events, and Auto-Join edit submits its disabled channel through a hidden field.
- Autorespond rules now reject empty commands, and the dialog table renders domain `trigger_event`/`channel_filter` fields instead of stale display keys.
- Custom Menus now reject empty/chained commands on add and edit, validate duplicate labels on edit, and expose stable row/form test ids.
- Alias entries now reject empty expansions, warn when an alias directly expands to itself, and expose stable row/form test ids.
- Address Book contact notes now surface in the hover card and `/whois` output for contextual lookup.
- `/clear` now also resets pagination state so scroll history loading cannot immediately repopulate a locally cleared window.
- Nick color changes now refresh the active chat stream so existing rows and future rows use the updated Address Book/context-menu color.
- Address Book Control and ignore-list persistence now include the `notices` ignore type, and `/ignore` help text documents it consistently.
- Conversations sidebar now renders the Popular Channels section before lazy-loading so users can expand it and join channels through the UI.
- Channel List close preserves the current filter search, and Browse All Channels from the conversations sidebar reapplies it to the refreshed channel list.
- Conversations sidebar context menus now support PM mute/copy actions, and PM mute suppresses sound/title flash while preserving unread indicators.
- Closing channel or PM tabs now clears unread/flash state so reopening the same conversation does not resurrect stale unread indicators.
- Remote nick changes now rename existing PM conversations and carry unread/mute/flash state to the new nick, preventing duplicate stale PM tabs.
- Nick-change remount now preserves the user's joined channels and active window by retargeting reconnect state from the old nick to the new nick.
- `/nick` now blocks active nickname collisions before confirmation, preventing accidental takeover/disconnect of the user already holding that nick.
- `/whowas` now detects online users and points to `/whois` for current information instead of returning a misleading missing-cache response.
- Whowas retention is now configurable through `/admin server set whowas_retention_seconds`, allowing safe verification of expiry behavior through normal admin UI.
- Away changes now broadcast to open channel views, refresh nicklist status, and keep nicklist hover cards in sync.
- Topic bar now receives the active channel mode string, making slash `/mode` changes visible in the channel header.
- Channel ban masks now match wildcard nick hostmasks for joins, knocks, and lower-rank ejections instead of exact nick only.
- Channel membership PubSub updates now ignore inactive-channel membership/away events for the visible nicklist, preventing cross-channel duplicates.
- Invite exceptions now use the same nick hostmask matcher as bans, so Channel Central Hostmask entries work for invite-only joins.
- `/cs register` now marks the live channel process as registered immediately, so later joins and mode persistence do not depend on process restart.
- Server bans now display a human-readable reconnect alert and prevent banned existing sessions from reopening `/chat`.
- `/admin log` now includes non-empty audit details such as ban reasons instead of hiding the persisted metadata.
- Bot creation from the management dialog now reports changeset field errors and converts the displayed cooldown seconds to milliseconds.
- Bot Management now renders enabled/disabled status from persisted bot state and lists capability names without crashing on capability maps.
- Timers now capture their creation window, target that window when firing, and restore the user's active tab so delayed commands cannot steal focus.
- P2P, call, sendfile, and game commands now reject registered targets who are offline before creating sessions or invite messages.
- P2P and game invite handling now respects invite-specific ignores for PM invite cards, status notifications, and session creation while leaving message-only ignores scoped to channel messages.
- P2P session close/expiry/failure notifications now originate from the session server and reach both participants' chat windows even if only one user opened the lobby.
- P2P media permission failures now show actionable browser-permission guidance once instead of duplicating the same error in the lobby chat.
- P2P video calls now render remote muted/camera-off indicators from the peer media state already broadcast by the session.
- P2P file-transfer cancellation now preserves file context and renders `Cancelled` instead of mislabeling the transfer as failed.
- P2P file-transfer validation errors now remain visible in the lobby and keep the file picker usable for a corrected file.
- Autojoin and reconnect rejoin now use background channel joins so no-focus-steal does not reload the active chat and wipe command output.
- Solo arcade sessions open external static game pages directly instead of embedding them in a local iframe blocked by the external frame-ancestors CSP.
- Same-nick takeover now waits for the previous LiveView to finish channel cleanup and skips duplicate terminate cleanup, preventing the old session from removing the new session's `#lobby` membership.
