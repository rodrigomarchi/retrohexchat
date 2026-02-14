# Research: Contextual Tips & Progressive Disclosure

**Feature**: 029-contextual-tips | **Date**: 2026-02-14

## R1: Toast Positioning & Z-Index Strategy

**Decision**: Use `position: fixed` with `bottom: 28px; right: 8px` and `z-index: var(--z-toast)` (10000).

**Rationale**: The `--z-toast` token already exists in `tokens.css` at 10000, above all other layers (modal: 200, context-menu: 300). Fixed positioning ensures the toast stays visible regardless of scroll state. Bottom offset of 28px clears the status bar.

**Alternatives considered**:
- `position: absolute` relative to chat container — rejected because toast must persist across tab switches and scroll changes.
- Using `--z-modal-above` (210) — rejected because toast must appear above modals; however, tips are suppressed while dialogs are open, so this is moot. Using `--z-toast` is semantically correct.

## R2: localStorage Key Strategy & Resilience

**Decision**: Use three localStorage keys:
- `retro_hex_chat_tips_seen` — JSON object mapping tip IDs to `true` (e.g., `{"first_message": true, "first_join": true}`)
- `retro_hex_chat_tips_suppressed` — standalone key, value `"true"` when globally suppressed
- `retro_hex_chat_tips_suppressed_backup` — redundant backup of suppression flag for resilience

**Rationale**: Follows existing `retro_hex_chat_*` prefix convention (matching `retro_hex_chat_history`, `retro_hex_chat_onboarding_complete`, etc.). The backup key ensures the "Não mostrar mais" preference survives partial localStorage clearing. On read, check both keys — if either says suppressed, honor it.

**Alternatives considered**:
- Single JSON object for all state — rejected because a single corrupt key would lose both seen state and suppression.
- Using sessionStorage — rejected because tips must persist across sessions.

## R3: Dialog Open Detection

**Decision**: The hook checks for the presence of `.dialog-overlay` elements in the DOM to determine if a dialog is open.

**Rationale**: All dialogs in the app use the `.dialog-overlay` CSS class. This is a simple, reliable DOM query that doesn't require maintaining a separate "dialogs open" counter. The hook can check `document.querySelector('.dialog-overlay')` before showing a toast.

**Alternatives considered**:
- Tracking `show_*_dialog` assigns server-side and pushing state to JS — rejected because there are 40+ dialog flags and this would add unnecessary coupling.
- MutationObserver on body — rejected as over-engineered for a simple check.

## R4: Onboarding Wizard Detection

**Decision**: Check `localStorage.getItem("retro_hex_chat_onboarding_complete")` — if this key does NOT exist, the user is in the onboarding flow and tips should be suppressed.

**Rationale**: The onboarding wizard runs on `ConnectLive` (before `ChatLive` mounts). Once the wizard completes, it sets `retro_hex_chat_onboarding_complete = "true"`. The contextual tips hook lives on `ChatLive`, which only mounts after connection. So by the time tips could fire, the flag is always set. However, the `show_onboarding_tip` assign (set via `?onboarded=true` URL param) indicates the user just completed onboarding — tips should wait a few seconds before becoming active to avoid overlapping with the onboarding tip banner.

**Alternatives considered**:
- Checking `show_onboarding_tip` server-side — rejected because it only applies to the immediate post-wizard session, not general onboarding state.

## R5: Tip Trigger Integration Points

**Decision**: Use LiveView `push_event` from existing event handlers to notify the JS hook of tip-worthy events.

