# E2E Test Catalog

Index of the browser-level Playwright suite.

**The specs are the source of truth.** Each `e2e/tests/*.spec.ts` documents its own
flows in an `@flow` header; the index below is generated from those headers by
`scripts/catalog.mjs`. Do not edit the generated block — edit the spec, then run
`make e2e.catalog`. `make ci` fails if the two disagree.

Everything outside the generated markers is hand-written and stays that way.

Planned-but-unwritten journeys live in [`TEST_BACKLOG.md`](TEST_BACKLOG.md), not
here: this file describes what the suite _does_, the backlog describes what it
does not. A flow only appears below once a spec actually covers it.

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

```bash
make e2e.catalog          # regenerate the index from the spec headers
make e2e.catalog.check    # verify it is current (also runs in make ci)
```

## Status Legend

- `done` - implemented and passing.
- `block` - intentionally not runnable until a safe black-box strategy exists.

## Intentional Block

| #   | Reason                                                                                                                                                                                                                      |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| M13 | Confirmed `/admin nuke --confirm` is destructive. Keep only the non-confirming help/confirmation path in the shared E2E DB until a separate disposable E2E profile exists and still satisfies strict black-box constraints. |

## Page Objects

| Page Object            | Status | Purpose                                                                  |
| ---------------------- | ------ | ------------------------------------------------------------------------ |
| `pages/ConnectPage.ts` | done   | Connect/register/auth flows and `uniqueNickname()` helper                |
| `pages/ChatPage.ts`    | active | Chat shell locators and shared high-level actions (incl. Games → Arcade) |

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
- Conversations sidebar now renders Popular Channels from the channel-directory read-model and keeps Browse All Channels in that same section.
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
- P2P audio-to-video upgrade responses now clear or promote local responder state so both peers can decline, retry, and accept upgrades coherently.
- P2P file-transfer cancellation now preserves file context and renders `Cancelled` instead of mislabeling the transfer as failed.
- P2P file-transfer validation errors now remain visible in the lobby and keep the file picker usable for a corrected file.
- Autojoin and reconnect rejoin now use background channel joins so no-focus-steal does not reload the active chat and wipe command output.
- Solo arcade sessions open external static game pages directly instead of embedding them in a local iframe blocked by the external frame-ancestors CSP.
- Same-nick takeover now waits for the previous LiveView to finish channel cleanup and skips duplicate terminate cleanup, preventing the old session from removing the new session's `#lobby` membership.

<!-- BEGIN GENERATED INDEX -->

## Coverage

- **262 spec files** under `e2e/tests/`.
- **662 Playwright `test()` cases**.
- **605 documented flows**, 604 done, 1 not done.
- **Every spec documents its own flows.**

## Flow index

Grouped by section. Every row comes from an `@flow` line in the spec itself.

### Auth And Lifecycle

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| A | Brand-new user registers a nickname in the sign-in window and lands in the chat | `tests/connect-flow.spec.ts` | done |
| B | Register a nick, disconnect, reconnect with correct password lands in the chat | `tests/returning-user.spec.ts` | done |
| C1 | Empty nickname keeps Connect disabled | `tests/nickname-validation.spec.ts` | done |
| C2 | Nickname longer than 16 chars shows inline error | `tests/nickname-validation.spec.ts` | done |
| C3 | Nickname containing a space shows inline error | `tests/nickname-validation.spec.ts` | done |
| C4 | Nickname starting with a digit shows inline error | `tests/nickname-validation.spec.ts` | done |
| D | Returning user wrong password shows error; retry with correct password works | `tests/returning-user.spec.ts` | done |
| E | Register step password mismatch shows inline error | `tests/register-validation.spec.ts` | done |
| F | Register step short password shows inline error | `tests/register-validation.spec.ts` | done |
| G | Back button returns from register/password to nickname | `tests/navigation.spec.ts` | done |
| H | The chat's old address `/chat` (and `?join=`) redirects permanently to the desktop: without a session that is the visitor's read-only chat, never a bounce to `/connect` | `tests/chat-guard.spec.ts` | done |
| I | `/connect?reason=expired` surfaces session expired message | `tests/disconnect-reason.spec.ts` | done |
| J | `/connect?reason=disconnected` surfaces session ended message | `tests/disconnect-reason.spec.ts` | done |
| K | A second browser context with the same nickname leaves the first one connected | `tests/multi-tab-takeover.spec.ts` | done |
| K2 | A game surface tab and the chat tab coexist in one browser context, and a second chat tab disturbs neither | `tests/surface-multi-tab.spec.ts` | done |
| K3 | A game address with no session lands on connect and reaches the game once the nickname is registered | `tests/surface-multi-tab.spec.ts` | done |
| K4 | A shared game link minted in one browser is followed from another with no session: the public card asks for a connect, and the connect lands back on the link | `tests/share-link-join.spec.ts` | done |
| K5 | A surface open beside the chat offers to go back to the tab that exists instead of opening a second chat, and says so when no tab answers | `tests/surface-cross-tab.spec.ts` | done |
| K6 | Copy on a surface's share bar puts the address on the clipboard with no chat tab involved | `tests/surface-cross-tab.spec.ts` | done |
| K7 | Opening the conference you are already in at its own address takes the seat rather than adding one: the other participant still sees a single row for you, and the room still counts two | `tests/surface-cross-tab.spec.ts` | done |
| K8 | With the conference open at its own address and not in the chat's window, the chat's status bar says the call is in another tab and is a way over to it | `tests/surface-cross-tab.spec.ts` | done |
| K9 | Opening a conference writes its card into the channel by itself, and that card counts up on its own when somebody joins the call, with no reload | `tests/share-link-join.spec.ts` | done |
| K10 | When the conference ends, the card in the channel becomes the record of it — when it stopped, how long it ran and how many people were in it — and offers no way on, with no reload | `tests/share-link-join.spec.ts` | done |
| K11 | A channel invite link shows a stranger the room, its topic and the last lines said there, and lands them inside the channel after connecting | `tests/share-link-join.spec.ts` | done |
| K12 | A fourth screen ends the one unused for longest and leaves the rest connected | `tests/multi-tab-takeover.spec.ts` | done |
| L | Logged-in user disconnects via UI and lands on `/connect` | `tests/logout.spec.ts` | done |
| M | Admin bans user with `/admin user ban` and victim is force-disconnected | `tests/admin-ban.spec.ts` | done |
| N | Admin closes registration; new user sees registration closed; spec restores open | `tests/admin-registration-closed.spec.ts` | done |

### Chat Foundation

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
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
| D5 | Close Conversation puts a private message away without marking it read (features P2) | `tests/chat-pm.spec.ts` | done |
| D6 | `/me` in a private chat sends an action both people see | `tests/chat-pm.spec.ts` | done |
| E1 | `/nick newname` confirms dialog and updates own nicklist entry | `tests/chat-identity.spec.ts` | done |
| E2 | `/away At lunch` and `/away` emit set/clear status messages | `tests/chat-identity.spec.ts` | done |
| F1 | `/help` lists available commands in active message list | `tests/chat-help.spec.ts` | done |
| F2 | Bold formatting button inserts IRC bold control code | `tests/chat-formatting.spec.ts` | done |
| F3 | Typing `@` shows nickname autocomplete dropdown | `tests/chat-autocomplete.spec.ts` | done |
| F4 | Typing `/jo` shows command autocomplete dropdown | `tests/chat-autocomplete.spec.ts` | done |

### UI Features Browser Regression

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| UI1 | Account dialog covers drop/re-register, profile bio, presence away state, wallops user mode, and Whois bio output (features 01, 10) | `tests/chat-ui-features-shell.spec.ts` | done |
| UI2 | Notify List opens from View; Bot Management is hidden from regular users and opens for admin users (features 02, 03) | `tests/chat-ui-features-shell.spec.ts` | done |
| UI3 | Edit menu preserves Clear/Copy/Find behavior through menu entry points (features 04) | `tests/chat-ui-features-shell.spec.ts` | done |
| UI4 | /me command and Send Notice composer send through the real chat input (features 07) | `tests/chat-ui-features-shell.spec.ts` | done |
| UI5 | Timers dialog opens from Tools and bare `/timer`, validates repeat intervals, saves once timers, and stops timers (features 08) | `tests/chat-ui-features-shell.spec.ts` | done |
| UI6 | User Lookup dialog and result cards cover Whois, Query, and Whowas flows (features 10) | `tests/chat-ui-features-shell.spec.ts` | done |
| UI7 | Channel nick context menu performs voice/devoice/op/deop/mute/unmute and blocks/restores target sends (features 05) | `tests/chat-ui-features-channel.spec.ts` | done |
| UI8 | Invite picker invites from a joined channel; Channel List knock request sends real knock flow (features 06) | `tests/chat-ui-features-channel.spec.ts` | done |
| UI9 | Channel Central applies welcome message, join throttle, and ownership transfer (features 09) | `tests/chat-ui-features-channel.spec.ts` | done |
| UI10 | Channel Central registration tab performs ChanServ register and AOP add/remove (features 11) | `tests/chat-ui-features-channel.spec.ts` | done |
| UI11 | Admin journeys across the split windows: server settings, MOTD, broadcast, audit log, TURN, danger preview, console (features 12) | `tests/chat-ui-features-admin.spec.ts` | done |
| UI11a | Admin Users window: info lookup and mute/unmute from File > Admin > Users (features 12) | `tests/chat-admin-users-window.spec.ts` | done |
| UI11b | Admin Users window opens from the File > Admin submenu and closes from its title bar (features 12) | `tests/chat-admin-users-window.spec.ts` | done |
| UI11c | Admin Channels window: create, inspect, and delete with typed confirmation (features 12) | `tests/chat-admin-channels-window.spec.ts` | done |
| UI11d | Admin Channels window opens from the File > Admin submenu and closes from its title bar (features 12) | `tests/chat-admin-channels-window.spec.ts` | done |
| UI11e | All nine admin windows open from File > Admin and close from their title bar (features 12) | `tests/chat-ui-features-admin.spec.ts` | done |

### G - Command Surface, Help, Autocomplete, Validation

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| G1 | Unknown command shows helpful unknown-command message (features P0) | `tests/chat-command-surface.spec.ts` | done |
| G2 | Missing args show usage for `/msg`, `/join`, `/mode`, `/ns`, `/admin` (features P0) | `tests/chat-command-surface.spec.ts` | done |
| G3 | `/help join` renders command-specific help (features P1) | `tests/chat-help-detail.spec.ts` | done |
| G4 | Help Topics menu opens full help system without submitting chat input (features P1) | `tests/chat-help-detail.spec.ts` | done |
| G5 | Syntax tooltip appears for `/mode` and tracks argument position (features P1) | `tests/chat-syntax-tooltip.spec.ts` | done |
| G6 | Subcommand autocomplete appears for `/ns`, `/cs`, `/perform`, `/autojoin` (features P1) | `tests/chat-autocomplete-advanced.spec.ts` | done |
| G7 | Selecting `/msg` autocomplete fills input and then nick autocomplete appears (features P1) | `tests/chat-autocomplete-advanced.spec.ts` | done |
| G8 | Autocomplete navigation never sends a chat message (features P1) | `tests/chat-autocomplete-advanced.spec.ts` | done |
| G9 | Command history recalls non-sensitive commands and skips sensitive NickServ commands (features P2) | `tests/chat-command-history.spec.ts` | done |
| G10 | Escape closes autocomplete, syntax tooltip, and history search in order (features P2) | `tests/chat-command-history.spec.ts` | done |

