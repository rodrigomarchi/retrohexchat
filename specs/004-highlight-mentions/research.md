# Research: Highlight / Mentions

**Feature**: 004-highlight-mentions
**Date**: 2026-02-11

## R1: Highlight Matching Strategy

**Decision**: Pure-function matching engine using `Formatter.strip/1` + word-boundary regex.

**Rationale**: The existing `Chat.Formatter` module already provides `strip/1` to remove all IRC formatting codes from text. Matching against stripped plain text satisfies FR-019 (ignore formatting codes). Elixir's `Regex` module with `\b` word boundaries and `caseless` option provides whole-word, case-insensitive matching per FR-003/FR-004. The function is pure (no side effects, no GenServer) so it's trivially testable and adds zero architectural complexity.

**Alternatives considered**:
- **Matching at broadcast time (server-side)**: Rejected. Highlights are purely local (FR-018). Each user has different highlight words, so matching must happen in the receiving LiveView process, not in the channel GenServer.
- **Regex pattern matching (user-configurable regex)**: Explicitly out of scope per spec. Simple word matching covers the use case.
- **Token-based matching (tokenize then scan)**: Overengineered. Regex with word boundaries is simpler and handles punctuation boundaries correctly (e.g., "hey Rodrigo," matches "Rodrigo").

## R2: URL Exclusion Strategy

**Decision**: Extract URL spans from plain text via `~r{https?://\S+}i`, replace with same-length placeholder, then match words against the modified text.

**Rationale**: No URL detection currently exists in the Formatter module. For highlight matching, we need a lightweight approach — not full linkification. A simple regex to identify `http://` and `https://` URLs and mask them before word matching satisfies FR-005 without overcomplicating the matching engine.

**Alternatives considered**:
- **Full URL parser (URI module)**: Overkill for exclusion. We just need to identify URL spans, not parse them.
- **Post-match position checking**: More complex — would need to track match positions and URL positions, then compare. Masking is simpler.
- **Linkification pass (clickable URLs)**: Separate concern, out of scope for this feature.

## R3: Message Decoration in Stream

**Decision**: Add `highlighted` and `highlight_color` keys to the payload map before `stream_insert/3`.

**Rationale**: The current stream item is a plain map (`%{id, channel, author, content, type, timestamp}`). Adding two optional keys (`highlighted: true/false`, `highlight_color: color_string`) is non-breaking — existing template code accesses known keys, and the new keys are only read by the new highlight rendering logic. Using `Map.put/3` on the payload before insertion keeps the change minimal.

**Alternatives considered**:
- **Separate stream for highlighted messages**: Unnecessary complexity. One stream with decoration is simpler.
- **LiveView assign tracking highlighted IDs**: Would require maintaining a separate set and cross-referencing during render. Map decoration is more self-contained.

## R4: TreeBar Flash Mechanism

**Decision**: New `highlight_channels` MapSet assign + `tree-highlight` CSS class with `@keyframes` animation.

**Rationale**: The existing TreeBar already accepts `unread_channels` as a list and applies `tree-unread` CSS class. Adding a parallel `highlight_channels` assign follows the same pattern. CSS `@keyframes` animation provides smooth flashing without JS intervention. The animation runs infinitely until the class is removed (when user switches to that channel).

**Alternatives considered**:
- **JS-driven flash via setInterval**: More complex, harder to test, violates Constitution VII (minimal JS hooks).
- **Reusing `tree-unread` with extra state**: Would conflate unread and highlight states. They're independent — a channel can be unread without highlights, or highlighted and already unread.

## R5: Sound Integration

**Decision**: Reuse existing SoundHook with `push_event("play_sound", %{type: "mention"})`.

**Rationale**: SoundHook already exists with a "mention" sound type (880Hz sine wave, 150ms duration, 0.3 volume). It uses Web Audio API oscillators (no audio files needed). The hook listens for `play_sound` handleEvent. ChatLive just needs to push this event when a highlight is detected. Zero new JS code required.

**Alternatives considered**:
- **New audio file (WAV/MP3)**: Increases bundle size, adds asset management. Synthesized tones are period-appropriate for the Windows 98 aesthetic.
- **Browser Notification API**: Out of scope. Sound is the specified notification mechanism.

## R6: Persistence Pattern

**Decision**: Follow existing NotifyList/ContactList/NickColors pattern — migration + Ecto schema + domain module save/load + Session extension + NickServ identify loading.

**Rationale**: Three prior features (002-notify-list, 003-address-book with contacts + nick_colors) established a well-tested persistence pattern. Reusing it ensures consistency, reduces learning curve, and leverages proven code paths (the NickServ identify handler already loads three data types — adding a fourth is a one-line addition per the established pattern).

**Alternatives considered**:
- **localStorage (client-side only)**: Doesn't satisfy FR-015 (server-side persistence for registered users). Also violates umbrella separation.
- **ETS-based persistence**: Volatile on restart. PostgreSQL provides durability.

## R7: Color Palette for Custom Highlight Words

**Decision**: Reuse the existing 16-color IRC palette (indices 0-15) from the text formatting feature.

**Rationale**: The 16-color IRC palette is already defined in CSS (`.irc-bg-0` through `.irc-bg-15`) and has a color picker UI in the FormatToolbar. Reusing these colors for highlight word backgrounds keeps the design consistent and avoids creating a new color system. The `HighlightWord` struct stores `bg_color` as an integer index (0-15) or nil for default.

**Alternatives considered**:
- **Full RGB color picker**: Overly complex for a Windows 98 aesthetic. The 16-color palette is period-appropriate.
- **Hardcoded highlight colors only**: Too restrictive. Per-word colors are a spec requirement (FR-012).

## R8: Muted Notifications

**Decision**: Design the highlight engine to support mute checking, but defer implementation until a per-channel mute feature exists.

**Rationale**: FR-010 requires suppressing sound and flash (but not visual highlighting) for muted channels. No per-channel mute mechanism currently exists in the codebase. The highlight integration in ChatLive will include a hook point (`channel_muted?(channel)`) that returns `false` by default, ready to be wired when the mute feature is implemented.

**Alternatives considered**:
- **Implement channel mute as part of this feature**: Scope creep. Mute is a separate feature affecting more than just highlights.
- **Ignore mute entirely**: Would violate FR-010. Adding the hook point is trivial and future-proofs the design.
