# Feature Specification: Scripting & Aliases (Simplified)

**Feature Branch**: `018-scripting-aliases`
**Created**: 2026-02-12
**Status**: Draft
**Input**: User description: "Scripting & Aliases (Simplified) for RetroHexChat — aliases with variable expansion, timers, custom popup menu items, and simple auto-respond rules"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Alias Creation and Expansion (Priority: P1)

A user frequently types the same command sequences. They open the Alias Editor dialog (via the Tools menu or `/alias` command) and create an alias with a name and an expansion string. The alias name starts with `/` (e.g., `/hi`). The expansion can contain variables like `$1`, `$2` (positional arguments), `$nick` (own nickname), and `$chan` (current channel name). When the user types the alias name in the input box, the system expands it by substituting variables with actual values and executes the resulting command (or sends as plain text).

**Why this priority**: Aliases are the foundational building block of the entire feature. Every other subsystem (custom menus, auto-respond) relies on the ability to define and expand command strings with variables. Without aliases, the feature has no core value.

**Independent Test**: Can be fully tested by creating an alias via the editor dialog and typing it in the chat input. Delivers immediate value — any user who types repetitive commands benefits.

**Acceptance Scenarios**:

1. **Given** a user has no aliases, **When** they open the Alias Editor (via menu or `/alias`), **Then** they see an empty list with controls to add a new alias (name field, expansion field, Add button).
2. **Given** the Alias Editor is open, **When** the user enters name `/hi` and expansion `/me says hello everyone!` and clicks Add, **Then** the alias appears in the list and a confirmation message is shown.
3. **Given** alias `/hi` exists with expansion `/me says hello everyone!`, **When** the user types `/hi` in a channel, **Then** the system executes `/me says hello everyone!` (an action message appears in the channel).
4. **Given** alias `/greet` exists with expansion `/me waves at $1`, **When** the user types `/greet Alice`, **Then** the system executes `/me waves at Alice`.
5. **Given** alias `/info` exists with expansion `I am $nick in $chan`, **When** the user types `/info` in channel #general while their nickname is "Bob", **Then** the message `I am Bob in #general` is sent to the channel.
6. **Given** alias `/greet` expects `$1`, **When** the user types `/greet` with no arguments, **Then** `$1` is replaced with an empty string (the command still executes).
7. **Given** the user creates alias `/join` which shadows the built-in `/join` command, **When** they save it, **Then** a warning is displayed ("This alias shadows built-in command /join. The alias will take priority.") but the alias is still saved.
8. **Given** alias A expands to alias B which expands to alias A (recursive), **When** the user tries to execute alias A, **Then** the system detects the recursion (max depth 5) and shows an error: "Alias expansion aborted: recursive alias detected."
9. **Given** a user creates an alias with expansion `/me greets | /notice $1 hi` (multiple commands separated by pipe), **When** they save it, **Then** the system rejects it with error: "Aliases cannot contain multiple commands. Use a single command per alias."
10. **Given** the user edits an existing alias and changes its expansion, **When** they save, **Then** the updated expansion is used on next invocation.
11. **Given** the user deletes an alias from the editor, **When** they confirm deletion, **Then** the alias is removed and no longer expands when typed.

---

### User Story 2 - Timer Commands (Priority: P2)

A user wants to schedule a command to run once after a delay, or to repeat at regular intervals. They use the `/timer` command to create, list, and cancel timers. Timers are session-only — they do not survive page reload or disconnection.

**Why this priority**: Timers add dynamic automation that complements aliases. They provide unique value (scheduled execution) that no other feature offers, and are commonly used in IRC clients for reminders and periodic actions.

**Independent Test**: Can be fully tested by creating a one-shot timer with `/timer`, waiting for it to fire, verifying the command executes. Also test repeat timers and cancellation. No database required — fully in-memory.

**Acceptance Scenarios**:

1. **Given** a user is connected, **When** they type `/timer remind 5 /me says time is up`, **Then** a confirmation message shows "Timer 'remind' set: will fire in 5 seconds" and after 5 seconds, `/me says time is up` is executed in the active channel.
2. **Given** a user is connected, **When** they type `/timer heartbeat repeat 10 /me is still here`, **Then** a confirmation shows "Timer 'heartbeat' set: repeats every 10 seconds" and the command fires every 10 seconds until stopped.
3. **Given** two timers are active, **When** the user types `/timer list`, **Then** a system message lists each timer's name, type (once/repeat), interval, remaining time (for one-shot) or next fire time, and command.
4. **Given** timer 'heartbeat' is active, **When** the user types `/timer stop heartbeat`, **Then** a confirmation shows "Timer 'heartbeat' stopped" and the timer no longer fires.
5. **Given** a user already has 5 active timers, **When** they try to create a 6th, **Then** an error message shows "Maximum number of active timers (5) reached. Stop an existing timer first."
6. **Given** a user has active timers, **When** they disconnect or reload the page, **Then** all timers are cancelled (session-only, no persistence).
7. **Given** a user types `/timer` with no arguments, **Then** a help/usage message is shown explaining syntax.
8. **Given** a timer name already exists, **When** the user creates a new timer with the same name, **Then** the old timer is replaced with the new one and a message confirms "Timer 'name' replaced."
9. **Given** a timer command references an alias, **When** the timer fires, **Then** the alias is expanded before execution.
10. **Given** a user specifies a minimum interval below 10 seconds for a repeating timer, **When** they submit the command, **Then** the interval is clamped to 10 seconds with a notice: "Minimum repeat interval is 10 seconds."

---

### User Story 3 - Custom Popup Menu Items (Priority: P3)

A user wants to add custom actions to the right-click context menus on nicknames (nicklist) and channel tabs. They open the Custom Menus editor (via the Tools menu or `/popups` command) and define menu items with a label and command string. The command string supports the same variables as aliases (`$1` for the right-clicked nick or channel name, `$nick`, `$chan`).

**Why this priority**: Custom menus provide a convenient UI-driven way to trigger actions, building on the alias variable system. They enhance usability for less command-line-oriented users, but depend on the alias/variable infrastructure from P1.

**Independent Test**: Can be tested by adding a custom menu item via the editor, right-clicking a nick in the nicklist, verifying the custom item appears appended to the built-in items, and clicking it to execute the command.

**Acceptance Scenarios**:

1. **Given** a user has no custom menu items, **When** they open the Custom Menus editor, **Then** they see two tabs (Nicklist, Channel) each with an empty list and controls to add items.
2. **Given** the user adds a nicklist menu item with label "Send greeting" and command `/notice $1 Welcome!`, **When** they right-click a nick "Alice" in the nicklist, **Then** the built-in context menu appears with "Send greeting" appended at the bottom (after a separator), and clicking it sends `/notice Alice Welcome!`.
3. **Given** the user adds a channel menu item with label "Announce topic" and command `/me announces the topic of $chan`, **When** they right-click a channel tab, **Then** "Announce topic" appears appended to the channel context menu.
4. **Given** custom menu items exist, **When** the user right-clicks, **Then** built-in context menu items are shown first, followed by a visual separator, followed by custom items. Custom items never replace built-in items.
5. **Given** a custom menu item references an alias that has been deleted, **When** the user clicks the menu item, **Then** the system attempts to execute the command as-is (it may result in "Unknown command" if the alias was the only handler).
6. **Given** the user deletes a custom menu item from the editor, **When** they right-click next, **Then** the item no longer appears.
7. **Given** a user has defined custom nicklist items, **When** they type `/popups`, **Then** the Custom Menus editor dialog opens.

---

### User Story 4 - Auto-Respond Rules (Priority: P4)

A user wants to automatically respond to events like someone joining a specific channel. They open the Auto-Respond editor (via the Tools menu or `/autorespond` command) and define rules. Each rule has a trigger event (e.g., "on join"), an optional channel filter, and a response command string with variable expansion.

