# Contracts: Autocomplete Events

**Feature**: 023-autocomplete-system
**Date**: 2026-02-13

## Overview

All autocomplete interaction flows through LiveView events between the JS hook (`AutocompleteHook`) and the ChatLive LiveView. This document defines the event contracts.

## Client → Server Events (pushEvent)

### autocomplete_query

Triggered when user input matches a trigger pattern. Replaces the current `open_command_palette` and `filter_command_palette` events.

```elixir
# Event name: "autocomplete_query"
# Payload:
%{
  "type" => "command" | "nick" | "channel" | "arg_nick" | "arg_channel",
  "partial" => String.t(),    # text after trigger char (e.g., "jo" for "/jo")
  "command" => String.t()     # only for arg_* types: the command name (e.g., "join")
}
```

**Trigger conditions**:
- `type: "command"` → input starts with `/` and no space yet
- `type: "nick"` → `@` found at word boundary, followed by 1+ chars
- `type: "channel"` → `#` found at word boundary, followed by 1+ chars
- `type: "arg_nick"` → input matches `/cmd ` where cmd expects a nick argument
- `type: "arg_channel"` → input matches `/cmd ` or `/cmd #` where cmd expects a channel argument

### autocomplete_close

Triggered when autocomplete should be dismissed.

```elixir
# Event name: "autocomplete_close"
# Payload: %{}
```

**Trigger conditions**:
- User presses Escape
- User deletes back past the trigger character
- Input loses focus
- No trigger pattern matches current input

### autocomplete_select

Triggered when user confirms a selection from the dropdown.

```elixir
# Event name: "autocomplete_select"
# Payload:
%{
  "type" => "command" | "nick" | "channel",
  "value" => String.t()       # the selected value (command name, nickname, channel name)
}
```

**Trigger conditions**:
- User presses Tab or Enter while dropdown is open with a highlighted item
- User clicks an item in the dropdown

### autocomplete_navigate

Triggered when user navigates the dropdown with arrow keys.

```elixir
# Event name: "autocomplete_navigate"
# Payload:
%{
  "direction" => "up" | "down"
}
```

### tab_complete

Enhanced version of existing event. Now supports cycling.

```elixir
# Event name: "tab_complete"
# Payload:
%{
  "partial" => String.t(),    # text to complete (without trigger char)
  "is_start" => boolean()     # true if partial is at position 0 of input
}
```

### save_recent_command

Triggered when a command is executed (not just selected from autocomplete).

```elixir
# Event name: "save_recent_command"
# Handled entirely in JS hook (localStorage write). No server round-trip.
```

## Server → Client Events (push_event)

### autocomplete_results

Pushed after processing `autocomplete_query`. Updates the dropdown content.

```elixir
# Event name: "autocomplete_results"
# Payload:
%{
  "results" => [
    # Command results:
    %{"type" => "command", "name" => "join", "description" => "Join a channel",
      "category" => "Canal", "recent" => false, "score" => 1000,
      "matched_chars" => [0, 1]},
    # Nick results:
    %{"type" => "nick", "nickname" => "Mario", "status" => "online",
      "color" => "#ff0000", "self" => false, "score" => 500},
    # Channel results:
    %{"type" => "channel", "name" => "#dev", "user_count" => 5,
      "joined" => true, "score" => 800}
  ],
  "mode" => "command" | "nick" | "channel"
}
```

### tab_matches

Pushed in response to `tab_complete`. Provides the match list for client-side cycling.

```elixir
# Event name: "tab_matches"
# Payload:
%{
  "matches" => ["Mario", "Marcelo", "Martin"],  # ordered alphabetically
  "is_start" => true                              # echoed back for colon logic
}
```

### set_input

Pushed when server needs to update the input value (e.g., after autocomplete selection on server side).

```elixir
# Event name: "set_input"
# Payload:
%{
  "value" => String.t()       # new input field value
}
```

## Domain API Contracts

### RetroHexChat.Commands.Autocomplete

