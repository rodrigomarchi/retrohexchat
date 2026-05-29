# E2E Test Backlog

Additional desktop/browser journeys still worth validating beyond the current
green catalog in `TEST_CATALOG.md`.

**Created:** 2026-05-29

## Scope

- Desktop browser journeys only. Mobile/responsive-specific coverage is
  intentionally out of scope for this backlog.
- Strict black-box only: no test-only routes, reset endpoints, HTTP seeds, DB
  shortcuts, or hidden fixtures.
- Every prerequisite must be created through visible user actions in the spec.
- If a scenario exposes behavior a real user would consider broken, fix product
  behavior or make an explicit product decision before weakening assertions.
- Implement this backlog in file order from top to bottom. Do not use a
  separate priority order unless this document is explicitly changed first.
- Every scenario in this backlog is intended to land. `investigate` and `block`
  are temporary execution states, not permission to skip a scenario.

## Status Legend

- `done` - implemented, passing, and reflected in `TEST_CATALOG.md`.
- `todo` - mapped, not implemented.
- `investigate` - inspect UI/product behavior, then implement the scenario or
  document the product/blocker decision before moving on.
- `block` - not runnable yet; first create a safe black-box strategy, then
  implement the scenario.

## Q - Catalog, Help, Parser, And Command Surface

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| Q1 | `/help` output includes every command registered in `Commands.Registry` and no stale command names | `tests/chat-command-registry.spec.ts` | P1 | done |
| Q2 | `/help <command>` renders detail for every registered command, including syntax and examples when present | `tests/chat-command-registry.spec.ts` | P1 | done |
| Q3 | Full Help Topics deep links render for every command help card reachable from `/help <command>` | `tests/chat-command-registry.spec.ts` | P1 | done |
| Q4 | Command autocomplete contains every registered command and groups commands by category labels | `tests/chat-command-registry.spec.ts` | P2 | done |
| Q5 | Slash commands are case-insensitive: `/JOIN #room`, `/Msg nick text`, `/Ns info` hit the same handlers | `tests/chat-command-parser.spec.ts` | P1 | done |
| Q6 | Leading/trailing whitespace around commands and args does not change dispatch behavior | `tests/chat-command-parser.spec.ts` | P1 | done |
| Q7 | A bare `/`, `/ `, and command-like whitespace show a helpful error without clearing unrelated UI state | `tests/chat-command-parser.spec.ts` | P2 | done |
| Q8 | Command arguments preserve user text containing punctuation, repeated spaces, unicode, and IRC formatting codes | `tests/chat-command-parser.spec.ts` | P2 | done |
| Q9 | Sensitive command names/args are omitted from command history beyond NickServ examples already covered | `tests/chat-command-history-sensitive.spec.ts` | P1 | done |
| Q10 | Recent-command autocomplete ranking updates after command use without leaking sensitive commands | `tests/chat-command-history-sensitive.spec.ts` | P2 | done |

## R - Security, Escaping, Limits, And Input Robustness

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| R1 | Chat message HTML/script content renders escaped and never executes | `tests/chat-security-escaping.spec.ts` | P0 | done |
| R2 | Topic, welcome, MOTD, away, bio, alias expansion, bot response, and autorespond output escape HTML/script content | `tests/chat-security-escaping.spec.ts` | P0 | done |
| R3 | URLs with unsafe schemes such as `javascript:` are not rendered as clickable openable links | `tests/chat-security-links.spec.ts` | P0 | done |
| R4 | Long unbroken words and very long URLs do not break the desktop chat layout | `tests/chat-message-rendering.spec.ts` | P2 | done |
| R5 | Unicode, emoji, combining marks, and non-Latin text survive send, history reload, edit, search, and copy-visible flows | `tests/chat-unicode.spec.ts` | P2 | done |
| R6 | Message input enforces the 1000-character limit consistently for typing, paste, send button, and Enter submit | `tests/chat-input-limits.spec.ts` | P1 | done |
| R7 | Paste confirmation disables send for more than the product max line count and cancel fully restores input focus | `tests/chat-paste-limits.spec.ts` | P1 | done |
| R8 | Flood protection settings actually affect rapid message/paste behavior and can be reset to defaults | `tests/chat-flood-protection.spec.ts` | P1 | done |
| R9 | Command rate-limit or flood errors do not leave stale pending messages or disabled input state | `tests/chat-rate-limit.spec.ts` | P2 | done |
| R10 | Editing a message to empty opens delete confirmation; cancelling returns to normal input state | `tests/chat-message-edit-delete-edges.spec.ts` | P1 | done |