**Why this priority**: Auto-respond is the most advanced subsystem, depending on alias variable expansion and PubSub event integration. It provides powerful automation but is used by fewer users and has more potential for abuse (requiring rate limiting).

**Independent Test**: Can be tested by creating a rule "on join #test → /notice $nick Welcome!", having another user join #test, and verifying the notice is sent. Rate limiting can be verified by triggering multiple joins in quick succession.

**Acceptance Scenarios**:

1. **Given** a user has no auto-respond rules, **When** they open the Auto-Respond editor, **Then** they see an empty list with controls to add a rule (trigger event dropdown, channel filter field, response command field).
2. **Given** the user creates a rule: trigger "on join", channel "#welcome", command `/notice $nick Welcome to #welcome!`, **When** another user joins #welcome, **Then** the system sends `/notice <joiner_nick> Welcome to #welcome!`.
3. **Given** an auto-respond rule exists for "on join" in "#welcome", **When** the rule owner themselves joins #welcome, **Then** the auto-respond does NOT fire (a user's own actions never trigger their own auto-respond rules).
4. **Given** an auto-respond rule fires for user Alice joining, **When** Alice leaves and rejoins within 60 seconds, **Then** the auto-respond does NOT fire again (rate limit: max 1 response per triggering user per rule per 60 seconds).
5. **Given** a rule has no channel filter (empty), **When** the trigger event occurs in any channel the user is in, **Then** the auto-respond fires (global rule).
6. **Given** the user has more than 10 auto-respond rules, **When** they try to create an 11th, **Then** an error shows "Maximum number of auto-respond rules (10) reached."
7. **Given** available trigger events are: "on join", "on part", "on nick change", **When** the user opens the trigger event dropdown, **Then** these three options are shown.
8. **Given** the user deletes an auto-respond rule, **When** the corresponding event occurs, **Then** no auto-response fires.

---

### User Story 5 - Alias Editor Dialog UI (Priority: P2)

A user interacts with the Alias Editor through a 2000s-erad dialog that provides CRUD operations for aliases. The dialog is accessible via the Tools menu and the `/alias` command with no arguments.

**Why this priority**: The dialog is essential for P1 alias functionality — while aliases can be managed via commands (`/alias add`, `/alias remove`, `/alias list`), the dialog provides the primary user-friendly interface expected in a mIRC-style client.

**Independent Test**: Can be tested by opening the dialog, adding/editing/removing aliases, and verifying changes are reflected both in the dialog list and in alias expansion behavior.

**Acceptance Scenarios**:

1. **Given** a user clicks Tools > Alias Editor or types `/alias`, **When** the dialog opens, **Then** it shows a list of existing aliases (name and expansion) with Add, Edit, Remove buttons and a Close button.
2. **Given** the user clicks Add, **When** they enter a name without the `/` prefix, **Then** the system auto-prepends `/` to the name.
3. **Given** the user selects an alias and clicks Edit, **When** they modify the expansion and save, **Then** the alias is updated in the list.
4. **Given** a registered user adds an alias, **When** they disconnect and reconnect, **Then** their aliases are loaded from the database and available immediately.
5. **Given** a guest user adds an alias, **When** they disconnect, **Then** the aliases are lost (session-only for guests).

---

### Edge Cases

- **Recursive alias detection**: Alias A → Alias B → Alias A must be detected within 5 levels of expansion depth and aborted with a clear error message.
- **Empty alias name or expansion**: Rejected with validation error.
- **Alias name with spaces**: Rejected — alias names must be single words (letters, numbers, hyphens, underscores).
- **Very long expansion string**: Limited to 500 characters to prevent abuse.
- **Timer with negative or zero interval**: Rejected with error message.
- **Timer with extremely large interval**: Capped at 86400 seconds (24 hours).
- **Custom menu item with empty label or command**: Rejected with validation error.
- **Auto-respond command that would trigger another auto-respond**: Auto-respond commands are marked as "auto-generated" and do not trigger other auto-respond rules (prevents cascading).
- **Variable `$chan` used when not in a channel (e.g., in PM context)**: Replaced with empty string.
- **Multiple pipe characters `|` in alias expansion**: The entire expansion is checked for command separators (`|`, `&&`, `;`, newlines) and rejected if found.