### H - Channels, Server Messages, Local Window State

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| H1 | `/join room` without `#` shows validation error (features P0) | `tests/chat-channel-errors.spec.ts` | done |
| H2 | Joining over channel limit shows max-channel error without losing tab (features P1) | `tests/chat-channel-errors.spec.ts` | done |
| H3 | `/leave #room bye` works as `/part`, removes tab, broadcasts reason (features P1) | `tests/chat-channel-lifecycle.spec.ts` | done |
| H4 | `/part #other` from `#lobby` removes only `#other` and does not steal focus (features P1) | `tests/chat-channel-lifecycle.spec.ts` | done |
| H5 | `/clear` clears only active window; other windows preserve history (features P1) | `tests/chat-channel-lifecycle.spec.ts` | done |
| H6 | `/topic` with no args prints current topic (features P1) | `tests/chat-topic-advanced.spec.ts` | done |
| H7 | Topic changes are visible in realtime to another user (features P1) | `tests/chat-topic-advanced.spec.ts` | done |
| H8 | `/list` opens channel list; search and the row press join (features P1) | `tests/chat-channel-list.spec.ts` | done |
| H8b | a registered channel everybody left stays listed, says when it was last used, and still joins | `tests/chat-channel-list.spec.ts` | done |
| H8c | a `+s` channel is missing from a non-member's list and from their /whois of a member | `tests/chat-channel-list.spec.ts` | done |
| H8d | a `+p` channel shows a non-member only a "Prv" row with its user count | `tests/chat-channel-list.spec.ts` | done |
| H9 | `/setwelcome` shows welcome once for a later joiner (features P1) | `tests/chat-channel-welcome.spec.ts` | done |
| H10 | `/clearwelcome` stops welcome for later joiners (features P1) | `tests/chat-channel-welcome.spec.ts` | done |
| H11 | `/setmotd`, `/motd`, new connect, and `/clearmotd` work (features P1) | `tests/chat-server-messages.spec.ts` | done |
| H12 | `/quit reason` disconnects self and broadcasts reason to channel (features P1) | `tests/chat-quit.spec.ts` | done |
| H13 | An operator schedules a channel event; the room gets a card in its own time zone, a second person says they are going, and the window lists it (features P1) | `tests/chat-channel-events.spec.ts` | done |

### I - Channel Modes, Privileges, Moderation

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| I1 | First user in unique channel is owner (features P0) | `tests/chat-channel-roles.spec.ts` | done |
| I2 | `/op`, `/deop`, `/voice`, `/devoice` update role in realtime (features P0) | `tests/chat-channel-roles.spec.ts` | done |
| I3 | Non-operator `/mode +m` or `/kick` gets permission error (features P0) | `tests/chat-channel-permissions.spec.ts` | done |
| I4 | Half-op can voice/devoice but cannot set protected modes (features P1) | `tests/chat-channel-modes.spec.ts` | done |
| I5 | Moderated channel blocks unvoiced user; voice restores; `-m` restores normal (features P0) | `tests/chat-channel-modes.spec.ts` | done |
| I6 | Invite-only channel blocks direct join; `/invite` allows join (features P0) | `tests/chat-channel-modes.spec.ts` | done |
| I7 | `/invite auto` toggles auto-join-on-invite without focus steal (features P2) | `tests/chat-channel-invite.spec.ts` | done |
| I8 | Keyed channel requires correct key (features P1) | `tests/chat-channel-modes.spec.ts` | done |
| I9 | Channel limit is enforced and removing it allows join (features P1) | `tests/chat-channel-modes.spec.ts` | done |
| I10 | Protected topic blocks non-op topic changes; `-t` restores (features P1) | `tests/chat-channel-modes.spec.ts` | done |
| I11 | `/ban bob` removes/blocks; `/unban bob` allows rejoin (features P0) | `tests/chat-channel-moderation.spec.ts` | done |
| I12 | `/kick bob reason` removes tab and broadcasts reason (features P0) | `tests/chat-channel-moderation.spec.ts` | done |
| I13 | `/mute bob` blocks channel messages; `/unmute bob` restores (features P0) | `tests/chat-channel-moderation.spec.ts` | done |
| I14 | `/slow 60` throttles rapid joins; `/slow 0` disables (features P2) | `tests/chat-channel-modes.spec.ts` | done |
| I15 | `/knock` notifies operators and repeated knock throttles (features P2) | `tests/chat-channel-knock.spec.ts` | done |
| I16 | `/mode +K` disables knock; `-K` allows it again (features P2) | `tests/chat-channel-knock.spec.ts` | done |
| I17 | `/transfer bob` changes ownership and privileges (features P1) | `tests/chat-channel-transfer.spec.ts` | done |
| I18 | Channel Central edits modes/key/limit consistently with slash output (features P2) | `tests/chat-channel-central.spec.ts` | done |
| I19 | `/mute bob 5s` blocks channel messages and lifts itself when the time is up | `tests/chat-channel-moderation.spec.ts` | done |
| I20 | `+c` strips colour and bold from every line sent to the channel; `-c` lets them through again | `tests/chat-channel-modes.spec.ts` | done |

### J - User Commands, Privacy, Presence

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| J1 | `/query bob` opens PM tab without sending a message (features P0) | `tests/chat-user-commands.spec.ts` | done |
| J2 | `/notice bob text` delivers notice without opening PM tab (features P0) | `tests/chat-notice.spec.ts` | done |
| J3 | `/notice #room text` delivers to channel and respects routing (features P1) | `tests/chat-notice.spec.ts` | done |
| J4 | `/notice_routing` reports current routing behavior (features P2) | `tests/chat-notice.spec.ts` | done |
| J5 | `/ignore bob all` hides channel messages, actions, PMs, notices, invites (features P0) | `tests/chat-ignore.spec.ts` | done |
| J6 | Type-specific ignore separates channel messages from PMs (features P1) | `tests/chat-ignore.spec.ts` | done |
| J7 | `/ignore` lists entries and `/unignore bob` restores visibility (features P0) | `tests/chat-ignore.spec.ts` | done |
| J8 | `/ignore <ownnick>` shows self-ignore error (features P1) | `tests/chat-ignore.spec.ts` | done |
| J9 | Timed ignore expiry emits status (features P2) | `tests/chat-ignore.spec.ts` | done |
| J10 | `/bio text` appears in another user's `/whois`; `/bio clear` removes it (features P1) | `tests/chat-whois.spec.ts` | done |
| J11 | `/whois bob` shows online, idle, registered, shared channels, away, bio (features P0) | `tests/chat-whois.spec.ts` | done |
| J12 | `/whois missingNick` shows not-online/not-found message (features P1) | `tests/chat-whois.spec.ts` | done |
| J13 | `/away msg` affects `/whois` and PM auto-reply behavior (features P1) | `tests/chat-away-advanced.spec.ts` | done |
| J14 | `/whowas bob` after disconnect shows last-seen data (features P1) | `tests/chat-whowas.spec.ts` | done |
| J15 | `/notify add bob` shows online/offline status messages (features P0) | `tests/chat-notify.spec.ts` | done |
| J16 | `/notify edit/list/remove` updates output and Address Book state (features P1) | `tests/chat-notify.spec.ts` | done |
| J17 | `/umode +w` opts in to wallops; `-w` opts out (features P1) | `tests/chat-wallops.spec.ts` | done |
| J18 | `/wallops msg` reaches opted-in users and enforces privileges (features P1) | `tests/chat-wallops.spec.ts` | done |
| J19 | Notify List opens from the View menu and status-bar online buddy badge (features P0) | `tests/chat-notify.spec.ts` | done |
| J20 | `/ignore bob actions` hides only actions; `notices` hides only notices | `tests/chat-ignore.spec.ts` | done |

### K - NickServ And ChanServ

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| K1 | `/nick`, `/ns register`, `/ns info` registration lifecycle (features P0) | `tests/chat-nickserv.spec.ts` | done |
| K2 | `/ns identify wrong` fails; correct password succeeds (features P0) | `tests/chat-nickserv.spec.ts` | done |
| K3 | `/ns drop wrong` fails; correct password deletes registration (features P1) | `tests/chat-nickserv.spec.ts` | done |
| K4 | `/ns ghost` rejects wrong password and disconnects stale session with correct password (features P1) | `tests/chat-nickserv.spec.ts` | done |
| K5 | `/nick registeredNick` opens password dialog and confirms only with correct password (features P0) | `tests/chat-nickserv.spec.ts` | done |
| K6 | `/cs register` registers channel and `/cs info` shows founder (features P0) | `tests/chat-chanserv.spec.ts` | done |
| K7 | `/cs aop add bob` auto-ops bob on rejoin (features P1) | `tests/chat-chanserv.spec.ts` | done |
| K8 | `/cs vop add bob` auto-voices bob on rejoin (features P1) | `tests/chat-chanserv.spec.ts` | done |
| K9 | `/cs sop/aop/vop list` displays access and `del` removes entry (features P1) | `tests/chat-chanserv.spec.ts` | done |
| K10 | Non-founder cannot `/cs drop`; founder can drop (features P1) | `tests/chat-chanserv.spec.ts` | done |
| K11 | `/admin ns info/resetpass/drop` changes NickServ state (features P1) | `tests/chat-admin-services.spec.ts` | done |
| K12 | `/admin cs info/access/transfer/drop` changes ChanServ state (features P1) | `tests/chat-admin-services.spec.ts` | done |
| K13 | The session form refuses a registered nickname sent without its password | `tests/chat-nickserv.spec.ts` | done |
| K14 | A nickname registered inside the chat stays identified across a reload of that session | `tests/chat-nickserv.spec.ts` | done |
| K15 | A member who is not an operator cannot `/cs register` the channel | `tests/chat-chanserv.spec.ts` | done |

### L - Config, Scripting, Timers, Custom Menus

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| L1 | `/alias add`, invoke, list, remove (features P0) | `tests/chat-alias.spec.ts` | done |
| L2 | Alias variables `$1`, `$nick`, `$chan`, `$$` expand correctly (features P1) | `tests/chat-alias.spec.ts` | done |
| L3 | Alias recursion limit errors instead of freezing UI (features P1) | `tests/chat-alias.spec.ts` | done |
| L4 | Alias expansion rejects command chaining characters (features P1) | `tests/chat-alias.spec.ts` | done |
| L5 | Alias dialog add/edit/remove mirrors slash output (features P2) | `tests/chat-alias-dialog.spec.ts` | done |
| L6 | `/perform add/list/move/remove/clear` updates output (features P0) | `tests/chat-perform.spec.ts` | done |
| L7 | Perform entries execute on reconnect without focus steal (features P0) | `tests/chat-perform.spec.ts` | done |
| L8 | Sensitive perform command display is masked and disallowed commands rejected (features P1) | `tests/chat-perform.spec.ts` | done |
| L9 | `/autojoin add/list/remove/clear` and invalid channel errors (features P0) | `tests/chat-autojoin.spec.ts` | done |
| L10 | Joining channel auto-adds to autojoin; part removes it (features P1) | `tests/chat-autojoin.spec.ts` | done |
| L11 | Autojoin entries execute on reconnect without focus steal (features P0) | `tests/chat-autojoin.spec.ts` | done |
| L12 | Autorespond `on_join` fires with variable expansion (features P1) | `tests/chat-autorespond.spec.ts` | done |
| L13 | Autorespond `on_part` and `on_nick_change` fire (features P2) | `tests/chat-autorespond.spec.ts` | done |
| L14 | Autorespond list/remove and invalid chaining behavior (features P1) | `tests/chat-autorespond.spec.ts` | done |
| L15 | `/timer once` fires once then disappears from list (features P1) | `tests/chat-timer.spec.ts` | done |
| L16 | `/timer stop` cancels; missing timer errors (features P1) | `tests/chat-timer.spec.ts` | done |
| L17 | Repeating timer clamp notice appears and can be stopped (features P2) | `tests/chat-timer.spec.ts` | done |
| L18 | `/popups` custom menu dialog and custom menu execution (features P2) | `tests/chat-custom-menus.spec.ts` | done |
| L18b | A tabbed window opened after the page loaded marks its first tab active and shows only that tab's panel | `tests/chat-custom-menus.spec.ts` | done |

