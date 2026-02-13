# Feature Specification: Options Dialog

**Feature Branch**: `021-options-dialog`
**Created**: 2026-02-13
**Status**: Draft
**Input**: User description: "Options Dialog for RetroHexChat — centralized user preferences hub with tree-view navigation and 6 settings panels (Connect, IRC Messages, Display, Fonts, Colors, Key Bindings), line shading, Apply/OK/Cancel, live font preview."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Options Dialog Shell + Display Panel (Priority: P1)

A user presses Alt+O (or selects Tools > Options from the menu bar). A Windows 98-style dialog opens with a tree-view navigation panel on the left listing categories: Connect, IRC Messages, Display, Fonts, Colors, Key Bindings. The Display category is selected by default. The right panel shows Display settings: toggles for toolbar visibility, treebar visibility, switchbar (tab bar) visibility, status bar visibility, compact mode, and line shading. Toggling line shading adds subtle alternating row backgrounds to chat messages. The user clicks Apply — changes take effect immediately without closing the dialog. OK applies and closes. Cancel discards unapplied changes and closes.

**Why this priority**: The dialog shell is the foundation for all other panels. The Display panel provides immediate, visible value — users can customize their workspace density. Line shading improves readability for long conversations. This story also establishes the Apply/OK/Cancel pattern reused by every other panel.

**Independent Test**: Can be fully tested by opening the dialog, toggling Display settings, clicking Apply, and verifying that UI elements show/hide and line shading appears. Delivers immediate workspace customization value.

**Acceptance Scenarios**:

1. **Given** a connected user, **When** they press Alt+O, **Then** the Options dialog opens with the tree-view on the left and Display panel on the right.
2. **Given** the Options dialog is open, **When** the user clicks a tree category, **Then** the right panel switches to show that category's settings.
3. **Given** the Display panel is active with toolbar toggled off, **When** the user clicks Apply, **Then** the main toolbar hides immediately without closing the dialog.
4. **Given** line shading is enabled and applied, **When** the user views the chat area, **Then** alternating messages have a subtly different background color.
5. **Given** the user has made changes but not applied, **When** they click Cancel, **Then** all changes are discarded and the dialog closes.
6. **Given** the Options dialog is already open, **When** the user presses Alt+O again, **Then** the existing dialog is focused (no duplicate).
7. **Given** the user clicks OK, **When** changes are pending, **Then** changes are applied and the dialog closes.

---

### User Story 2 — Fonts Panel (Priority: P2)

A user navigates to the Fonts category in the Options dialog. They see settings for four text areas: chat messages, input box, nicklist, and treebar. For each area, the user can select a font family from available monospace fonts and a font size. A live preview area at the bottom shows sample text rendered with the currently selected settings, updating in real time as options change. Clicking Apply updates the actual UI fonts immediately.

**Why this priority**: Font customization has high visual impact and accessibility value. Users with vision preferences or high-DPI displays need font size control. The live preview prevents trial-and-error frustration.

**Independent Test**: Can be fully tested by opening Options > Fonts, changing font family and size for chat messages, verifying the preview updates, clicking Apply, and confirming chat text renders with the new font settings.

**Acceptance Scenarios**:

1. **Given** the Fonts panel is active, **When** the user selects a different font size for chat messages, **Then** the live preview immediately reflects the new size.
2. **Given** the user has applied a larger font for chat messages, **When** they return to the chat area, **Then** all chat messages render with the new font size without losing scroll position.
3. **Given** the user has changed nicklist font, **When** they click Apply, **Then** the nicklist immediately renders with the new font.
4. **Given** the user selects a font family, **When** they view the preview, **Then** sample text shows the selected font alongside the current size setting.

---

### User Story 3 — Colors Panel (Priority: P3)

A user navigates to the Colors category. They see customizable color slots for: chat background, default text color, own messages, system messages, timestamps, error messages, and the 16-color nick palette. Each slot shows the current color as a swatch. Clicking a slot opens a Windows 98-style color picker grid (16 preset IRC colors plus 8 additional presets, totaling 24 colors). Clicking Apply updates all visible UI elements with the new colors in real time.

**Why this priority**: Color customization personalizes the experience and supports accessibility needs (contrast preferences). It builds on the existing 16-color IRC palette already used for nick colors and formatting.

**Independent Test**: Can be fully tested by opening Options > Colors, changing the chat background color, clicking Apply, and verifying the chat area background updates.

**Acceptance Scenarios**:

1. **Given** the Colors panel is active, **When** the user clicks the chat background color swatch, **Then** a 24-color picker grid appears.
2. **Given** a color is selected from the picker, **When** the user clicks Apply, **Then** the chat background changes to the selected color immediately.
3. **Given** the user changes their own-messages color, **When** they send a new message, **Then** it renders with the newly chosen color.
4. **Given** the user has customized multiple colors, **When** they click Cancel without applying, **Then** no colors change.

---

### User Story 4 — Connect Panel (Priority: P4)