## Requirements *(mandatory)*

### Functional Requirements

**Aliases**

- **FR-001**: System MUST allow users to create aliases with a unique name (starting with `/`) and an expansion string.
- **FR-002**: System MUST expand alias variables (`$1`, `$2`, ..., `$nick`, `$chan`) when an alias is invoked.
- **FR-003**: System MUST detect recursive alias expansion (max depth 5) and abort with an error.
- **FR-004**: System MUST reject alias expansions containing command chaining characters (`|`, `&&`, `;`, newlines).
- **FR-005**: System MUST show a warning when creating an alias that shadows a built-in command, but still allow creation.
- **FR-006**: System MUST provide CRUD operations for aliases via both the Alias Editor dialog and `/alias` commands (`/alias add <name> <expansion>`, `/alias remove <name>`, `/alias list`).
- **FR-007**: System MUST limit alias names to alphanumeric characters, hyphens, and underscores (after the `/` prefix), max 30 characters.
- **FR-008**: System MUST limit alias expansion strings to 500 characters.
- **FR-009**: System MUST persist aliases for registered users across sessions. Guest aliases are session-only.
- **FR-010**: Alias lookup MUST take priority over built-in commands when both exist for the same name.

**Timers**

- **FR-011**: System MUST support one-shot timers via `/timer <name> <seconds> <command>`.
- **FR-012**: System MUST support repeating timers via `/timer <name> repeat <seconds> <command>`.
- **FR-013**: System MUST support timer management: `/timer list` to show active timers, `/timer stop <name>` to cancel.
- **FR-014**: System MUST limit concurrent timers to 5 per user.
- **FR-015**: System MUST enforce a minimum repeat interval of 10 seconds for repeating timers.
- **FR-016**: System MUST cap maximum timer interval at 86400 seconds (24 hours).
- **FR-017**: Timers MUST be session-only — they do not persist across page reloads or disconnections.
- **FR-018**: When a timer fires, the command MUST be expanded (alias + variable substitution) and executed in the context of the user's currently active channel.
- **FR-019**: Creating a timer with an existing name MUST replace the old timer.

**Custom Popup Menus**

- **FR-020**: System MUST allow users to add custom items to the nicklist right-click context menu.
- **FR-021**: System MUST allow users to add custom items to the channel tab right-click context menu.
- **FR-022**: Custom menu items MUST be appended after built-in items, separated by a visual divider. They MUST NOT replace built-in items.
- **FR-023**: Custom menu item commands MUST support the same variable expansion as aliases (`$1` = right-clicked nick or channel name, `$nick`, `$chan`).
- **FR-024**: System MUST provide CRUD operations for custom menu items via the Custom Menus editor dialog and `/popups` command.
- **FR-025**: System MUST persist custom menu items for registered users. Guest custom menus are session-only.
- **FR-026**: System MUST limit custom menu items to 10 per menu type (nicklist, channel).

**Auto-Respond**

- **FR-027**: System MUST support auto-respond rules with: trigger event, optional channel filter, and response command.
- **FR-028**: Available trigger events MUST include: "on join", "on part", "on nick change".
- **FR-029**: Auto-respond MUST NOT be triggered by the rule owner's own actions.
- **FR-030**: Auto-respond MUST enforce rate limiting: maximum 1 response per triggering user per rule per 60 seconds.
- **FR-031**: Auto-respond commands MUST be marked as auto-generated to prevent cascading triggers.
- **FR-032**: System MUST limit auto-respond rules to 10 per user.
- **FR-033**: System MUST provide CRUD operations via the Auto-Respond editor dialog and `/autorespond` command.
- **FR-034**: System MUST persist auto-respond rules for registered users. Guest rules are session-only.
- **FR-035**: Auto-respond response commands MUST support the same variable expansion as aliases.