### M - Admin, Server Operations, Bots

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| M1 | Non-admin `/admin server info` shows permission error (features P0) | `tests/chat-admin-extended.spec.ts` | done |
| M2 | Admin server info/get/settings displays server data (features P1) | `tests/chat-admin-extended.spec.ts` | done |
| M3 | Admin server setting validation and restore in `finally` (features P1) | `tests/chat-admin-extended.spec.ts` | done |
| M4 | `/admin user list --search`, info, banlist display rows (features P1) | `tests/chat-admin-users.spec.ts` | done |
| M5 | `/admin user kick` force-disconnects target; target can reconnect (features P0) | `tests/chat-admin-users.spec.ts` | done |
| M6 | `/admin user mute/unmute` blocks and restores target sends (features P0) | `tests/chat-admin-users.spec.ts` | done |
| M7 | `/admin user rename` updates target session and nicklists (features P1) | `tests/chat-admin-users.spec.ts` | done |
| M8 | `/admin user role` validates root restriction and promotion denial (features P2) | `tests/chat-admin-users.spec.ts` | done |
| M9 | `/admin channel create/info/list/banlist/delete` over unique channels (features P1) | `tests/chat-admin-channels.spec.ts` | done |
| M10 | `/admin channel purge #room --from bob` removes bob's visible history only (features P2) | `tests/chat-admin-channels.spec.ts` | done |
| M11 | Admin diagnostics render without crashing (features P2) | `tests/chat-admin-diagnostics.spec.ts` | done |
| M12 | `/admin nuke` without confirm shows destructive confirmation/help only (features P2) | `tests/chat-admin-nuke.spec.ts` | done |
| M13 | `/admin nuke --confirm` in disposable isolated E2E profile (features P2) | `tests/chat-admin-nuke.spec.ts` | block |
| M14 | Non-admin `/bot` is refused; admin `/bot` opens management dialog (features P1) | `tests/chat-bots.spec.ts` | done |
| M15 | Admin creates bot, joins unique channel, sees bot in nicklist (features P1) | `tests/chat-bots.spec.ts` | done |
| M16 | Bot custom command add/list/invoke/delete works (features P1) | `tests/chat-bots.spec.ts` | done |
| M17 | Bot enable/disable/destroy changes response behavior and cleans up (features P2) | `tests/chat-bots.spec.ts` | done |
| M18 | `/announce` broadcasts to connected users and bypasses ignore (features P1) | `tests/chat-announce.spec.ts` | done |
| M19 | Regular user admin-only commands show permission errors (features P1) | `tests/chat-admin-permissions.spec.ts` | done |
| M20 | The Arcade desktop icon opens the catalogue's cards under their engines, a game's sheet, then launches a WASM session through a noopener anchor at its own address | `tests/chat-arcade.spec.ts` | done |
| M21 | The production provisioning script runs end to end with every line accepted by the Admin Console | `tests/chat-admin-server-provision.spec.ts` | done |
| M22 | A newcomer joining a provisioned channel is greeted, and every advertised bot trigger answers | `tests/chat-admin-server-provision.spec.ts` | done |
| M23 | The Bot Management roster describes each bot, and selecting one drills into it | `tests/chat-bot-management-window.spec.ts` | done |
| M24 | System overview reports the node's identity, limits, and memory split | `tests/chat-system-windows.spec.ts` | done |
| M25 | The process listing filters and reorders against the live node | `tests/chat-system-windows.spec.ts` | done |
| M26 | Every runtime listing window opens and renders rows | `tests/chat-system-windows.spec.ts` | done |
| M27 | Host readings render, or say plainly that they cannot be read | `tests/chat-system-windows.spec.ts` | done |
| M28 | App info counts the channels and people actually present | `tests/chat-system-windows.spec.ts` | done |
| M29 | A database report runs and returns rows | `tests/chat-system-windows.spec.ts` | done |
| M30 | Metrics charts subscribe to a group and draw | `tests/chat-system-windows.spec.ts` | done |
| M31 | The live log streams only once asked | `tests/chat-system-windows.spec.ts` | done |
| M32 | The Oban health window groups contracts into tabs without horizontal overflow | `tests/chat-system-windows.spec.ts` | done |
| M33 | A runtime listing is resized, narrowed, and read row by row | `tests/chat-system-windows.spec.ts` | done |
| M34 | Open system windows are reachable from the taskbar | `tests/chat-system-windows.spec.ts` | done |
| M35 | The system windows coexist on one desktop | `tests/chat-system-windows.spec.ts` | done |
| M36 | The Games folder is the catalogue: a game icon opens the game's home over the chat, and its Play opens the game in a tab of its own (features P2) | `tests/chat-retro-games.spec.ts` | done |
| M37 | Start -> Games -> Retro Games opens the folder, and the Arcade is still a window (features P2) | `tests/chat-retro-games.spec.ts` | done |
| M38 | An admin gives a bot a language with /bot set or Bot Management, and its flag is drawn beside its nickname in the user list, the roster and its detail | `tests/chat-bot-management-window.spec.ts` | done |
| M39 | /bot set game_announce on gives a bot the Game capability, which Bot Management shows as a working capability that can be switched off | `tests/chat-bot-management-window.spec.ts` | done |
| M40 | Play on an arcade game's public page opens the Arcade on that game for a member, and asks a visitor to sign in from the Arcade icon | `tests/chat-arcade.spec.ts` | done |
| M41 | End pressed mid-match writes the match down as it stood: the score and "Ended early", with nobody named the winner (features P2) | `tests/chat-retro-games.spec.ts` | done |

