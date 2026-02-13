# Research: Options Dialog (021)

**Date**: 2026-02-13
**Branch**: `021-options-dialog`

## R1: Persistence Strategy — Single Table vs Multiple Tables

**Decision**: Single `user_preferences` table with JSONB columns for each settings group.

**Rationale**: The Options dialog centralizes 6 categories of preferences. Creating 6 separate tables (one per panel) would be over-engineering for what is conceptually one entity: "user preferences." The existing SoundSettings precedent already uses JSONB columns for nested map storage. A single table with typed JSONB columns keeps the migration count low, allows adding new preference categories with column additions (not new tables), and maps cleanly to a single domain module.

**Alternatives considered**:
- 6 separate tables (one per panel): More granular but creates excessive migration/schema/module proliferation for a hub feature.
- One table per existing pattern (notice_routing already has its own table): Would require the Options dialog to load/save from 6 different modules. Notice routing can be migrated to the unified table or left as-is with the Options dialog reading/writing both.

**Resolution**: New `user_preferences` table with columns: `owner_nickname` (PK), `display_settings` (JSONB), `font_settings` (JSONB), `color_settings` (JSONB), `connect_settings` (JSONB), `message_settings` (JSONB), `key_bindings` (JSONB), timestamps. Leave existing `notice_routing_settings` table intact — the Options dialog reads from Session (which already loads notice_routing) and writes to both Session and the notice_routing persistence module.

## R2: CSS Custom Properties Strategy for Dynamic Fonts/Colors

**Decision**: Introduce CSS custom properties (variables) on `:root` for all customizable fonts and colors, with a JS hook that updates `:root` style properties via `push_event`.

**Rationale**: CSS custom properties cascade naturally, work with all browsers, and can be updated from JavaScript without replacing stylesheets. The existing codebase has only 3 CSS variables (for MOTD/wallops), so this is a greenfield introduction. The alternative (inline styles on every element) would require touching dozens of template locations and is brittle.

**Alternatives considered**:
- Inline `style` attributes on each element: Too many touch points, not maintainable.
- Dynamic CSS stylesheet generation: Over-engineered for preset color grids.
- Server-rendered `<style>` tag in layout: Would work but CSS variables + JS hook is more LiveView-native and allows instant updates without re-render.

**Resolution**:
1. Define CSS variables in layout.css with fallback defaults: `var(--chat-font-family, Fixedsys)`, `var(--chat-bg-color, white)`, etc.
2. Replace hardcoded values across chat.css, layout.css, components.css with CSS variable references.
3. Create `OptionsHook` JS hook that receives `push_event("apply_preferences", %{styles: map})` and sets `document.documentElement.style.setProperty(name, value)` for each changed property.
4. On mount/reconnect, push current preferences to the hook to restore styles.

## R3: Dynamic Key Bindings Architecture

**Decision**: Replace hardcoded pattern matching in `keyboard_events.ex` with a runtime lookup table stored in Session.

**Rationale**: The current `keyboard_events.ex` uses Elixir pattern matching for each shortcut (e.g., `%{"key" => "b", "altKey" => true}` → toggle address book). To make bindings customizable, the handler must match against a dynamic map instead. The binding map is stored in Session and passed to the keyboard events handler via socket assigns.

**Alternatives considered**:
- JS-side key interception before LiveView: Would bypass the `phx-window-keydown` mechanism, creating a parallel event system. More complex, less testable.
- Generate Elixir code dynamically: Not practical in a running system.

**Resolution**:
1. Define a `KeyBindings` domain module with a `defaults/0` function returning `%{action_id => %{key: String.t(), modifiers: MapSet.t()}}`.
2. Store custom bindings in Session (loaded from `user_preferences.key_bindings` JSONB).
3. In `keyboard_events.ex`, replace each pattern match with a single `handle_event("window_keydown", params, socket)` that:
   - Extracts key + modifiers from params
   - Looks up the matching action in `socket.assigns.key_bindings`
   - Dispatches to the appropriate handler function