**General**

- **FR-036**: All editor dialogs (Alias, Custom Menus, Auto-Respond) MUST be accessible from the Tools menu and via slash commands.
- **FR-037**: System MUST provide help documentation for all new commands and features.

### Key Entities

- **Alias**: Represents a user-defined command shortcut. Attributes: name (unique per user, starts with `/`), expansion (command string with optional variables), owner (user nickname).
- **Timer**: Represents a scheduled command execution. Attributes: name (unique per user), type (once/repeat), interval (seconds), command (expansion string), owner, created_at, next_fire_at. Session-only, not persisted.
- **Custom Menu Item**: Represents a user-defined context menu entry. Attributes: menu_type (nicklist/channel), label (display text), command (expansion string with variables), position (ordering), owner.
- **Auto-Respond Rule**: Represents an event-triggered automatic command. Attributes: trigger_event (join/part/nick_change), channel_filter (optional, specific channel or empty for all), command (expansion string), owner, enabled flag.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can create and use an alias within 30 seconds of opening the Alias Editor, reducing repetitive typing for common commands.
- **SC-002**: Alias expansion including variable substitution completes instantly (no perceptible delay to the user) for all supported variable types.
- **SC-003**: Recursive alias chains are detected and reported to the user within 1 second, without any system hang or crash.
- **SC-004**: Timer commands fire within 2 seconds of their scheduled time, providing reliable automation for users.
- **SC-005**: Custom popup menu items appear in context menus without displacing or hiding any built-in menu options.
- **SC-006**: Auto-respond rules fire reliably for the specified trigger events while respecting the rate limit, preventing any user from being spammed more than once per minute per rule.
- **SC-007**: All editor dialogs (Alias, Custom Menus, Auto-Respond) are visually consistent with existing retro-styled dialogs in the application.
- **SC-008**: Registered users' aliases, custom menus, and auto-respond rules persist across sessions with zero data loss.
- **SC-009**: Guest users can use all features during their session without errors, understanding that data is session-only.

## Assumptions

- **A-001**: The "pipe" character `|` is treated as a command separator for the purpose of chaining detection. If the user needs a literal `|` in text, they should use it in plain message aliases (non-command expansions), where it is harmless.
- **A-002**: Timer interval precision is "best effort" — the system targets the specified delay but does not guarantee millisecond accuracy due to process scheduling.
- **A-003**: The variable `$1` in custom nicklist menu commands refers to the right-clicked nickname. In channel menu commands, `$1` refers to the right-clicked channel name.
- **A-004**: Alias names are case-insensitive (e.g., `/Hi` and `/hi` are treated as the same alias).
- **A-005**: The Tools menu is the primary access point for all editor dialogs, consistent with mIRC's menu structure.
- **A-006**: Auto-respond rate limit cooldowns are tracked in-memory per session and reset on disconnect.

## Scope Boundaries

**In Scope**:
- Alias system with full variable expansion ($1–$9, $nick, $chan)
- Alias Editor dialog (retro-styled)
- `/alias` command (add, remove, list subcommands)
- `/timer` command (one-shot, repeat, list, stop)
- Custom popup menu editor and integration with existing context menus
- `/popups` command
- Auto-respond rules with event triggers (join, part, nick change)
- `/autorespond` command
- Help documentation for all new commands and features
- Persistence for registered users (aliases, custom menus, auto-respond rules)

**Out of Scope**:
- Full scripting language, conditional logic, loops, or branching
- File I/O or external system access
- Regex matching or pattern-based triggers
- Event scripting beyond the three specified trigger types
- Command chaining (multiple commands per alias)
- Timer persistence across sessions
- Inline alias expansion (aliases work only as commands, not mid-sentence)