### N - P2P, File, Call, Game

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| N1 | Channel group call opens for two registered users, shows the rich live channel badge/popover before the second user joins, exchanges live remote video both ways, names each remote tile after its participant, toggles mic/camera by asserting local `MediaStreamTrack.enabled` and remote participant media state, then removes a leaver (features P0) | `tests/chat-group-call.spec.ts` | done |
| N2 | Channel group call renegotiates with three registered media users: third participant joins, all clients receive two live remote videos each named after its participant, audio/video off-on state propagates to both observers, the third participant leaves, and remaining users keep media (features P0) | `tests/chat-group-call.spec.ts` | done |
| N3 | Channel group call pre-join persists muted media preferences after cancel/reopen, enters with microphone and camera disabled, mounts WebRTC with disabled media state, avoids local media tracks, and propagates disabled media to another participant (features P0) | `tests/chat-group-call.spec.ts` | done |
| N4 | Channel group call screen share uses browser display capture, replaces the published video, marks the remote tile as `source=screen`, and returns to camera when stopped (features P0) | `tests/chat-group-call.spec.ts` | done |
| N5 | Channel group call participant quality and active speaker indicators update the ignored video tile and LiveView participant row from a browser stats summary (features P0) | `tests/chat-group-call.spec.ts` | done |
| N6 | Channel group call failed media recovery shows a manual Retry action, requests a fresh media offer, keeps the conference window open, and preserves remote video (features P0) | `tests/chat-group-call.spec.ts` | done |
| N7 | Channel group call camera moderation lets a higher-ranked participant disable another user's camera, verifies the target browser video track is disabled, prevents local re-enable while blocked, and restores video after release (features P0) | `tests/chat-group-call.spec.ts` | done |
| N8 | Channel group call bulk moderation lets a higher-ranked participant mute microphones and turn off cameras for lower-ranked participants, verifies two target browsers are forced off, and confirms local attempts cannot bypass the server block (features P0) | `tests/chat-group-call.spec.ts` | done |
| N9 | Channel group call lock lets a moderator prevent lower-ranked users from joining, shows the locked state in the channel badge, and returns a locked-call error when a blocked user attempts to enter (features P0) | `tests/chat-group-call.spec.ts` | done |
| N10 | Channel group call request-to-speak lets a muted participant raise a hand, shows the moderator queue, lets the moderator allow speech, and verifies the target browser audio track is re-enabled (features P0) | `tests/chat-group-call.spec.ts` | done |
| N11 | Channel group call screen-share moderation lets a moderator stop a participant screen share, blocks immediate re-share on the target browser, and re-allows sharing afterward (features P0) | `tests/chat-group-call.spec.ts` | done |
| N12 | Channel group call mini mode shrinks the call to a small window and expanding restores its size, keeps the WebRTC surface mounted, preserves the same remote video element, exposes compact mic/camera/leave/expand controls, and verifies compact mute affects the real local track and remote participant state (features P0) | `tests/chat-group-call.spec.ts` | done |
| N13 | Channel group call can dock the statistics window beside the conference without stealing the call workflow, then maximize and restore the conference window while stats remains visible (features P1) | `tests/chat-group-call.spec.ts` | done |
| N14 | Channel group call advanced layouts switch to speaker view from active-speaker state, pin a participant, preserve the same remote video element across layout transitions, and expose compact grid density through the WebRTC surface (features P1) | `tests/chat-group-call.spec.ts` | done |
| N15 | Channel group call reactions send through the conference signaling channel, appear on the remote video tile and participant row, then expire from the tile overlay (features P1) | `tests/chat-group-call.spec.ts` | done |
| N16 | Channel group call pre-join handles denied microphone/camera permission with a visible warning, retry action, and a receive-only join path that mounts without local tracks (features P0) | `tests/chat-group-call.spec.ts` | done |
| N17 | Channel group call visual polish renders SVG reaction controls, captures desktop/mobile windows, and asserts the conference panel has no horizontal layout overflow (features P1) | `tests/chat-group-call.spec.ts` | done |
| N18 | Both peers enter the session by the card the invite writes into the private message | `tests/chat-p2p.spec.ts` | done |
| N19 | The auto-started call carries real video both ways; file transfer and the game share the same connection | `tests/chat-p2p.spec.ts` | done |
| N20 | pt-BR privacy relay setup connects both peers when TURN is available | `tests/chat-p2p.spec.ts` | done |
| N21 | Receive-only setup joins without local tracks and keeps remote media reachable | `tests/chat-p2p.spec.ts` | done |
| N22 | Audio-only setup publishes the microphone without a local camera and still receives remote video | `tests/chat-p2p.spec.ts` | done |
| N23 | Screen share marks the peer tile and the P2P stats video source | `tests/chat-p2p.spec.ts` | done |
| N24 | Failed recovery offers a retry without closing the P2P console | `tests/chat-p2p.spec.ts` | done |
| N25 | Mini mode, the stats section, and maximize keep the P2P video alive | `tests/chat-p2p.spec.ts` | done |
| N26 | Declining the invite tells the inviter and clears the pending state | `tests/chat-p2p.spec.ts` | done |
| N27 | The inviter cancels a pending invite from the room the card led to | `tests/chat-p2p.spec.ts` | done |
| N28 | A settled call keeps its picture and logs no signalling failure | `tests/chat-p2p-negotiation.spec.ts` | done |
| N29 | The picture arrives without renegotiating repeatedly | `tests/chat-p2p-negotiation.spec.ts` | done |
| N30 | Publishing a camera mid-call renegotiates without desync | `tests/chat-p2p-negotiation.spec.ts` | done |
| N31 | The picture comes back after the peer cycles their camera | `tests/chat-p2p-negotiation.spec.ts` | done |
| N32 | A relay-only call carries the picture end to end (skipped unless E2E_BASE_URL points at a deployment with TURN: `config/e2e.exs` sets `turn_listener_count: 0`) | `tests/chat-p2p-negotiation.spec.ts` | done |
| N33 | A call negotiated across intercontinental latency stays clean | `tests/chat-p2p-negotiation.spec.ts` | done |
| N34 | P2P stays actionable across a short LiveView outage and can end after reconnect | `tests/chat-call-fault-injection.spec.ts` | done |
| N35 | The P2P recovery-error End button opens confirm and terminates the session | `tests/chat-call-fault-injection.spec.ts` | done |
| N36 | A P2P answerer reloads while applying the initial offer and reconnects media | `tests/chat-call-fault-injection.spec.ts` | done |
| N37 | Simultaneous manual P2P retries stay coordinated and recover media | `tests/chat-call-fault-injection.spec.ts` | done |
| N38 | A conference stays actionable across a short LiveView outage and can be left after reconnect | `tests/chat-call-fault-injection.spec.ts` | done |
| N39 | A conference participant reloads while applying the SFU offer and rejoins media | `tests/chat-call-fault-injection.spec.ts` | done |
| N40 | Conference retry rejoins media when the participant PeerServer disappears | `tests/chat-call-fault-injection.spec.ts` | done |
| N41 | The conference recovery-error Leave button opens confirm and exits cleanly | `tests/chat-call-fault-injection.spec.ts` | done |
| N42 | The P2P session at /p2p/:token carries real video both ways, and file transfer and the game share the same connection | `tests/p2p-surface.spec.ts` | done |
| N43 | A second tab of the same session moves it, and the displaced tab takes it back | `tests/p2p-surface.spec.ts` | done |
| N44 | Closing the P2P tab does not end the session for the other side | `tests/p2p-surface.spec.ts` | done |
| N45 | A match link minted inside a game is followed from another browser, the seat is taken and the game runs over the P2P session | `tests/game-open-lobby.spec.ts` | done |
| N46 | A third person following the same match link is told the seat is taken, and it stays taken after the match ends | `tests/game-open-lobby.spec.ts` | done |
| N47 | The P2P summary popover in the PM toolbar opens above the strip, stays open while messages arrive, and closes on Escape | `tests/chat-p2p.spec.ts` | done |
| N48 | Choosing a call layout rearranges the call: side by side puts your camera beside the peer's, focus puts it in a corner of theirs | `tests/chat-p2p-call-moments.spec.ts` | done |
| N49 | A reaction sent from one side of the call appears on the other side's peer tile | `tests/chat-p2p-call-moments.spec.ts` | done |
| N50 | A second file picked while one is transferring waits in the queue, then is offered and completes by itself | `tests/chat-p2p-call-moments.spec.ts` | done |
| N51 | Leaving the call leaves only you: the peer is told you left instead of a frozen picture, and you can join again | `tests/chat-p2p-call-moments.spec.ts` | done |
| N52 | Channel group call per-participant moderation mutes one participant's microphone from their row's menu: their own browser's audio track goes off, their row is marked as muted by the moderator, their own toggle cannot turn it back on, and the moderator's "Allow participant microphone" restores it (features P0) | `tests/chat-group-call.spec.ts` | done |
| N53 | Removing a participant from the conference bans them from its channel: after the confirm, their row leaves the moderator's call, their own tab says they were removed and banned, and the channel's tab leaves their chat (features P0) | `tests/chat-group-call.spec.ts` | done |
| N54 | Focusing a participant from their row's menu puts their tile on the stage, the Settings section names the layout in use, and Auto layout lets the call arrange itself again (features P1) | `tests/chat-group-call.spec.ts` | done |
| N55 | The speaker picked before joining is the one the call plays through: the remote participant's audio is routed to that output device (features P1) | `tests/chat-group-call.spec.ts` | done |
| N56 | Six people in one channel conference each receive live video from the other five, and the Leave confirmation stays on top of the full grid: its button is what a click on it reaches, never a tile's nameplate (features P1) | `tests/chat-group-call.spec.ts` | done |
| N57 | A participant whose microphone carries sound lights up as the active speaker on another participant's screen, from the audio level measured in the call, with no simulated stats (features P0) | `tests/chat-group-call.spec.ts` | done |
| N58 | Push-to-talk: holding Ctrl+Shift+Z while muted turns the microphone on for as long as it is held, and letting go turns it off again (features P1) | `tests/chat-group-call.spec.ts` | done |
| N59 | The layout picked before joining offers every layout the call has, Speaker included, and the call opens in the one picked (features P1) | `tests/chat-group-call.spec.ts` | done |
| N60 | A call tab that loses the server says so: its status reads "Reconnecting to the server…" instead of the last state it heard, and its controls read as unavailable until the page is connected again, when the status and the controls come back by themselves (features P0) | `tests/chat-group-call.spec.ts` | done |
| N61 | Closing the call tab by accident is not leaving: reopening the call's address within the reconnection window puts you straight back in your seat — even after a moderator locked the room — with no antechamber, live video both ways, and one row for you on the other side (features P0) | `tests/chat-group-call.spec.ts` | done |
| N62 | While your conference runs in its own tab, the chat keeps up: coming back to it shows the newest lines of the channel, the call's card included, and a line you send scrolls into view (features P0) | `tests/chat-group-call.spec.ts` | done |
| N63 | Ending the conference for everyone ends it on every page and says so: the moderator's tab says they ended it, each other participant's tab names who did, and neither points back at a room that no longer exists (features P0) | `tests/chat-group-call.spec.ts` | done |
| N64 | A game's channel names its game under the topic, and Find a partner puts one seat's card in the channel; pressing it again points at the same card | `tests/game-channels.spec.ts` | done |
| N65 | A match between two people is written down once: Scoreboard, the room's announcing bot, says it in the game's channel with a card, and the same card lands in the two players' private conversation | `tests/game-channels.spec.ts` | done |
| N66 | A visitor reads a game's channel and its public page — ranking, latest matches, the channel's last lines — and pressing Find a partner opens the sign-in window | `tests/game-channels.spec.ts` | done |
| N67 | Somebody with no account watches the match being played, at its /watch address, drawn live from the host's relayed frames | `tests/game-open-lobby.spec.ts` | done |
| N68 | The players see how many are watching and the watch link to hand on; the match is offered to watch under its game channel's topic and on the game's page | `tests/game-open-lobby.spec.ts` | done |
| N69 | A full match's link, a playing nickname's menu and the game's page each lead to watching it; a member's Play on the game's page opens beside the desktop | `tests/game-open-lobby.spec.ts` | done |
| N70 | A result card's game name opens the game's home, whose You tab shows the player's own rating and latest matches | `tests/game-channels.spec.ts` | done |
| N71 | Whoever enters a game's channel is told by Scoreboard what the game is and where its weekly challenge stands, and !ranking is answered in the room from the game's own data | `tests/game-channels.spec.ts` | done |
| N72 | An arcade game's channel names its game under the topic and Pixel tells whoever arrives what the game is and its controls; Play opens the in-app Arcade on that game, and starting it is said by Pixel in the game's channel and in #arcade, each line with its card | `tests/arcade-channels.spec.ts` | done |
| N73 | An arcade game's page is its home: Play with the game's sheet, who played it lately, who plays it most, the reader's own plays and the channel's last lines | `tests/arcade-channels.spec.ts` | done |
| N74 | A visitor reads an arcade game's channel and its page; pressing Play opens the sign-in window, which returns to the same game | `tests/arcade-channels.spec.ts` | done |
| N75 | A game played alone (Hex Jungle): its home offers Play and nothing that needs somebody else — no partner, match link, invitation or Live tab; a run ended with End is written down, in the player's own record and among the best runs | `tests/game-solo-only.spec.ts` | done |
| N76 | In the channel of a game played alone, the strip offers Play without Find a partner, and /lfg says the game is played alone | `tests/game-solo-only.spec.ts` | done |
| N77 | Players who take their time in a match room — reading it, pressing Ready a while after arriving — still get the game when the host presses Start | `tests/game-open-lobby.spec.ts` | done |

### O - Chat UI Micro-Journeys

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| O1 | Emoji picker opens, searches, inserts emoji, closes (features P1) | `tests/chat-emoji.spec.ts` | done |
| O2 | Formatting buttons insert expected IRC control codes (features P1) | `tests/chat-formatting-advanced.spec.ts` | done |
| O3 | Strip formatting toggle affects rendered formatted text (features P2) | `tests/chat-formatting-advanced.spec.ts` | done |
| O4 | Multi-line paste confirmation send/cancel paths (features P1) | `tests/chat-paste.spec.ts` | done |
| O5 | Large paste flood warning and sequential send order (features P2) | `tests/chat-paste.spec.ts` | done |
| O6 | Search opens, highlights, navigates, invalid regex errors (features P1) | `tests/chat-search.spec.ts` | done |
| O7 | Search options persist while search stays open (features P2) | `tests/chat-search.spec.ts` | done |
| O8 | Reply context menu creates reply bar; send includes reply block; dismiss cancels (features P1) | `tests/chat-message-actions.spec.ts` | done |
| O9 | Edit last own message with ArrowUp; submit edit updates message (features P1) | `tests/chat-message-actions.spec.ts` | done |
| O10 | Delete own message marks deleted placeholder for both users (features P1) | `tests/chat-message-actions.spec.ts` | done |
| O11 | Retry failed pending message appears when send rejected by mode/mute (features P2) | `tests/chat-message-actions.spec.ts` | done |
| O12 | Nicklist context menu query/whois/ignore/op/voice actions (features P1) | `tests/chat-context-menus.spec.ts` | done |
| O13 | Conversation context menu mark-read, mute, copy, leave/settings (features P2) | `tests/chat-context-menus.spec.ts` | done |
| O14 | Hover card shows registered/away/idle/shared channel info (features P2) | `tests/chat-hover-card.spec.ts` | done |
| O15 | URL catcher records links, search filters, preview updates (features P2) | `tests/chat-url-catcher.spec.ts` | done |
| O16 | Address Book add/edit/remove contact, notify, color, control entries (features P2) | `tests/chat-address-book.spec.ts` | done |
| O17 | Custom nick color applies to chat nick rendering (features P2) | `tests/chat-address-book.spec.ts` | done |
| O18 | Keyboard shortcuts switch windows/open dialogs without accidental submit (features P1) | `tests/chat-keyboard.spec.ts` | done |
| O19 | Status bar mute toggle reflects mute state and survives rerender (features P2) | `tests/chat-statusbar.spec.ts` | done |
| O20 | An uploaded image renders as an inline thumbnail with an authorized download | `tests/chat-attachments.spec.ts` | done |
| O21 | Non-inline uploads render as safe file cards carrying path metadata | `tests/chat-attachments.spec.ts` | done |
| O22 | The nicklist renders a role-grouped IRC roster with status badges inside the platform sidebar | `tests/chat-nicklist-sidebar.spec.ts` | done |
| O23 | A BBC RSS item renders as a rich Markdown message in the desktop timeline | `tests/chat-rss-link-preview-visual.spec.ts` | done |
| O24 | The BBC RSS Markdown preview stays contained at phone width | `tests/chat-rss-link-preview-visual.spec.ts` | done |
| O25 | A pasted link grows the RSS card under the message, live and again after a reload | `tests/chat-link-card.spec.ts` | done |
| O26 | A card landing decorates its message in place, without reordering the conversation | `tests/chat-link-card.spec.ts` | done |
| O27 | A link in the first private message is captured and carded on both sides, once | `tests/chat-pm-link-card.spec.ts` | done |
| O28 | Reacting from the smiley on the line reaches the other person's screen, and clicking again removes it | `tests/chat-message-actions.spec.ts` | done |
| O29 | A link posted in a channel asks before opening a tab, naming the host and the whole address | `tests/chat-open-tab-confirm.spec.ts` | done |
| O30 | Cancelling the question opens nothing and leaves the conversation where it was | `tests/chat-open-tab-confirm.spec.ts` | done |
| O31 | Ctrl-clicking a link skips the question, because it already asked for a tab | `tests/chat-open-tab-confirm.spec.ts` | done |
| O32 | On a desktop the composer toolbar offers the microphone; a discarded take sends nothing, a finished one is sent alone — even with a file attached mid-take, which stays pending — and a file attached alone sends without text | `tests/chat-voice-messages.spec.ts` | done |
| O33 | The conversation is one Tab stop: arrows move between lines, Enter reacts, Shift+F10 opens the line's menu | `tests/chat-message-actions.spec.ts` | done |

