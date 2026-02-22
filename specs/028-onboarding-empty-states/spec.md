# Feature Specification: Onboarding & Empty States

**Feature Branch**: `028-onboarding-empty-states`
**Created**: 2026-02-14
**Status**: Draft
**Input**: User description: "Onboarding & Empty States for RetroHexChat — welcome wizard and contextual empty states"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - First-Time Welcome Wizard (Priority: P1)

A first-time user opens RetroHexChat and is greeted by a retro-style wizard dialog that guides them through initial setup in 3 steps: choosing a nickname, configuring the server connection, and optionally joining channels. The wizard only appears once — on subsequent visits, the user goes directly to the chat interface.

**Why this priority**: The wizard is the primary onboarding touchpoint. Without it, new users face a blank interface with no guidance, leading to immediate abandonment. This story delivers the core "first impression" value.

**Independent Test**: Can be fully tested by opening the app for the first time (or clearing localStorage) and completing the wizard flow. Delivers immediate value by converting confused new users into connected, chatting users.

**Acceptance Scenarios**:

1. **Given** a user visits RetroHexChat for the first time (no `onboarding_complete` flag in localStorage), **When** the page loads, **Then** a wizard dialog appears with Step 1 visible: ASCII/pixel art logo, nickname input field, and a tip explaining what a nick is.
2. **Given** the user is on Step 1, **When** they enter a nickname and click "Próximo" (Next), **Then** Step 2 appears with server configuration fields pre-filled with sensible defaults and an SSL checkbox.
3. **Given** the user is on Step 2, **When** they click "Conectar" (Connect), **Then** the system attempts to connect to the server. On success, Step 3 appears with a list of popular channels (with user counts) as checkboxes and a text field for custom channel names.
4. **Given** the user is on Step 2, **When** the server connection fails, **Then** an error message appears within the wizard and the user can modify settings and retry without restarting the wizard.
5. **Given** the user is on Step 3, **When** they select channels and click "Entrar!" (Enter), **Then** the wizard closes, the user joins the selected channels, and a subtle banner appears in the chat: "Dica: digite / para ver comandos disponíveis. Use ↑↓ para navegar o histórico."
6. **Given** the user is on Step 3, **When** they click "Pular" (Skip), **Then** the wizard closes without joining any channels and the tip banner still appears.
7. **Given** the wizard is open at any step, **When** the user closes it via the X button or presses Esc, **Then** the `onboarding_complete` flag is set in localStorage and the wizard does not reappear.
8. **Given** a returning user (with `onboarding_complete` flag in localStorage), **When** they visit RetroHexChat, **Then** the wizard does not appear and the normal chat interface loads directly.

---

### User Story 2 - Empty Channel State (Priority: P2)

When a user joins a channel with no messages, instead of a blank screen they see a centered welcome message with the channel name and helpful tips. The empty state disappears instantly when the first message arrives.

**Why this priority**: The empty channel is the most commonly encountered empty state — every new channel starts empty. Providing guidance here reduces confusion and encourages interaction.

**Independent Test**: Can be tested by joining or creating an empty channel and verifying the welcome message appears, then sending a message and verifying the empty state vanishes instantly.

**Acceptance Scenarios**:

1. **Given** a user joins a channel with no messages, **When** the channel view renders, **Then** a centered, non-selectable welcome message appears: "Bem-vindo ao #[channel-name]! Este é o início do canal. Diga oi! Dica: /topic para ver o tópico."
2. **Given** an empty channel is displaying the welcome message, **When** the first message arrives (from any user), **Then** the welcome message disappears instantly and is replaced by the message.
3. **Given** the welcome message is displayed, **When** the user tries to select/copy the text, **Then** the text is not selectable (it is not rendered as a chat message).

---

### User Story 3 - Empty Nicklist State (Priority: P3)

When a channel's nicklist is empty (no other users), a friendly message replaces the blank space, telling the user they are the first one there.

**Why this priority**: The nicklist is visible alongside the chat. An empty nicklist is less disorienting than an empty chat, but still benefits from a friendly nudge.

**Independent Test**: Can be tested by joining a channel where the user is the only member and verifying the empty nicklist message appears, then having another user join and verifying the message vanishes.

**Acceptance Scenarios**:

1. **Given** a user is in a channel with no other users in the nicklist, **When** the nicklist renders, **Then** it shows a non-selectable message: "Ninguém aqui — Você é o(a) primeiro(a)!"
2. **Given** the empty nicklist message is displayed, **When** another user joins the channel, **Then** the message disappears instantly and the user's nick appears in the nicklist.

---

### User Story 4 - Empty Treebar State (Priority: P4)

When the treebar (channel sidebar) has no channels, it displays a helpful message with a button to explore channels, instead of blank space.

**Why this priority**: The treebar is the navigation hub. An empty treebar with an actionable button can help users discover channels, but it's a less common state than empty chat or nicklist.

**Independent Test**: Can be tested by having a user with no joined channels and verifying the treebar shows the empty state message with the "Explorar canais" button, then clicking the button and verifying the channel list opens.

**Acceptance Scenarios**:

1. **Given** a user has no joined channels, **When** the treebar renders, **Then** it shows a non-selectable message: "Nenhum canal — /join #canal para começar" with an "Explorar canais" button.
2. **Given** the empty treebar message is displayed, **When** the user clicks "Explorar canais", **Then** the channel list dialog opens.
3. **Given** the empty treebar message is displayed, **When** the user joins a channel, **Then** the message disappears instantly and the channel appears in the treebar.

---

### User Story 5 - Empty URL Catcher State (Priority: P5)

When the URL catcher has no captured URLs, it shows an explanatory message instead of blank space.

