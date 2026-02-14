# Research: Onboarding & Empty States

**Feature**: 028-onboarding-empty-states
**Date**: 2026-02-14

## Decision 1: Wizard Architecture — Where to Host the Wizard

**Decision**: Extend ConnectLive with multi-step wizard behavior. The wizard replaces the current single-step nickname form for first-time users.

**Rationale**:
- ConnectLive already handles the pre-chat flow (nickname input, navigation to `/chat`)
- Adding wizard steps here keeps the "connect" concern in one place
- No new routes needed — the wizard is a UI enhancement of the existing connect page
- Returning users (with `onboarding_complete` in localStorage) see the current simple form
- The wizard naturally feeds into the existing `push_navigate` to `/chat`

**Alternatives considered**:
- **Separate OnboardingLive**: Would fragment the connect flow across two LiveViews. The wizard steps include nickname + server config, which overlap with ConnectLive's existing responsibility.
- **Modal overlay in ChatLive**: Would require mounting ChatLive first, then showing the wizard. Adds complexity and delays the user seeing the wizard. ChatLive already has 19 event hooks — adding wizard logic there would violate lean LiveView principles.

## Decision 2: First-Run Detection Mechanism

**Decision**: Use localStorage key `retro_hex_chat_onboarding_complete` checked via a JS hook on ConnectLive mount. The hook pushes an event to the server indicating whether the wizard should be shown.

**Rationale**:
- Spec explicitly requires localStorage-based detection (no server-side persistence)
- JS hook can check localStorage on mount and push a `"check_onboarding"` event with `{first_visit: true/false}`
- ConnectLive adjusts its assigns (`wizard_mode: true/false`) based on this event
- Consistent with existing localStorage usage pattern (see `history.js`)

**Alternatives considered**:
- **Server-side user preference**: Would require login before onboarding — contradicts guest user support requirement.
- **Cookie-based**: Less reliable than localStorage for persistent client-side state.

## Decision 3: Wizard Step Navigation Pattern

**Decision**: Use LiveView assigns-based step tracking with conditional rendering (same pattern as OptionsDialog panels). Steps: `:welcome` → `:server` → `:channels`.

**Rationale**:
- The OptionsDialog already demonstrates multi-panel conditional rendering via `@active_panel`
- Each step rendered via `<.step_welcome :if={@wizard_step == :welcome} />` etc.
- Back/Next buttons update `@wizard_step` assign
- Server connection in Step 2 uses the same connection logic that ChatLive uses on mount
- Step 3 channel list uses existing `Channels.list_channels/0` or similar

**Alternatives considered**:
- **JS-only wizard**: Would lose LiveView's server-side validation and event handling. Connection attempt in Step 2 requires server interaction.
- **Separate LiveView per step**: Over-engineered for 3 steps. URL changes between steps would break the wizard's dialog UX.

## Decision 4: Empty State Implementation Pattern

**Decision**: Implement empty states as conditional blocks within existing components using `:if` guards on empty data. Use CSS `user-select: none` for non-selectability.

**Rationale**:
- Each empty state is a simple conditional render — show placeholder when list is empty, hide when content arrives
- LiveView's reactive rendering handles instant disappearance naturally — when assigns update, the template re-renders
- `user-select: none` CSS property prevents text selection as required
- No new components needed — just conditional blocks in existing templates (treebar, nicklist, chat, url_catcher_window)

**Alternatives considered**:
- **Separate EmptyState component**: Over-abstraction for 4 simple conditional blocks with different text and layouts.
- **JS-based visibility toggle**: Unnecessary — LiveView handles this natively via assigns.

## Decision 5: Post-Wizard Tip Banner

**Decision**: Implement as a transient system message in ChatLive, shown once per session via a `show_onboarding_tip` assign set from a URL query parameter (`?onboarded=true`).

**Rationale**:
- ConnectLive can pass `?onboarded=true` when navigating to `/chat` after wizard completion
- ChatLive checks this param on mount and sets `show_onboarding_tip: true`
- The banner renders above the message area as a styled system message
- Dismissed automatically or via click — no persistence needed

**Alternatives considered**:
- **localStorage flag for banner**: Would add complexity for a one-time transient message. Query param is simpler.
- **PubSub event**: The banner is per-user, per-session — no need for pub/sub.

## Decision 6: Channel List in Wizard Step 3

**Decision**: Reuse existing channel listing logic from the domain layer. Query active channels with user counts and present as checkboxes in the wizard.

**Rationale**:
- `RetroHexChat.Channels` context already has channel management functions
- Step 3 needs: channel name, user count, sorted by popularity
- The wizard can call the same domain functions that ChannelListLive uses
- Custom channel name text field is a simple addition alongside the checkbox list

**Alternatives considered**:
- **Embed ChannelListLive**: ChannelListLive is a separate route-level LiveView, not a component. Embedding it would require refactoring.
- **Hardcoded channel list**: Would not reflect actual server state. Dynamic is better.

## Decision 7: CSS Architecture for Wizard

**Decision**: Create `wizard-dialog.css` in the Dialogs layer. Follow existing dialog CSS patterns with `.wizard-` prefix.

**Rationale**:
- Estimated 80-120 lines of CSS — fits the sweet spot for a standalone file
- Uses existing design tokens, utility classes, and dialog framework
- Wizard-specific classes: `.wizard-step-indicator`, `.wizard-content`, `.wizard-logo`, `.wizard-tip`
- Import in app.css in the Dialogs layer (alphabetical)

**Alternatives considered**:
- **Inline in dialogs.css**: Would push dialogs.css over 300 lines (currently ~245).
- **Reuse connect-dialog.css**: The wizard is significantly different from the simple connect form.

## Decision 8: Empty States CSS

**Decision**: Create `empty-state.css` in the Components layer with a shared `.empty-state` class. Each empty state location adds minimal component-specific overrides.

**Rationale**:
- 4 empty states share common styling: centered text, muted color, non-selectable, icon/emoji optional
- A shared `.empty-state` base class (~40-50 lines) avoids duplication
- Component-specific overrides (e.g., treebar button, channel name interpolation) stay small
- Existing `.table-empty` pattern validates this approach

**Alternatives considered**:
- **Inline in each component's CSS**: Would duplicate `user-select: none`, `text-align: center`, `color: var(--color-muted)` four times.
- **Add to utilities.css**: Empty states are too specific for generic utilities.