### P - Persistence, Reconnect, History, No-Focus-Steal

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| P1 | Registered PM partners restore on reconnect ordered by recency (features P0) | `tests/chat-persistence.spec.ts` | done |
| P2 | Guest PM partners do not persist after reconnect (features P1) | `tests/chat-persistence.spec.ts` | done |
| P3 | Incoming PM marks indicator without switching active tab (features P0) | `tests/chat-no-focus-steal.spec.ts` | done |
| P4 | Incoming channel message marks unread without switching active tab (features P0) | `tests/chat-no-focus-steal.spec.ts` | done |
| P5 | Perform/autojoin on reconnect create tabs without focus steal (features P0) | `tests/chat-autojoin.spec.ts`, `tests/chat-perform.spec.ts` | done |
| P6 | Registered aliases/perform/autojoin/ignore/notify/colors persist (features P1) | `tests/chat-settings-persistence.spec.ts` | done |
| P7 | Guest aliases/perform/autojoin/ignore/notify are session-only (features P2) | `tests/chat-settings-persistence.spec.ts` | done |
| P8 | Browser reload keeps chat session and reconnects LiveView cleanly (features P1) | `tests/chat-reconnect.spec.ts` | done |
| P9 | Reconnect UI disables input and preserves typed draft (features P2) | `tests/chat-reconnect.spec.ts` | done |
| P10 | Scroll loader loads older channel/PM history without duplicates (features P2) | `tests/chat-history-pagination.spec.ts` | done |
| P10a | Scrolling back loads the older page, keeps the reader's place, and marks the beginning of history (features P1) | `tests/chat-infinite-scroll.spec.ts` | done |
| P10b | Pagination survives an ignored author filling the first page (`has_more` comes from the database) (features P1) | `tests/chat-infinite-scroll.spec.ts` | done |
| P10c | Trusted Terminals security log pages past the first page and closes with an end marker (features P2) | `tests/chat-trusted-terminals-pagination.spec.ts` | done |
| P10d | A 1000-message channel walks back to its first message: every window consecutive, no page fetched and dropped (features P1) | `tests/chat-scrollback-audit.spec.ts` | done |
| P11 | `/whois` idle increases and resets after command/message (features P2) | `tests/chat-idle.spec.ts` | done |
| P12 | PM typing indicator appears and clears after timeout or send (features P1) | `tests/chat-typing-indicator.spec.ts` | done |
| P13 | Newest channel messages stay visible until the reader intentionally scrolls up | `tests/chat-autoscroll.spec.ts` | done |
| P14 | Paging back through history leaves the reader where they were reading | `tests/chat-scrollback-position.spec.ts` | done |
| P15 | A message arriving while the reader is in history does not move them | `tests/chat-scrollback-position.spec.ts` | done |
| P16 | The view stays on the newest message while the reader is at the end | `tests/chat-scrollback-position.spec.ts` | done |
| P17 | A short outage shows the reconnect banner but not the intrusive modal (BA1) | `tests/chat-deploy-reconnect.spec.ts` | done |
| P18 | A cold remount does not replay the login sequence (BA2) | `tests/chat-deploy-reconnect.spec.ts` | done |
| P19 | A mention made while away is counted, listed in the Mentions window, and leads back to the line | `tests/chat-mentions.spec.ts` | done |
| P20 | Reading, leaving, receiving and coming back draws the new-messages rule in the right place | `tests/chat-unread-divider.spec.ts` | done |

### Q - Catalog, Help, Parser, And Command Surface

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| Q1 | `/help` output includes every registered command and no stale command names (features P1) | `tests/chat-command-registry.spec.ts` | done |
| Q2 | `/help <command>` renders detailed inline help for every registered command (features P1) | `tests/chat-command-registry.spec.ts` | done |
| Q3 | Inline command help deep links render full Help Topics pages (features P1) | `tests/chat-command-registry.spec.ts` | done |
| Q4 | Command autocomplete exposes every registered command grouped by category (features P2) | `tests/chat-command-registry.spec.ts` | done |
| Q5 | Slash commands are case-insensitive for channel, PM, and service handlers (features P1) | `tests/chat-command-parser.spec.ts` | done |
| Q6 | Leading/trailing whitespace around commands and args keeps dispatch behavior (features P1) | `tests/chat-command-parser.spec.ts` | done |
| Q7 | Bare slash inputs show helpful errors without changing active tab state (features P2) | `tests/chat-command-parser.spec.ts` | done |
| Q8 | Free-text command args preserve punctuation, repeated spaces, unicode, and IRC formatting (features P2) | `tests/chat-command-parser.spec.ts` | done |
| Q9 | Sensitive command names/args cannot be recalled from command history (features P1) | `tests/chat-command-history-sensitive.spec.ts` | done |
| Q10 | Recent-command autocomplete ranks safe commands without leaking sensitive commands (features P2) | `tests/chat-command-history-sensitive.spec.ts` | done |

### R/Y - Security, Safety, And Rendering Additions

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| R1 | Chat message HTML/script content renders escaped and never executes (features P0) | `tests/chat-security-escaping.spec.ts` | done |
| R2 | Topic, welcome, MOTD, away, bio, alias expansion, bot response, and autorespond output escape HTML/script content (features P0) | `tests/chat-security-escaping.spec.ts` | done |
| R3 | Unsafe URL schemes such as `javascript:` and `data:` are not rendered as clickable links (features P0) | `tests/chat-security-links.spec.ts` | done |
| R4 | Long unbroken words and very long URLs stay inside the desktop chat layout (features P2) | `tests/chat-message-rendering.spec.ts` | done |
| R5 | Unicode, emoji, combining marks, and non-Latin text survive send, reload, edit, search, and visible copy flows (features P2) | `tests/chat-unicode.spec.ts` | done |
| R6 | Message input enforces the 1000-character limit for typing, paste, Send button, and Enter submit (features P1) | `tests/chat-input-limits.spec.ts` | done |
| R7 | Paste confirmation disables Send above max line count and Cancel restores input focus (features P1) | `tests/chat-paste-limits.spec.ts` | done |
| R8 | Flood Protection settings affect rapid paste behavior and Reset Defaults restores effective defaults (features P1) | `tests/chat-flood-protection.spec.ts` | done |
| R9 | P2P command errors and failed sends leave no stale pending messages or disabled input (features P2) | `tests/chat-rate-limit.spec.ts` | done |
| R10 | Empty message edit opens delete confirmation and cancel restores normal input state (features P1) | `tests/chat-message-edit-delete-edges.spec.ts` | done |
| Y10 | Reciprocal autorespond notice rules fire once and do not loop (features P0) | `tests/chat-autorespond-loop.spec.ts` | done |

### S - Message Lifecycle Additions

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| S1 | Non-author cannot edit or delete another user's channel message (features P0) | `tests/chat-message-permissions.spec.ts` | done |
| S2 | PM messages support reply, edit, delete, and deleted placeholders (features P1) | `tests/chat-pm-message-actions.spec.ts` | done |
| S3 | Reply preview updates when the parent message is edited (features P1) | `tests/chat-message-reply-edges.spec.ts` | done |
| S4 | Reply preview shows deleted state when the parent message is deleted (features P1) | `tests/chat-message-reply-edges.spec.ts` | done |
| S5 | Reply parent link scrolls to and highlights a loaded parent message (features P2) | `tests/chat-message-reply-edges.spec.ts` | done |
| S6 | Reply parent link reports clearly when the parent is only in older unloaded history (features P2) | `tests/chat-message-reply-history.spec.ts` | done |
| S7 | Search history mode highlights matches that become available after scroll pagination (features P2) | `tests/chat-search-history.spec.ts` | done |
| S8 | Search Next/Prev scrolls the active highlighted result into view and preserves active highlight (features P2) | `tests/chat-search-navigation.spec.ts` | done |
| S9 | Search closes on channel, PM, and Status switches while preserving the last query for reopening (features P2) | `tests/chat-search-window-state.spec.ts` | done |
| S10 | Failed pending message retry succeeds after removing the blocking channel mode (features P1) | `tests/chat-message-retry.spec.ts` | done |
| S11 | Failed pending message can be deleted without leaving retry/orphan UI behind (features P2) | `tests/chat-message-retry.spec.ts` | done |
| S12 | Message timestamps use detected browser timezone with the current default `dd/mm HH:MM` format (features P2) | `tests/chat-timestamps.spec.ts` | done |
| S13 | Saving a message from its menu keeps it in the Saved Messages window, privately, with a note (features P1) | `tests/chat-saved-messages.spec.ts` | done |
| S14 | A message that was answered counts its replies and opens them together, while every reply stays in the room (features P1) | `tests/chat-threads.spec.ts` | done |
| S15 | An operator pins a line from its right-click menu; every member gets the Pinned button and the window lists it; Unpin there removes it | `tests/chat-pins.spec.ts` | done |
| S16 | `/pin <id>` and `/unpin <id>` do the same by number; a regular member is refused and has no Pin menu item | `tests/chat-pins.spec.ts` | done |