## S - Message Lifecycle, Replies, History, And Search Edges

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| S1 | Non-author cannot edit or delete another user's channel message via context menu or event path | `tests/chat-message-permissions.spec.ts` | P0 | done |
| S2 | PM messages support reply, edit, delete, and deleted placeholder behavior consistently with channel messages | `tests/chat-pm-message-actions.spec.ts` | P1 | done |
| S3 | Reply preview updates when the parent message is edited | `tests/chat-message-reply-edges.spec.ts` | P1 | done |
| S4 | Reply preview remains coherent when the parent message is deleted | `tests/chat-message-reply-edges.spec.ts` | P1 | done |
| S5 | Clicking a reply parent link scrolls to the parent when it is currently loaded | `tests/chat-message-reply-edges.spec.ts` | P2 | done |
| S6 | Clicking a reply parent link whose parent is only in older history loads or reports that history coherently | `tests/chat-message-reply-history.spec.ts` | P2 | done |
| S7 | Search with history mode finds matches only available after scroll pagination | `tests/chat-search-history.spec.ts` | P2 | done |
| S8 | Search active result scrolls into view and maintains active highlight while navigating next/previous | `tests/chat-search-navigation.spec.ts` | P2 | done |
| S9 | Search state resets or persists deliberately when switching channel, PM, and Status tabs | `tests/chat-search-window-state.spec.ts` | P2 | done |
| S10 | Pending failed message retry succeeds after the blocking mode/mute condition is removed | `tests/chat-message-retry.spec.ts` | P1 | done |
| S11 | Failed pending message can be cancelled/deleted without leaving orphan UI | `tests/chat-message-retry.spec.ts` | P2 | done |
| S12 | Message timestamps respect selected timezone and timestamp format after browser timezone detection | `tests/chat-timestamps.spec.ts` | P2 | done |

## T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| T1 | File/View/Tools/Help menu items open the same dialogs/actions as toolbar buttons where both exist | `tests/chat-menu-toolbar-parity.spec.ts` | P1 | todo |
| T2 | Opening menus and dialogs never steals chat input focus unless the dialog intentionally owns focus | `tests/chat-menu-focus.spec.ts` | P1 | todo |
| T3 | About dialog opens from Help menu and app logo, closes cleanly, and returns focus to chat input | `tests/chat-about-dialog.spec.ts` | P2 | todo |
| T4 | View toggles hide/show conversations, nicklist, channel list, and search without losing active tab or unread state | `tests/chat-view-menu.spec.ts` | P1 | todo |
| T5 | Tools menu opens Address Book, Highlights, URL Catcher, Channel Central, Perform, Sound, Flood Protection, Alias, Custom Menus, Autorespond | `tests/chat-tools-menu.spec.ts` | P1 | todo |
| T6 | Escape closes the topmost dialog/menu only and leaves underlying dialogs/state intact | `tests/chat-dialog-keyboard.spec.ts` | P1 | todo |
| T7 | Enter activates primary dialog action and Escape/cancel paths do not persist draft changes | `tests/chat-dialog-keyboard.spec.ts` | P2 | todo |
| T8 | Tab key focus order inside major dialogs is usable and does not escape modal unexpectedly | `tests/chat-dialog-keyboard.spec.ts` | P2 | todo |
| T9 | Window switch shortcuts skip Status as designed and cycle channels/PMs in stable order | `tests/chat-window-shortcuts.spec.ts` | P1 | todo |
| T10 | Cheatsheet opens from menu/shortcut, lists active key bindings, and closes without submitting chat input | `tests/chat-cheatsheet.spec.ts` | P2 | todo |
| T11 | Dialog close buttons, cancel buttons, and backdrop behavior are consistent for all major dialogs | `tests/chat-dialog-close.spec.ts` | P2 | todo |
| T12 | Toolbar/menu disabled state during reconnect prevents destructive actions but keeps Help accessible | `tests/chat-reconnect-shell.spec.ts` | P1 | todo |

