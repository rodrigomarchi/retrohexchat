# Feature Specification: RetroHexChat Phase 1 — Foundation & Core Chat

**Feature Branch**: `001-phase1-foundation`
**Created**: 2026-02-09
**Status**: Draft
**Input**: User description: "Fase 1 do RetroHexChat — fundação completa do cliente IRC web com design retro dark theme"

## Scope & Exclusions

**In scope (Phase 1)**: Connection flow, MDI layout, channels, real-time
chat, private messages, "/" commands, NickServ, ChanServ, channel modes,
chat search, nicklist, rate limiting (basic), design system with dark
theme, UX polish.

**Explicitly excluded (future phases)**: DCC file transfer, federation with
real IRC servers, scripting/aliases, user theme customization, push/desktop
notifications, end-to-end encryption, multi-server support.

## Clarifications

### Session 2026-02-09

- Q: Rate limiting strategy? (RateLimit is a constitutional bounded context but absent from spec) → A: Basic per-user message throttle (5 msg/sec) + command throttle (2 cmd/sec), with temporary mute on violation.
- Q: Browser disconnect behavior (tab close without /quit)? → A: Immediate disconnect — socket close triggers instant quit broadcast and full cleanup (no grace period).
- Q: Password hashing algorithm for NickServ? → A: bcrypt via `bcrypt_elixir` (Elixir ecosystem standard, used by phx.gen.auth). Reduced rounds in test config for speed.
- Q: Maximum message length? → A: 1000 characters max for user-authored content (messages, actions, topics); system/service messages unconstrained.
- Q: Observability / Telemetry scope for Phase 1? → Deferred (user advanced to /speckit.plan). Will address in plan phase.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Connect and Chat in #lobby (Priority: P1)

A user opens the application and sees a 2000s-era "Connect to
Server" dialog centered on screen. They enter a nickname (e.g., "Rodrigo"),
click Connect, and are immediately placed in the `#lobby` channel. The
full mIRC-style layout appears: treebar on the left showing #lobby under
"Channels", the chat area in the center with a sunken panel, a nicklist
on the right listing all connected users, and a status bar at the bottom.
The user types a message and presses Enter — the message appears
instantly for all participants in `[HH:MM] <Rodrigo> hello world` format.
They see other users' messages appear in real time with color-coded
nicknames. System messages (joins, parts) appear in muted gray-blue.

**Why this priority**: This is the absolute MVP. Without connection +
channel chat + layout, nothing else functions. Every other feature builds
on this foundation.

**Independent Test**: Can be fully tested by opening two browser tabs,
connecting with different nicknames, and exchanging messages in #lobby.
Delivers the core value: real-time IRC-style chat with retro UI.

**Acceptance Scenarios**:

1. **Given** a user visits the app for the first time, **When** the page
   loads, **Then** they see a retro-style connection dialog centered
   on screen with Nickname and Alt Nickname fields.

2. **Given** the connection dialog is shown, **When** the user enters a
   valid nickname and clicks Connect, **Then** they are placed in #lobby
   with the full MDI layout visible (treebar, chat, nicklist, status bar).

3. **Given** the user enters a nickname that is already in use, **When**
   they click Connect, **Then** the alt nickname is tried; if both are
   taken, they connect as `Guest_XXXXX`.

4. **Given** a user is connected in #lobby, **When** they type a message
   and press Enter, **Then** the message appears for all channel
   participants in `[HH:MM] <nickname> message` format within 200ms.

5. **Given** a user is in #lobby, **When** another user joins, **Then** a
   system message `* User has joined #lobby` appears in gray-blue and the
   nicklist updates instantly.

6. **Given** a user is in #lobby, **When** they type `/me dances`, **Then**
   all users see `* nickname dances` in purple.

7. **Given** the nickname field is empty, **When** the user clicks Connect,
   **Then** the field shows a validation error and connection is blocked.

8. **Given** the user enters "123bad" (starts with number), **When** they
   type it, **Then** real-time validation shows the nickname is invalid.

---

### User Story 2 — Channels: Create, Join, Part (Priority: P2)

A connected user types `/join #elixir` in the input. Since the channel
doesn't exist, it is created and the user becomes operator (@). The
channel appears in the treebar under "Channels". Another user can type
`/join #elixir` to enter. The treebar highlights indicate which channel
has unread messages. The user can switch between channels by clicking in
the treebar. `/part #elixir Goodbye!` leaves the channel with a farewell
message. `/list` opens a Channel List dialog showing all active channels
with name, topic, and user count, with a search/filter bar.

**Why this priority**: Multi-channel support is the second pillar of IRC
after basic chat. Users need to create and organize conversations beyond
the default lobby.

**Independent Test**: Tested by one user creating a channel, another
joining it, exchanging messages, then one leaving. Verify treebar updates,
operator badge, and channel lifecycle.

**Acceptance Scenarios**:

1. **Given** a user is connected, **When** they type `/join #elixir`,
   **Then** the channel is created, the user is operator (@), the channel
   appears in the treebar, and the chat area switches to #elixir.

2. **Given** #elixir exists with users, **When** a new user types
   `/join #elixir`, **Then** they join, see recent messages, appear in
   the nicklist, and a join system message is shown.