### T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| T1 | File/View/Tools/Help menu items open the same shell surfaces as keyboard equivalents where both exist (features P1) | `tests/chat-menu-toolbar-parity.spec.ts` | done |
| T2 | Menus keep chat input focus and intentional dialog inputs own focus (features P1) | `tests/chat-menu-focus.spec.ts` | done |
| T3 | About dialog opens from the Help menu and from Start, closes cleanly, and restores chat input focus (features P2) | `tests/chat-about-dialog.spec.ts` | done |
| T3b | The one About, opened from Start and from the About this site folder, is photographed | `tests/chat-about-dialog.spec.ts` | done |
| T4 | View menu toggles conversations, nicklist, channel list, and search without losing active tab or unread state (features P1) | `tests/chat-view-menu.spec.ts` | done |
| T5 | Tools menu opens Address Book, Highlights, URL Catcher, Channel Central, Perform, Sound, Flood Protection, Alias, Custom Menus, and Autorespond (features P1) | `tests/chat-tools-menu.spec.ts` | done |
| T6 | Escape closes only the topmost dialog/menu layer and preserves underlying state (features P1) | `tests/chat-dialog-keyboard.spec.ts` | done |
| T7 | Enter submits primary sub-dialog action and Escape/cancel paths discard drafts (features P2) | `tests/chat-dialog-keyboard.spec.ts` | done |
| T8 | Tab focus stays inside major modal dialogs (features P2) | `tests/chat-dialog-keyboard.spec.ts` | done |
| T9 | Window switch shortcuts skip Status and cycle channels/PMs in stable order (features P1) | `tests/chat-window-shortcuts.spec.ts` | done |
| T10 | Shortcut cheatsheet opens from Help menu and shortcut, lists active bindings, and does not submit draft input (features P2) | `tests/chat-cheatsheet.spec.ts` | done |
| T10b | A key is drawn the same way wherever it is named — the cheatsheet, a game's page, the help — and each is photographed | `tests/keycaps.spec.ts` | done |
| T11 | Dialog title close, cancel buttons, and backdrop paths close major dialogs consistently (features P2) | `tests/chat-dialog-close.spec.ts` | done |
| T12 | Reconnect state disables destructive shell menus while keeping Help accessible and preserving draft input (features P1) | `tests/chat-reconnect-shell.spec.ts` | done |
| T13 | Taskbar collapses a window family into one grouped entry, expands it, and drops back to a plain button (features P2) | `tests/chat-taskbar-groups.spec.ts` | done |
| T14 | Window title bar, taskbar button, and browser tab all name the active conversation `#channel[nick]` and follow tab switches (features P1) | `tests/chat-window-title.spec.ts` | done |
| T15 | Activity flash alternates over the conversation's name and restores it (features P1) | `tests/chat-window-title.spec.ts` | done |
| T16 | A private message titles the window `remote:mine` (features P2) | `tests/chat-window-title.spec.ts` | done |
| T17 | Every desktop hangs the wallpaper, and the file behind it really loads | `tests/desktop-wallpaper.spec.ts` | done |
| T18 | A phone-width viewport hangs the tall wallpaper instead of the wide one | `tests/desktop-wallpaper.spec.ts` | done |
| T19 | The wide wallpaper is preloaded in the head; the tall one deliberately is not | `tests/desktop-wallpaper.spec.ts` | done |
| T24 | The character made in a space stands beside the nickname in the chat, in the nicklist and on the hover card, and View ▸ Character Portraits turns them off (features P2) | `tests/chat-character-portraits.spec.ts` | done |
| T25 | The desktop's Tools folder lists what Start ▸ Tools lists — Saved Messages and Events included — and each opens its window (features P2) | `tests/desktop-tools-folder.spec.ts` | done |

### U - Dialog CRUD And Settings Depth

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| U1 | Highlight dialog adds, edits, removes a word/color and matching inbound messages render highlighted (features P1) | `tests/chat-highlights.spec.ts` | done |
| U2 | Highlight settings persist for registered users and remain session-only for guests after reload (features P2) | `tests/chat-highlights-persistence.spec.ts` | done |
| U3 | Sound Settings OK/Apply/Cancel/Preview persists only intended settings (features P2) | `tests/chat-sound-settings.spec.ts` | done |
| U4 | Sound mute/status-bar setting and Sound Settings preview stay in sync across rerenders/reconnect (features P2) | `tests/chat-sound-settings.spec.ts` | done |
| U5 | Flood Protection save/reset/cancel paths update effective paste flood behavior only when intended (features P1) | `tests/chat-flood-protection.spec.ts` | done |
| U6 | Perform window edit/move/toggle-enabled paths mirror slash command behavior and reconnect execution (features P1) | `tests/chat-perform-dialog.spec.ts` | done |
| U6b | Removing the last row keeps the keyboard inside the list instead of dropping it on the page | `tests/chat-perform-dialog.spec.ts` | done |
| U7 | Auto-Join window add/edit/remove paths mirror slash command behavior and reconnect execution (features P1) | `tests/chat-perform-dialog.spec.ts` | done |
| U8 | Autorespond dialog add/edit/toggle/delete validates fields and mirrors slash list output (features P1) | `tests/chat-autorespond-dialog.spec.ts` | done |
| U9 | Custom Menus dialog validates duplicate labels, empty command, command chaining, and tab-specific menu types (features P1) | `tests/chat-custom-menus-dialog.spec.ts` | done |
| U10 | Alias dialog validates duplicate aliases, empty expansion, recursion warning, and cancel/discard behavior (features P1) | `tests/chat-alias-dialog-edges.spec.ts` | done |
| U11 | Notify List dialog auto-WHOIS and auto-add-PM settings affect later online/PM behavior (features P1) | `tests/chat-notify-settings.spec.ts` | done |
| U12 | Address Book contact notes surface in hover card and whois output (features P2) | `tests/chat-address-book-contacts.spec.ts` | done |
| U13 | Address Book nick color edit/delete immediately updates existing chat rows and future rows (features P2) | `tests/chat-address-book-colors.spec.ts` | done |
| U14 | Control-list entries from Address Book match `/ignore` filtering behavior by type (features P1) | `tests/chat-address-book-control.spec.ts` | done |
| U15 | Channel Central ban exception and invite exception add/remove flows affect join/ban behavior (features P1) | `tests/chat-channel-central-exceptions.spec.ts` | done |
| U16 | Channel Central topic/mode edits stay in sync with slash command output after dialog close/reopen (features P2) | `tests/chat-channel-central-sync.spec.ts` | done |
| U17 | The Sounds window carries a Notify box per event and says what the browser answered about permission | `tests/chat-sound-settings.spec.ts` | done |
| U18 | The Sounds window offers one switch for notifications with the chat closed, and remembers it per browser | `tests/chat-sound-settings.spec.ts` | done |
| U19 | An administrator adds a server emoji from its window, and everybody writing :name: sees the picture while an unknown name stays text (features P2) | `tests/chat-server-emoji.spec.ts` | done |
| U20 | An administrator's desktop has the Admin and System folders, and the Admin folder lists the same windows as the Start menu's Admin group, Server Emoji included | `tests/chat-server-emoji.spec.ts` | done |

### V - Conversations, Tabs, Unread, Mute, And No-Focus-Steal Depth

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| V1 | Conversation sidebar section collapse/expand state survives rerenders and does not affect active tab (features P2) | `tests/chat-conversations-sidebar.spec.ts` | done |
| V2 | Popular channel item joins/switches channel through browser UI without command typing (features P2) | `tests/chat-conversations-sidebar.spec.ts` | done |
| V3 | Browse all channels from conversations sidebar opens the channel list and preserves the previous filter search (features P2) | `tests/chat-conversations-sidebar.spec.ts` | done |
| V4 | Conversation context menu Mark Read clears unread indicators in the tab bar and conversations sidebar without switching focus (features P1) | `tests/chat-conversation-unread.spec.ts` | done |
| V5 | Muted channels and PM conversations suppress sound/title flash while keeping visual unread indicators (features P1) | `tests/chat-conversation-mute.spec.ts` | done |
| V6 | Copy name from the conversations context menu writes channel and PM targets to the clipboard (features P2) | `tests/chat-conversation-context-clipboard.spec.ts` | done |
| V7 | Leave from the conversations context menu removes only the targeted inactive or active channel (features P1) | `tests/chat-conversation-context-leave.spec.ts` | done |
| V8 | Channel Settings from the conversations context menu opens Channel Central for the targeted channel, not the active channel (features P1) | `tests/chat-conversation-context-settings.spec.ts` | done |
| V9 | Closing unread channel and PM tabs clears stale unread state before the conversation is reopened (features P2) | `tests/chat-tab-unread-edges.spec.ts` | done |
| V10 | Incoming PM and typing from an ignored user do not create unread indicators, typing UI, or title flash (features P1) | `tests/chat-ignore-notifications.spec.ts` | done |
| V11 | Incoming invite from an ignored user does not open invite UI or steal focus (features P1) | `tests/chat-ignore-notifications.spec.ts` | done |
| V12 | Multiple simultaneous PM unread counts update independently and reset only when each PM is opened (features P1) | `tests/chat-pm-unread-multiple.spec.ts` | done |
| V13 | A visitor's sidebar suggests by subject: a Games section opening with #retro-games and the game rooms, empty ones included, then News with the rooms in the reader's language first, then the popular channels about anything else — each row carrying only its language flag, on a desktop and on a phone | `tests/chat-conversations-sidebar.spec.ts` | done |
| V14 | "See more…" under a featured section opens the Channel List narrowed to that subject, said by a strip above the rooms; the Category list switches the subject, the strip's X shows every room again, and a member and a visitor get the same — on a desktop and on a phone | `tests/chat-conversations-sidebar.spec.ts` | done |

### W - Presence, Identity, Nick Changes, Whois/Whowas

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| W1 | Remote nick change updates nicklist, existing PM tab labels, conversations sidebar PM item, future channel attribution, and future PM routing (features P1) | `tests/chat-nick-change-realtime.spec.ts` | done |
| W2 | Nick collision shows an error without opening takeover flow and both users keep their channel membership (features P1) | `tests/chat-nick-change-edges.spec.ts` | done |
| W3 | Registered nick password dialog Cancel keeps the old nickname, active channel, and usable chat input (features P1) | `tests/chat-nickserv-dialog-edges.spec.ts` | done |
| W4 | NickServ register/drop changes are reflected by another user's `/whois Registered:` output without reconnect (features P2) | `tests/chat-nickserv-whois-realtime.spec.ts` | done |
| W5 | `/whowas` for an online nick points users to `/whois` for current info instead of stale/offline lookup (features P2) | `tests/chat-whowas-edges.spec.ts` | done |
| W6 | `/whowas` records expire after the configured retention period using the public admin setting (features P3) | `tests/chat-whowas-edges.spec.ts` | done |
| W7 | Away auto-reply fires once per sender, resets after clearing away, and fires again after a new away message (features P1) | `tests/chat-away-edges.spec.ts` | done |
| W8 | Away state immediately updates already-open channel nicklists and nicklist hover cards (features P2) | `tests/chat-away-edges.spec.ts` | done |
| W9 | Notify auto-WHOIS emits online notification plus WHOIS registration detail when a watched user connects (features P1) | `tests/chat-notify-settings.spec.ts` | done |
| W10 | Notify auto-add-PM adds first PM partners and persists the entry across registered-user reconnect (features P1) | `tests/chat-notify-settings.spec.ts` | done |
| W11 | Passive tab switching, dialog open/close, and nicklist hover do not reset the observed idle timer (features P2) | `tests/chat-idle-passive.spec.ts` | done |
| W12 | A private conversation shows the same user list as a channel, listing both participants with the peer first (features P1) | `tests/chat-pm-user-list.spec.ts` | done |
| W13 | The peer's away state reaches a private conversation's user list with no channel in common (features P1) | `tests/chat-pm-user-list.spec.ts` | done |
| W14 | Another case of a registered nickname asks for its password and signs in shown as typed | `tests/nickname-casemap.spec.ts` | done |
| W15 | `/msg alice` reaches whoever is online as AlIcE, live | `tests/nickname-casemap.spec.ts` | done |
| W16 | `/op alice` finds the member AlIcE and the nick list keeps her spelling | `tests/nickname-casemap.spec.ts` | done |
| W17 | An identified user changes only the case of their nickname without a password | `tests/nickname-casemap.spec.ts` | done |
| W18 | Everybody's nickname carries the flag of the language they use the chat in: the user list, their lines, the hover card and a private conversation's row and tab, on a desktop and on a phone | `tests/chat-locale-flags.spec.ts` | done |
| W19 | A visitor watching without an account is listed under Visitors with the flag of the language the chat is shown to them in | `tests/chat-locale-flags.spec.ts` | done |
| W20 | The tools that list people draw the same flag: autocomplete, whois, the address book, notify list, nick colours, ignore list, URL catcher, mentions, pinned lines, Channel Central and a private conversation's typing line | `tests/chat-locale-flags.spec.ts` | done |
| W21 | A channel's founder sets the language it is spoken in with /cs language or Channel Central's Registration tab, and its flag is drawn beside the channel's name: the tab, the topic bar, the conversations list, the channel list and the public archive, on a desktop and on a phone | `tests/chat-locale-flags.spec.ts` | done |
| W22 | A channel's founder says what it is about with /cs category or Channel Central, and its coloured plaque is drawn ahead of the language flag beside the channel's name: the tab, the topic bar, the conversations list, the channel list and the public archive; the help lists every plaque | `tests/chat-locale-flags.spec.ts` | done |