## U - Dialog CRUD And Settings Depth

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| U1 | Highlight dialog add/edit/remove word and color; matching inbound message highlights in chat | `tests/chat-highlights.spec.ts` | P1 | todo |
| U2 | Highlight settings persist for registered users and remain session-only for guests | `tests/chat-highlights-persistence.spec.ts` | P2 | todo |
| U3 | Sound Settings OK/Apply/Cancel/Preview behavior persists only intended settings | `tests/chat-sound-settings.spec.ts` | P2 | investigate |
| U4 | Sound mute/status-bar setting and sound dialog stay in sync across rerenders/reconnect | `tests/chat-sound-settings.spec.ts` | P2 | todo |
| U5 | Flood Protection dialog save/reset/cancel updates effective flood behavior | `tests/chat-flood-protection.spec.ts` | P1 | investigate |
| U6 | Perform dialog edit/move/toggle-enabled paths mirror slash command behavior | `tests/chat-perform-dialog.spec.ts` | P1 | todo |
| U7 | Autojoin dialog edit/reorder/remove paths mirror slash command behavior | `tests/chat-perform-dialog.spec.ts` | P1 | todo |
| U8 | Autorespond dialog add/edit/toggle/delete validates fields and mirrors slash behavior | `tests/chat-autorespond-dialog.spec.ts` | P1 | todo |
| U9 | Custom Menus dialog validates duplicate labels, empty command, command chaining, and tab-specific menu types | `tests/chat-custom-menus-dialog.spec.ts` | P1 | todo |
| U10 | Alias dialog validates duplicate aliases, empty expansion, recursion warning, and cancel/discard behavior | `tests/chat-alias-dialog-edges.spec.ts` | P1 | todo |
| U11 | Notify List dialog auto-WHOIS and auto-add-PM settings affect later online/PM behavior | `tests/chat-notify-settings.spec.ts` | P1 | todo |
| U12 | Address Book contact notes surface in hover/whois-adjacent UI where product intends them to surface | `tests/chat-address-book-contacts.spec.ts` | P2 | investigate |
| U13 | Address Book nick color edit/delete immediately updates existing chat rows and future rows | `tests/chat-address-book-colors.spec.ts` | P2 | todo |
| U14 | Control-list entries from Address Book match `/ignore` filtering behavior by type | `tests/chat-address-book-control.spec.ts` | P1 | todo |
| U15 | Channel Central ban exception and invite exception add/remove flows affect join/ban behavior | `tests/chat-channel-central-exceptions.spec.ts` | P1 | todo |
| U16 | Channel Central topic/mode edits stay in sync with slash command output after dialog close/reopen | `tests/chat-channel-central-sync.spec.ts` | P2 | todo |

