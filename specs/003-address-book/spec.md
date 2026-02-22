# Feature Specification: Address Book

**Feature Branch**: `003-address-book`
**Created**: 2026-02-11
**Status**: Draft
**Input**: User description: "Address Book for RetroHexChat — unified tabbed dialog (Alt+B) for managing contacts, notify list, nick colors, and ignore rules in a single retro-style interface."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Address Book Dialog Shell (Priority: P1)

A connected user presses Alt+B (or clicks the Address Book toolbar icon) and a tabbed retro-style dialog opens centered on screen. The dialog has four tabs: Contacts, Notify, Nick Colors, and Control. The user can switch between tabs by clicking the tab headers. Pressing Alt+B again or clicking the close button dismisses the dialog. Only one Address Book dialog can be open at a time.

**Why this priority**: The dialog shell is the foundation — without it, none of the four tab features can be accessed. It also establishes the Alt+B shortcut, toolbar icon, and tabbed navigation pattern.

**Independent Test**: Can be fully tested by pressing Alt+B, verifying the dialog appears with four tabs, switching between tabs, and closing the dialog. Delivers value as the navigation container.

**Acceptance Scenarios**:

1. **Given** a connected user in the chat view, **When** the user presses Alt+B, **Then** the Address Book dialog opens centered on screen with four tabs visible: Contacts, Notify, Nick Colors, Control.
2. **Given** the Address Book is open, **When** the user clicks a different tab header, **Then** the tab content area switches to show that tab's content.
3. **Given** the Address Book is open, **When** the user clicks the close button (X) or presses Alt+B again, **Then** the dialog closes.
4. **Given** the Address Book is already open, **When** the user presses Alt+B, **Then** the existing dialog is closed (toggle behavior), not a second one opened.
5. **Given** the Address Book is open, **When** the user clicks the Address Book toolbar icon, **Then** the dialog closes (toggle behavior).

---

### User Story 2 — Contacts Tab (Priority: P2)

A user opens the Address Book and lands on the Contacts tab (default tab). They see a list of their saved contacts displayed in columns: Nickname, Notes, and First Contact Date. The user can add a new contact by clicking "Add", entering a nickname and optional note. They can edit an existing contact's note by selecting it and clicking "Edit". They can remove a contact by selecting it and clicking "Remove". Contacts are the user's personal rolodex — a list of people they want to remember.

**Why this priority**: The Contacts tab is the most novel feature — it introduces a brand-new data concept (personal contacts) that doesn't exist anywhere else in the app. The other tabs are alternate UIs for existing or upcoming features.

**Independent Test**: Can be fully tested by opening Address Book, adding a contact with a note, verifying it appears in the list, editing the note, and removing the contact. Delivers value as a personal contact manager.

**Acceptance Scenarios**:

1. **Given** a user with no contacts, **When** they open the Contacts tab, **Then** the list is empty with a message "No contacts saved".
2. **Given** the Contacts tab is open, **When** the user clicks "Add" and enters nickname "Alice" with note "Met in #elixir", **Then** "Alice" appears in the contacts list with the note and the current date as first contact date.
3. **Given** a contact "Alice" exists, **When** the user selects "Alice" and clicks "Edit", changes the note to "Elixir developer", **Then** the note updates in the list.
4. **Given** a contact "Alice" exists, **When** the user selects "Alice" and clicks "Remove", **Then** "Alice" is removed from the contacts list.
5. **Given** the user is registered and identified, **When** they add a contact, **Then** the contact persists across sessions (survives disconnect/reconnect).
6. **Given** the user is a guest (not identified), **When** they add a contact, **Then** the contact exists in-memory for the current session only.
7. **Given** the user adds a contact, **When** they try to add the same nickname again, **Then** the system shows an error "Contact already exists".

---

### User Story 3 — Notify Tab (Priority: P2)