```elixir
@spec fuzzy_match(String.t(), String.t()) :: {:match, non_neg_integer(), [non_neg_integer()]} | :no_match
# Returns match score and indices of matched characters, or :no_match

@spec search_commands(String.t(), [String.t()]) :: [command_result()]
# Search commands with fuzzy matching, returns scored and sorted results
# Second arg is recent commands list (from client)

@spec search_nicks(String.t(), [map()], String.t()) :: [nick_result()]
# Search nicks from channel_users list, deprioritizing own nick (third arg)

@spec search_channels(String.t(), [String.t()]) :: [channel_result()]
# Search visible channels, marking joined ones (second arg is user's channels)

@spec argument_context(String.t()) :: {:nick, String.t()} | {:channel, String.t()} | nil
# Given a command name, returns what type of argument it expects
# e.g., argument_context("msg") → {:nick, ""}, argument_context("join") → {:channel, ""}
```

### RetroHexChat.Commands.Registry (enhanced)

```elixir
# Existing:
@spec list_commands() :: [String.t()]
@spec lookup(String.t()) :: {:ok, module()} | {:error, :unknown_command}

# New:
@spec commands_by_category() :: [{String.t(), [%{name: String.t(), description: String.t()}]}]
# Returns commands grouped by category label, ordered by category order

@spec command_metadata() :: [%{name: String.t(), description: String.t(), category: String.t()}]
# Returns all commands with metadata for autocomplete rendering
```

### RetroHexChat.Commands.Handler (enhanced behaviour)

```elixir
# Existing callbacks:
@callback validate(String.t()) :: :ok | {:error, String.t()}
@callback execute([String.t()], context()) :: result()
@callback help() :: %{name: String.t(), syntax: String.t(), description: String.t(), examples: [String.t()]}

# New callback:
@callback category() :: :basics | :channel | :user | :config | :advanced
```

## Event Flow Diagrams

### Command Autocomplete Flow

```
User types "/"
  → Hook: keyup detects "/" at pos 0
  → pushEvent("autocomplete_query", {type: "command", partial: ""})
  → Server: Autocomplete.search_commands("", recent_commands)
  → push_event("autocomplete_results", {results: [...], mode: "command"})
  → Hook: renders dropdown

User types "j" (now "/j")
  → Hook: keyup detects "/" at pos 0, partial = "j"
  → pushEvent("autocomplete_query", {type: "command", partial: "j"})
  → Server: Autocomplete.search_commands("j", recent_commands)
  → push_event("autocomplete_results", {results: [join, autojoin], mode: "command"})

User presses Tab
  → pushEvent("autocomplete_select", {type: "command", value: "join"})
  → Server: assign input = "/join ", close autocomplete
  → Hook: checks if "join" expects arguments → type: "arg_channel"
  → Waits for user to type "#" to trigger argument completion
```

### Nick @ Trigger Flow

```
User types "@m" (after space or at start)
  → Hook: keyup detects "@" at word boundary, partial = "m"
  → pushEvent("autocomplete_query", {type: "nick", partial: "m"})
  → Server: Autocomplete.search_nicks("m", channel_users, own_nick)
  → push_event("autocomplete_results", {results: [...], mode: "nick"})

User presses Enter on "Mario"
  → pushEvent("autocomplete_select", {type: "nick", value: "Mario"})
  → Server: replaces "@m" with "@Mario " in input
```

### Tab Cycling Flow (IRC-style, no dropdown)

```
User types "Mar" (at start of input) + Tab
  → Hook: pushEvent("tab_complete", {partial: "Mar", is_start: true})
  → Server: finds matches ["Marcelo", "Mario", "Martin"]
  → push_event("tab_matches", {matches: [...], is_start: true})
  → Hook: inserts "Marcelo: " (first match, with colon for start)
  → Hook: stores {original: "Mar", matches: [...], index: 0, is_start: true}

User presses Tab again
  → Hook: increments index to 1, inserts "Mario: " (no server call)

User presses Tab again
  → Hook: increments index to 2, inserts "Martin: " (no server call)

User types any other key
  → Hook: clears cycling state
```