**Why this priority**: The URL catcher is a secondary feature. An empty state here is helpful but has the least impact on user onboarding.

**Independent Test**: Can be tested by opening the URL catcher with no captured URLs and verifying the message appears, then posting a URL in chat and verifying the empty state vanishes.

**Acceptance Scenarios**:

1. **Given** the URL catcher has no captured URLs, **When** it renders, **Then** it shows a non-selectable message: "Nenhuma URL capturada. URLs mencionadas no chat aparecerão aqui."
2. **Given** the empty URL catcher message is displayed, **When** a URL is posted in chat, **Then** the message disappears instantly and the URL appears in the list.

---

### Edge Cases

- **localStorage cleared**: If localStorage is cleared, the wizard reappears on next visit. This is acceptable behavior.
- **Wizard dismissed early**: Closing the wizard via X or Esc at any step marks onboarding as complete — the wizard never reappears.
- **Connection failure in wizard**: If the server connection fails during Step 2, the wizard stays on Step 2, shows an error message, and allows the user to modify settings and retry.
- **"Explorar canais" button resilience**: The "Explorar canais" button in the treebar empty state must work even if the channel list feature is still loading — it should open the channel list dialog regardless.
- **Guest users**: Guest users (not logged in) also see the onboarding wizard and all empty states.
- **Empty state timing**: All empty states must disappear within the same render cycle as the first content arrival — no visible delay or flicker.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a 3-step welcome wizard on first visit when no `onboarding_complete` flag exists in localStorage.
- **FR-002**: Wizard Step 1 MUST display an ASCII/pixel art logo, a nickname input field, and a tip: "Seu nick é como seu nome no chat. Pode mudar depois com /nick."
- **FR-003**: Wizard Step 2 MUST display server configuration with sensible defaults pre-filled, an SSL checkbox, and a tip: "Não sabe o que escolher? Deixe o padrão!"
- **FR-004**: Wizard Step 2 MUST handle connection failures by displaying an error message and allowing retry without restarting the wizard.
- **FR-005**: Wizard Step 3 MUST display a list of popular channels with user counts as checkboxes and a text field for custom channel names.
- **FR-006**: Wizard Step 3 MUST include a "Pular" (Skip) button that allows the user to skip channel selection entirely.
- **FR-007**: System MUST set `onboarding_complete` flag in localStorage when the wizard is completed, skipped, or dismissed (via X or Esc).
- **FR-008**: System MUST NOT display the wizard on subsequent visits when the `onboarding_complete` flag exists.
- **FR-009**: System MUST display a post-wizard banner in the chat: "Dica: digite / para ver comandos disponíveis. Use ↑↓ para navegar o histórico."
- **FR-010**: System MUST display a centered welcome message in empty channels: "Bem-vindo ao #[channel-name]! Este é o início do canal. Diga oi! Dica: /topic para ver o tópico."
- **FR-011**: System MUST display a message in empty nicklists: "Ninguém aqui — Você é o(a) primeiro(a)!"
- **FR-012**: System MUST display a message with an "Explorar canais" button in empty treebars: "Nenhum canal — /join #canal para começar."
- **FR-013**: System MUST display a message in empty URL catchers: "Nenhuma URL capturada. URLs mencionadas no chat aparecerão aqui."
- **FR-014**: All empty state messages MUST disappear instantly when content arrives (first message, first user, first channel, first URL).
- **FR-015**: Empty state text MUST NOT be selectable or copyable — it must not behave as chat message content.
- **FR-016**: The wizard MUST be styled as a retro-style wizard dialog, consistent with retro design system design language.
- **FR-017**: Guest users MUST see the onboarding wizard and all empty states.

### Key Entities

- **Onboarding State**: Client-side flag (`onboarding_complete`) stored in localStorage that tracks whether the user has completed (or dismissed) the welcome wizard. No server-side persistence required.
- **Wizard Step**: The current step (1, 2, or 3) within the onboarding wizard, each with distinct content and actions.
- **Empty State**: A placeholder UI element displayed when a container (channel, nicklist, treebar, URL catcher) has no content. Contains non-selectable text and optional action buttons.

## Scope *(mandatory)*

### In Scope

- 3-step welcome wizard (nickname, server connection, channel selection)
- First-run detection via localStorage
- Post-wizard tip banner in chat
- 4 empty states: channel messages, nicklist, treebar, URL catcher
- retro-style wizard dialog design
- Guest user support

### Out of Scope

- Contextual tips and progressive disclosure (Category Z2)
- Interactive tutorial/walkthrough overlay
- Video guides
- Onboarding analytics/tracking
- Server-side onboarding state persistence

## Assumptions

- The existing connect flow (ConnectLive) can be adapted or extended to support the wizard's Step 2 connection logic.
- The channel list feature (for Step 3's popular channels and the "Explorar canais" button) is already available or can be invoked programmatically.
- The post-wizard banner is a transient UI element that appears once per session after wizard completion (not persisted).
- "Popular channels" in Step 3 refers to channels sorted by user count in descending order, limited to a reasonable number (e.g., top 10).
- The wizard dialog follows standard retro dialog patterns (title bar with X button, "Back"/"Next"/"Cancel" navigation buttons).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: First-time users can go from opening the app to chatting in a channel in under 60 seconds using the wizard.
- **SC-002**: The wizard appears only once per browser — never re-triggers on subsequent visits (unless localStorage is cleared).
- **SC-003**: All 4 empty states display helpful guidance text when their respective containers are empty.
- **SC-004**: Empty states disappear within the same render cycle as the first content arrival — no visible delay or flicker.
- **SC-005**: 100% of empty state text is non-selectable (cannot be copied as if it were chat content).
- **SC-006**: The wizard gracefully handles connection failures without losing user input or restarting the flow.