## V - Conversations, Tabs, Unread, Mute, And No-Focus-Steal Depth

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| V1 | Conversation sidebar section collapse/expand state survives rerenders and does not affect active tab | `tests/chat-conversations-sidebar.spec.ts` | P2 | todo |
| V2 | Popular channel item joins/switches channel through browser UI without command typing | `tests/chat-conversations-sidebar.spec.ts` | P2 | investigate |
| V3 | Browse all channels from conversations sidebar opens channel list with search pre-state intact | `tests/chat-conversations-sidebar.spec.ts` | P2 | todo |
| V4 | Conversation context menu Mark Read clears unread badges in tab and sidebar but does not switch focus | `tests/chat-conversation-unread.spec.ts` | P1 | todo |
| V5 | Muted channel/PM suppresses sound/title-flash while still showing visual unread indicators | `tests/chat-conversation-mute.spec.ts` | P1 | investigate |
| V6 | Copy channel/PM name from context menu writes expected text to clipboard with browser permission | `tests/chat-conversation-context-clipboard.spec.ts` | P2 | todo |
| V7 | Leave from conversation context menu removes only the targeted channel and handles active/inactive cases | `tests/chat-conversation-context-leave.spec.ts` | P1 | todo |
| V8 | Channel Settings from conversation context menu opens Channel Central for the selected channel, not active channel | `tests/chat-conversation-context-settings.spec.ts` | P1 | todo |
| V9 | Closing a tab with unread messages clears or preserves unread state according to product decision when re-opened | `tests/chat-tab-unread-edges.spec.ts` | P2 | investigate |
| V10 | Incoming PM from ignored user does not create unread indicator, typing indicator, or title flash | `tests/chat-ignore-notifications.spec.ts` | P1 | todo |
| V11 | Incoming invite from ignored user does not auto-open invite dialog or steal focus | `tests/chat-ignore-notifications.spec.ts` | P1 | todo |
| V12 | Multiple simultaneous PM unread counts update independently and reset only when each PM is opened | `tests/chat-pm-unread-multiple.spec.ts` | P1 | todo |

## W - Presence, Identity, Nick Changes, Whois/Whowas

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| W1 | Nick change by another user updates channel message attribution, nicklist, PM tab labels, and conversations sidebar | `tests/chat-nick-change-realtime.spec.ts` | P1 | todo |
| W2 | Nick collision flow shows error and leaves original session/channel membership intact | `tests/chat-nick-change-edges.spec.ts` | P1 | todo |
| W3 | Registered nick password dialog cancel path leaves nickname unchanged and chat input usable | `tests/chat-nickserv-dialog-edges.spec.ts` | P1 | todo |
| W4 | NickServ registration/drop updates `/whois Registered:` state in another user's session without reconnect | `tests/chat-nickserv-whois-realtime.spec.ts` | P2 | todo |
| W5 | `/whowas` for an online user points to `/whois` or returns the intended online-user behavior | `tests/chat-whowas-edges.spec.ts` | P2 | investigate |
| W6 | `/whowas` entry expiry behavior is visible after configured retention only if retention can be reached safely | `tests/chat-whowas-edges.spec.ts` | P3 | investigate |
| W7 | Away auto-reply resets after away is cleared and can trigger again after setting away again | `tests/chat-away-edges.spec.ts` | P1 | todo |
| W8 | Away state is reflected in nicklist styling/hover card immediately for already-open channels | `tests/chat-away-edges.spec.ts` | P2 | todo |
| W9 | Notify auto-WHOIS setting emits WHOIS details when a watched user comes online | `tests/chat-notify-settings.spec.ts` | P1 | todo |
| W10 | Notify auto-add-PM setting adds PM partners after first PM and persists for registered users | `tests/chat-notify-settings.spec.ts` | P1 | todo |
| W11 | Idle timer does not reset from passive events such as switching tabs, opening dialogs, or hovering nicklist | `tests/chat-idle-passive.spec.ts` | P2 | todo |

