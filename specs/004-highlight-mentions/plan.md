# Implementation Plan: Highlight / Mentions

**Branch**: `004-highlight-mentions` | **Date**: 2026-02-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-highlight-mentions/spec.md`

## Summary

Add highlight/mention detection to RetroHexChat so users see visually distinct messages when their nickname or custom words are mentioned. The implementation adds a pure-function highlight matching engine in the domain layer (`Chat.Highlight`), a custom highlight words CRUD module (`Chat.HighlightWords`) with persistence, Session extension for in-memory storage, ChatLive integration for message decoration + treebar flash + sound triggering, a configuration dialog (98.css), and CSS highlight styling.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.7+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css
**Storage**: PostgreSQL 16+ (new `highlight_words` table) + in-memory Session state for guests
**Testing**: ExUnit (unit, integration, liveview, e2e tags), Mox, ExMachina, StreamData, Floki
**Target Platform**: Web (browser)
**Project Type**: Phoenix umbrella app
**Performance Goals**: Highlight matching must add zero perceptible delay to message rendering
**Constraints**: Matching engine must be a pure function (no GenServer, no side effects); all highlight state is local to the user's LiveView process
**Scale/Scope**: Highlight word list capped at 50 entries per user

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | All implementation in Elixir/Phoenix/LiveView. No JS frameworks. Sound uses existing SoundHook (minimal JS). |
| II. Umbrella + Bounded Contexts | Yes | PASS | Matching engine + HighlightWords in `retro_hex_chat` (Chat context). Dialog component + ChatLive changes in `retro_hex_chat_web`. |
| III. OTP Process Architecture | Yes | PASS | No new GenServers needed. Highlight matching is a pure function called in ChatLive's handle_info. Highlight state lives in Session (LiveView assigns). |
| IV. Test-First Development | Yes | PASS | Unit tests for matching engine + HighlightWords CRUD. Integration tests for persistence. LiveView tests for ChatLive integration + dialog. E2E for full flow. |
| V. Contracts and Behaviours | Yes | PASS | HighlightWords follows existing domain module patterns. No new "/" command needed (dialog-based config), but `/highlight` command could be added following Handler behaviour if desired. |
| VI. Static Analysis | Yes | PASS | All public functions get @spec. Credo + Dialyzer + format enforced. |
| VII. Lean LiveViews | Yes | PASS | ChatLive delegates to `Chat.Highlight.check/3` for matching. Dialog component is a function component. JS hook interaction is minimal (push_event for sound). |
| VIII. Windows 98 Design Fidelity | Yes | PASS | Dialog uses 98.css. Color picker reuses existing 16-color IRC palette. |
| IX. Hot/Cold Data Separation | Yes | PASS | Runtime highlight state in Session (hot). Persistent highlight words in PostgreSQL (cold). Loaded on NickServ identify. |
| X. Scalable Architecture | Yes | PASS | Pure function matching scales with message volume. No shared state between users. |

**Gate result: ALL PASS. No violations.**

## Project Structure

### Documentation (this feature)

```text
specs/004-highlight-mentions/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── events.md        # LiveView events contract
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/
│   ├── chat/
│   │   ├── highlight.ex             # Pure matching engine (NEW)
│   │   └── highlight_words.ex       # In-memory CRUD + persistence (NEW)
│   └── accounts/
│       ├── session.ex               # Add highlight_words field (MODIFY)
│       └── highlight_word_entry.ex  # Ecto schema for persistence (NEW)
├── priv/repo/migrations/
│   └── *_create_highlight_words.exs # Migration (NEW)
└── test/
    ├── retro_hex_chat/chat/
    │   ├── highlight_test.exs       # Matching engine tests (NEW)
    │   └── highlight_words_test.exs # CRUD + persistence tests (NEW)

apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── live/
│   │   └── chat_live.ex             # Highlight integration (MODIFY)
│   └── components/
│       ├── treebar.ex               # Flash class support (MODIFY)
│       └── highlight_dialog.ex      # Configuration dialog (NEW)
├── assets/
│   ├── css/
│   │   └── dark-theme.css           # Highlight + flash CSS (MODIFY)
│   └── js/hooks/
│       └── highlight_flash_hook.js  # Treebar flash animation (NEW)
└── test/
    ├── retro_hex_chat_web/
    │   ├── live/chat_live_highlight_test.exs  # Integration tests (NEW)
    │   └── components/highlight_dialog_test.exs # Dialog tests (NEW)
