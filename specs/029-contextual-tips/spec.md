# Feature Specification: Contextual Tips & Progressive Disclosure

**Feature Branch**: `029-contextual-tips`
**Created**: 2026-02-14
**Status**: Draft
**Input**: User description: "Contextual Tips & Progressive Disclosure for RetroHexChat"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - First Message Tip & Toast Infrastructure (Priority: P1)

A user sends their first message in any channel. A small toast notification appears in the bottom-right corner of the screen with the text "Use ↑ para editar sua última mensagem". The toast has an "Entendi!" dismiss button and a "Não mostrar mais dicas" checkbox. If the user does not interact with it, the toast auto-dismisses after 8 seconds. The tip never appears again for that user.

**Why this priority**: The toast component and tip infrastructure must be built for this first tip. This story delivers the reusable foundation that all other tips and future toast consumers depend on.

**Independent Test**: Can be fully tested by sending a message in a channel and verifying the toast appears with correct text, dismiss button, and checkbox. Delivers immediate discoverability of the message editing shortcut.

**Acceptance Scenarios**:

1. **Given** a user who has never sent a message, **When** they send their first message in any channel, **Then** a toast appears in the bottom-right with "Use ↑ para editar sua última mensagem", an "Entendi!" button, and a "Não mostrar mais dicas" checkbox
2. **Given** the toast is visible, **When** the user clicks "Entendi!", **Then** the toast dismisses immediately and the tip is marked as seen
3. **Given** the toast is visible, **When** 8 seconds pass without interaction, **Then** the toast auto-dismisses and the tip is marked as seen
4. **Given** a user who has already seen the first-message tip, **When** they send another message, **Then** no toast appears
5. **Given** the toast is visible, **When** the user checks "Não mostrar mais dicas" and dismisses, **Then** all future tips are globally suppressed

---

### User Story 2 - Tip Queuing and Conflict Resolution (Priority: P1)

When multiple tips would trigger at the same moment (e.g., the user sends a first message right after joining their first channel), tips queue and display one at a time with a 2-second gap between them. Tips do not appear while a dialog or modal is open — they queue until the dialog closes. Tips never appear during the onboarding wizard flow.

**Why this priority**: Without queuing, simultaneous triggers would stack toasts or lose tips. This is essential infrastructure that prevents broken UX for all other stories.

**Independent Test**: Can be tested by triggering two tip conditions simultaneously and verifying they appear sequentially with a 2-second gap.

**Acceptance Scenarios**:

1. **Given** two tip triggers fire simultaneously, **When** the first toast appears, **Then** the second tip queues and appears 2 seconds after the first is dismissed or auto-dismissed
2. **Given** a dialog or modal is open, **When** a tip trigger fires, **Then** the tip queues and appears only after the dialog closes
3. **Given** the onboarding wizard is active, **When** a tip trigger fires, **Then** the tip does not appear and does not queue
4. **Given** a tip is queued and the user checks "Não mostrar mais dicas" on the current toast, **Then** the queued tip is discarded and not shown

---

### User Story 3 - Channel Join Tip (Priority: P2)

When a user joins a channel via /join for the first time, a toast appears: "Canais que você entra aparecem no painel esquerdo". This tip fires only once per user, follows the same dismiss/auto-dismiss behavior, and respects the global suppression toggle.

**Why this priority**: Helps users understand the channel panel after their first explicit channel join. Builds on the toast infrastructure from P1.

**Independent Test**: Can be tested by joining a channel with /join and verifying the toast appears with correct text.

**Acceptance Scenarios**:

1. **Given** a user who has never joined a channel via /join, **When** they join a channel, **Then** a toast appears with "Canais que você entra aparecem no painel esquerdo"
2. **Given** a user who has already seen the join tip, **When** they join another channel, **Then** no toast appears
3. **Given** global tip suppression is enabled, **When** the user joins their first channel, **Then** no toast appears and the tip is marked as seen

---

### User Story 4 - PM Received Tip (Priority: P2)

