# Feature Specification: P2P Actions in Context Menus

**Feature Branch**: `040-p2p-context-menus`
**Created**: 2026-02-16
**Status**: Draft
**Input**: User description: "P2P Actions in Context Menus for RetroHexChat"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - P2P Actions via Nicklist Context Menu (Priority: P1)

A registered user right-clicks on a nickname in the nicklist. Below "Set Nick Color" and above the operator separator, they see four P2P action items: "Sessão P2P", "Chamada de Áudio", "Chamada de Vídeo", and "Enviar Arquivo". Clicking any of these creates the corresponding P2P session and navigates the user to the P2P lobby.

**Why this priority**: The nicklist is the primary discovery point for user-to-user actions. Adding P2P items here directly addresses the discoverability gap for the most common interaction path.

**Independent Test**: Can be fully tested by right-clicking a nick in the nicklist and verifying P2P items appear with correct visibility, disabled states, and click behavior.

**Acceptance Scenarios**:

1. **Given** a registered user viewing a channel with other users, **When** they right-click a registered user's nick in the nicklist, **Then** they see four enabled P2P items below "Set Nick Color": "Sessão P2P", "Chamada de Áudio", "Chamada de Vídeo", "Enviar Arquivo".
2. **Given** a registered user viewing the nicklist, **When** they click "Chamada de Áudio" on a registered target nick, **Then** a P2P session of type `audio_call` is created and they are navigated to the P2P lobby.
3. **Given** a registered user viewing the nicklist, **When** they click "Chamada de Vídeo" on a registered target nick, **Then** a P2P session of type `video_call` is created and they are navigated to the P2P lobby.
4. **Given** a registered user viewing the nicklist, **When** they click "Sessão P2P" on a registered target nick, **Then** a P2P session of type `generic` is created and they are navigated to the P2P lobby.
5. **Given** a registered user viewing the nicklist, **When** they click "Enviar Arquivo" on a registered target nick, **Then** a P2P session of type `file_transfer` is created and they are navigated to the P2P lobby.

---

### User Story 2 - P2P Actions via Chat Nick Context Menu (Priority: P1)

A registered user right-clicks on a nickname displayed within a chat message. Below "Set Nick Color" and above the operator separator, they see the same four P2P action items. Behavior is identical to the nicklist context menu.

**Why this priority**: Chat messages are the second most common place users interact with nicknames. Both context menus must have feature parity for consistent discoverability.

**Independent Test**: Can be fully tested by right-clicking a nick in a chat message and verifying P2P items appear with correct visibility, disabled states, and click behavior.

**Acceptance Scenarios**:

1. **Given** a registered user viewing chat messages, **When** they right-click a registered user's nick in a chat message, **Then** they see four enabled P2P items below "Set Nick Color": "Sessão P2P", "Chamada de Áudio", "Chamada de Vídeo", "Enviar Arquivo".
2. **Given** a registered user, **When** they click "Enviar Arquivo" on a nick in a chat message, **Then** a P2P session of type `file_transfer` is created and they navigate to the P2P lobby.

---

### User Story 3 - Guest Users Cannot See P2P Items (Priority: P2)

A guest (unidentified) user right-clicks on a nickname in either the nicklist or a chat message. They see the standard context menu items but no P2P actions at all. P2P items are completely absent from the menu.

**Why this priority**: Prevents confusion for guests who cannot use P2P features. Simpler than showing disabled items — the feature simply does not exist for them.

**Independent Test**: Can be tested by logging in as a guest user and right-clicking any nick to verify P2P items are absent.

**Acceptance Scenarios**:

1. **Given** a guest user viewing the nicklist, **When** they right-click any nick, **Then** the context menu appears without any P2P items.
2. **Given** a guest user viewing chat messages, **When** they right-click any nick, **Then** the context menu appears without any P2P items.

---

### User Story 4 - Disabled State for Unregistered Targets (Priority: P2)

A registered user right-clicks on a guest (unregistered) user's nick. The four P2P items appear but are grayed out (disabled). Hovering over a disabled P2P item shows a tooltip: "Usuário não registrado".

**Why this priority**: Provides clear feedback about why P2P is unavailable for a specific target, guiding the user toward valid targets.

**Independent Test**: Can be tested by right-clicking a guest nick as a registered user and verifying items are disabled with the correct tooltip.

**Acceptance Scenarios**:

1. **Given** a registered user, **When** they right-click a guest user's nick in the nicklist, **Then** the four P2P items appear grayed out/disabled.
2. **Given** a registered user hovering over a disabled P2P item, **When** they see the tooltip, **Then** it reads "Usuário não registrado".
3. **Given** a registered user, **When** they click a disabled P2P item, **Then** nothing happens (click is ignored).

---

### User Story 5 - Self-Targeting Disabled (Priority: P3)

A registered user right-clicks on their own nick. The P2P items appear but are disabled. No tooltip is shown (the reason is self-evident).

**Why this priority**: Edge case handling. Users rarely right-click themselves, but the menu should behave consistently.

**Independent Test**: Can be tested by right-clicking your own nick and verifying P2P items are disabled.

**Acceptance Scenarios**:

1. **Given** a registered user, **When** they right-click their own nick in the nicklist, **Then** the P2P items are disabled with no tooltip.
2. **Given** a registered user, **When** they right-click their own nick in a chat message, **Then** the P2P items are disabled with no tooltip.

---

### Edge Cases

- **Target is offline**: Session is created normally in "pending" state. The target can join when they come online.
- **Target is ignored/blocked**: Session creation fails. A flash error message is shown with a generic error (no specific mention of ignore/block status to avoid information leakage).
- **Rate limit hit**: Session creation fails. A flash error message is shown indicating the user should wait, including the remaining wait time.
- **Multiple rapid clicks**: Only the first click is processed; subsequent clicks while a session is being created are ignored.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display four P2P action items ("Sessão P2P", "Chamada de Áudio", "Chamada de Vídeo", "Enviar Arquivo") in the nicklist context menu for registered users, positioned after "Set Nick Color" and before the operator separator.
- **FR-002**: System MUST display the same four P2P action items in the chat nick context menu for registered users, in the same relative position.
- **FR-003**: System MUST NOT display P2P items for guest (unidentified) users in either context menu.
- **FR-004**: System MUST disable P2P items (grayed out, non-clickable) when the target nick is not a registered user, with tooltip "Usuário não registrado".
- **FR-005**: System MUST disable P2P items when the target nick is the viewer's own nick (no tooltip).
- **FR-006**: Clicking an enabled "Sessão P2P" item MUST create a P2P session of type `generic` and navigate to the lobby.
- **FR-007**: Clicking an enabled "Chamada de Áudio" item MUST create a P2P session of type `audio_call` and navigate to the lobby.
- **FR-008**: Clicking an enabled "Chamada de Vídeo" item MUST create a P2P session of type `video_call` and navigate to the lobby.
- **FR-009**: Clicking an enabled "Enviar Arquivo" item MUST create a P2P session of type `file_transfer` and navigate to the lobby.
- **FR-010**: System MUST show a flash error when session creation fails due to the target being ignored/blocked, without revealing the specific reason.
- **FR-011**: System MUST show a flash error with remaining wait time when session creation is rate-limited.
- **FR-012**: A separator MUST appear before the P2P items group to visually distinguish them from the preceding items.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All four P2P actions are accessible within two clicks (right-click + menu item click) from both the nicklist and chat message nicks.
- **SC-002**: Registered users can start any P2P session type (generic, audio call, video call, file transfer) without knowing slash commands.
- **SC-003**: Guest users never see P2P options, eliminating confusion about unavailable features.
- **SC-004**: Users targeting unregistered nicks receive immediate visual feedback (disabled state + tooltip) explaining why P2P is unavailable.
- **SC-005**: All existing context menu functionality continues to work without regression.

## Assumptions

- The existing P2P command handlers can be reused from context menu event handlers without modification.
- The "registered" status of a user can be determined from existing data available in the context menu component assigns (user metadata or presence information).
- P2P items are rendered as flat menu items (not a submenu/flyout), consistent with existing menu item patterns.
- The separator before P2P items follows the same visual pattern as existing separators in the context menus.
- Video call is included as a direct menu item even though there is no `/videocall` slash command — the context menu provides a new entry point for this session type.

## Scope

**In scope**:
- P2P action items in both nicklist and chat nick context menus
- Event handlers for all four P2P actions in both menus
- Visibility rules (guest vs. registered viewer)
- Disabled states (unregistered target, self-targeting)
- Error handling via flash messages (ignore/block, rate limit)
- Tests for visibility, disabled states, and event handlers

**Out of scope**:
- New P2P features or session types
- Changes to P2P session flow or lobby behavior
- Submenu/flyout styling (items are flat in the menu)
- Changes to existing context menu items
- P2P items in URL, channel, or message context menu variants
