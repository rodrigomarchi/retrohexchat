# Quickstart: Autocomplete System

**Feature**: 023-autocomplete-system
**Date**: 2026-02-13

## Prerequisites

```bash
make setup    # if not already done
make server   # verify app starts cleanly
make test     # verify all tests pass
make lint     # verify all static analysis passes
```

## Implementation Order

The feature is designed as 4 independent stories (P1–P4) that build incrementally:

### Phase 1: Enhanced Command Palette (P1)

**Goal**: Fuzzy search, categories, recent commands in existing palette.

1. **Domain**: Add `category/0` callback to Handler behaviour
2. **Domain**: Implement `Commands.Autocomplete` module with `fuzzy_match/2` and `search_commands/2`
3. **Registry**: Add `commands_by_category/0` and `command_metadata/0` functions
4. **Handler updates**: Add `category/0` to all 42+ handler modules
5. **Component**: Evolve `command_palette.ex` → `autocomplete_dropdown.ex` with category grouping
6. **JS Hook**: Evolve `command_palette_hook.js` → `autocomplete_hook.js` with fuzzy filter + recent commands (localStorage)
7. **Events**: Update `menu_toolbar_events.ex` to use new autocomplete events
8. **CSS**: Update `components.css` for category headers, match highlighting

### Phase 2: Nick Autocomplete (P2)

**Goal**: `@` trigger dropdown + enhanced Tab cycling.

1. **Domain**: Add `search_nicks/3` to `Commands.Autocomplete`
2. **JS Hook**: Add `@` word-boundary trigger detection
3. **Component**: Add `:nick` mode to dropdown (status icons, colors)
4. **Events**: Add nick autocomplete event handlers
5. **Tab cycling**: Enhance `tab_complete` in `core_events.ex` for multi-match cycling
6. **JS Hook**: Add Tab-cycling state management (client-side)

### Phase 3: Argument Completion (P3)

**Goal**: Context-aware suggestions after command selection.

1. **Domain**: Add `argument_context/1` to map commands → expected arg types
2. **JS Hook**: Detect command argument context after space
3. **Events**: Route argument completion to appropriate search function
4. **Component**: Reuse `:nick` and `:channel` modes for argument results

### Phase 4: Channel Autocomplete (P4)

**Goal**: `#` trigger dropdown in free-form messages.

1. **Domain**: Add `search_channels/2` to `Commands.Autocomplete`, extract channel listing from `ChannelListLive`
2. **JS Hook**: Add `#` word-boundary trigger detection
3. **Component**: Add `:channel` mode to dropdown (user count, joined badge)
4. **Events**: Add channel autocomplete event handlers

### Phase 5: Polish & Help

1. **Help topic**: Add "Autocomplete" to `HelpTopics.Features`
2. **Keyboard shortcuts**: Update "Keyboard Shortcuts" help topic
3. **Edge cases**: No results message, viewport repositioning, secret channel filtering

## Key Files to Understand

| File | Purpose | Read Before |
|------|---------|-------------|
| `commands/registry.ex` | Command list + lookup | Phase 1 |
| `components/command_palette.ex` | Current dropdown component | Phase 1 |
| `hooks/command_palette_hook.js` | Current JS hook | Phase 1 |
| `chat_live/menu_toolbar_events.ex` | Palette event handlers | Phase 1 |
| `chat_live/core_events.ex` | Tab complete handler | Phase 2 |
| `presence/tracker.ex` | Nick listing per channel | Phase 2 |
| `channels/server.ex` | Channel state queries | Phase 4 |
| `live/channel_list_live.ex` | Channel listing pattern | Phase 4 |
| `chat/help_topics/features.ex` | Help topic format | Phase 5 |

## Running Tests

```bash
# Run all tests
mix test --include e2e

# Run only autocomplete tests (once created)
mix test test/retro_hex_chat/commands/autocomplete_test.exs
mix test test/retro_hex_chat_web/components/autocomplete_dropdown_test.exs
mix test test/retro_hex_chat_web/live/autocomplete_test.exs

# Full CI validation
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix test --include e2e
mix dialyzer
```

## Architecture Notes

- **No new database tables** — all data from runtime state
- **No new GenServers** — queries existing Channel Registry + Presence
- **Minimal JS** — hook handles trigger detection + cursor management + Tab cycling; server handles matching + rendering
- **Single dropdown component** — mode-based rendering for commands/nicks/channels
- **localStorage for recent commands** — client-only, no server persistence