A user navigates to the Connect category. They see settings for auto-reconnect behavior: an enable/disable toggle, retry interval (in seconds, default 5, range 1–60), maximum retries (default 10, range 1–100), and connection timeout (in seconds, default 30, range 5–120). These settings control the auto-reconnect behavior. Clicking Apply saves the new reconnect preferences.

**Why this priority**: Auto-reconnect already exists but has hardcoded parameters. Making these configurable lets users adapt to their network conditions.

**Independent Test**: Can be fully tested by opening Options > Connect, changing the retry interval, clicking Apply, then disconnecting — the reconnect behavior should use the new interval.

**Acceptance Scenarios**:

1. **Given** the Connect panel is active, **When** the user changes retry interval to 10 seconds and applies, **Then** subsequent reconnection attempts use a 10-second base interval.
2. **Given** auto-reconnect is disabled, **When** the connection drops, **Then** no automatic reconnection is attempted.
3. **Given** the user sets max retries to 3 and applies, **When** 3 reconnection attempts fail, **Then** reconnection stops and a "connection failed" message is shown.

---

### User Story 5 — IRC Messages Panel (Priority: P5)

A user navigates to the IRC Messages category. They see routing preferences for: whois results (show in active window or dedicated whois dialog), notices (show in active window, Status tab, or open a PM-style window with the sender), and query/PM messages (open new PM tab automatically or wait for user action). Clicking Apply changes how incoming messages are routed.

**Why this priority**: Message routing is a nuanced preference that experienced IRC users care about deeply, but it doesn't block core functionality. The existing notice routing session field already supports active/status/sender.

**Independent Test**: Can be fully tested by opening Options > IRC Messages, changing notice routing to "Status Window", clicking Apply, then receiving a notice — it should appear in the Status tab.

**Acceptance Scenarios**:

1. **Given** notice routing is set to "Status Window" and applied, **When** a notice arrives, **Then** it appears in the Status tab instead of the active channel.
2. **Given** whois routing is set to "Active Window", **When** the user runs /whois, **Then** results display inline in the currently active channel or PM.
3. **Given** PM routing is set to "Open new tab", **When** a new PM arrives from an unknown sender, **Then** a PM tab opens automatically.

---

### User Story 6 — Key Bindings Panel (Priority: P6)

A user navigates to the Key Bindings category. They see a scrollable list of all application actions (Open Address Book, Toggle Search, Open Help, etc.) with their current key binding displayed next to each. To reassign, the user clicks an action row — it highlights and shows "Press a key combination..." — then presses a new key combo. If the combo conflicts with another action, a warning appears showing which action already uses it. The user can choose to override (which unbinds the other action) or cancel. A "Reset to Defaults" button at the bottom requires a confirmation dialog before restoring all original bindings.

**Why this priority**: Key binding customization is a power-user feature. The existing shortcuts work well for most users. This panel is the most complex to implement (key capture, conflict detection, browser-reserved key filtering) and serves the smallest audience.

**Independent Test**: Can be fully tested by opening Options > Key Bindings, clicking an action, pressing a new key combination, applying, and verifying the shortcut works with the new binding.

**Acceptance Scenarios**:

1. **Given** the Key Bindings panel is active, **When** the user clicks "Open Address Book" and presses Alt+A, **Then** the binding updates to show Alt+A.
2. **Given** Alt+H is assigned to "Open Highlight Dialog", **When** the user tries to assign Alt+H to another action, **Then** a conflict warning shows "Alt+H is already assigned to Open Highlight Dialog".
3. **Given** the user confirms override of a conflicting binding, **When** they apply, **Then** the new binding works and the old action becomes unbound.
4. **Given** the user presses Ctrl+W (browser-reserved), **When** capturing a key binding, **Then** a warning shows "This shortcut is reserved by the browser and cannot be used".
5. **Given** the user clicks "Reset to Defaults" and confirms, **When** the reset completes, **Then** all bindings revert to their original assignments.

---

### Edge Cases