## X - Channel Modes, Services, Permissions, And Persistence Edges

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| X1 | Channel mode combinations `+imntkl` applied together survive dialog reopen and slash `/mode` output | `tests/chat-channel-mode-matrix.spec.ts` | P1 | todo |
| X2 | Removing channel key/limit with `/mode -k` and `/mode -l` clears visible state and join restrictions | `tests/chat-channel-mode-matrix.spec.ts` | P1 | todo |
| X3 | Ban masks or wildcard-style bans behave as product intends, not only exact nick bans | `tests/chat-channel-ban-masks.spec.ts` | P2 | investigate |
| X4 | Ban exception allows a banned user to join when exception matches | `tests/chat-channel-ban-exceptions.spec.ts` | P1 | todo |
| X5 | Invite exception allows a user into invite-only channel without one-off invite | `tests/chat-channel-invite-exceptions.spec.ts` | P1 | todo |
| X6 | ChanServ registered channel access survives all users leaving and later rejoining | `tests/chat-chanserv-persistence.spec.ts` | P1 | todo |
| X7 | ChanServ founder transfer persists and changes future access control | `tests/chat-chanserv-transfer-persistence.spec.ts` | P1 | todo |
| X8 | SOP outranks AOP/VOP for service-managed permissions and automatic role assignment | `tests/chat-chanserv-access-hierarchy.spec.ts` | P2 | todo |
| X9 | Non-founder service access mutation attempts produce clear errors and no partial state change | `tests/chat-chanserv-permission-edges.spec.ts` | P1 | todo |
| X10 | Admin channel delete while users are inside removes tabs and prevents stale sends | `tests/chat-admin-channel-destructive.spec.ts` | P1 | todo |
| X11 | Admin channel purge updates already-open clients in realtime, not only after tab reload | `tests/chat-admin-channel-purge-realtime.spec.ts` | P2 | todo |
| X12 | Admin user ban persists across reconnect and unban restores access through UI-visible flow | `tests/chat-admin-ban-persistence.spec.ts` | P1 | todo |
| X13 | Admin mute persists across reconnect and unmute restores normal send behavior | `tests/chat-admin-user-mute-persistence.spec.ts` | P1 | todo |
| X14 | Admin role change is reflected immediately in menus/permissions after target reconnects | `tests/chat-admin-role-persistence.spec.ts` | P2 | todo |
| X15 | Admin audit log shows entries for representative admin actions with actor/target/reason | `tests/chat-admin-audit-log.spec.ts` | P1 | todo |

## Y - Bots, Automation, Timers, And Race Conditions

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| Y1 | Bot duplicate nickname/create validation shows clear errors without corrupting bot list | `tests/chat-bot-edges.spec.ts` | P1 | todo |
| Y2 | Bot part/join across multiple channels updates nicklists and bot info correctly | `tests/chat-bot-channel-membership.spec.ts` | P1 | todo |
| Y3 | Bot custom command with variables/special chars responds correctly and escapes output | `tests/chat-bot-custom-command-edges.spec.ts` | P1 | todo |
| Y4 | Bot disabled state persists across dialog close/reopen and reconnect | `tests/chat-bot-persistence.spec.ts` | P2 | todo |
| Y5 | Timer firing while active tab changes sends output to intended active window or documented target | `tests/chat-timer-window-context.spec.ts` | P1 | investigate |
| Y6 | Timer command that opens a tab obeys no-focus-steal guarantees | `tests/chat-timer-window-context.spec.ts` | P1 | todo |
| Y7 | Timer created with command that later becomes invalid shows error without repeating forever unexpectedly | `tests/chat-timer-error-edges.spec.ts` | P2 | todo |
| Y8 | Perform command failure during reconnect reports error and continues later perform entries if product intends | `tests/chat-perform-error-edges.spec.ts` | P1 | investigate |
| Y9 | Autojoin failure during reconnect reports error but does not block other autojoin channels | `tests/chat-autojoin-error-edges.spec.ts` | P1 | todo |
| Y10 | Autorespond loop prevention handles two users with reciprocal autorespond rules | `tests/chat-autorespond-loop.spec.ts` | P0 | done |
| Y11 | Alias expansion inside perform/timer/autorespond works or is rejected consistently | `tests/chat-automation-composition.spec.ts` | P2 | investigate |
| Y12 | Two rapid concurrent state changes, such as kick plus PM or rename plus message, do not leave stale tabs/nicks | `tests/chat-realtime-race-edges.spec.ts` | P2 | investigate |

