# Feature Specification: Favorites / Bookmarks

**Feature Branch**: `015-favorites`
**Created**: 2026-02-12
**Status**: Draft
**Input**: User description: "Favorites / Bookmarks for RetroHexChat — channel bookmarking with auto-join, Favorites menu, Organize dialog, and context menu integration."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Add and Use Favorites (Priority: P1)

A user regularly visits #elixir and wants quick access to it. They right-click the channel in the treebar and select "Add to Favorites". A Windows 98-style dialog appears with the channel name pre-filled, an optional description field, an optional password field (masked), and an "Auto-join on connect" checkbox. They fill in a description and save.

Now the "Favorites" menu in the menu bar shows #elixir. Clicking it joins the channel instantly. If the user is already in the channel, clicking the favorite switches to it instead of attempting to rejoin. The Favorites menu shows a checkmark next to channels the user is currently in.

**Why this priority**: Core value proposition — without the ability to add and use favorites, no other feature in this spec delivers value.

**Independent Test**: Add a channel to favorites via treebar context menu, verify it appears in the Favorites menu, click it to join/switch to the channel.

**Acceptance Scenarios**:

1. **Given** a user is in #elixir, **When** they right-click the channel in the treebar and select "Add to Favorites", **Then** a dialog appears with #elixir pre-filled in the channel name field.
2. **Given** the Add Favorite dialog is open with a channel name, **When** the user fills in an optional description and clicks OK, **Then** the favorite is saved and appears in the Favorites menu.
3. **Given** a favorite exists for #elixir and the user is not in it, **When** they click #elixir in the Favorites menu, **Then** the system joins #elixir.
4. **Given** a favorite exists for #elixir and the user is already in it, **When** they click #elixir in the Favorites menu, **Then** the system switches to #elixir without attempting to rejoin.
5. **Given** the user is currently in #elixir and it is a favorite, **When** they open the Favorites menu, **Then** #elixir is shown with a checkmark indicator.
6. **Given** a favorite exists for a +k channel with a saved password, **When** the user clicks it in the Favorites menu, **Then** the system joins using the saved password.
7. **Given** a favorite with a saved password and the channel password has changed, **When** the user clicks the favorite, **Then** the join fails with a "Wrong channel key" message.

---

### User Story 2 - Organize Favorites (Priority: P2)

A user has accumulated several favorites and wants to reorder, edit, or remove them. They open the Organize Favorites dialog from the Favorites menu. The dialog shows an ordered list of all favorites. Each entry shows the channel name and description (passwords are shown as "Password set" rather than plain text). The user can reorder entries with Up/Down buttons, edit entries to change description/password/auto-join settings, and remove entries. The order set here determines the display order in the Favorites menu.

**Why this priority**: Managing favorites is essential once a user has more than a few. Without it, the feature becomes cumbersome over time.

**Independent Test**: Add multiple favorites, open Organize Favorites, reorder them, verify the Favorites menu reflects the new order.

**Acceptance Scenarios**:

1. **Given** multiple favorites exist, **When** the user opens Organize Favorites, **Then** all favorites are shown in their current order with channel name and description.
2. **Given** a favorite has a saved password, **When** it appears in the Organize dialog, **Then** the password is shown as "Password set" (not in plain text).
3. **Given** a favorite is selected in the list, **When** the user clicks the Up button, **Then** the favorite moves up one position in the list.
4. **Given** a favorite is selected, **When** the user clicks Edit, **Then** the Add/Edit Favorite dialog opens pre-filled with the favorite's current values.
5. **Given** a favorite is selected, **When** the user clicks Remove and confirms, **Then** the favorite is deleted from the list.
6. **Given** the user reorders favorites and clicks OK, **When** they open the Favorites menu, **Then** favorites appear in the new order.

---

### User Story 3 - Auto-Join Favorites on Connect (Priority: P3)

A user has marked several favorites with the "Auto-join on connect" checkbox. When they connect to RetroHexChat, those channels are automatically joined without needing to type /join commands. Only favorites with auto-join enabled are joined; others remain in the favorites list but are not joined automatically.

**Why this priority**: Reduces repetitive manual work on each session start but depends on favorites existing first (US1).

**Independent Test**: Create favorites with auto-join enabled and disabled, reconnect, verify only auto-join favorites are joined.

**Acceptance Scenarios**:

1. **Given** a favorite for #elixir has auto-join enabled, **When** the user connects, **Then** #elixir is automatically joined.
2. **Given** a favorite for #general has auto-join disabled, **When** the user connects, **Then** #general is not automatically joined.
3. **Given** multiple favorites have auto-join enabled, **When** the user connects, **Then** all auto-join favorites are joined in their favorites order.
4. **Given** a favorite with auto-join and a saved password, **When** the user connects, **Then** the channel is joined using the saved password.

---

### User Story 4 - Duplicate and Update Handling (Priority: P4)

When a user tries to add a favorite for a channel that already exists in their favorites, the system offers to update the existing entry rather than creating a duplicate. This prevents confusion from having multiple entries for the same channel.