When a user receives their first private message, a toast appears: "PMs aparecem como janelas separadas no treebar". Same dismiss/auto-dismiss behavior and global suppression respect.

**Why this priority**: Helps users discover the PM window system on first PM receipt.

**Independent Test**: Can be tested by sending a PM to the user and verifying the toast appears.

**Acceptance Scenarios**:

1. **Given** a user who has never received a PM, **When** they receive their first PM, **Then** a toast appears with "PMs aparecem como janelas separadas no treebar"
2. **Given** a user who has already seen the PM tip, **When** they receive another PM, **Then** no toast appears

---

### User Story 5 - Nick Highlight Tip (Priority: P2)

When someone mentions the user's nick for the first time, a toast appears: "Seu nick foi mencionado! Configure alertas em Settings". Same behavior as other tips.

**Why this priority**: Teaches users about the highlight/alert settings on first mention.

**Independent Test**: Can be tested by mentioning the user's nick in a channel message and verifying the toast appears.

**Acceptance Scenarios**:

1. **Given** a user whose nick has never been mentioned, **When** another user mentions their nick, **Then** a toast appears with "Seu nick foi mencionado! Configure alertas em Settings"
2. **Given** a user who has already seen the highlight tip, **When** their nick is mentioned again, **Then** no toast appears

---

### User Story 6 - Idle Help Tip (Priority: P3)

When a user is idle for 30 seconds (no keyboard or mouse interaction), a toast appears: "Digite /help para ver todos os comandos". If the user has already used /help before the idle timer fires, the tip is marked as seen and not shown.

**Why this priority**: Lowest priority because it's time-based rather than action-based, and serves as a catch-all for users who haven't discovered the help system.

**Independent Test**: Can be tested by remaining idle for 30 seconds and verifying the toast appears, or by using /help first and verifying it does not.

**Acceptance Scenarios**:

1. **Given** a user who has never seen the idle tip and has not used /help, **When** they are idle for 30 seconds, **Then** a toast appears with "Digite /help para ver todos os comandos"
2. **Given** a user who has previously used /help, **When** they are idle for 30 seconds, **Then** no toast appears and the tip is marked as seen
3. **Given** a user who has already seen the idle tip, **When** they are idle again, **Then** no toast appears

---

### User Story 7 - Global Tip Toggle in Settings (Priority: P2)

Users can re-enable tips from the Settings dialog after having disabled them with the "Não mostrar mais dicas" checkbox. The setting appears in the Settings dialog and toggles global tip suppression on/off. Re-enabling resets the global suppression but does not reset individual tip seen states — only tips not yet seen will appear.

**Why this priority**: Essential for users who accidentally suppressed tips or changed their mind.

**Independent Test**: Can be tested by disabling tips via checkbox, opening Settings, re-enabling, and triggering a not-yet-seen tip.

**Acceptance Scenarios**:

1. **Given** a user who checked "Não mostrar mais dicas", **When** they open Settings, **Then** they see a "Mostrar dicas contextuais" toggle in the off state
2. **Given** the toggle is off in Settings, **When** the user enables it, **Then** future unseen tips will appear when triggered
3. **Given** a user re-enables tips, **When** a previously-seen tip would trigger, **Then** it does not appear (individual tip state is preserved)

---

### Edge Cases