## Z - P2P, File, Call, Game, Arcade

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| Z1 | P2P/call/sendfile/game to offline but registered user shows clear offline/unavailable error | `tests/chat-p2p-availability.spec.ts` | P1 | todo |
| Z2 | P2P target ignores sender and does not receive invite card or notification | `tests/chat-p2p-ignore.spec.ts` | P1 | todo |
| Z3 | P2P invite expires or is cancelled and both users' lobby/chat state clears | `tests/chat-p2p-expiry-cancel.spec.ts` | P2 | investigate |
| Z4 | Double-clicking accept/decline on invite cards is idempotent and does not create duplicate sessions | `tests/chat-p2p-idempotency.spec.ts` | P1 | todo |
| Z5 | Closing one side of a P2P lobby/session updates the other side's state and does not steal chat focus | `tests/chat-p2p-session-lifecycle.spec.ts` | P1 | todo |
| Z6 | Media permission denied path for `/call` shows actionable error and leaves chat usable | `tests/chat-p2p-call-permissions.spec.ts` | P1 | todo |
| Z7 | Audio/video mute toggles in call session update local UI and remote indicators if present | `tests/chat-p2p-call-controls.spec.ts` | P2 | investigate |
| Z8 | File transfer cancel before upload and cancel during upload cleanly update both peers | `tests/chat-p2p-file-cancel.spec.ts` | P1 | todo |
| Z9 | File transfer rejects oversized or disallowed file according to product limits | `tests/chat-p2p-file-limits.spec.ts` | P1 | investigate |
| Z10 | Game invite decline and game selection cancellation return both users to chat/lobby state cleanly | `tests/chat-p2p-game-lifecycle.spec.ts` | P2 | todo |
| Z11 | Shared game shell exchanges at least one state update between peers, beyond simply opening the lobby | `tests/chat-p2p-game-state.spec.ts` | P2 | investigate |
| Z12 | Solo arcade link opens playable session; canvas/frame is nonblank and can return to chat | `tests/chat-singleplayer-arcade.spec.ts` | P2 | investigate |

## AA - Reconnect, Multi-Context, Browser State, And Destructive Safety

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| AA1 | Browser offline/online during active PM preserves PM draft, active tab, unread state, and typing state | `tests/chat-reconnect-window-state.spec.ts` | P1 | todo |
| AA2 | Browser offline/online while a modal dialog has unsaved changes preserves or discards draft according to product decision | `tests/chat-reconnect-dialog-state.spec.ts` | P2 | investigate |
| AA3 | Reconnect during P2P invite/lobby/session produces coherent state for both peers | `tests/chat-reconnect-p2p.spec.ts` | P2 | investigate |
| AA4 | Multi-tab same-user takeover while source has unsaved draft/dialog closes source cleanly and preserves new context session | `tests/multi-tab-takeover-edges.spec.ts` | P1 | todo |
| AA5 | Admin kick/ban during reconnect or while user is offline produces correct reconnect denial/allow behavior | `tests/chat-admin-reconnect-edges.spec.ts` | P1 | todo |
| AA6 | Registration closed blocks new registration but never blocks existing registered user authentication | `tests/admin-registration-closed-edges.spec.ts` | P1 | todo |
| AA7 | Registration closed plus nickname takeover does not bypass auth or registration policy | `tests/admin-registration-closed-edges.spec.ts` | P2 | todo |
| AA8 | Local browser storage settings such as mute/sound survive reload but do not leak across isolated browser contexts | `tests/chat-local-storage-isolation.spec.ts` | P2 | todo |
| AA9 | Confirmed `/admin nuke --confirm` remains blocked until disposable isolated profile exists | `tests/chat-admin-nuke.spec.ts` | P2 | block |

## Implementation Order

Work strictly in the order this file is written:

1. Finish all open `Q` scenarios, then `R`, `S`, `T`, `U`, `V`, `W`, `X`, `Y`,
   `Z`, and `AA`.
2. Within each section, work by row number.
3. For `investigate`, inspect the product/UI first, update the row if needed,
   then implement the E2E coverage before proceeding.
4. For `block`, do not skip the row permanently. Define a safe black-box
   strategy or an explicit product-safe constraint, then implement coverage.
5. Mark a row `done` only after its focused E2E spec passes and
   `TEST_CATALOG.md` reflects the new coverage.

## Maintenance Notes

- When a backlog scenario lands, keep the row in this file and mark it `done`.
  Also add or update the completed coverage entry in `TEST_CATALOG.md`.
- Keep this backlog intentionally separate from the green catalog so readers can
  distinguish current confidence from planned coverage while still seeing
  implementation progress in one place.
- Do not add mobile/responsive scenarios here unless the scope changes.
