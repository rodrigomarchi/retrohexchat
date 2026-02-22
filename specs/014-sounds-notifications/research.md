# Research: 014 Sounds & Notifications

**Date**: 2026-02-12
**Feature Branch**: `014-sounds-notifications`

## R1: Sound Catalog — Programmatic vs. Bundled Audio Files

**Decision**: Programmatic Web Audio API synthesis using the existing `SoundHook` pattern, extended with a comprehensive sound definition catalog.

**Rationale**: The existing sound system already uses Web Audio API oscillators (`sound_hook.js`) with per-sound configs of frequency, duration, volume, and waveType. Extending this approach to 12+ named sounds avoids bundling audio files, eliminates HTTP requests for assets, keeps the retro aesthetic (synthesized beeps feel authentic to the era), and leverages the proven existing pattern. Each sound in the catalog is a named config with potentially multiple oscillator notes for richer sounds (e.g., two-tone chimes).

**Alternatives considered**:
- Bundled WAV files: Would provide richer audio fidelity but adds asset management, increases bundle size, and diverges from the established pattern. Rejected.
- Web Audio API with pre-recorded AudioBuffer: Overly complex for retro-style beeps. Rejected.

## R2: Typing Indicator — PubSub Broadcasting Strategy

**Decision**: Use the existing PubSub infrastructure with the PM topic (`pm:#{sorted_nicks}`) for typing events. The typing user's LiveView sends a `"typing"` broadcast. The receiver's LiveView handles it and sets a transient assign with a client-side timeout.

**Rationale**: The PM PubSub topic (`pm:#{pm_topic(nick_a, nick_b)}`) already exists and both users subscribe to it. Adding a `"typing"` event type to this topic is the simplest approach — no new topics, no new processes, no new GenServers. The 5-second timeout is handled client-side in the receiver's LiveView using `Process.send_after`.

**Alternatives considered**:
- Dedicated GenServer per PM conversation: Unnecessary complexity for a simple boolean signal. Rejected.
- Separate PubSub topic for typing: Would require additional subscriptions with no clear benefit. Rejected.
- Client-side WebSocket custom events: Would bypass LiveView's event model. Rejected.

## R3: Typing Indicator — Debounce Strategy

**Decision**: JS hook detects `input` events on the message textarea, debounces them (500ms), and sends a `"pm_typing"` event to the LiveView. The LiveView broadcasts to PubSub. A `Process.send_after` of 5 seconds on the receiver side clears the indicator. The sender also sends a `"pm_stop_typing"` event when the message is sent.

**Rationale**: The JS `KeyboardHook` already handles input events. Adding typing detection is a natural extension. The 500ms debounce prevents flooding PubSub with events on every keystroke. The server-side timeout ensures cleanup even if the sender disconnects.

**Alternatives considered**:
- Server-only detection (detect typing from message submission events): Would not detect typing in real-time. Rejected.
- Pure client-side via Phoenix Channels: Would bypass LiveView patterns. Rejected.

## R4: Visual Flash/Blink — CSS Animation vs. JS Timer

**Decision**: CSS `@keyframes` animation for treebar flashing (the `tree-highlight` class already implements this pattern). Title bar alternation via a JS hook since document.title manipulation requires JavaScript.

**Rationale**: The treebar already has a `.tree-highlight` CSS class with a flash animation (`@keyframes tree-flash`). For title bar changes, a dedicated JS hook (`TitleFlashHook`) will alternate `document.title` using `setInterval` and respond to `visibilitychange` events to stop when the tab regains focus.

**Alternatives considered**:
- All JS-driven: Would bypass CSS for treebar, adding unnecessary complexity. Rejected.
- All CSS-driven: Cannot manipulate `document.title` from CSS. Not possible for title bar.

## R5: Sound Preferences — Storage Architecture

**Decision**: New `sound_settings` PostgreSQL table (one row per user, with a JSONB column containing the full event-to-sound mapping and flash settings) + in-memory map in Session struct for guests. Mute state stays in localStorage (existing pattern).

**Rationale**: Using JSONB for the event-sound mapping avoids a many-row-per-user design (10 rows per user for 10 event types). A single JSONB column is simpler, maps directly to the in-memory map, and is easy to evolve when new event types are added. The existing settings pattern (domain module + Ecto schema + Session integration) is followed exactly. Mute state stays in localStorage because it's a client-side concern (Web Audio API is client-side).

**Alternatives considered**:
- One row per event type per user (normalized): 10 rows per user, more complex queries, harder to load/save atomically. Rejected.
- localStorage for all settings: Would not persist for registered users across devices. Rejected.
- ETS-backed cache: Unnecessary layer for a settings table read once at login. Rejected.

## R6: OK/Cancel/Apply Dialog Pattern

**Decision**: Store a "draft" copy of settings in socket assigns when the dialog opens. Apply writes the draft to session + persists. OK does the same and closes. Cancel restores the original from session and closes.

**Rationale**: This is the standard retro dialog pattern. The existing dialogs use Save/Cancel (no Apply). Adding Apply is a minor extension: keep a `sound_settings_draft` assign that's initialized from `session.sound_settings` on open, mutated by form changes, and committed by Apply/OK.

**Alternatives considered**:
- Two-way binding with automatic save: Not retro pattern. Rejected per clarification.
- Form submission only on OK: Would not support Apply behavior. Rejected.

## R7: Treebar Flash — Per-Event Configurability

**Decision**: Extend the existing `highlight_channels` MapSet concept. Instead of a single `highlight_channels` set, the system will check the user's flash settings for each event type before adding to the set. The existing CSS animation (`tree-highlight` class with `@keyframes tree-flash`) handles the visual flash.

**Rationale**: The treebar component already applies the `.tree-highlight` CSS class from `highlight_channels`. The only change needed is gating the addition to `highlight_channels` based on the user's per-event flash settings. A new `flash_channels` MapSet (or reuse of `highlight_channels`) tracks channels that should be flashing.

**Alternatives considered**:
- Separate flash tracking per event type: Over-engineered for treebar display which only needs "is flashing or not". Rejected.
- New component: The existing treebar already has the right CSS. No need for a new component.