A user opens the Address Book and switches to the Notify tab. They see the same buddy/notify list data that appears in the standalone Notify List window, displayed in the Address Book's tab format. They can add/remove buddies, edit notes, and toggle notification preferences (auto-whois) — all the same operations available in the Notify List window. Changes made in the Address Book Notify tab are immediately reflected in the standalone Notify List window, and vice versa.

**Why this priority**: Same priority as Contacts because it provides an important alternate access point for an existing core feature. Users who prefer a single unified dialog benefit from managing their notify list here.

**Independent Test**: Can be fully tested by opening Address Book Notify tab, adding a buddy, then checking the standalone Notify List window to verify the change appeared. Delivers value as a consolidated management surface.

**Acceptance Scenarios**:

1. **Given** the user has buddies in their notify list, **When** they open the Notify tab, **Then** they see all buddies with online/offline status, notes, and last seen time.
2. **Given** the Notify tab is open, **When** the user adds a buddy "Bob", **Then** "Bob" appears in both the Notify tab and the standalone Notify List window.
3. **Given** the Notify tab is open, **When** the user selects "Bob" and edits the note, **Then** the updated note is visible in both the Notify tab and the standalone Notify List window.
4. **Given** the Notify tab is open, **When** the user removes "Bob", **Then** "Bob" disappears from both the Notify tab and the standalone Notify List window.
5. **Given** a buddy is added via the standalone Notify List window while the Address Book is open, **When** the user switches to the Notify tab, **Then** the newly added buddy is visible.
6. **Given** the Notify tab is open, **When** the user toggles auto-whois, **Then** the setting changes in both the Notify tab and the standalone Notify List window.

---

### User Story 4 — Nick Colors Tab (Priority: P3)

A user opens the Address Book and switches to the Nick Colors tab. They see a list of custom nick-to-color mappings they have defined. By default the list is empty — all nicknames use the automatic hash-based color. The user can add a custom color for any nickname: they enter the nickname, pick a color from a palette of 16 IRC colors, and confirm. From that point on, that nickname appears in the chosen color everywhere in chat, overriding the hash-based default. The user can also edit or remove custom color assignments.

**Why this priority**: Nick colors are a personalization feature that enhances readability but isn't critical to core communication. It builds on the existing hash-based nick coloring.

**Independent Test**: Can be fully tested by opening Nick Colors tab, assigning a custom color to a nickname, then verifying that nickname appears in the chosen color in chat messages. Delivers value as personalization.

**Acceptance Scenarios**:

1. **Given** the user has no custom nick colors, **When** they open the Nick Colors tab, **Then** the list is empty with a message "No custom colors set. Nicknames use automatic colors."
2. **Given** the Nick Colors tab is open, **When** the user clicks "Add", enters nickname "Alice" and selects red from the color palette, **Then** "Alice → Red" appears in the nick colors list.
3. **Given** "Alice" has a custom red color assigned, **When** Alice sends a message in chat, **Then** Alice's nickname appears in red instead of the hash-based color.
4. **Given** "Alice" has a custom color, **When** the user selects the entry and clicks "Edit", changes the color to blue, **Then** Alice's nickname changes to blue in chat.
5. **Given** "Alice" has a custom color, **When** the user selects the entry and clicks "Remove", **Then** Alice's nickname reverts to the hash-based color in chat.
6. **Given** the user is registered, **When** they add nick color overrides, **Then** overrides persist across sessions.
7. **Given** the user has a custom color for "Alice", **When** Alice changes her nickname to "Alice_AFK", **Then** the override still applies only to the original "Alice" nickname (no automatic tracking).

---

### User Story 5 — Control Tab (Priority: P3)

A user opens the Address Book and switches to the Control tab. They see a list of their ignore rules — each entry shows the ignored nickname, the ignore type (all messages, PMs only, invites only, actions only), and expiration time for temporary ignores. The user can add new ignore rules, edit existing ones (change type or duration), and remove ignore entries. Removing an ignore immediately stops filtering that user's messages. This tab is an alternate UI for the ignore system (Cat F).

**Why this priority**: Depends on the Ignore System (Cat F) being implemented first. Until Cat F exists, this tab shows a placeholder message. Once available, it provides convenient centralized ignore management.