| Tip | Trigger Point | File | Mechanism |
|-----|--------------|------|-----------|
| First message | `send_input` handler, after `{:message, text}` match | `core_events.ex` | `push_event("tip_trigger", %{tip: "first_message"})` |
| First join | `join_channel/4` success path | `helpers/channel.ex` | `push_event("tip_trigger", %{tip: "first_join"})` |
| First PM | `handle_info(%{event: "new_pm", ...})` | `pubsub_handlers/messages.ex` | `push_event("tip_trigger", %{tip: "first_pm"})` |
| First highlight | After `maybe_highlight` returns `highlighted: true` | `pubsub_handlers/messages.ex` | `push_event("tip_trigger", %{tip: "first_highlight"})` |
| Idle 30s | Client-side idle timer | `contextual_tips_hook.js` | No server event — purely JS |
| /help preempt | `/help` command dispatch | `command_dispatch.ex` | `push_event("tip_trigger", %{tip: "help_used"})` |

**Rationale**: `push_event` is lightweight and non-intrusive — a single line added at each trigger point. The JS hook handles all state management (seen check, queue, display). The server doesn't need to know tip state.

**Alternatives considered**:
- Client-side detection via DOM mutations — rejected because message sending, channel joins, and PMs are server-driven events that the client can't reliably intercept without hooks.
- Dedicated PubSub topic for tips — rejected as over-engineered for a client-side feature.

## R6: Idle Timer Implementation

**Decision**: Use `setTimeout` + event listeners for `keydown`, `mousemove`, and `click` on `document`. Reset timer on any activity. Timer only runs once — after first fire, it's cleared permanently.

**Rationale**: Simple, well-understood pattern. The timer is a one-shot — it fires at most once (since tips show only once). No need for `setInterval` or recurring checks.

**Alternatives considered**:
- `requestIdleCallback` — rejected because it detects CPU idle, not user idle.
- Server-side idle detection via `Process.send_after` — rejected because this is a client-side UX concern.

## R7: Toast Component Design (98.css)

**Decision**: Toast uses 98.css `window` class with `title-bar` for the tip title and `window-body` for content. The dismiss button uses 98.css's standard button styling. The checkbox uses 98.css's standard checkbox input.

**Rationale**: Maintains Windows 98 design fidelity (Constitution VIII). The `window` class provides the characteristic 3D beveled border and title bar. Using standard 98.css elements ensures visual consistency.

**Alternatives considered**:
- Custom flat toast design — rejected because it would break the Windows 98 aesthetic.
- Using the existing `onboarding-tip-banner` pattern — rejected because a fixed-position floating window better matches the "tooltip/notification" metaphor than a page-embedded banner.

## R8: Hook vs. LiveComponent for Toast

**Decision**: Use a JS hook (`ContextualTipsHook`) that creates/manages toast DOM elements directly, rather than a Phoenix LiveComponent.

**Rationale**: All tip state lives in localStorage (client-side). The toast appears/disappears based on client-side timers and user interaction. Using a LiveComponent would require round-trips to the server for each toast show/dismiss, adding unnecessary latency and server load. The hook creates the toast element, manages the queue, and handles all interaction — the server only pushes trigger events.

A Phoenix function component (`toast.ex`) provides the container element that the hook attaches to.

**Alternatives considered**:
- Full LiveComponent with server-managed state — rejected because tip state doesn't need server persistence, and round-trip latency would violate the 500ms display goal.
- No Elixir component at all — rejected because we need a mount point in the template for the hook.

## R9: Settings Integration

**Decision**: Add a "Mostrar dicas contextuais" checkbox to the Display panel of the Options dialog, using the same pattern as existing display toggles (e.g., `show_toolbar`).

**Rationale**: Display settings is the natural home for tip visibility controls. The existing `options_toggle_display` event handler pattern handles checkbox toggles. The setting will be part of `user_preferences.display`.

**Implementation**: The toggle controls the `retro_hex_chat_tips_suppressed` localStorage key. When toggled ON (show tips), the JS hook removes the suppression key. When toggled OFF, it sets the key. This is done via `push_event` from the options event handler to the tips hook.

**Alternatives considered**:
- Separate "Tips" panel in Settings — rejected because a single checkbox doesn't warrant its own panel.
- Storing in user_preferences database table — rejected because tips need to work for guests too, and localStorage is the single source of truth.