- Opening the Options dialog while it is already open focuses the existing instance.
- Changing font size reflows chat messages without losing the current scroll position.
- Changing colors updates all currently visible UI elements (chat area, nicklist, treebar, tabs) in real time.
- If a user is a guest, preferences persist only for the current session (stored in session state).
- If a user is registered and identified, preferences persist across sessions (stored in the database).
- Resizing the Options dialog scales the tree-view and settings panel proportionally.
- Applying an empty change (no modifications) is a no-op — no errors, no unnecessary redraws.
- The dialog is modeless — the user can continue chatting while Options is open.
- If the connection drops while the Options dialog is open, settings are preserved in the session state; the dialog can be reopened after reconnection.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a centralized Options dialog accessible via Alt+O keyboard shortcut and Tools > Options menu item.
- **FR-002**: The Options dialog MUST display a tree-view navigation panel on the left with categories: Connect, IRC Messages, Display, Fonts, Colors, Key Bindings.
- **FR-003**: Clicking a tree category MUST switch the right panel to display that category's settings.
- **FR-004**: The dialog MUST support three action buttons: OK (apply + close), Cancel (discard + close), Apply (apply without closing).
- **FR-005**: The Options dialog MUST be modeless — users can interact with the chat while the dialog is open.
- **FR-006**: The Display panel MUST provide toggles for: toolbar visibility, treebar visibility, switchbar (tab bar) visibility, status bar visibility, compact mode, and line shading.
- **FR-007**: Line shading MUST render alternating row backgrounds in the chat area with a subtle intensity difference.
- **FR-008**: The Fonts panel MUST allow selection of font family (from available monospace fonts) and size for: chat messages, input box, nicklist, and treebar.
- **FR-009**: The Fonts panel MUST include a live preview that updates in real time as the user changes font settings.
- **FR-010**: The Colors panel MUST allow customization of: chat background, default text color, own messages color, system messages color, timestamps color, error messages color, and the nick color palette.
- **FR-011**: The Colors panel MUST provide a Windows 98-style color picker grid with 24 preset colors (16 IRC + 8 additional).
- **FR-012**: The Connect panel MUST provide settings for: auto-reconnect enable/disable, retry interval, maximum retries, and connection timeout.
- **FR-013**: The IRC Messages panel MUST provide routing preferences for: whois results, notices, and PM messages.
- **FR-014**: The Key Bindings panel MUST display all application actions with their current shortcut, and allow reassignment by key capture.
- **FR-015**: The Key Bindings panel MUST detect and warn about conflicts when two actions would share the same key combination.
- **FR-016**: The Key Bindings panel MUST prevent assignment of browser-reserved shortcuts (Ctrl+W, Ctrl+T, Ctrl+N, Ctrl+L, Ctrl+Tab, etc.).
- **FR-017**: The Key Bindings panel MUST provide a "Reset to Defaults" button that requires confirmation before executing.
- **FR-018**: Applied changes MUST take effect immediately without requiring a page reload.
- **FR-019**: For registered users, preferences MUST persist across sessions via database storage.
- **FR-020**: For guest users, preferences MUST persist for the duration of the current session.
- **FR-021**: Opening the Options dialog when it is already open MUST focus the existing instance, not create a duplicate.
- **FR-022**: Changing font size MUST reflow the chat area without losing the user's scroll position.

### Key Entities

- **UserPreferences**: A settings record per registered user containing all configurable preferences (display toggles, font choices, color overrides, connect settings, message routing, key bindings). Stored as a single database row per user with structured fields.
- **KeyBinding**: An action-to-shortcut mapping. Each binding has an action identifier, a display label, a modifier set (Alt, Ctrl, Shift), a key name, and a default value for reset purposes.
- **ColorSlot**: A named color assignment (e.g., "chat_background", "own_messages") with a hex color value.
- **FontSetting**: A named font assignment (e.g., "chat_messages", "nicklist") with a font family and pixel size.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can open the Options dialog and apply a Display setting change (e.g., hide toolbar) in under 10 seconds.
- **SC-002**: Font and color changes take effect within 1 second of clicking Apply, with no page reload.
- **SC-003**: All 6 settings panels are navigable and functional — every setting in every panel can be modified, applied, and persisted.
- **SC-004**: Key binding reassignment with conflict detection completes without data loss — no two actions share the same binding after apply.
- **SC-005**: Registered users who change preferences, disconnect, and reconnect find their preferences preserved.
- **SC-006**: Guest users who change preferences during a session retain those preferences until they disconnect.
- **SC-007**: The Options dialog does not block chat interaction — users can send and receive messages while the dialog is open.
- **SC-008**: Line shading visually differentiates alternating chat rows when enabled, improving readability for conversations with 20+ messages.

## Assumptions

- **Font availability**: The Fonts panel will offer a curated list of web-safe monospace fonts (Fixedsys, Courier New, Consolas, Lucida Console, monospace) rather than enumerating system fonts, since JavaScript font enumeration is unreliable and a privacy concern.
- **Color picker simplicity**: The color picker uses a fixed 24-color grid rather than a full hex/RGB picker, matching the Windows 98 aesthetic and keeping implementation focused.
- **Compact mode**: Reduces padding and margins throughout the UI (smaller tab bars, tighter chat line spacing, smaller nicklist entries) — a single toggle that applies a CSS class.
- **Switchbar**: Refers to the tab bar component (Status/Channel/PM tabs) — consistent with mIRC terminology.
- **Status bar**: Refers to the bottom status bar area showing connection info — currently always visible.
- **Draft state pattern**: The dialog maintains a draft copy of settings while the user edits. Apply commits the draft to the live session. Cancel discards the draft. This matches the existing pattern used in other dialogs.
- **Existing reconnect settings**: The Connect panel configures parameters that are currently hardcoded in the reconnect logic (backoff interval 1-30s). Making these dynamic requires passing them to the client-side reconnect handler.
- **Notice routing reuse**: The IRC Messages panel reuses and extends the existing `notice_routing` field in Session rather than creating a parallel mechanism.