**Independent Test**: Can be fully tested by opening Control tab, adding an ignore rule, verifying the ignored user's messages are filtered, then removing the rule and verifying messages appear again. Delivers value as unified ignore management.

**Acceptance Scenarios**:

1. **Given** the ignore system is not yet implemented, **When** the user opens the Control tab, **Then** they see a message "Ignore management will be available in a future update."
2. **Given** the ignore system is implemented and the user has ignore rules, **When** they open the Control tab, **Then** they see all ignore entries with nickname, type, and expiration.
3. **Given** the Control tab is open, **When** the user adds an ignore rule for "Troll" with type "All messages", **Then** "Troll" appears in the ignore list and Troll's messages are immediately filtered.
4. **Given** an ignore rule exists for "Troll", **When** the user removes the rule via the Control tab, **Then** Troll's messages immediately start appearing again.
5. **Given** a temporary ignore exists (expires in 30 minutes), **When** the user views it in the Control tab, **Then** the remaining time is displayed.
6. **Given** an ignore rule is added via the /ignore command, **When** the user opens the Control tab, **Then** the rule appears in the list.

---

### Edge Cases

- Opening Address Book while the About dialog is open: the Address Book opens normally (they are independent overlays at different z-index levels).
- Attempting to add a contact with an empty nickname: the system rejects the entry with an error message.
- Adding a contact with a nickname longer than 16 characters: rejected (matches the existing nickname length constraint).
- Adding more than 100 contacts: the system rejects with "Contact list is full (maximum 100)".
- Adding more than 50 nick color overrides: the system rejects with "Color list is full (maximum 50)".
- Switching tabs while an add/edit dialog is open within a tab: the dialog closes and the tab switches.
- A buddy goes online/offline while the Notify tab is visible: the online status updates in real time.
- The Alt+B shortcut is pressed while the chat input has focus: the Address Book opens (the shortcut takes priority over text input for Alt-key combinations).
- Right-clicking a nickname that is already a contact and selecting "Add to Contacts": the system shows an error "Contact already exists".
- Right-clicking a nickname and selecting "Set Nick Color" when 50 overrides already exist: the system shows an error "Color list is full (maximum 50)".

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a tabbed Address Book dialog accessible via Alt+B keyboard shortcut and a toolbar icon.
- **FR-002**: The Address Book dialog MUST display four tabs: Contacts, Notify, Nick Colors, and Control.
- **FR-003**: The dialog MUST open centered on screen with a 2000s-era appearance using retro tab control styling.
- **FR-004**: Only one Address Book dialog instance MUST be open at a time (toggle open/close).
- **FR-005**: The Contacts tab MUST display a scrollable list with columns: Nickname, Notes, First Contact Date, sorted alphabetically by nickname (case-insensitive).
- **FR-006**: Users MUST be able to add, edit (notes only), and remove contacts from the Contacts tab.
- **FR-007**: The system MUST validate contact entries: nickname required, max 16 characters, no duplicates, max 100 entries.
- **FR-008**: Contact notes MUST support up to 200 characters.
- **FR-009**: The Notify tab MUST display the same buddy list data as the standalone Notify List window.
- **FR-010**: Changes to the notify list in the Address Book MUST be immediately reflected in the standalone Notify List window, and vice versa.
- **FR-011**: The Notify tab MUST support add, remove, edit notes, and toggle auto-whois operations.
- **FR-012**: The Nick Colors tab MUST display a list of nickname-to-color override mappings.
- **FR-013**: Users MUST be able to add, edit, and remove custom nick color assignments.
- **FR-014**: The color picker MUST offer the 16 standard IRC colors for selection.
- **FR-015**: Custom nick colors MUST override the automatic hash-based color in all nickname displays, including chat messages, nicklist panel, whois results, notify list entries, and context menu target.
- **FR-016**: The Control tab MUST display ignore list entries with nickname, ignore type, and expiration time.
- **FR-017**: If the ignore system is not yet implemented, the Control tab MUST show a placeholder message.
- **FR-018**: Users MUST be able to add, edit, and remove ignore rules from the Control tab (when the ignore system is available).
- **FR-019**: Removing an ignore rule MUST immediately stop filtering that user's messages.
- **FR-020**: All Address Book data MUST persist across sessions for registered (identified) users.
- **FR-021**: Guest users MUST have in-memory-only Address Book data for the current session.
- **FR-022**: The Address Book toolbar icon MUST be added to the main toolbar area.
- **FR-023**: The Contacts tab MUST be the default tab shown when the Address Book opens.
- **FR-024**: Nick color overrides MUST be limited to 50 entries maximum.
- **FR-025**: The nick right-click context menu MUST include an "Add to Contacts" option that adds the target nickname to the contacts list (or shows an error if already a contact).
- **FR-026**: The nick right-click context menu MUST include a "Set Nick Color" option that opens a color picker allowing the user to assign a custom color to the target nickname.

