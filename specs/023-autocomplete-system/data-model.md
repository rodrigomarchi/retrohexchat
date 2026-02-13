# Data Model: Autocomplete System

**Feature**: 023-autocomplete-system
**Date**: 2026-02-13

## Overview

No new database tables or migrations required. All autocomplete data is sourced from existing runtime state. This document defines the in-memory data structures used for matching, rendering, and state management.

## Entities

### AutocompleteResult

A unified result item returned by any autocomplete query. Polymorphic via the `type` field.

```elixir
@type autocomplete_result :: command_result() | nick_result() | channel_result()

@type command_result :: %{
  type: :command,
  name: String.t(),             # e.g., "join"
  description: String.t(),      # e.g., "Join a channel"
  category: String.t(),         # e.g., "Canal"
  recent?: boolean(),           # true if in user's recent commands
  score: non_neg_integer()      # fuzzy match score (higher = better)
}

@type nick_result :: %{
  type: :nick,
  nickname: String.t(),         # e.g., "Mario"
  status: :online | :away,      # from Presence tracker
  away_message: String.t() | nil,
  color: String.t() | nil,      # nick color if set
  self?: boolean(),             # true if this is the current user
  score: non_neg_integer()
}

@type channel_result :: %{
  type: :channel,
  name: String.t(),             # e.g., "#dev"
  user_count: non_neg_integer(),
  topic: String.t() | nil,
  joined?: boolean(),           # true if user is a member
  score: non_neg_integer()
}
```

### CommandCategory

Static mapping from category atom to display label. Compile-time constant.

```elixir
@type command_category :: %{
  id: atom(),                   # e.g., :basics
  label: String.t(),            # e.g., "Básicos"
  order: non_neg_integer()      # display order in dropdown
}
```

**Predefined categories** (ordered):

| Order | ID | Label |
|-------|----|-------|
| 0 | :recent | Recentes |
| 1 | :basics | Básicos |
| 2 | :channel | Canal |
| 3 | :user | Usuário |
| 4 | :config | Configuração |
| 5 | :advanced | Avançado |

### AutocompleteState (LiveView assigns)

New and modified assigns tracked in the ChatLive socket.

```elixir
# Replaces command_palette_visible and command_palette_filter
@type autocomplete_assigns :: %{
  autocomplete_visible: boolean(),         # dropdown visibility
  autocomplete_mode: :command | :nick | :channel | :arg_nick | :arg_channel | nil,
  autocomplete_results: [autocomplete_result()],  # current results to display
  autocomplete_filter: String.t(),         # current partial text
  autocomplete_selected: non_neg_integer(), # index of highlighted item (0-based)
  # Tab cycling state (for IRC-style nick completion without dropdown)
  tab_cycle_matches: [String.t()],         # ordered list of matching nicknames
  tab_cycle_index: non_neg_integer(),      # current position in cycle
  tab_cycle_partial: String.t() | nil      # original partial before first Tab
}
```

### RecentCommands (localStorage)

Client-side persistence. Managed by JS hook.

```json
{
  "retro_hex_chat_recent_commands": ["join", "msg", "nick", "away", "help"]
}
```

**Invariants**:
- Maximum 5 entries
- Most recent first
- No duplicates (re-use moves to front)
- Stored as command names without `/` prefix

## Data Sources

### Commands → CommandRegistry

```
RetroHexChat.Commands.Registry.list_commands() → [String.t()]
RetroHexChat.Commands.Registry.lookup(name) → {:ok, handler_module} | {:error, :unknown_command}
handler_module.help() → %{name, syntax, description, examples}
handler_module.category() → atom()  # NEW callback
```

### Nicks → Presence Tracker

```
RetroHexChat.Presence.Tracker.list_users("channel:#{channel_name}") → [%{nickname, away, away_message, ...}]
```

### Channels → Channel Registry + Server

```
Registry.select(...) → [{channel_name, pid}]
RetroHexChat.Channels.Server.get_state(channel_name) → {:ok, %{name, topic, member_count, modes_detail, ...}}
```

## State Transitions

### Autocomplete Lifecycle

```
CLOSED → OPEN (trigger detected)
  ├─ User types trigger char (/, @, #) at word boundary
  ├─ Server computes results
  └─ autocomplete_visible = true, results populated

OPEN → FILTERING (user types more characters)
  ├─ Each keystroke updates autocomplete_filter
  ├─ Server recomputes results with new filter
  └─ autocomplete_selected resets to 0

OPEN → NAVIGATING (↑/↓ arrows)
  ├─ autocomplete_selected increments/decrements
  └─ Wraps around at boundaries

OPEN/FILTERING/NAVIGATING → SELECTED (Tab/Enter)
  ├─ Selected result text inserted into input
  ├─ autocomplete_visible = false
  └─ For commands: may transition to argument completion

OPEN/FILTERING/NAVIGATING → CLOSED (Escape, trigger deletion, blur)
  └─ autocomplete_visible = false, results cleared
```

### Tab Cycling Lifecycle (IRC-style, no dropdown)

```
IDLE → CYCLING (Tab pressed with partial text, no @ trigger)
  ├─ Server computes matches, sends via push_event
  ├─ First match inserted
  └─ tab_cycle_matches + tab_cycle_index stored in hook

CYCLING → CYCLING (Tab pressed again)
  ├─ Next match inserted (no server round-trip)
  └─ tab_cycle_index incremented (wraps)

CYCLING → IDLE (any non-Tab key pressed)
  └─ Cycling state cleared
```

## Relationships

```
CommandRegistry ──1:N──→ Handler modules ──1:1──→ CommandCategory
                                          ──1:1──→ help() metadata

Presence.Tracker ──1:N──→ channel users (per topic)

Channels.Registry ──1:N──→ Channel.Server processes
                                    ──1:1──→ channel state (modes, membership, topic)

AutocompleteHook (JS) ──push_event──→ ChatLive ──delegates──→ Autocomplete module
                      ←─push_event──          ←─results────
```