### X - Channel Modes, Services, Permissions, Persistence Edges

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| X1 | Combined `+imntkl` channel modes survive Channel Central reopen and render in channel mode output (features P1) | `tests/chat-channel-mode-matrix.spec.ts` | done |
| X2 | `/mode -k` and `/mode -l` clear Channel Central state and remove join restrictions (features P1) | `tests/chat-channel-mode-matrix.spec.ts` | done |
| X3 | Wildcard ban masks block matching nicks, spare non-matching nicks, and allow rejoin after unban (features P2) | `tests/chat-channel-ban-masks.spec.ts` | done |
| X4 | Matching ban exception hostmask overrides a wildcard ban, and removal restores the ban (features P1) | `tests/chat-channel-ban-exceptions.spec.ts` | done |
| X5 | Matching invite exception hostmask allows invite-only join, and removal restores the restriction (features P1) | `tests/chat-channel-invite-exceptions.spec.ts` | done |
| X6 | ChanServ registered channel access survives an empty channel and later founder/member rejoins (features P1) | `tests/chat-chanserv-persistence.spec.ts` | done |
| X7 | Admin-transferred founder controls future ChanServ access after empty-channel rejoin (features P1) | `tests/chat-chanserv-transfer-persistence.spec.ts` | done |
| X8 | SOP/AOP/VOP hierarchy controls automatic roles and access-management permissions (features P2) | `tests/chat-chanserv-access-hierarchy.spec.ts` | done |
| X9 | Non-founder access mutations fail clearly and leave AOP/VOP state unchanged (features P1) | `tests/chat-chanserv-permission-edges.spec.ts` | done |
| X10 | Admin channel delete removes open tabs and sends after deletion target the fallback channel (features P1) | `tests/chat-admin-channel-destructive.spec.ts` | done |
| X11 | Admin channel purge removes visible history from already-open clients in realtime (features P2) | `tests/chat-admin-channel-purge-realtime.spec.ts` | done |
| X12 | Server bans block reconnect and stale-session desktop access until admin unban restores login (features P1) | `tests/chat-admin-ban-persistence.spec.ts` | done |
| X13 | Server mutes survive disconnect/reconnect and block sends until admin unmute restores sending (features P1) | `tests/chat-admin-user-mute-persistence.spec.ts` | done |
| X14 | Server operator role appears after reconnect and grants operator-only command/menu access (features P2) | `tests/chat-admin-role-persistence.spec.ts` | done |
| X15 | Admin audit log shows actor, target, action, and persisted reason for user ban entries (features P1) | `tests/chat-admin-audit-log.spec.ts` | done |
| X16 | a registered channel keeps its topic and modes while empty; an unregistered one forgets them | `tests/chat-chanserv-persistence.spec.ts` | done |

### Y - Bot And Automation Edges

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| Y1 | Duplicate bot name/nickname creation attempts show field-specific errors and leave one bot list row (features P1) | `tests/chat-bot-edges.spec.ts` | done |
| Y2 | Bot join/part across two channels updates each nicklist and `/bot info` channel count (features P1) | `tests/chat-bot-channel-membership.spec.ts` | done |
| Y3 | Bot custom command variables and HTML-like special characters render as escaped text (features P1) | `tests/chat-bot-custom-command-edges.spec.ts` | done |
| Y4 | Disabled bot state persists across Bot Management reopen and operator reconnect (features P2) | `tests/chat-bot-persistence.spec.ts` | done |
| Y5 | Timers execute in the window active at creation even when another tab is active at fire time (features P1) | `tests/chat-timer-window-context.spec.ts` | done |
| Y6 | Timer-fired `/query` opens a PM tab without switching away from the user's active tab (features P1) | `tests/chat-timer-window-context.spec.ts` | done |
| Y7 | A timer whose creation window disappears reports an error, removes itself, and does not deliver to another tab (features P2) | `tests/chat-timer-error-edges.spec.ts` | done |
| Y8 | Perform reconnect continues later entries after an earlier command reports an error (features P1) | `tests/chat-perform-error-edges.spec.ts` | done |
| Y9 | Auto-join reconnect continues later channels after an earlier key-protected channel fails (features P1) | `tests/chat-autojoin-error-edges.spec.ts` | done |
| Y11 | Alias commands expand inside timer, perform reconnect, and autorespond trigger flows (features P2) | `tests/chat-automation-composition.spec.ts` | done |
| Y12 | Rapid nick change plus immediate channel message leaves no stale old nick tab, nicklist row, or attribution (features P2) | `tests/chat-realtime-race-edges.spec.ts` | done |

### AA - Reconnect, Multi-Context, Browser State, And Destructive Safety

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| AA1 | Browser offline/online during an active PM preserves the PM draft, selected PM tab, existing unread PM badge, and typing indicator state (features P1) | `tests/chat-reconnect-window-state.spec.ts` | done |
| AA2 | Browser offline/online with an unsaved Alias Editor draft preserves the dialog inputs and can save/run the alias after reconnect (features P2) | `tests/chat-reconnect-dialog-state.spec.ts` | done |
| AA4 | A second context of the same nickname leaves the first one's unsaved draft and open dialog intact, and starts clean itself | `tests/multi-tab-takeover-edges.spec.ts` | done |
| AA5 | Admin kick while a target browser is offline redirects on reconnect but allows later login, while admin ban blocks reconnect until unban (features P1) | `tests/chat-admin-reconnect-edges.spec.ts` | done |
| AA6 | Closed registration blocks brand-new nick registration while existing registered users can still authenticate (features P1) | `tests/admin-registration-closed-edges.spec.ts` | done |
| AA7 | Closed registration keeps a nickname password-gated: a wrong password neither signs in nor displaces the session already using it, and the right one signs in beside it (features P2) | `tests/admin-registration-closed-edges.spec.ts` | done |
| AA8 | Mute survives reload for the account that set it, silences its sound preview, and does not leak to another session (features P2) | `tests/chat-mute-isolation.spec.ts` | done |

### MB - Mobile & Touch

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| MB1 | The phone desktop shows one fullscreen window at a time, switched via the taskbar | `tests/chat-mobile-desktop.spec.ts` | done |
| MB2 | Sidebars are reachable from the toolbar and the composer stays touch-sized | `tests/chat-mobile-desktop.spec.ts` | done |
| MB3 | The Start menu drills one level at a time | `tests/chat-mobile-desktop.spec.ts` | done |
| MB4 | The mobile taskbar collapses while the virtual keyboard is open | `tests/chat-mobile-desktop.spec.ts` | done |
| MB5 | Emoji opens from the mobile composer and inserts into a message | `tests/chat-mobile-message-flow.spec.ts` | done |
| MB6 | Long press drives reply and edit without a hardware keyboard | `tests/chat-mobile-message-flow.spec.ts` | done |
| MB7 | Message deletion confirms and cancels from the long-press menu | `tests/chat-mobile-message-flow.spec.ts` | done |
| MB8 | PM reply, edit, and delete work from touch message actions | `tests/chat-mobile-message-flow.spec.ts` | done |
| MB9 | Nicklist and conversation actions open by long press | `tests/chat-mobile-message-flow.spec.ts` | done |
| MB10 | Every tab and control fits the phone's tab strip without clipping | `tests/chat-mobile-desktop.spec.ts` | done |
| MB11 | A voice message is recorded from the microphone in the phone composer's single toolbar row and sent on its own, keeping the typed draft | `tests/chat-mobile-voice.spec.ts` | done |
| MB12 | A reaction is picked from the smiley every message shows, without hover | `tests/chat-mobile-message-flow.spec.ts` | done |

### SP - Virtual Spaces

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| SP1 | The door of a space is the character creator: pieces, each pictured on the character, colours and Surprise me change the preview, and entering wears exactly that character; one body is no tab | `tests/space-character-creator.spec.ts` | done |
| SP2 | A PM space mounts the End of Time scene with the character made at its door | `tests/space-end-of-time.spec.ts` | done |
| SP3 | The toggle enters and exits fullscreen on the space stage | `tests/space-fullscreen.spec.ts` | done |
| SP4 | Holding the virtual pad walks continuously, sliding off it onto the floor and lifting stops the walk, and the sword button attacks | `tests/space-virtual-pad.spec.ts` | done |
| SP5 | The creator's art is its catalog and its PNG pieces, each decodable, the catalog asked for at most once per screen, and no per-class sprite sheet ever | `tests/space-character-creator.spec.ts` | done |
| SP6 | A space is entered from the conversation and runs in a tab of its own | `tests/space-surface.spec.ts` | done |
| SP7 | A shared space link resolves to a card and then to the space itself | `tests/space-surface.spec.ts` | done |
| SP8 | Two people in the same space see each other | `tests/space-surface.spec.ts` | done |
| SP9 | Walking into an empty space writes its card into the conversation | `tests/space-surface.spec.ts` | done |
| SP10 | The creator opens on the character the nickname made last | `tests/space-surface.spec.ts` | done |
| SP11 | A line typed in a channel's space is said in the channel and pops up over the speaker for everyone in the space | `tests/space-talk.spec.ts` | done |
| SP12 | Enter puts the cursor in the space's say line, Esc gives the keyboard back to the map, and typing never walks | `tests/space-talk.spec.ts` | done |
| SP13 | A line typed in a private space goes to the other person's private chat | `tests/space-talk.spec.ts` | done |
| SP14 | Change character swaps the character inside a running space, for everyone, without leaving it | `tests/space-talk.spec.ts` | done |
| SP15 | Four sword hits knock a character out for everyone in the space, and a few seconds later they get back up on their own | `tests/space-gathering.spec.ts` | done |
| SP16 | A space's card in the channel shows the gathering live, counts the people in it, and becomes its record once everybody has left | `tests/space-gathering.spec.ts` | done |
| SP17 | E at the End of Time's gate asks before going: No stays on the island, Yes opens the channel's Construct with the same character, and its white gate leads back | `tests/space-construct.spec.ts` | done |
| SP18 | A piece placed from the Construct's palette is seen by everyone inside, can be dragged elsewhere and removed with a right-click, and the room is still built the next time it opens | `tests/space-construct.spec.ts` | done |
| SP19 | A chair placed in the Construct can be sat in with F | `tests/space-construct.spec.ts` | done |
| SP20 | On the touch pad, the hand button goes through the gate and sits down on a chair, as E and F do | `tests/space-construct.spec.ts` | done |
| SP21 | E switches a Construct lamp off and on and opens a door to walk through, and a second person inside sees both | `tests/space-construct-objects.spec.ts` | done |
| SP22 | E on a die rolls it: the face shows over the die and the roll is said in the channel's chat | `tests/space-construct-objects.spec.ts` | done |
| SP23 | Two teleporters placed in a Construct pair up, and E on one sends you to the other | `tests/space-construct-objects.spec.ts` | done |
| SP24 | Whoever put up a sign writes on it from its panel and the line floats over it; somebody else only reads it | `tests/space-construct-objects.spec.ts` | done |
| SP25 | A board shows the channel's topic, a screen the last picture posted, an arcade cabinet its games | `tests/space-construct-objects.spec.ts` | done |
| SP26 | Dragging across the floor from the Floor tab paints it, for everyone inside, and it is still painted the next time the room opens | `tests/space-construct-objects.spec.ts` | done |
| SP27 | A long table covers two tiles and turns with its footprint; chairs set around it are sat in, and a room of each theme (home, office, garden, gamer) is built from the palette's tabs | `tests/space-construct-library.spec.ts` | done |
| SP28 | The End of Time's own pieces — Morpheus, Neo, the old TV, the DeLorean, the Balrog — are placed in a Construct, animated and lit as on the island | `tests/space-construct-library.spec.ts` | done |
| SP29 | A sofa seats two people at once, one on each of its tiles | `tests/space-construct-library.spec.ts` | done |
| SP30 | On a phone, the space's screens — the character creator, the build palette, the pad, a piece's panel — wear the space's pixel-art kit and fit the screen | `tests/space-pixel-ui.spec.ts` | done |
| SP31 | A line said in Japanese or in Traditional Chinese is drawn over the speaker in the pixel font, that region's own glyphs fetched for it | `tests/space-pixel-ui.spec.ts` | done |
| SP32 | A character who takes a hit shows the kit's HP bar under its nameplate until it is whole again | `tests/space-pixel-ui.spec.ts` | done |
| SP33 | The Construct's pieces live in a Build menu; what is in hand shows on a card that turns, removes or drops it, so a touch screen can let go of a piece | `tests/space-pixel-ui.spec.ts` | done |
| SP34 | An arcade cabinet shelves its games as cartridges, each with its cover, under the cabinet's own icon | `tests/space-pixel-ui.spec.ts` | done |
| SP35 | The pad is held like a handheld (actions under the left thumb, the D-pad under the right) and the say bar carries the status on one line, on a desktop, a phone and a small phone in Russian | `tests/space-pixel-ui.spec.ts` | done |
| SP36 | A fair and a fantasy corner are built from their own tabs — tents, stalls, Leene's Bell, the Telepod, Nu, braziers and arches, some of them moving; the End of Time's lamppost and the Victorian lamp switch off, and the wingback chair is sat in | `tests/space-construct-library.spec.ts` | done |
| SP37 | The character made at the door is remembered for the nickname on reload, and another person in the channel sees it beside the nickname | `tests/space-character-creator.spec.ts` | done |
| SP38 | Q waves and Z starts and stops a dance, and the other person in the space sees both; a step ends the dance | `tests/space-emotes.spec.ts` | done |
| SP39 | On the on-screen pad, the hand button waves and the note button dances | `tests/space-emotes.spec.ts` | done |
| SP40 | The gate stands a few steps from where people arrive; the hand button stays dim until the gate is in reach, then lights up while the gate glows under a prompt | `tests/space-construct.spec.ts` | done |
| SP41 | The Office's wooden door stands south of where people arrive: it lights up in reach, asks before going, and opens a furnished room whose furniture cannot be picked up, where a piece can still be added, whose glass doors open with E, and whose own door leads back | `tests/space-office.spec.ts` | done |
| SP42 | The Game Room's neon door stands beside the Office's wooden door: it lights up in reach, asks before going, and opens a furnished room whose arcade cabinets each play one Retro Game of their own and list the rest, whose furniture cannot be picked up, where a piece can still be added, and whose own neon door leads back | `tests/space-game-room.spec.ts` | done |