```

**Structure Decision**: Follows existing umbrella structure. New modules placed in the Chat bounded context (matching is a chat concern). Persistence schema in Accounts (follows contacts/nick_colors pattern for user-owned data). TreeBar flash uses a new JS hook for CSS animation control.

## Complexity Tracking

> No violations to justify. All gates pass cleanly.

## Implementation Phases

### Phase 1: Highlight Matching Engine + Visual Highlighting (US1)

**Goal**: Messages mentioning the user's nick get a distinct background color.

1. **`Chat.Highlight` module** — pure function matching engine:
   - `check(content, own_nick, highlight_words, sender_nick)` → `{:highlight, color} | :no_highlight`
   - Strips formatting codes via `Formatter.strip/1` before matching
   - Extracts URL spans via regex `~r{https?://\S+}i` and excludes them
   - Whole-word matching: `\b#{Regex.escape(word)}\b` (case-insensitive)
   - Returns `:no_highlight` if sender == own_nick (self-highlight prevention)
   - Priority: own_nick match returns default color; custom words checked in list order

2. **ChatLive `handle_info` modification** — decorate messages before stream insert:
   - After receiving `%{event: "new_message"}`, call `Chat.Highlight.check/4`
   - If highlight detected: add `highlighted: true` and `highlight_color: color` to payload map
   - Skip check for `:system`, `:service`, `:error` message types (FR-006)
   - Insert decorated payload into stream

3. **CSS highlight styling** in `dark-theme.css`:
   - `.chat-message--highlighted` with default yellow background (`#3a3500` dark-theme friendly)
   - Support for custom highlight colors via inline style override

4. **Template modification** — apply highlight class:
   - Add conditional `chat-message--highlighted` class to message div
   - Add inline `background-color` style when custom color is set

### Phase 2: TreeBar Flash for Non-Active Channels (US2)

**Goal**: When a highlight occurs in a non-active channel, its treebar entry flashes.

1. **New assign `highlight_channels`** (MapSet) in ChatLive:
   - Populated when highlight occurs in non-active channel
   - Cleared when user switches to the channel

2. **TreeBar component modification**:
   - Accept `highlight_channels` assign
   - Apply `tree-highlight` CSS class when channel is in highlight set

3. **CSS flash animation** in `dark-theme.css`:
   - `@keyframes tree-flash` — alternating background color
   - `.tree-highlight` applies the animation (infinite until class removed)

4. **HighlightFlashHook** (JS) — optional, for smoother animation control:
   - Manages CSS animation start/stop
   - Clears flash when channel becomes active

### Phase 3: Notification Sound (US3)

**Goal**: Play a sound when a highlight is triggered.

1. **Leverage existing SoundHook** — already has `"mention"` sound type (880Hz sine, 150ms)
2. **ChatLive push_event** — when highlight detected, push `play_sound` event with type `"mention"`
3. **Mute awareness** — check if channel is in a "muted" set (deferred if mute feature doesn't exist yet; document the hook point)
4. **Sound cooldown** — SoundHook already handles rapid-fire gracefully via Web Audio API scheduling

### Phase 4: Custom Highlight Words (US4)

**Goal**: Users can configure additional words that trigger highlighting.

1. **`Chat.HighlightWords` module** — in-memory CRUD:
   - `new()` → `%{entries: []}`
   - `add_entry(list, word, bg_color \\ nil)` → validates, appends `%HighlightWord{}`
   - `remove_entry(list, word)` → filters out
   - `update_entry(list, word, attrs)` → update color/word
   - `entries(list)` → sorted list
   - Max 50 entries enforced

2. **`HighlightWord` struct**:
   - `word: String.t()` (required, 1-50 chars)
   - `bg_color: integer() | nil` (0-15 IRC color index, nil = default highlight color)
   - `position: integer()` (list order for priority)

3. **Session extension**:
   - Add `highlight_words: map()` field (default: `HighlightWords.new()`)
   - Add `set_highlight_words/2` and `get_highlight_words/1`

4. **ChatLive integration update**:
   - Pass `session.highlight_words.entries` to `Chat.Highlight.check/4`
   - Highlight engine already supports custom words from Phase 1

### Phase 5: Configuration Dialog + Persistence (US5)

**Goal**: UI for managing highlight words; persistence for registered users.

1. **Migration**: `highlight_words` table:
   - `owner_nickname` (FK → registered_nicks, CASCADE)
   - `word` (string, max 50)
   - `bg_color` (integer, nullable, 0-15)
   - `position` (integer)
   - Unique index: `(lower(owner_nickname), lower(word))`

2. **`HighlightWordEntry` Ecto schema** — maps to `highlight_words` table

3. **Persistence in `Chat.HighlightWords`**:
   - `save(owner, highlight_words)` — full replace pattern (delete all + insert all)
   - `load(owner)` → `{:ok, map} | {:error, :not_found}`

4. **NickServ identify integration** — load highlight words alongside notify_list/contacts/nick_colors

5. **`HighlightDialog` component** (98.css):
   - Window chrome with title "Highlight Words"
   - List showing current words with color indicators
   - Own nick shown as non-removable first entry
   - Add/Edit/Remove buttons
   - Color picker (reuse 16-color IRC palette from formatting toolbar)
   - Accessible via menu bar item or keyboard shortcut (Alt+H)

6. **`maybe_persist_highlight_words/2`** helper in ChatLive — async save on change (same pattern as notify_list)

7. **Nick change handling** — when user changes nick, the matching engine automatically uses the new `session.nickname` (no stored reference to update)