### Key Entities

- **Contact**: A personal address book entry representing a remembered user. Attributes: owner nickname, contact nickname, note (optional, max 200 chars), first contact date. One contact per unique nickname per owner.
- **NickColorOverride**: A custom color assignment for a specific nickname. Attributes: owner nickname, target nickname, color (one of 16 IRC colors). One override per unique target nickname per owner.
- **NotifyEntry** *(existing)*: A buddy list entry tracking online/offline status. Managed by the existing Notify List system; the Address Book provides an alternate UI.
- **IgnoreRule** *(future, Cat F)*: A rule defining which users to ignore and how. Managed by the future Ignore System; the Address Book provides an alternate UI.

## Assumptions

- The Contacts tab is a new feature — no contacts data store exists yet and will be created as part of this feature.
- Nick color overrides are a new feature — no override data store exists yet and will be created as part of this feature.
- The Notify List (Cat B / feature 002) is already implemented and its data structures/APIs are available for reuse.
- The Ignore System (Cat F) is not yet implemented — the Control tab will show a placeholder until Cat F is available.
- The 16 IRC colors for nick color selection match the same palette used in the formatting toolbar color picker.
- Contact first_contact_date is set automatically to the current timestamp when the contact is added and is not editable.
- The Address Book dialog does not support drag/move — it stays centered (consistent with the existing About dialog pattern).
- Tab switching preserves each tab's scroll position and selection state within the same dialog session.

## Dependencies

- **Notify List (002)**: Must be implemented. The Notify tab reads/writes the same data. *(Already complete)*
- **Ignore System (Cat F)**: Should be implemented for the Control tab to be fully functional. Without it, a placeholder is shown.

## Clarifications

### Session 2026-02-11

- Q: Should custom nick color overrides apply only in chat messages, or in all nickname displays (nicklist, whois, notify list, context menu)? → A: All nickname displays — overrides apply everywhere a nickname appears.
- Q: Should the nick right-click context menu include "Add to Contacts" and/or "Set Nick Color" shortcuts? → A: Both — add "Add to Contacts" and "Set Nick Color" to the context menu for quick access.
- Q: What is the default sort order for the Contacts list? → A: Alphabetical by nickname (case-insensitive), consistent with nicklist and notify list sorting.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can open the Address Book, switch between all four tabs, and close the dialog in under 3 seconds total interaction time.
- **SC-002**: Users can add a new contact with a note in under 10 seconds (open dialog → Add → fill fields → confirm).
- **SC-003**: Users can assign a custom nick color and see the change reflected in chat messages immediately (no page refresh required).
- **SC-004**: Changes made in the Notify tab are visible in the standalone Notify List window within 1 second (real-time synchronization).
- **SC-005**: All Address Book operations (add, edit, remove) across all tabs complete without page reload or loss of chat context.
- **SC-006**: Registered users' contacts and nick colors persist correctly across disconnect/reconnect cycles with zero data loss.
- **SC-007**: 100% of Address Book operations are accessible via both the Alt+B dialog and any equivalent command-line commands.