### LC - Localization

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| LC1 | The sign-in window switches between English and pt-BR, at the address in that language, and persists the selection | `tests/i18n.spec.ts` | done |
| LC2 | A first visit uses pt-BR from Accept-Language | `tests/i18n.spec.ts` | done |
| LC3 | Switching to Japanese survives a reload | `tests/i18n.spec.ts` | done |
| LC4 | pt-BR is kept through registration into the chat shell | `tests/i18n.spec.ts` | done |
| LC5 | Language switches from the chat menu bar | `tests/i18n.spec.ts` | done |

### PW - Public Pages, Landing, And Showcase

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| PW1 | The home loads the desktop's small first-paint bundle, README.txt on the desk opens in place, and a desktop icon moves to another page without a page load | `tests/landing-public.spec.ts` | done |
| PW2 | On a phone a page shows its first window, and the taskbar's group for the page brings any other window of it to the screen | `tests/landing-public.spec.ts` | done |
| PW3 | The Start menu reaches every page as windows of the desktop, and closing a page's last window hands the address back to the chat | `tests/landing-public.spec.ts` | done |
| PW4 | Help wears the phone chrome of a window with a menu bar; the sign-in window carries no menu bar | `tests/shell-chrome-parity.spec.ts` | done |
| PW5 | A rail button opens the shared drawer on its own section | `tests/shell-chrome-parity.spec.ts` | done |
| PW6 | A page of the site carries no menu bar of its own; Start ▸ Open the app is there and inert on the desktop | `tests/shell-chrome-parity.spec.ts` | done |
| PW7 | The showcase drives the page as a window and carries the layout across pages | `tests/showcase-desktop.spec.ts` | done |
| PW8 | Components are navigated through the Components window | `tests/showcase-desktop.spec.ts` | done |
| PW9 | The Start menu is the app's own, with the showcase's windows in it | `tests/showcase-desktop.spec.ts` | done |
| PW10 | Every menu row takes the same highlight | `tests/showcase-desktop.spec.ts` | done |
| PW11 | The nested demo desktop runs beside the shell's own | `tests/showcase-desktop.spec.ts` | done |
| PW12 | With JavaScript disabled the page still reads and links like a document, keeping its canonical URL | `tests/showcase-desktop.spec.ts` | done |
| PW13 | Windows on each landing page are sized by their content (one case per public page) | `tests/desktop-window-sizing.spec.ts` | done |
| PW14 | The showcase component window is sized by its content | `tests/desktop-window-sizing.spec.ts` | done |
| PW15 | From the visitor's bar under the chat, Create an account opens the sign-in window over the chat without a page load, and registering lands in the chat | `tests/sign-in-window.spec.ts` | done |
| PW16 | A page of the site keeps the chat's LiveSocket off for a crawler, which never acts; a reader's starts on the first interaction | `tests/sign-in-window.spec.ts` | done |
| PW17 | A remembered terminal signs back in with one click from the sign-in window | `tests/sign-in-window.spec.ts` | done |
| PW18 | The sign-in window opens fully on screen at every desktop size | `tests/sign-in-window.spec.ts` | done |
| PW19 | The public pages declare an installable web app: a linked manifest whose icons and service worker are actually served | `tests/landing-public.spec.ts` | done |
| PW20 | A channel's public archive is reachable, indexable, and disappears when the founder switches it off (features P1) | `tests/archive-public.spec.ts` | done |
| PW21 | The founder switches the archive with /cs archive on\|off, and another member of the room sees the notice (features P1) | `tests/archive-public.spec.ts` | done |
| PW22 | The public games catalogue leads from a game's page, through the sign-in window over the same desktop, into the game | `tests/games-catalog.spec.ts` | done |
| PW23 | The mIRC commands guide answers a mIRC habit row by row, and its links lead into the matching help topic and the other guides | `tests/irc-guides.spec.ts` | done |
| PW24 | Without an account a channel's address (/c/<name>) opens read-only: a visitor watches it live under a Guest name, members see them under Visitors, and any action opens the sign-in window at /connect | `tests/chat-public-visitor.spec.ts` | done |
| PW25 | A visitor who registers from the chat's Connect window comes back to the channel they were watching, now as a member | `tests/chat-public-visitor.spec.ts` | done |
| PW26 | No link leaves a visitor's chat: a message URL (plain, Ctrl or middle click) and a game in the desktop Games folder open the Connect window naming the feature, and no tab opens | `tests/chat-public-visitor.spec.ts` | done |
| PW27 | A game, the arcade or a call opened by address without an account lands in the chat with the Connect window naming it, and registering there returns to that address | `tests/chat-public-visitor.spec.ts` | done |
| PW28 | The desktop is the home: a visitor at / gets the live #lobby in front with an icon per page on the desk; a page opens as its group of windows over the chat, cascaded with its first window in front, and closing its last window goes back to the chat | `tests/desktop-home.spec.ts` | done |
| PW29 | A visitor arriving at / is greeted in #lobby by the system, for their eyes only: their guest name, how to move between channels, what an account opens (Space, Group Call, P2P, Arcade) and where to create one — on a desktop and on a phone | `tests/chat-public-visitor.spec.ts` | done |
| PW30 | A visitor reads on arrival what a member reads: the server's message of the day in the Status window and a channel's own welcome (/setwelcome) when they open it | `tests/chat-public-visitor.spec.ts` | done |
| PW31 | Every step of the sign-in window — nickname, a wrong nickname, registration with Remember this terminal, password, remembered nicknames — fits a 1280x720 desktop and a phone without scrolling or spilling sideways, a visitor's reason included; How sessions work and each thing an account opens open their help topic in a new tab, leaving the window where it was | `tests/sign-in-window-fit.spec.ts` | done |
| PW32 | A trusted terminal set to Auto-login is signed in by the first page it opens after the browser restarts, with no sign-in window or form in between; Log out keeps it out until the browser closes; Log in beside a remembered nickname works before the chat's socket has joined — on a desktop and on a phone | `tests/trusted-terminal-return.spec.ts` | done |
| PW33 | The public Spaces page shows the world in real pictures — the island, the Construct, the Game Room, the Office and the character creator — on a desktop and a phone, and its way in takes a visitor through creating an account straight into the #lobby Space, put in the channel on arrival | `tests/spaces-page.spec.ts` | done |
| PW34 | A member's way in on the Spaces page opens the #lobby Space in a tab of its own, and the features window and the home page lead to the Spaces page | `tests/spaces-page.spec.ts` | done |

### Dialog Gallery

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| DG1 | Every reworked dialog body opens and is photographed into e2e/screenshots/dialog-gallery for visual audit | `tests/dialog-gallery.spec.ts` | done |
| DG2 | Every list dialog is photographed empty, on a desktop and on a phone, so its empty state is judged by eye | `tests/dialog-gallery.spec.ts` | done |
| DG3 | The confirmations are photographed on a phone as well as on a desktop | `tests/dialog-gallery.spec.ts` | done |
| DG4 | Mentions, Pinned and Saved, which share one message row, are photographed filled on a phone too | `tests/dialog-gallery.spec.ts` | done |

### P - Performance Budgets

| # | Flow | Spec file | Status |
| --- | --- | --- | --- |
| PF1 | /connect stays inside its document-size and DOM-node budget | `tests/perf-payload.spec.ts` | done |
| PF2 | A help topic stays inside its document-size and DOM-node budget | `tests/perf-payload.spec.ts` | done |
| PF3 | Every icon is a sprite reference and none draws its art inline | `tests/perf-payload.spec.ts` | done |
| PF4 | The sprite really resolves — a referenced icon has painted pixels | `tests/perf-payload.spec.ts` | done |
| PF5 | The second page pays nothing for the sprite | `tests/perf-payload.spec.ts` | done |
| PF6 | The sprite is preloaded in the head, not discovered mid-body | `tests/perf-payload.spec.ts` | done |
| PF7 | With RUM off, the Faro SDK is never downloaded | `tests/perf-critical-path.spec.ts` | done |
| PF8 | The RUM entrypoint stays a gate and never carries the SDK | `tests/perf-critical-path.spec.ts` | done |
| PF9 | No third-party stylesheet blocks the first paint | `tests/perf-critical-path.spec.ts` | done |
| PF10 | /connect paints inside its FCP and LCP budget | `tests/perf-critical-path.spec.ts` | done |
| PF11 | Every content-addressed asset is cached immutably, never revalidated | `tests/perf-critical-path.spec.ts` | done |

## Spec files with no documented flows

None. Every spec documents its own flows.

<!-- END GENERATED INDEX -->
