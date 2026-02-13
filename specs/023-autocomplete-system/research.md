# Research: Autocomplete System

**Feature**: 023-autocomplete-system
**Date**: 2026-02-13

## R1: Fuzzy Matching Algorithm

**Decision**: Subsequence match with weighted scoring — implemented in pure Elixir.

**Rationale**: The autocomplete dataset is small (45 commands, ~50 nicks, ~100 channels). A simple in-process subsequence match with scoring is optimal: no external dependency, sub-millisecond latency, easy to test. Prefix matches rank highest, then consecutive character matches, then dispersed subsequence matches.

**Alternatives considered**:
- **Levenshtein distance**: Too expensive for real-time and penalizes long commands unfairly. Subsequence match is more intuitive for autocomplete (typing "jo" should match "join" and "autojoin").
- **External fuzzy library (fuzzily, fuzzy_compare)**: Adds a dependency for a trivial algorithm. The matching logic is ~30 lines of Elixir.
- **Client-side filtering (JS)**: Violates Constitution I (Elixir-first). Server-side matching keeps the JS hook minimal and allows LiveView to control rendering.

**Scoring algorithm**:
1. Exact prefix match → score 1000 + (length_bonus)
2. Word-boundary subsequence (match at start of words after `-`, `_`) → score 500
3. General subsequence (characters appear in order) → score 100
4. No match → excluded
5. Tiebreaker: alphabetical order

## R2: Command Category Mapping

**Decision**: Add a `category/0` callback to the Handler behaviour. Each handler returns its category atom. Registry aggregates categories at compile time.

**Rationale**: Handlers already implement `help/0` with metadata. Adding `category/0` follows the same pattern and keeps category knowledge co-located with the command. This is better than a centralized mapping because adding a new command automatically gets a category.

**Category mapping** (45 commands → 5 categories):

| Category | Portuguese | Commands |
|----------|-----------|----------|
| Basics | Básicos | help, clear, quit, away, bio, nick, me |
| Channel | Canal | join, part, leave, list, topic, mode, kick, ban, invite, knock |
| User | Usuário | msg, query, notice, notice_routing, whois, whowas, ctcp, wallops, ignore, unignore |
| Configuration | Configuração | alias, autojoin, autorespond, notify, perform, timer, popups, umode |
| Advanced | Avançado | announce, cs, ns, motd, setmotd, clearmotd, setwelcome, clearwelcome |

**Alternatives considered**:
- **Centralized map in Registry**: Fragile — must update when adding commands. Rejected.
- **Directory-based inference**: Handler file paths don't align with user-facing categories. Rejected.

## R3: Recent Commands Persistence

**Decision**: localStorage with a simple JSON array, managed entirely by the JS hook. No server-side persistence.

**Rationale**: Recent commands are a UI convenience, not critical data. localStorage persists per-browser without requiring authentication, works for guests, and adds zero server load. The JS hook writes on command selection; the LiveView reads via `push_event`/`handle_event` on mount.

**Data format**:
```json
{
  "retro_hex_chat_recent_commands": ["join", "msg", "nick", "away", "help"]
}
```
- Array ordered by recency (most recent first)
- Capped at 5 entries (shift oldest when adding)
- Deduplicated (moving an existing command to front)

**Alternatives considered**:
- **Server-side in session**: Session is ephemeral for guests, doesn't persist across reloads. Rejected.
- **Server-side in database**: Overkill for 5 strings. Requires auth for guests. Rejected.
- **Cookie**: Size-limited, sent with every request. Rejected.

## R4: Trigger Detection Architecture

**Decision**: Single unified JS hook (`AutocompleteHook`) replacing `CommandPaletteHook`, with cursor-position-aware trigger detection.

**Rationale**: The current hook already handles `/` detection, Tab completion, history navigation, and IRC formatting shortcuts. Adding `@` and `#` triggers to the same hook avoids multiple hooks competing for the same input element. The hook detects the active trigger by scanning backward from cursor position to the nearest word boundary.

**Trigger detection algorithm**:
1. On each `keyup`/`input` event, scan backward from cursor position
2. Find the nearest unescaped trigger character (`/` at position 0, `@` or `#` after whitespace/start)
3. Extract the partial text between trigger and cursor
4. Push appropriate event to LiveView: `autocomplete_query` with `{type, partial, cursor_pos}`
5. If no trigger found or cursor moved past trigger, push `autocomplete_close`

**Alternatives considered**:
- **Separate hooks per trigger**: Multiple hooks on same element cause event conflicts. Rejected.
- **Server-side input parsing**: Requires sending full input on every keystroke. Current approach only sends the relevant partial. Better latency.

## R5: Dropdown Component Architecture

**Decision**: Single `autocomplete_dropdown` component replacing `command_palette`, with a `mode` attribute (`:command`, `:nick`, `:channel`) that controls rendering.

**Rationale**: All three autocomplete types share the same UI pattern (positioned dropdown, keyboard navigation, selection behavior). A single component with mode-specific rendering reduces duplication and ensures consistent styling. The component receives a list of result maps with type-specific metadata.

**Result map shapes**:
- Command: `%{type: :command, name: "join", description: "Join a channel", category: "Canal", recent?: true}`
- Nick: `%{type: :nick, nickname: "Mario", status: :online, color: "#ff0000"}`
- Channel: `%{type: :channel, name: "#dev", user_count: 5, joined?: true}`

**Alternatives considered**:
- **Three separate components**: Duplication of keyboard navigation, styling, positioning logic. Rejected.
- **Generic `<.dropdown>` with slots**: Over-engineered for 3 known modes. Simple conditional rendering is clearer.

## R6: Tab Cycling State Management

**Decision**: Tab cycling state maintained in the JS hook (not server-side). The hook tracks `{originalPartial, matches, currentIndex}` and cycles locally.

**Rationale**: Tab cycling is rapid-fire UI interaction. Round-tripping to the server on each Tab press would add latency. The server provides the initial match list via `push_event`; the hook cycles through it locally. State resets when user types any non-Tab key.

**Flow**:
1. User types partial + Tab → hook sends `tab_complete` event to server
2. Server computes matches from `channel_users`, returns list via `push_event("tab_matches", %{matches: [...]})`
3. Hook stores matches and inserts first match
4. Subsequent Tab presses cycle through stored matches (no server round-trip)
5. Any other keypress resets cycling state

**Alternatives considered**:
- **Server-side cycling**: Server round-trip per Tab press. Too slow for rapid cycling. Rejected.
- **Fully client-side matching**: Requires sending full user list to client and keeping it synced. Violates thin-JS principle. Hybrid approach is best.

## R7: Channel Data Aggregation for Autocomplete

**Decision**: Query active channels from the Elixir Registry + Channel Server (same pattern as `ChannelListLive.list_active_channels/1`), applying visibility rules inline.

**Rationale**: The existing `ChannelListLive` already implements the exact pattern needed: scan Registry, get state from each Channel Server, apply secret/private visibility rules. We extract this into a reusable function in the domain layer so both `ChannelListLive` and autocomplete can use it.

**Visibility rules** (from existing code):
- Secret (+s) channels: hidden from non-members (return `nil`)
- Private (+p) channels: shown as "Prv" to non-members (masked name)
- Public channels: fully visible with name, topic, user count
- Member channels: always fully visible regardless of mode

**Alternatives considered**:
- **Database query for registered channels**: Only covers registered channels, misses ad-hoc ones. Runtime Registry is the source of truth. Rejected.
- **Dedicated ETS cache**: Premature optimization. Registry select is fast enough for <100 channels. Rejected.