4. The Key Bindings panel uses a `KeyBindingCaptureHook` JS hook that captures keydown events in the dialog and sends them to LiveView for validation.
5. Browser-reserved shortcuts (Ctrl+W, Ctrl+T, etc.) are checked client-side — the browser intercepts them before they reach LiveView, so the hook validates and warns.

## R4: Display Toggles Integration with Existing UI

**Decision**: Extend existing boolean assigns (`show_treebar`, `show_nicklist`) with new assigns (`show_toolbar`, `show_switchbar`, `show_statusbar`, `compact_mode`, `line_shading`) and persist all through the unified preferences system.

**Rationale**: The treebar and nicklist toggles already work via `assign(socket, show_treebar: !socket.assigns.show_treebar)`. The Options dialog's Display panel simply provides additional toggles using the same pattern. The toolbar, tab bar (switchbar), and status bar currently have no toggle mechanism — their visibility is unconditional in the template. Adding `:if` or `style="display:none"` conditionals follows the existing pattern.

**Alternatives considered**:
- CSS-only toggles (body class → display:none): Would work but disconnects state from LiveView assigns, making testing harder.

**Resolution**: Add new assigns to `assign_defaults`: `show_toolbar: true`, `show_switchbar: true`, `show_statusbar: true`, `compact_mode: false`, `line_shading: false`. Wrap toolbar/tab-bar/status-bar in `:if` conditionals. Line shading uses `chat-line-shading` CSS class on the chat-messages container. Compact mode uses `compact-mode` CSS class on the app-container.

## R5: Nick Color Palette Scope (from skipped clarification)

**Decision**: The Colors panel controls the global 16 IRC color palette values (what color indexes 0–15 render as across the entire app).

**Rationale**: The Address Book's Nick Colors tab already handles per-nick color overrides. The Options > Colors panel serves a different purpose: customizing the base IRC color palette (the 16 standard colors used for `\x03` format codes, nick auto-coloring, and the formatting toolbar picker). This matches how mIRC's Options > Colors works.

**Alternatives considered**:
- Duplicate the Address Book Nick Colors functionality: Redundant.
- Remove nick palette from Colors panel: Loses the ability to customize the base palette.

**Resolution**: The Colors panel includes a "Nick Colors" subsection showing the 16 IRC color swatches. Clicking one opens the same 24-color picker to change what that index renders as. These override the CSS classes `.irc-fg-0` through `.irc-fg-15` via CSS custom properties.

## R6: Reconnect Settings Push to JS

**Decision**: Pass reconnect settings from server to ReconnectHook via `push_event` on mount and on apply.

**Rationale**: The ReconnectHook currently hardcodes `maxAttempts = 10` and `Math.min(base, 30)` for backoff cap. To make these configurable, the LiveView must push the settings to the hook. The existing pattern of `push_event` + hook `handleEvent` is used throughout the app (link previews, sound playback, downloads).

**Resolution**:
1. On mount (and on apply from Options > Connect), push: `push_event(socket, "reconnect_config", %{enabled: true, max_attempts: 10, max_delay: 30, timeout: 30})`.
2. ReconnectHook.js stores these in instance variables and uses them instead of hardcoded values.
3. If `enabled: false`, the hook skips reconnection entirely.

## R7: Font Preview Implementation

**Decision**: In-dialog live preview using inline styles on a sample text element.

**Rationale**: The Fonts panel needs a preview that updates as the user changes settings without affecting the rest of the UI. This is purely a dialog-internal concern — the draft font settings apply inline styles to a `<div class="font-preview">` element within the dialog.

**Resolution**: The preview div renders sample text like `"<Alice> Hello! The quick brown fox jumps over the lazy dog."` with timestamp and nick, styled with the draft font family and size. Changes to the select/number inputs update the draft assign, which re-renders the preview via LiveView reactivity.