3. **Given** a user is in #elixir and #lobby, **When** they click #lobby
   in the treebar, **Then** the chat area switches to #lobby preserving
   scroll position in #elixir.

4. **Given** a user is in #elixir, **When** they type
   `/part #elixir Bye!`, **Then** they leave, the channel is removed from
   their treebar, and other users see `* User has left #elixir (Bye!)`.

5. **Given** the last user leaves an unregistered channel, **When** the
   part completes, **Then** the channel process is terminated and the
   channel no longer appears in `/list`.

6. **Given** a user types `/list`, **When** the command executes, **Then**
   a 2000s-era Channel List dialog opens showing channel name,
   topic, user count, with a search/filter input.

7. **Given** a user is in #lobby and a message arrives in #elixir,
   **When** #elixir is not the active view, **Then** the #elixir entry
   in the treebar shows a bold/highlight indicator.

8. **Given** a user tries `/join` with an invalid name (no #, spaces),
   **When** the command is sent, **Then** a red error message explains
   the naming rules.

9. **Given** a user is in 10 channels (the limit), **When** they try
   `/join #another`, **Then** they see an error "Maximum channel limit
   reached (10)".

---

### User Story 3 — Private Messages (Priority: P3)

A user types `/query Rodrigo` which opens a PM conversation in the
treebar under "Private". They can also use `/msg Rodrigo hey there`
which sends a direct message and opens the PM window automatically.
The conversation behaves like a channel chat — real-time messages,
timestamps, color-coded nicknames — but without a nicklist panel.
When the user receives a PM while viewing a channel, the treebar
"Private" section highlights with a bold indicator. An optional
notification sound plays.

**Why this priority**: Private messaging is essential for any chat system
but depends on the channel/chat infrastructure being solid first.

**Independent Test**: Two users open PMs to each other, exchange messages
bidirectionally, verify persistence and treebar indicators.

**Acceptance Scenarios**:

1. **Given** a connected user, **When** they type `/query Rodrigo`,
   **Then** a PM window opens in the treebar under "Private" and the
   chat area switches to the PM conversation.

2. **Given** a connected user, **When** they type `/msg Rodrigo hello`,
   **Then** the message is sent, a PM window opens in the treebar, and
   Rodrigo receives the message in real time.

3. **Given** user A has a PM with user B, **When** user A is viewing a
   channel and user B sends a PM, **Then** the PM entry in the treebar
   shows bold/highlight and an optional notification sound plays.

4. **Given** a PM conversation exists, **When** the user scrolls up,
   **Then** older messages are loaded via infinite scroll (same cursor-
   based pagination as channels).

5. **Given** a user tries `/msg NonExistent hello`, **When** the command
   executes, **Then** a red error message says the user is not online.

6. **Given** a PM conversation, **When** the user reconnects later,
   **Then** the conversation history is available (persisted in DB).

---

### User Story 4 — Slash Commands System (Priority: P4)

When a user types "/" in the input field, a command palette popup appears
above the input (styled as a retro design system listbox). It shows all available
commands with brief descriptions. As the user continues typing (e.g.,
"/jo"), the list filters in real time. Selecting a command via Enter or
click fills the input and shows syntax hints. The up/down arrow keys
navigate command history (last 50 entries). Tab key completes nicknames
from the current channel's nicklist.

**Why this priority**: The command system is the primary interaction
pattern for IRC. While basic `/join` and `/msg` work in previous stories,
this story adds the full command infrastructure, autocomplete UX, and
all remaining commands.

**Independent Test**: Type "/" and verify popup appears, filter works,
selection fills input. Type a command and verify execution. Test ↑/↓
history and Tab nickname completion independently.

**Acceptance Scenarios**:

1. **Given** the input is empty, **When** the user types "/", **Then** a
   command palette popup appears above the input listing all available
   commands with name and description.

2. **Given** the command palette is open, **When** the user types "jo",
   **Then** the list filters to show only `/join`.

3. **Given** the command palette shows `/join`, **When** the user presses
   Enter, **Then** the input fills with `/join ` and shows syntax
   placeholder `#channel`.

4. **Given** the user has sent 3 commands, **When** they press ↑ in
   the input, **Then** the previous command fills the input. Pressing ↑
   again shows the one before. ↓ reverses direction.

5. **Given** the user is in a channel with "Rodrigo" and "Roberto",
   **When** they type "Ro" and press Tab, **Then** "Rodrigo" completes.
   Pressing Tab again cycles to "Roberto".

6. **Given** the command palette is open, **When** the user presses Esc,
   **Then** the popup closes and focus stays in the input.

7. **Given** a user types `/nick NewName`, **When** the command executes
   and the new name is valid and available, **Then** the nickname changes
   everywhere (nicklist, status bar, treebar), and a system message
   `* OldName is now known as NewName` appears in all shared channels.

8. **Given** a user types `/whois Rodrigo`, **When** the command executes,
   **Then** a retro dialog opens showing: nickname, channels,
   connection time, away status.

9. **Given** a user types `/clear`, **When** the command executes,
   **Then** the current chat view is visually cleared (messages remain
   in DB).

10. **Given** a user types `/away Gone for lunch`, **When** the command
    executes, **Then** their status changes to away (icon updates in
    nicklists), and `/away` with no message removes the away status.

11. **Given** a user types `/quit See ya`, **When** the command executes,
    **Then** they are disconnected, all channels receive
    `* User has quit (See ya)`, and the connection dialog reappears.

12. **Given** a user types `/help`, **When** the command executes,
    **Then** a list of all commands with descriptions is shown. `/help join`
    shows detailed syntax for `/join`.

---

### User Story 5 — Channel Modes and Operator Controls (Priority: P5)

A channel operator can control the channel via mode commands. They type
`/mode #elixir +m` to make it moderated (only ops and voiced users can
talk). `/mode #elixir +t` restricts topic changes to operators.
`/mode #elixir +k secret` adds a password. `/mode #elixir +i` makes it
invite-only. `/mode #elixir +l 50` sets a user limit. Modes can be
combined: `/mode #elixir +mt`. The operator can `/kick #elixir BadUser
Spam` and `/ban #elixir BadUser`. Mode changes generate system messages
visible to all channel members.

**Why this priority**: Moderation tools are critical for a functional
IRC system but only become meaningful once channels and chat work properly.

**Independent Test**: Create a channel, verify operator status, apply
each mode and verify its effect (e.g., non-operator can't talk in +m,
password required for +k). Test kick and ban independently.

**Acceptance Scenarios**:

1. **Given** user A creates #test (becomes operator), **When** user A
   types `/mode #test +m`, **Then** the channel becomes moderated and a
   system message `* UserA sets mode +m on #test` appears.

2. **Given** #test is +m (moderated), **When** a regular user tries to
   send a message, **Then** the input is disabled with an explanatory
   message; ops and voiced users can still type.

3. **Given** #test is +t, **When** a non-operator types
   `/topic #test New Topic`, **Then** they see a red error "You must be
   a channel operator to change the topic".

4. **Given** #test is +k with password "secret", **When** a user types
   `/join #test`, **Then** they are denied; `/join #test secret` succeeds.

5. **Given** #test is +i (invite-only), **When** a non-invited user types
   `/join #test`, **Then** they are denied with "Channel is invite-only".

6. **Given** #test has +l 2 and already 2 users, **When** a third user
   tries to join, **Then** they are denied with "Channel is full".

7. **Given** an operator in #test, **When** they type
   `/kick #test BadUser Spam`, **Then** BadUser is removed from the
   channel, sees a kick message, and all members see
   `* BadUser was kicked by Operator (Spam)`.

8. **Given** an operator bans a user, **When** the banned user tries to
   `/join #test`, **Then** they are denied with "You are banned from
   this channel".

9. **Given** an operator types `/mode #test +o RegularUser`, **When**
   the mode is applied, **Then** RegularUser becomes operator (@ prefix
   in nicklist) and a system message confirms it.

10. **Given** an operator types `/mode #test +v QuietUser`, **When**
    the mode is applied in a +m channel, **Then** QuietUser can now
    send messages.

11. **Given** a non-operator, **When** they try any mode/kick/ban
    command, **Then** they see a red error "Permission denied: you must
    be a channel operator".

---

### User Story 6 — NickServ: Nick Registration and Protection (Priority: P6)

A user types `/ns register mysecretpass` to register their current
nickname. After registration, the nickname is protected — if someone
else connects with it, they have 60 seconds to `/ns identify` or get
renamed to `Guest_XXXXX`. NickServ messages appear in the treebar under
"Services" in gold/yellow color. `/ns info Rodrigo` shows registration
details. `/ns ghost OldNick pass` kills a ghost session. `/ns drop`
removes registration.

**Why this priority**: Nick registration enables persistent identity, which
is a prerequisite for ChanServ (channel ownership requires identified
users). Without it, channel access lists are meaningless.

**Independent Test**: Register a nickname, disconnect, reconnect with it,
verify the 60-second identify timer, test ghost command. All testable
without any other feature.

**Acceptance Scenarios**:

1. **Given** a connected user "Rodrigo", **When** they type
   `/ns register mypass`, **Then** NickServ responds in gold:
   "Nickname Rodrigo has been registered" and the nickname is stored
   with bcrypt hashed password.

2. **Given** "Rodrigo" is registered, **When** a new user connects as
   "Rodrigo", **Then** NickServ warns in gold: "This nickname is
   registered. You have 60 seconds to identify via /ns identify <password>
   or you will be renamed."

3. **Given** the 60-second timer is active, **When** the user types
   `/ns identify mypass` with the correct password, **Then** NickServ
   confirms: "You are now identified as Rodrigo."

4. **Given** the 60-second timer expires without identification, **When**
   the timeout fires, **Then** the user is forcibly renamed to
   `Guest_XXXXX` with a NickServ message explaining why.

5. **Given** "Rodrigo" is registered and identified, **When** they type
   `/ns info Rodrigo`, **Then** NickServ shows: registered date, last
   seen, current status (online/offline).

6. **Given** a ghost session exists for "Rodrigo", **When** the real
   owner types `/ns ghost Rodrigo mypass`, **Then** the ghost session is
   disconnected and the nick becomes available.

7. **Given** "Rodrigo" is identified, **When** they type `/ns drop`,
   **Then** the registration is removed and NickServ confirms.

8. **Given** NickServ sends a message, **When** it appears, **Then** it
   shows in the treebar under "Services" section and messages are gold-
   colored with `[NickServ]` prefix.

---

### User Story 7 — ChanServ: Channel Registration and Access Lists (Priority: P7)

An identified user types `/cs register #elixir` to register the channel.
They become Founder with permanent operator status. The channel now
persists even when empty (topic, modes, access list preserved). The
founder can manage an access list: `/cs sop #elixir add TrustedUser`
makes them Super Operator (auto-op, can manage AOPs/VOPs).
`/cs aop #elixir add Helper` gives auto-op on join.
`/cs vop #elixir add Regular` gives auto-voice on join. When any listed
user joins the channel after identifying with NickServ, their access
level is automatically applied.

**Why this priority**: Channel registration and access lists are the
final governance layer. They depend on NickServ (identification) and
channel modes both working correctly.

**Independent Test**: Register a channel, add users to access list at
each level, verify auto-op/voice on join, verify persistence when channel
empties.

**Acceptance Scenarios**:

1. **Given** an identified user in #elixir, **When** they type
   `/cs register #elixir`, **Then** ChanServ confirms in gold: "Channel
   #elixir has been registered. You are the Founder." The channel is
   now persistent.

2. **Given** #elixir is registered and everyone leaves, **When** the last
   user parts, **Then** the channel process stays alive with topic, modes,
   and access list intact.

3. **Given** the Founder types `/cs sop #elixir add Admin`, **When**
   Admin joins #elixir (while identified), **Then** Admin automatically
   receives operator (@) status.

4. **Given** an SOP types `/cs aop #elixir add Helper`, **When** Helper
   joins (while identified), **Then** Helper automatically receives
   operator status.

5. **Given** an AOP types `/cs vop #elixir add Newbie`, **When** Newbie
   joins (while identified), **Then** Newbie automatically receives
   voice (+) status.

6. **Given** a non-identified user on the access list joins, **When**
   they enter the channel, **Then** they do NOT receive automatic
   privileges (must identify first).

7. **Given** the Founder types `/cs drop #elixir`, **When** confirmed,
   **Then** the channel becomes unregistered (will be destroyed when
   empty, access list removed).

8. **Given** a non-Founder types `/cs register #elixir`, **When** the
   command runs, **Then** ChanServ denies: "Channel is already registered".

9. **Given** a user types `/cs info #elixir`, **When** the command runs,
   **Then** ChanServ shows: founder, registration date, topic, modes,
   access list count.

10. **Given** only the Founder, **When** they type
    `/cs sop #elixir list`, **Then** ChanServ lists all SOPs for #elixir.
    Same for `/cs aop` and `/cs vop list`.

---

### User Story 8 — Infinite Scroll and Chat Persistence (Priority: P8)

When a user joins a channel, they see the 50 most recent messages. As
they scroll up, older messages load automatically with a retro
hourglass/progress indicator. The scroll position is preserved — no
jumping. If the user has scrolled up and new messages arrive, a floating
"New messages ↓" button appears at the bottom. Clicking it scrolls to
the latest. All messages (regular, actions, system events) are persisted
in PostgreSQL with optimized indexes for cursor-based pagination.

**Why this priority**: Basic message display works in P1, but proper
infinite scroll, persistence, and the scroll-position UX are refinements
that make the chat truly usable for long conversations.

**Independent Test**: Send 100+ messages to a channel, join, verify 50
are loaded. Scroll up, verify older messages load. Scroll up again while
new messages arrive, verify "New messages" button appears.

**Acceptance Scenarios**:

1. **Given** a channel with 200 messages, **When** a user joins,
   **Then** the 50 most recent messages are displayed and the view is
   scrolled to the bottom.

2. **Given** the user is viewing the chat, **When** they scroll to the
   top of the loaded messages, **Then** the next batch of older messages
   loads with a progress indicator (hourglass or retro segmented
   progress bar).

3. **Given** older messages are loading, **When** they finish loading,
   **Then** the scroll position stays where the user was reading (no
   jump to top).

4. **Given** the user has scrolled up 100 messages, **When** a new
   message arrives from another user, **Then** the chat does NOT
   auto-scroll, and a floating "New messages ↓" button appears.

5. **Given** the "New messages ↓" button is visible, **When** the user
   clicks it, **Then** the chat scrolls to the most recent message and
   the button disappears.

6. **Given** the user is at the bottom of the chat, **When** a new
   message arrives, **Then** the chat auto-scrolls to show it.

7. **Given** messages are persisted, **When** querying by channel and
   timestamp range, **Then** results return in under 50ms for channels
   with up to 100k messages (indexed cursor pagination).

---

### User Story 9 — Chat Search (Priority: P9)

A user presses `Ctrl+F` (or uses Edit > Find menu) and a 2000s-era
search dialog appears. They type a search term and matching text is
highlighted in yellow within the visible chat. "Find Next" / "Find
Previous" buttons (and Enter / Shift+Enter) navigate between matches.
A counter shows "result X of Y". The search queries the database for
matches beyond the currently loaded messages, loading them if needed.

**Why this priority**: Search enhances usability significantly but is
not required for core chat functionality. It depends on persistence and
infinite scroll working first.

**Independent Test**: Send several messages with a known keyword, open
search, verify highlighting, navigation, and result counter independently.

**Acceptance Scenarios**:

1. **Given** a user presses Ctrl+F, **When** the search dialog opens,
   **Then** it's styled as a retro dialog with TextBox, "Find Next",
   "Find Previous" buttons, and "Case sensitive" checkbox.

2. **Given** the search dialog is open, **When** the user types "elixir",
   **Then** all occurrences of "elixir" in the visible chat are
   highlighted with a yellow background.

3. **Given** matches are highlighted, **When** the user clicks
   "Find Next", **Then** the view scrolls to and focuses the next match,
   and the counter shows "2 of 5" (etc.).

4. **Given** the user is at the last match, **When** they click
   "Find Next", **Then** it wraps to the first match.

5. **Given** "Case sensitive" is checked, **When** searching for "Elixir",
   **Then** "elixir" (lowercase) is NOT highlighted.

6. **Given** matches exist in messages not yet loaded (older history),
   **When** the search requests them, **Then** those messages are loaded
   from the DB and displayed with highlights.

7. **Given** the search dialog is open, **When** the user presses Esc,
   **Then** the dialog closes and highlights are removed.

---

### User Story 10 — Nicklist and User Context Menu (Priority: P10)

The nicklist panel on the right side of a channel shows all members
grouped by role: operators (@) first, then voiced (+), then regular
users — alphabetically sorted within each group. A user count is shown
at the top. Right-clicking a nickname opens a 2000s-era context
menu with options: Query, Whois, and (for operators) Kick, Ban, Give/Take
Op, Give/Take Voice. User presence updates in real time — joins, parts,
nick changes, away status all reflect instantly.

**Why this priority**: The nicklist is visible from P1, but the full
interaction model (context menu, role grouping, real-time presence) is
a refinement that enhances the IRC experience.

**Independent Test**: Join a channel with multiple users of different
roles, verify sorting. Right-click to test context menu actions. Have a
user go away and verify icon change.

**Acceptance Scenarios**:

1. **Given** a channel with operators, voiced, and regular users,
   **When** the nicklist is displayed, **Then** operators (@ prefix) are
   listed first, voiced (+ prefix) second, regulars last, each group
   sorted alphabetically.

2. **Given** the nicklist, **When** a user count is shown at the top,
   **Then** it accurately reflects the number of users in the channel.

3. **Given** a user right-clicks a nickname, **When** the context menu
   opens, **Then** it shows: Query, Whois, separator, and (if the
   clicker is an operator) Kick, Ban, separator, Give Op/Take Op,
   Give Voice/Take Voice.

4. **Given** the context menu, **When** the user clicks "Query", **Then**
   a PM conversation opens with that user.

5. **Given** an operator clicks "Kick" on a user, **When** confirmed,
   **Then** the user is kicked and removed from the nicklist.

6. **Given** a user changes their nickname, **When** the change takes
   effect, **Then** the nicklist updates instantly with the new name in
   the correct alphabetical position.

7. **Given** a user sets themselves as away, **When** their status
   changes, **Then** their nicklist icon becomes dimmed/modified to
   indicate away status.

8. **Given** a non-operator right-clicks a nickname, **When** the context
   menu opens, **Then** Kick, Ban, Give Op/Take Op, Give Voice/Take Voice
   are NOT shown.

---

### User Story 11 — retro Design System and Dark Theme (Priority: P11)

The entire application uses retro design system as the base design system with a custom
dark theme overlay via CSS custom properties. The dark theme is the
default. Windows have 3D beveled borders, title bars with gradients,
sunken panels for text areas. Fonts are monospace in the chat (Fixedsys /
Consolas / Courier New) and the standard retro design system pixel font for UI
elements. All custom components (chat message, treebar, command palette,
context menu, dialogs) are styled consistently with the retro design system foundation.

**Why this priority**: Visual design can be refined iteratively. Core
retro design system integration happens naturally in P1, but the full dark theme with
all custom properties, custom components, and pixel-perfect polish is a
dedicated effort.

**Independent Test**: Visual inspection of every component against
Retro reference screenshots. Verify dark theme colors, 3D borders,
font rendering, and component consistency.

**Acceptance Scenarios**:

1. **Given** the app loads, **When** displayed, **Then** the overall
   appearance matches the retro dark theme aesthetic: dark blue
   backgrounds (#1a1a2e), silver text (#c0c0c0), 3D beveled borders.

2. **Given** any window/panel, **When** inspected, **Then** it uses
   standard retro design system Window component with title bar, borders, and
   appropriate raised/sunken styling.

3. **Given** the chat area, **When** a message is displayed, **Then**
   the font is monospace (Fixedsys / Consolas / Courier New), timestamps
   are in `[HH:MM]` format, nicknames are color-coded from a
   12-color palette.

4. **Given** a system message (join/part/quit), **When** displayed,
   **Then** it appears in gray-blue (#666680).

5. **Given** a NickServ/ChanServ message, **When** displayed, **Then**
   it appears in gold (#d4a017).

6. **Given** an error message, **When** displayed, **Then** it appears
   in red (#cc4444).

7. **Given** an action (/me), **When** displayed, **Then** it appears
   in purple (#9b59b6) as `* nickname action`.

8. **Given** scrollbars, buttons, inputs, **When** inspected, **Then**
   they all use the dark theme colors while maintaining 3D styling.

9. **Given** loading states, **When** active, **Then** a retro
   hourglass cursor or retro segmented progress indicator is shown.

---

### User Story 12 — UX Polish: Sounds, Dialogs, Menu Bar (Priority: P12)

The menu bar is fully functional with keyboard shortcuts (Alt+F for File,
etc.). Confirmation dialogs (kick, ban, drop) use 2000s-era
dialog windows. Optional notification sounds (wav-style) play for new
messages, PMs, and user joins. The toolbar provides quick access to
Connect/Disconnect, Channel List, and Settings. All interaction feedback
follows the classic desktop paradigm — hourglass on loading, beveled buttons
with press states, proper focus management.

**Why this priority**: Polish and sounds are the final layer that make
the experience feel authentic. They can be added last without affecting
core functionality.

**Independent Test**: Navigate all menus, verify keyboard shortcuts work.
Trigger confirmation dialogs, verify they block action until confirmed.
Enable sounds and verify playback on relevant events.

**Acceptance Scenarios**:

1. **Given** the menu bar, **When** the user clicks "File", **Then** a
   dropdown opens with "Disconnect" and "Exit" options.

2. **Given** the menu bar, **When** the user presses Alt+F, **Then** the
   File menu opens via keyboard.

3. **Given** "Edit > Find", **When** clicked, **Then** the search dialog
   opens (same as Ctrl+F).

4. **Given** "View > Toggle Treebar", **When** clicked, **Then** the
   treebar panel shows or hides.

5. **Given** an operator clicks Kick on a user, **When** the action
   triggers, **Then** a retro confirmation dialog appears: "Kick
   user from #channel? [OK] [Cancel]" with optional reason field.

6. **Given** sounds are enabled, **When** a new PM arrives, **Then** a
   retro-style notification sound plays.

7. **Given** the toolbar, **When** the user clicks the Channel List
   icon, **Then** the channel list dialog opens (same as `/list`).

8. **Given** any button in the UI, **When** pressed, **Then** it shows a
   proper retro "pressed" state (sunken 3D border).

---

### Edge Cases

- **Rapid nickname switching**: User changes nick multiple times in quick
  succession — all nicklists and messages must stay consistent.
- **Simultaneous joins**: 100 users join a channel within 1 second —
  the nicklist and system messages must remain ordered and complete.
- **Channel process crash**: If a channel GenServer crashes, the
  supervisor restarts it and state is recovered from PostgreSQL.
- **Browser disconnect without /quit**: The user closes the browser tab
  — Phoenix LiveView detects the socket close and immediately broadcasts
  a quit message to all channels and cleans up all state (no grace
  period, no reconnect window). This is identical to `/quit`.
- **Unicode in messages**: Full Unicode support including emoji, RTL
  text, and CJK characters in messages and nicknames (within IRC rules).
- **Very long messages**: User-authored messages exceeding 1000
  characters are rejected with a red error. System/service messages
  are unconstrained.
- **Empty channels with pending messages**: Messages sent to a channel
  at the exact moment the last user leaves — message is persisted but
  no broadcast needed.
- **NickServ timer race condition**: User identifies at second 59.9 —
  the system must handle the race between the timer and identification
  cleanly.
- **Double registration**: User tries to register an already-registered
  nick — clear error from NickServ.
- **ChanServ access list for deleted nicks**: A nickname on an access
  list is `/ns drop`-ed — the entry remains but has no effect.
- **Mode combination conflicts**: `/mode #chan +m-m` — last flag wins.
- **Self-kick**: Operator tries to `/kick` themselves — should be
  denied or allowed (following IRC convention: denied).
- **Ghost of unregistered nick**: `/ns ghost` for an unregistered nick —
  NickServ responds with error.
- **PubSub message ordering**: Messages must maintain causal ordering
  within a single channel — PubSub through the channel GenServer
  guarantees this.
- **Rate limit burst**: A user sends exactly 5 messages in rapid
  succession (at the limit) — all 5 are delivered; the 6th within the
  same second is rejected. Counter resets after 1 second of no messages.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Identity & Connection
- **FR-001**: System MUST display a retro-style connection dialog
  on first visit with Nickname and Alt Nickname fields.
- **FR-002**: System MUST validate nicknames in real time: max 16 chars,
  no spaces, must start with letter or allowed special char (not number),
  limited special characters per IRC convention.
- **FR-003**: System MUST check nickname uniqueness in real time against
  connected users.
- **FR-004**: System MUST try alt nickname automatically if primary is
  taken; if both taken, assign `Guest_XXXXX` (random 5 digits).
- **FR-005**: System MUST auto-join the user to #lobby after connection.

#### Layout & UI
- **FR-006**: System MUST render the full MDI-style layout: title bar,
  menu bar, toolbar, treebar, chat area, nicklist, status bar.
- **FR-007**: Treebar MUST organize items in sections: Services,
  Channels, Private — with unread indicators (bold/highlight).
- **FR-008**: Status bar MUST show: current nickname, active
  channel/conversation, user count, connection status.
- **FR-009**: Menu bar MUST be functional: File (Disconnect, Exit),
  Edit (Find, Clear Window), View (Toggle Treebar, Toggle Nicklist),
  Help (About, IRC Commands Reference).

#### Channels
- **FR-010**: System MUST create channels on `/join #name` if they don't
  exist; creator becomes operator.
- **FR-011**: Channel names MUST start with `#`, max 50 chars, no spaces.
- **FR-012**: System MUST destroy unregistered channels when the last
  user leaves.
- **FR-013**: System MUST enforce a configurable per-user channel limit
  (default: 10).
- **FR-014**: Channel `#lobby` MUST always exist and MUST be auto-joined.
- **FR-015**: System MUST persist channel messages in PostgreSQL.
- **FR-016**: `/list` MUST display all channels with name, topic, user
  count, and search/filter capability.

#### Chat
- **FR-017**: Messages MUST be broadcast via PubSub within 200ms of
  submission.
- **FR-018**: Messages MUST display as `[HH:MM] <nickname> message`.
- **FR-019**: Nicknames MUST be color-coded via hash to a 12-color
  palette optimized for dark backgrounds.
- **FR-020**: System messages MUST display in gray-blue (#666680).
- **FR-021**: `/me` actions MUST display as `* nickname action` in
  purple (#9b59b6).
- **FR-022**: Service messages MUST display in gold (#d4a017).
- **FR-023**: Error messages MUST display in red (#cc4444).
- **FR-024**: Chat MUST support infinite scroll with cursor-based
  pagination (50 messages per page).
- **FR-025**: Chat MUST NOT auto-scroll when user has scrolled up;
  MUST show "New messages ↓" floating button.
- **FR-026**: Chat MUST auto-scroll when user is at the bottom and
  new messages arrive.
- **FR-027**: System MUST use LiveView streams for message rendering.

#### Private Messages
- **FR-028**: `/query nickname` MUST open a PM window in the treebar.
- **FR-029**: `/msg nickname message` MUST send a PM and open the window.
- **FR-030**: PM notifications MUST show as bold/highlight in treebar.
- **FR-031**: PMs MUST be persisted bidirectionally in PostgreSQL.
- **FR-032**: PMs MUST support the same infinite scroll as channels.

#### Commands
- **FR-033**: Each "/" command MUST be a separate module implementing
  `Handler` behaviour with `execute/2`, `validate/1`, `help/0`.
- **FR-034**: Command palette MUST open on "/" keystroke with real-time
  filtering.
- **FR-035**: Input MUST support ↑/↓ command history (last 50 entries).
- **FR-036**: Input MUST support Tab nickname completion.
- **FR-037**: All 18 commands listed in scope MUST be implemented:
  `/join`, `/part`, `/msg`, `/query`, `/me`, `/nick`, `/topic`, `/kick`,
  `/ban`, `/mode`, `/whois`, `/list`, `/clear`, `/away`, `/quit`,
  `/help`, `/ns`, `/cs`.

#### Channel Modes
- **FR-038**: System MUST support modes: +o, -o, +v, -v, +m, -m, +i, -i,
  +t, -t, +k, -k, +l, -l.
- **FR-039**: Mode combinations MUST be supported (e.g., `/mode +mt`).
- **FR-040**: Mode changes MUST generate system messages visible to all
  channel members.
- **FR-041**: Mode effects MUST be enforced in real time (e.g., +m
  disables input for non-voiced/non-ops).
- **FR-042**: Modes MUST be persisted for ChanServ-registered channels.

#### NickServ
- **FR-043**: `/ns register <password>` MUST register the current
  nickname with bcrypt hashed password.
- **FR-044**: System MUST enforce 60-second identify timer for registered
  nicknames, renaming to `Guest_XXXXX` on timeout.
- **FR-045**: `/ns identify <password>` MUST authenticate the user.
- **FR-046**: `/ns ghost <nickname> <password>` MUST disconnect ghost
  sessions.
- **FR-047**: `/ns info`, `/ns drop`, `/ns help` MUST work as specified.

#### ChanServ
- **FR-048**: `/cs register #channel` MUST register the channel (requires
  NickServ identification). Founder = registering user.
- **FR-049**: Registered channels MUST persist when empty (topic, modes,
  access list).
- **FR-050**: Access list MUST support 4 levels: Founder, SOP, AOP, VOP
  with hierarchical permissions.
- **FR-051**: Auto-privilege MUST be applied on join for identified users
  on the access list.
- **FR-052**: `/cs op`, `/cs deop`, `/cs voice`, `/cs devoice` MUST
  grant/revoke temporary privileges.
- **FR-053**: `/cs info`, `/cs drop`, `/cs help` MUST work as specified.

#### Search
- **FR-054**: `Ctrl+F` and Edit > Find MUST open search dialog.
- **FR-055**: Search MUST highlight matches in yellow within visible chat.
- **FR-056**: Search MUST support "Find Next", "Find Previous", case
  sensitivity toggle, and result counter ("X of Y").
- **FR-057**: Search MUST query the database for matches beyond loaded
  messages.

#### Nicklist
- **FR-058**: Nicklist MUST display users grouped by role (@, +, regular)
  sorted alphabetically within each group.
- **FR-059**: Right-click context menu MUST show role-appropriate options
  (operators see moderation actions).
- **FR-060**: Nicklist MUST update in real time via Phoenix Presence
  (joins, parts, nick changes, away status).

#### Design System
- **FR-061**: UI MUST use retro design system as base design system with dark theme
  as default.
- **FR-062**: Dark theme MUST use the specified color palette: windows
  #1a1a2e, chat #0d0d1a, text #c0c0c0, etc.
- **FR-063**: Chat fonts MUST be monospace (Fixedsys / Consolas /
  Courier New).
- **FR-064**: All custom components (chat message, treebar, command
  palette, context menu, dialogs, scroll loader) MUST be implemented
  as LiveView function components.

#### UX Polish
- **FR-065**: Hourglass cursor MUST display during loading states.
- **FR-066**: Optional notification sounds (wav-style) for PM, new
  message, user join.
- **FR-067**: Confirmation dialogs (kick, ban, drop) MUST use retro
  dialog style.
- **FR-068**: Toolbar MUST provide Connect/Disconnect, Channel List,
  Settings quick actions.

#### Rate Limiting
- **FR-069**: System MUST enforce a per-user message rate limit of 5
  messages per second. Exceeding the limit MUST temporarily mute the
  user (reject messages with a red error: "You are sending messages
  too fast. Please wait.").
- **FR-070**: System MUST enforce a per-user command rate limit of 2
  commands per second. Exceeding the limit MUST reject the command with
  a red error: "You are sending commands too fast. Please wait."
- **FR-071**: Rate limit counters MUST be tracked in-memory (GenServer
  or ETS) per the RateLimit bounded context. No database persistence
  required for rate limit state.
- **FR-072**: Temporary mute duration MUST be brief (e.g., 2-3 seconds)
  and auto-clear. No progressive penalties in Phase 1.

#### Session Lifecycle
- **FR-073**: When a LiveView socket disconnects (browser close, network
  loss, navigation away), the system MUST immediately broadcast a quit
  message to all channels the user was in and clean up all in-memory
  state (Presence, channel membership, NickServ identify timer). No
  grace period or reconnect window.
- **FR-074**: Socket disconnect MUST be functionally identical to
  `/quit` — the user's nickname becomes available immediately.

#### Content Validation
- **FR-075**: User-authored content (messages, actions, topics) MUST be
  limited to 1000 characters. Messages exceeding this limit MUST be
  rejected with a red error: "Message too long (max 1000 characters)."
- **FR-076**: System-generated and service-generated messages MUST NOT
  be subject to the 1000-character limit.

### Key Entities

- **User (Session)**: Nickname, alt nickname, connection timestamp,
  away status, away message, identified (boolean), registered nick
  reference. Exists in-memory (Phoenix Presence / LiveView assigns);
  no persistent user table in Phase 1 beyond NickServ registrations.

- **RegisteredNick**: Nickname, password hash, registered at, last
  seen at. PostgreSQL-persisted. Owned by NickServ context.

- **Channel**: Name, topic, modes (bitmask or map), created at,
  registered (boolean), founder nick. Hot state in GenServer; cold
  state in PostgreSQL for registered channels.

- **ChannelMembership**: Channel reference, user nickname, role
  (operator/voiced/regular), joined at. In-memory in GenServer state;
  system messages persisted as Message records.

- **Message**: ID, channel or PM reference, author nickname, content,
  type (message | action | system | service | error), inserted at
  (timestamp). PostgreSQL-persisted with indexes on (channel, timestamp).

- **PrivateMessage**: ID, sender nickname, recipient nickname, content,
  type, inserted at. PostgreSQL-persisted with indexes for both
  participants.

- **RegisteredChannel**: Channel name, founder nick, registered at,
  topic, modes, created via ChanServ. PostgreSQL-persisted.

- **AccessListEntry**: Channel name, nickname, level (founder | sop |
  aop | vop), added by, added at. PostgreSQL-persisted.

- **Ban**: Channel name, banned nickname, banned by, reason, banned at.
  In GenServer state and optionally persisted for registered channels.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Two users can connect, join #lobby, and exchange messages
  in real time with under 200ms latency end-to-end.

- **SC-002**: A user can create a channel, invite others, apply channel
  modes, and moderate the channel using only "/" commands — all
  functioning correctly.

- **SC-003**: The UI passes visual comparison against mIRC/retro
  reference screenshots at a reasonable fidelity level — retro design system
  components are used correctly with dark theme applied consistently.

- **SC-004**: Infinite scroll loads 50-message pages in under 100ms for
  channels with up to 100k persisted messages.

- **SC-005**: `mix test` passes with 100% of acceptance scenarios covered,
  runs in under 60 seconds, and `mix test --only unit` in under 10
  seconds.

- **SC-006**: `mix format --check-formatted`, `mix credo --strict`, and
  `mix dialyzer` all pass with zero violations.

- **SC-007**: NickServ registration + identification flow completes
  correctly, including the 60-second enforce timer.

- **SC-008**: ChanServ channel registration persists across empty-channel
  periods, and access list auto-privileges are applied on join.

- **SC-009**: Chat search finds matches across loaded and unloaded
  messages, with correct highlighting and navigation.

- **SC-010**: System handles 50 concurrent users across 10 channels
  without degradation (messages delivered within 200ms, no dropped
  messages).