- **Multiple simultaneous triggers**: Tips queue and show one at a time with 2-second gaps
- **Dialog/modal open during tip trigger**: Tip queues until dialog closes
- **Onboarding wizard active**: Tips do not fire and do not queue
- **Feature knowledge already demonstrated**: If the user has already used /help, the idle tip is marked as seen without showing
- **localStorage full**: Tip tracking operations fail gracefully — tips may re-show rather than throwing errors
- **localStorage cleared externally**: The global suppression setting uses a dedicated resilient key so clearing other localStorage data does not accidentally reset it
- **Toast must not steal focus**: The input field retains focus at all times while a toast is visible
- **Toast positioning**: Bottom-right corner, must not overlap the input area or status bar

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a toast notification in the bottom-right corner when a contextual tip trigger fires
- **FR-002**: Each toast MUST contain the tip text, an "Entendi!" dismiss button, and a "Não mostrar mais dicas" checkbox
- **FR-003**: Toasts MUST auto-dismiss after 8 seconds if the user does not interact
- **FR-004**: Each tip type MUST appear at most once per user — ever
- **FR-005**: System MUST persist per-tip seen state and global suppression state in localStorage
- **FR-006**: If the "Não mostrar mais dicas" checkbox is checked, all future tips MUST be globally suppressed
- **FR-007**: When multiple tips trigger simultaneously, the system MUST queue them and display one at a time with a 2-second gap
- **FR-008**: Tips MUST NOT appear while a dialog or modal is open — they MUST queue until the dialog closes
- **FR-009**: Tips MUST NOT appear during the onboarding wizard flow
- **FR-010**: The toast MUST NOT steal focus from the chat input field
- **FR-011**: The system MUST support 5 tip triggers: first message sent, first channel join, first PM received, first nick highlight, and 30-second idle
- **FR-012**: The idle tip MUST be pre-emptively marked as seen if the user has already used /help
- **FR-013**: Users MUST be able to re-enable tips from the Settings dialog
- **FR-014**: Re-enabling tips MUST only show tips not yet individually seen
- **FR-015**: The toast component MUST be reusable by other features for their own toast messages
- **FR-016**: If localStorage operations fail (e.g., storage full), the system MUST gracefully skip tip tracking rather than throwing errors
- **FR-017**: The global suppression setting MUST be resilient — it should survive partial localStorage clearing

### Key Entities

- **Tip**: A contextual hint with a unique identifier, trigger condition, display text, and seen state
- **TipQueue**: An ordered list of pending tips waiting to be displayed, processed one at a time
- **TipState**: Per-user persistence tracking which tips have been seen and whether global suppression is active
- **Toast**: A reusable UI component for displaying dismissible notifications with optional checkbox

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each of the 5 contextual tips appears exactly once per user when its trigger condition is met for the first time
- **SC-002**: Tips display within 500ms of the trigger event occurring
- **SC-003**: Toasts auto-dismiss after exactly 8 seconds if not interacted with
- **SC-004**: When multiple tips trigger simultaneously, they appear sequentially with a 2-second gap — no overlapping toasts
- **SC-005**: The chat input field retains focus 100% of the time while toasts are visible
- **SC-006**: The global suppression toggle in Settings correctly enables/disables all future unseen tips
- **SC-007**: Tip state persists across page reloads and browser sessions
- **SC-008**: Users who have already demonstrated feature knowledge (e.g., used /help) never see the corresponding tip

## Assumptions

- All tip text is in Portuguese as specified — no internationalization needed
- The 30-second idle timer resets on any keyboard or mouse activity within the chat interface
- The onboarding wizard sets a flag that can be checked to suppress tips during its flow
- The existing Settings dialog has a section or can accommodate a new toggle for tip preferences
- localStorage is the appropriate persistence mechanism since tips apply to both guests and registered users
- The "resilient" global suppression setting will use a dedicated localStorage key separate from other tip state

## Scope

### In Scope

- 5 contextual tip triggers (first message, first join, first PM, first highlight, idle)
- Reusable toast component styled with retro design system (dismiss button + global toggle checkbox)
- Per-tip seen tracking in localStorage
- Global tips toggle in Settings dialog
- Tip queuing system with 2-second gap
- Dialog/modal awareness (pause tips while open)
- Onboarding wizard awareness (no tips during wizard)
- Pre-emptive tip marking for demonstrated knowledge (/help usage)

### Out of Scope

- Tip content customization by users
- More than 5 initial tip types (extensible later)
- Tip analytics or usage tracking
- Tips in languages other than Portuguese
- Server-side tip state persistence
- A/B testing of tip content or timing

## Dependencies

- Onboarding wizard (feature 028) must expose a flag indicating whether it is active
- Settings dialog must support adding a new toggle control
- Existing command system must allow detection of /help usage for pre-emptive tip marking