**Why this priority**: Polish feature that prevents data inconsistency, but the core experience works without it.

**Independent Test**: Add a favorite for #elixir, try to add #elixir again, verify the system offers to update instead of duplicating.

**Acceptance Scenarios**:

1. **Given** a favorite for #elixir already exists, **When** the user tries to add #elixir to favorites again, **Then** the system shows the existing entry in edit mode with a message indicating it already exists.
2. **Given** the edit-existing prompt is shown, **When** the user modifies and saves, **Then** the existing favorite is updated (not duplicated).

---

### Edge Cases

- What happens when a user adds a favorite for a channel that no longer exists? The favorite is still saved; joining it will create or join the channel as normal.
- What happens when the favorites list is empty? The Favorites menu shows "No favorites" (disabled item) and the "Organize Favorites" option.
- What happens when a user tries to move the first favorite up or the last one down? The Up/Down buttons are disabled at the boundaries.
- What happens if a guest user adds favorites? Favorites are stored in-session and lost on disconnect (consistent with other guest data behavior in the application).
- What happens when the user has many favorites (e.g., 50+)? The Favorites menu scrolls if needed; no arbitrary limit is imposed.
- What happens if auto-join favorites include a channel the user was banned from? The join fails silently with a system message in the status window, and the remaining auto-joins continue.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to add a channel to favorites via a treebar context menu option "Add to Favorites".
- **FR-002**: System MUST display an Add/Edit Favorite dialog with fields: channel name (required, pre-filled), description (optional, free text), password (optional, masked input), and auto-join checkbox.
- **FR-003**: System MUST display a "Favorites" top-level menu in the menu bar showing all saved favorites in user-defined order.
- **FR-004**: System MUST join the channel when a favorite is clicked in the Favorites menu, using the saved password if one exists.
- **FR-005**: System MUST switch to the channel (not rejoin) when clicking a favorite for a channel the user is already in.
- **FR-006**: System MUST show a checkmark indicator next to favorited channels the user is currently joined to.
- **FR-007**: System MUST provide an "Organize Favorites" dialog accessible from the Favorites menu with reorder (Up/Down), Edit, and Remove functionality.
- **FR-008**: System MUST persist favorites order as set in the Organize Favorites dialog.
- **FR-009**: System MUST mask saved passwords — passwords must never be displayed in plain text in any UI element (show "Password set" indicator or asterisks).
- **FR-016**: System MUST store favorite passwords encrypted at rest using reversible encryption with a server-side key, since passwords must be recoverable for programmatic channel joins.
- **FR-010**: System MUST auto-join favorites marked with "Auto-join on connect" when the user connects.
- **FR-011**: System MUST NOT auto-join favorites that do not have the auto-join setting enabled.
- **FR-012**: System MUST detect when a user attempts to add a duplicate favorite and offer to update the existing entry instead.
- **FR-013**: System MUST persist favorites across sessions for registered (identified) users.
- **FR-014**: System MUST store favorites in-session only for guest users (lost on disconnect).
- **FR-015**: System MUST display a graceful error message when joining a favorite fails due to a wrong channel key.

### Key Entities

- **Favorite**: Represents a bookmarked channel. Attributes: channel name (unique per user), description (optional text), password (optional, encrypted at rest with reversible server-side key — must be decryptable for channel joins), auto-join flag (boolean), display order (integer position).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can add a channel to favorites in under 5 seconds (right-click, select, fill dialog, save).
- **SC-002**: Users can join a favorited channel in 1 click from the Favorites menu.
- **SC-003**: Users can reorder, edit, or remove any favorite within the Organize dialog without needing to re-add entries.
- **SC-004**: Auto-join favorites connect the user to all marked channels within 2 seconds of connecting.
- **SC-005**: 100% of favorites persist correctly across sessions for registered users.
- **SC-006**: Passwords are never visible in plain text in any UI surface.

## Scope

### In Scope

- Favorites management: add, edit, remove, reorder
- Favorites menu in the menu bar with checkmark indicators
- "Add to Favorites" option in treebar channel context menu
- Auto-join favorites on connect
- Organize Favorites dialog with Up/Down/Edit/Remove
- Per-favorite password storage (masked)
- Persistence for registered users, in-session for guests

### Out of Scope

- Folder or group organization for favorites (flat list only)
- Favorites sync between devices
- Favorites import/export
- Custom icons or colors per favorite

## Clarifications

### Session 2026-02-12

- Q: How should favorite passwords be stored at rest? → A: Encrypted at rest with reversible server-side key (passwords must be decryptable for channel joins).

## Assumptions

- The existing treebar context menu infrastructure supports adding new menu items.
- The existing channel join mechanism supports programmatic joins with optional passwords.
- The application already has patterns for per-user persistent settings (similar to notify list, ignore list, sound settings, etc.).
- Guest users understand that their favorites (like all guest data) are session-only.
- No limit is imposed on the number of favorites a user can have.
