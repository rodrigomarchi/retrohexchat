# E2E Test Catalog

Single source of truth for the browser-level Playwright suite.

**Last reviewed:** 2026-05-29

## Current Coverage

- **91 spec files** under `e2e/tests/`.
- **184 Playwright `test()` cases**.
- **Auth/lifecycle:** 17 mapped flows, all done.
- **Chat foundation:** 25 mapped flows, all done.
- **Chat extended coverage:** 147 mapped flows, 146 done, 1 intentionally blocked.
- **Open todo/investigate items:** none.
- **Blocked item:** M13, confirmed `/admin nuke --confirm`, until a disposable isolated E2E profile exists.

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

## Intentional Block

| # | Reason |
|---|--------|
| M13 | Confirmed `/admin nuke --confirm` is destructive. Keep only the non-confirming help/confirmation path in the shared E2E DB until a separate disposable E2E profile exists and still satisfies strict black-box constraints. |

## Page Objects

| Page Object | Status | Purpose |
|-------------|--------|---------|
| `pages/ConnectPage.ts` | done | Connect/register/auth flows and `uniqueNickname()` helper |
| `pages/ChatPage.ts` | active | Chat shell locators and shared high-level actions |

## Notable Product Fixes Found By E2E

- Send button was permanently disabled because the client character counter did not sync button state.
- `/help` text referenced F1 even though the full help system is menu-driven; copy was corrected.
- PM unread indicators now use the same PM key shape as conversations/tabs.
- Reconnect UI hook is mounted in the app shell and preserves typed drafts across disconnect/reconnect.
- History pagination for channel and PM windows now loads older rows in chronological order without duplicate messages.
