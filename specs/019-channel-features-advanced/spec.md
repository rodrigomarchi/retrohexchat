# Feature Specification: Channel Features Advanced

**Feature Branch**: `019-channel-features-advanced`
**Created**: 2026-02-13
**Status**: Draft
**Input**: User description: "Advanced channel modes, user hierarchy (owner/half-op), knock system, and protection modes for RetroHexChat IRC"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Extended User Hierarchy with Owner and Half-Operator (Priority: P1)

A channel founder sets up a team channel with fine-grained permissions. They are the owner (~prefix, granted via +q) with full control over the channel. They promote trusted users to operator (@prefix, +o) who can manage the channel day-to-day. Semi-trusted helpers receive half-operator (%prefix, +h) who can kick disruptive users and voice others but cannot set channel modes or ban users. New members get voice (+prefix, +v) to speak in moderated mode. The hierarchy enforces strict rank ordering: owner > operator > half-op > voice > regular. Higher-ranked users cannot be kicked or demoted by lower-ranked users.

**Why this priority**: The user hierarchy is foundational — it gates permissions for every other feature (modes, kick, ban). Without it, the remaining features cannot enforce proper access control.

**Independent Test**: Can be fully tested by creating a channel, assigning roles (+q, +h), and verifying that the nicklist displays correct prefixes (~, @, %, +) and that permission enforcement works (e.g., half-ops cannot kick operators).

**Acceptance Scenarios**:

1. **Given** a user creates a new channel, **When** they are the first to join, **Then** they become the channel owner (~prefix) instead of just operator.
2. **Given** a channel owner, **When** they type `/mode +q Alice`, **Then** Alice becomes a channel owner with ~prefix in the nicklist.
3. **Given** a channel owner, **When** they type `/mode +h Bob`, **Then** Bob becomes a half-operator with %prefix in the nicklist.
4. **Given** a half-operator, **When** they attempt `/kick Operator`, **Then** the system rejects the action with "Cannot kick a higher-ranked user."
5. **Given** an operator, **When** they attempt `/kick Owner`, **Then** the system rejects the action with "Cannot kick a higher-ranked user."
6. **Given** a half-operator, **When** they type `/mode +v Charlie`, **Then** Charlie receives voice successfully.
7. **Given** a half-operator, **When** they attempt `/mode +m`, **Then** the system rejects the action with "Insufficient privileges to set channel modes."
8. **Given** a half-operator, **When** they attempt `/ban User`, **Then** the system rejects the action with "Insufficient privileges."
9. **Given** a channel with multiple role tiers, **When** the nicklist is displayed, **Then** users are grouped in order: Owners (~), Operators (@), Half-Operators (%), Voiced (+), Regular — each group sorted alphabetically.

---

### User Story 2 - Channel Protection Modes: No External Messages, Secret, Private (Priority: P2)

An operator configures channel visibility and message restrictions. Setting +n (no external messages) prevents non-members from sending messages to the channel. Setting +s (secret) hides the channel completely from /list results and from members' /whois channel lists. Setting +p (private) shows the channel in /list but only as "Prv" without revealing the channel name. These modes give operators control over channel discoverability and message integrity.

**Why this priority**: Protection modes are core IRC features that affect channel security and privacy. They are used frequently and impact the /list and /whois commands which are already implemented.

**Independent Test**: Can be tested by setting each mode and verifying: +n blocks messages from non-members; +s hides the channel from /list and /whois; +p masks the channel name in /list. Each mode can be tested independently.

**Acceptance Scenarios**:

1. **Given** a channel with +n set, **When** a non-member attempts to send a message to the channel, **Then** the message is blocked with "Cannot send to channel (no external messages)."
2. **Given** a channel with +n set, **When** a channel member sends a message, **Then** the message is delivered normally.
3. **Given** a channel with +s set, **When** a user runs `/list`, **Then** the secret channel does not appear in the results.
4. **Given** a channel with +s set, **When** a user runs `/whois MemberNick`, **Then** the secret channel does not appear in MemberNick's channel list.
5. **Given** a channel with +p set, **When** a non-member runs `/list`, **Then** the channel appears as "Prv" with no visible name or topic.
6. **Given** a channel with +p set, **When** a member runs `/list`, **Then** the channel appears normally with its real name and topic.
7. **Given** a channel with +s set, **When** an operator attempts `/mode +p`, **Then** the system rejects with "+s and +p are mutually exclusive."
8. **Given** a channel with +p set, **When** an operator attempts `/mode +s`, **Then** the system rejects with "+s and +p are mutually exclusive."

---

### User Story 3 - Knock System for Invite-Only Channels (Priority: P2)

A user wants to join an invite-only channel (#private, mode +i) but has no contact with the operators. They type `/knock #private Hey, can I join? I was referred by Alice.` All operators in the channel see a system message: `* UserNick has knocked on #private (Hey, can I join? I was referred by Alice.)` Operators can then decide to `/invite` the user. Channel operators can disable the knock feature by setting mode +K (uppercase K), in which case users attempting to knock receive "Knocking is disabled for this channel."

**Why this priority**: Knock provides a discovery mechanism for invite-only channels. It complements the existing invite system and solves the problem of users having no way to request access.

**Independent Test**: Can be tested by setting a channel to +i, having a non-member knock, and verifying operators see the notification. Test +K mode disabling knock separately.

**Acceptance Scenarios**:

1. **Given** a channel is +i (invite-only), **When** a non-member types `/knock #channel Hello!`, **Then** all operators in the channel see a system message with the knock request.
2. **Given** a channel is +i and a user has knocked, **When** an operator types `/invite UserNick`, **Then** the user receives an invite and can join.
3. **Given** a channel is NOT +i, **When** a user types `/knock #channel`, **Then** they receive "Channel is not invite-only."
4. **Given** a channel is +i with +K set, **When** a user types `/knock #channel`, **Then** they receive "Knocking is disabled for this channel."
5. **Given** a user is already a member of the channel, **When** they type `/knock #channel`, **Then** they receive "You are already in that channel."
6. **Given** a user is banned from the channel, **When** they type `/knock #channel`, **Then** they receive "You are banned from that channel."

---

### User Story 4 - Strip Colors Mode and Registered-Only Mode (Priority: P3)

An operator sets +c (strip colors) on a professional channel to force plain text, removing all color formatting codes from messages including /me actions. Another operator sets +R (registered only) on a trusted community channel so that only NickServ-identified users can join. Existing unregistered members are allowed to stay when +R is set, but new unregistered users are blocked from joining.

**Why this priority**: These are quality-of-life modes that serve specific community needs. They are less commonly used than the core protection modes but still important for channel customization.

**Independent Test**: +c can be tested by sending a colored message and verifying it arrives stripped. +R can be tested by attempting to join with an unregistered nick and verifying the block.

**Acceptance Scenarios**:

1. **Given** a channel with +c set, **When** a user sends a message with color formatting codes, **Then** the message is delivered with all color codes stripped.
2. **Given** a channel with +c set, **When** a user sends a `/me` action with color codes, **Then** the action text is delivered with all color codes stripped.
3. **Given** a channel with +R set, **When** an unregistered user attempts to join, **Then** they receive "You must be registered to join this channel."
4. **Given** a channel without +R, **When** +R is set by an operator, **Then** existing unregistered members remain in the channel.
5. **Given** a channel with +R set, **When** a NickServ-registered user attempts to join, **Then** they join successfully.

---

### User Story 5 - Join Throttle Mode (Priority: P3)

An operator sets +j 5:10 to limit joins to 5 users per 10-second window, preventing join-flooding attacks. When the throttle is active and the limit is reached, new join attempts receive "Channel join throttle active, please try again shortly." Operators and higher ranks bypass the throttle entirely.

**Why this priority**: Join throttling is a defensive measure against spam bots. It is situational and less critical than core permission and privacy features.

**Independent Test**: Can be tested by setting +j 5:10, rapidly joining users, and verifying that the 6th join within 10 seconds is blocked while an operator join succeeds.

**Acceptance Scenarios**:

1. **Given** a channel with +j 5:10, **When** 5 users join within 10 seconds, **Then** the 6th user attempting to join receives "Channel join throttle active, please try again shortly."
2. **Given** a channel with +j 5:10 and the throttle window has expired, **When** a new user joins, **Then** they join successfully and the counter resets.
3. **Given** a channel with +j 5:10 and the throttle is active, **When** an operator attempts to join, **Then** they bypass the throttle and join successfully.
4. **Given** an operator, **When** they type `/mode +j 5:10`, **Then** the join throttle is activated with the specified parameters.
5. **Given** invalid parameters like `/mode +j abc`, **When** the command is processed, **Then** the system responds with "Invalid join throttle format. Use +j count:seconds (e.g., +j 5:10)."

---

### Edge Cases

- **+s and +p mutual exclusivity**: Setting both simultaneously is rejected with a clear error message. Unsetting one does not auto-set the other.
- **+c strips all formatting**: Color codes, bold, underline, italic, and reverse formatting codes are all stripped from messages and /me actions.
- **+R grandfathering**: When +R is activated, currently connected unregistered members remain. They are only blocked if they leave and try to rejoin.
- **Knock rate limiting**: A user can knock on the same channel at most once every 60 seconds to prevent knock-flooding.
- **Half-op permissions boundary**: Half-operators can kick regular and voiced users, and can grant/remove voice (+v). They cannot: set channel modes, ban users, kick operators/owners, or grant/remove operator/owner status.
- **Owner immutability by operators**: Operators cannot remove owner status (+q) from another user. Only owners can manage owner status.
- **First joiner role**: The first user to join a new (unregistered) channel becomes owner (+q) instead of operator (+o).
- **+j parameter persistence**: Join throttle settings (+j count:seconds) are persisted for registered channels and restored on restart.
- **+n and service messages**: System-generated messages (join/part notifications, mode changes) are never blocked by +n. Only user-originated chat messages from non-members are blocked.
- **Half-op prefix ordering**: In the nicklist, the display order is: ~ (owner) > @ (operator) > % (half-op) > + (voice) > no prefix (regular).

## Requirements *(mandatory)*

### Functional Requirements

**User Hierarchy**:
- **FR-001**: System MUST support four user roles in channels: owner (~), operator (@), half-operator (%), and voice (+), in addition to regular (no prefix).
- **FR-002**: System MUST enforce a strict hierarchy where higher-ranked users cannot be kicked, banned, or demoted by lower-ranked users. The rank order is: owner > operator > half-operator > voice > regular.
- **FR-003**: The first user to join a new unregistered channel MUST receive owner status (+q) instead of operator (+o).
- **FR-004**: Half-operators MUST be able to kick voiced and regular users, and grant or remove voice (+v).
- **FR-005**: Half-operators MUST NOT be able to set channel modes, ban users, or modify operator/owner roles.
- **FR-006**: Only owners MUST be able to grant or remove owner status (+q).
- **FR-007**: The nicklist MUST display users grouped by rank in descending order: owners (~), operators (@), half-operators (%), voiced (+), regular.

**Channel Modes**:
- **FR-008**: System MUST support +n (no external messages) mode that blocks messages from non-members.
- **FR-009**: System MUST support +s (secret) mode that hides the channel from /list results and from /whois channel lists for all users.
- **FR-010**: System MUST support +p (private) mode that shows the channel as "Prv" in /list for non-members while showing normally for members.
- **FR-011**: System MUST reject simultaneous +s and +p modes as mutually exclusive.
- **FR-012**: System MUST support +c (strip colors) mode that removes all formatting codes (color, bold, underline, italic, reverse) from all messages including /me actions.
- **FR-013**: System MUST support +R (registered only) mode that prevents unregistered users from joining while allowing existing unregistered members to remain.
- **FR-014**: System MUST support +j count:seconds (join throttle) mode that limits the rate of user joins. Operators and above bypass the throttle.
- **FR-015**: System MUST validate +j parameters as positive integers in the format count:seconds.

**Knock System**:
- **FR-016**: System MUST support a `/knock #channel [message]` command that notifies channel operators when a user requests to join an invite-only channel.
- **FR-017**: System MUST support +K mode that disables the knock feature for a channel.
- **FR-018**: System MUST reject knock attempts on non-invite-only channels with "Channel is not invite-only."
- **FR-019**: System MUST reject knock attempts when +K is set with "Knocking is disabled for this channel."
- **FR-020**: System MUST reject knock attempts from users already in the channel or banned from it.
- **FR-021**: System MUST rate-limit knock attempts to at most once per 60 seconds per user per channel.

**Mode Display and Persistence**:
- **FR-022**: The /mode command MUST support +q, +h, +n, +s, +p, +c, +R, +j, and +K in addition to existing modes.
- **FR-023**: All new modes MUST be persisted for registered channels and restored on channel process restart.
- **FR-024**: The channel modes display MUST show all active modes including the new ones.

**Help System**:
- **FR-025**: System MUST include help topics for all new modes (+q, +h, +n, +s, +p, +c, +R, +j, +K) and the /knock command.

### Key Entities

- **Channel Role**: An extended enumeration (owner, operator, half_operator, voiced, regular) representing a user's privilege level in a channel. Determines what actions the user can perform.
- **Channel Mode**: A flag or parameterized setting on a channel that controls behavior (message filtering, visibility, join restrictions). Includes both simple flags (+n, +s, +p, +c, +R, +K) and parameterized modes (+j count:seconds, +k password, +l limit).
- **Knock Request**: A transient notification sent from a non-member to channel operators requesting access to an invite-only channel. Contains the requester's nickname, the target channel, and an optional message.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can assign and visually distinguish all five role levels (owner, operator, half-operator, voice, regular) in the channel nicklist within a single interaction.
- **SC-002**: Permission enforcement correctly blocks 100% of unauthorized actions (e.g., half-ops kicking operators, operators removing owners) with clear error messages.
- **SC-003**: Secret channels (+s) are completely invisible in /list results and /whois output for all non-member users.
- **SC-004**: The knock-to-invite workflow (knock, operator notification, invite, join) completes successfully end-to-end.
- **SC-005**: Join throttle (+j) blocks excess joins within the configured window while allowing operators to bypass the restriction.
- **SC-006**: All new modes persist across channel process restarts for registered channels without data loss.
- **SC-007**: All new modes and the /knock command have corresponding help topics accessible via the help system.
- **SC-008**: The +c mode strips all formatting codes from messages so that no color, bold, underline, italic, or reverse formatting appears in the delivered text.

## Assumptions

- The existing `/mode` command handler will be extended to support the new mode characters. No new command is needed for mode setting beyond `/knock`.
- The knock notification is delivered as a system message only to users with operator role or above in the target channel.
- The join throttle window uses a sliding window approach: the system tracks join timestamps and counts joins within the last N seconds.
- For registered channels, the owner role is determined by channel registration (founder). For unregistered channels, the first joiner gets owner status.
- The +n mode does not block system-generated messages (join/part notifications, mode changes, kick messages). It only blocks user-originated chat messages from non-members.
- When +p is set, members of the channel see the full channel name and topic in /list, while non-members see "Prv" as the channel name with no topic.

## Scope

**In scope**:
- `/knock` command and +K mode (disable knock)
- +h half-operator role and +q channel owner role
- +n no external messages mode
- +s secret mode
- +p private mode
- +c strip colors/formatting mode
- +R registered-only mode
- +j join throttle mode
- Help topics for all new features
- Nicklist display updates for new roles
- Permission hierarchy enforcement
- Mode persistence for registered channels

**Out of scope**:
- +S SSL-only mode
- +f per-message flood protection
- Channel mode parameters on ban-type modes (e.g., extended ban syntax)
- ChanServ automatic owner restoration (existing ChanServ behavior unchanged)
